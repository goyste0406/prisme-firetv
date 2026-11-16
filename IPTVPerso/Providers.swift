import Foundation
import SwiftUI

/// Un fournisseur Xtream (plusieurs possibles). Les identifiants restent sur l'Apple TV.
/// Les champs ajoutés depuis la 1.7 sont facultatifs : une liste enregistrée par une version précédente se relit telle quelle.
struct Provider: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var server: String
    var username: String
    /// En mémoire seulement : sur le disque, le mot de passe est dans le trousseau Apple dès que `pwKeychain` vaut true.
    var password: String
    var on: Bool = true
    var lastImport: Date?
    var counts: [String: Int] = [:]   // "live", "vod", "series", "epg"
    var expires: Date?
    /// fuseau horaire du serveur (replay) ; absent dans les anciennes installations, repris au prochain import
    var tz: String?
    // --- 1.7 : état propre à chaque fournisseur
    /// mot de passe rangé dans le trousseau (et retiré de la liste enregistrée)
    var pwKeychain: Bool?
    /// dernière erreur de CE fournisseur (nil = la dernière tentative a réussi)
    var lastError: String?
    /// date de la dernière tentative de mise à jour (réussie ou non)
    var lastTry: Date?
    /// couleur choisie à l'ajout (repère du fournisseur dans les réglages et les sources)
    var color: Int?
    /// temps de réponse mesuré (ms), connexions autorisées, état de l'abonnement annoncé par le serveur
    var ping: Int?
    var maxConn: Int?
    var subStatus: String?
    /// catégories masquées (« live:12 », « vod:40 ») : leurs contenus ne sont pas chargés
    var hidden: [String]?
    /// types non importés (« live », « vod », « series »), choisis à l'ajout
    var skip: [String]?

    var account: XtreamAccount { XtreamAccount(server: server, username: username, password: password) }

    /// État lisible du fournisseur (réglages, sources)
    enum Health: Equatable { case off, never, ok, expired, failing(String) }
    var health: Health {
        if !on { return .off }
        if let e = expires, e < Date() { return .expired }
        if let e = lastError { return .failing(e) }
        return lastImport == nil ? .never : .ok
    }

    /// Couleurs des fournisseurs (simulateur, PVCOL2)
    static let colors: [Color] = [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.93, green: 0.28, blue: 0.60), Color(red: 0.13, green: 0.77, blue: 0.37),
                                  Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.66, green: 0.33, blue: 0.97), Color(red: 0.94, green: 0.27, blue: 0.27),
                                  Color(red: 0.08, green: 0.72, blue: 0.65)]
    var tint: Color { Provider.colors[(color ?? (Int(id.filter(\.isNumber).suffix(4)) ?? 0)) % Provider.colors.count] }
}

/// Liste des fournisseurs + état de l'import en cours (affiché dans les réglages et sur l'accueil).
/// Chaque fournisseur garde son propre état (dernière erreur, dernière tentative) : la panne de l'un
/// n'empêche jamais les autres de se mettre à jour ni de s'afficher.
@MainActor
final class ProviderStore: ObservableObject {
    static let shared = ProviderStore()
    private let key = "prisme.providers"

    @Published var providers: [Provider] = [] { didSet { save() } }
    @Published var importing: String?          // id du fournisseur en cours d'import (un à la fois)
    @Published var progress: Double = 0
    @Published var status: String = ""
    /// dernière erreur, tous fournisseurs confondus (compatibilité) ; l'erreur de chacun est dans `Provider.lastError`
    var lastError: String? { providers.first { $0.on && $0.lastError != nil }.map { "\($0.name) : \($0.lastError!)" } }
    /// Change à chaque import terminé : les écrans se rechargent.
    @Published var catalogVersion = 0
    /// premier lancement : le parcours d'ajout reste affiché jusqu'au bout, même une fois le fournisseur créé
    @Published var onboarding = false
    /// résultat de la migration du mot de passe vers le trousseau (simulateur de test : écrit dans donnees.txt)
    private(set) var keychainNote = ""

    private var tried = Set<String>()
    private var pending: [String] = []
    private func next() { if !pending.isEmpty { refresh(pending.removeFirst()) } else { refreshIfStale() } }

    /// Copie lisible depuis n'importe quel fil (lecteurs) ; tenue à jour à chaque changement.
    private nonisolated(unsafe) static var snapshot: [Provider] = []
    private nonisolated static let lock = NSLock()

    private init() {
        var list: [Provider] = []
        if let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode([Provider].self, from: d) {
            list = p
        } else if let d = UserDefaults.standard.data(forKey: "xtream_account"),
                  let old = try? JSONDecoder().decode(XtreamAccount.self, from: d) {
            // compte de la version précédente : repris tel quel, rien n'est perdu
            list = [Provider(id: "p1", name: "Mon fournisseur", server: old.server, username: old.username, password: old.password)]
        }
        // mots de passe : relus dans le trousseau ; ceux encore dans la liste y sont copiés, vérifiés, puis seulement retirés
        var notes: [String] = []
        for i in list.indices {
            if list[i].pwKeychain == true {
                if let pw = Keychain.get(list[i].id) { list[i].password = pw; notes.append("\(list[i].name): lu dans le trousseau") }
                else { notes.append("\(list[i].name): ABSENT du trousseau") }
            } else if !list[i].password.isEmpty {
                if Keychain.set(list[i].password, for: list[i].id), Keychain.get(list[i].id) == list[i].password {
                    list[i].pwKeychain = true; notes.append("\(list[i].name): copié dans le trousseau et vérifié")
                } else { notes.append("\(list[i].name): trousseau indisponible, gardé dans la liste") }
            }
        }
        keychainNote = notes.joined(separator: " · ")
        providers = list
        // simulateur de test uniquement (argument de lancement) : faux fournisseur local
        if providers.isEmpty, let demo = Debug.demoServer {
            providers = [Provider(id: "demo", name: "Lune", server: demo, username: "demo", password: "demo")]
        }
        if let demo = Debug.demoServer {
            // visite « gros catalogue » : le faux fournisseur change d'adresse → catalogue réimporté (tests seulement)
            if let i = providers.firstIndex(where: { $0.id == "demo" }), providers[i].server != demo { providers[i].server = demo; providers[i].lastImport = nil }
            if let s2 = Debug.demoServer2, provider("demo2") == nil {
                providers.append(Provider(id: "demo2", name: "Soleil", server: s2, username: "demo", password: "demo", color: 1))
            }
            if let down = Debug.demoDown, provider("demo3") == nil {
                providers.append(Provider(id: "demo3", name: "Étoile", server: down, username: "demo", password: "demo", color: 3))
            }
        }
        save()
    }

    private func save() {
        // sur le disque : jamais un mot de passe déjà rangé dans le trousseau
        let disk = providers.map { p -> Provider in var x = p; if x.pwKeychain == true { x.password = "" }; return x }
        if let d = try? JSONEncoder().encode(disk) { UserDefaults.standard.set(d, forKey: key) }
        ProviderStore.lock.lock(); ProviderStore.snapshot = providers; ProviderStore.lock.unlock()
    }

    var active: [Provider] { providers.filter { $0.on } }
    func provider(_ id: String) -> Provider? { providers.first { $0.id == id } }

    /// Lecture des fournisseurs depuis n'importe quel fil (le lecteur n'est pas sur l'acteur principal).
    nonisolated static func sharedProvider(_ id: String) -> Provider? {
        lock.lock(); defer { lock.unlock() }
        return snapshot.first { $0.id == id }
    }

    func add(name: String, server: String, user: String, pass: String, color: Int? = nil) async throws {
        let p = Provider(id: "p" + String(Int(Date().timeIntervalSince1970)), name: name.isEmpty ? "Fournisseur \(providers.count + 1)" : name,
                         server: server, username: user, password: pass, color: color ?? providers.count % Provider.colors.count)
        try await XtreamAPI(account: p.account).authenticate()
        var q = p
        if Keychain.set(pass, for: p.id), Keychain.get(p.id) == pass { q.pwKeychain = true }
        providers.append(q)
        refresh(q.id)
    }

    /// Ajoute un fournisseur déjà vérifié (parcours en 4 étapes) et lance son import. Renvoie son identifiant.
    @discardableResult
    func addVerified(name: String, server: String, user: String, pass: String, color: Int, hidden: [String], skip: [String], ping: Int?, maxConn: Int?, expires: Date?) -> String {
        var p = Provider(id: "p" + String(Int(Date().timeIntervalSince1970)), name: name, server: server, username: user, password: pass,
                         expires: expires, color: color, ping: ping, maxConn: maxConn, hidden: hidden.isEmpty ? nil : hidden, skip: skip.isEmpty ? nil : skip)
        if Keychain.set(pass, for: p.id), Keychain.get(p.id) == pass { p.pwKeychain = true }
        providers.append(p)
        refresh(p.id)
        return p.id
    }

    /// Temps de réponse de chaque fournisseur actif (sans ouvrir aucun flux)
    func testServers() async {
        for p in active {
            let t0 = Date()
            do {
                try await XtreamAPI(account: p.account).authenticate()
                if let i = providers.firstIndex(where: { $0.id == p.id }) { providers[i].ping = Int(Date().timeIntervalSince(t0) * 1000) }
            } catch {
                if let i = providers.firstIndex(where: { $0.id == p.id }) { providers[i].ping = nil; providers[i].lastError = ProviderStore.message(error); providers[i].lastTry = Date() }
            }
        }
    }

    /// Change le nom, la couleur ou les identifiants d'un fournisseur (sans toucher à son catalogue).
    func update(_ p: Provider) {
        guard let i = providers.firstIndex(where: { $0.id == p.id }) else { return }
        var q = p
        if q.password != providers[i].password || q.pwKeychain != true {
            q.pwKeychain = (Keychain.set(q.password, for: q.id) && Keychain.get(q.id) == q.password) ? true : nil
        }
        providers[i] = q
    }

    func remove(_ id: String) {
        providers.removeAll { $0.id == id }
        Keychain.remove(id)
        Task.detached(priority: .utility) {
            let db = Database.shared
            await db.read { db in
                for t in ["category", "live", "vod", "series"] { db.run("DELETE FROM \(t) WHERE pid=?", [id]) }
            }
            await MainActor.run { ProviderStore.shared.catalogVersion += 1 }
        }
    }

    func toggle(_ id: String) {
        if let i = providers.firstIndex(where: { $0.id == id }) { providers[i].on.toggle(); catalogVersion += 1 }
    }

    /// Télécharge le catalogue d'un fournisseur en arrière-plan (l'écran reste utilisable).
    /// Un seul import à la fois (certains abonnements n'autorisent qu'une connexion) ; les autres attendent leur tour.
    func refresh(_ id: String) {
        guard let p = provider(id) else { return }
        if importing != nil { if !pending.contains(id) && importing != id { pending.append(id) }; return }
        importing = id; progress = 0; status = "Connexion à \(p.name)…"
        PerfLog.ev("Import \(p.name) début")
        let t0 = Date()
        Task.detached(priority: .utility) {
            do {
                let res = try await CatalogImporter(provider: p).run { pct, msg in
                    Task { @MainActor in ProviderStore.shared.progress = pct; ProviderStore.shared.status = msg }
                }
                await MainActor.run {
                    let s = ProviderStore.shared
                    if let i = s.providers.firstIndex(where: { $0.id == id }) {
                        var x = s.providers[i]
                        x.lastImport = Date(); x.lastTry = Date(); x.lastError = res.warning
                        x.counts = res.counts; x.expires = res.expires
                        if let tz = res.tz { x.tz = tz }
                        x.ping = res.ping; x.maxConn = res.maxConn; x.subStatus = res.subStatus
                        s.providers[i] = x
                    }
                    s.importing = nil; s.status = ""; s.catalogVersion += 1
                    PerfLog.ev("Import \(p.name) : \(Int(Date().timeIntervalSince(t0) * 1000)) ms · \(res.counts)\(res.warning.map { " · " + $0 } ?? "")")
                    s.next()
                }
            } catch {
                await MainActor.run {
                    let s = ProviderStore.shared
                    if let i = s.providers.firstIndex(where: { $0.id == id }) {
                        s.providers[i].lastTry = Date(); s.providers[i].lastError = ProviderStore.message(error)
                    }
                    s.importing = nil; s.status = ""; s.catalogVersion += 1
                    PerfLog.ev("Import \(p.name) : échec · \(ProviderStore.message(error))")
                    s.next()
                }
            }
        }
    }

    /// Message simple pour une erreur de connexion
    nonisolated static func message(_ e: Error) -> String {
        if let x = e as? XtreamError { return x.errorDescription ?? "Erreur du serveur." }
        let n = e as NSError
        if n.domain == NSURLErrorDomain {
            switch n.code {
            case NSURLErrorTimedOut: return "Le serveur ne répond pas (délai dépassé)."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed: return "Serveur injoignable."
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost: return "Pas de connexion Internet."
            default: return "Connexion impossible (\(n.code))."
            }
        }
        if e is DecodingError || n.domain == NSCocoaErrorDomain { return "Réponse du serveur illisible." }
        return e.localizedDescription
    }

    /// Au lancement : actualise les fournisseurs dont le catalogue a plus de 24 h (ou jamais importé).
    func refreshIfStale() {
        for p in active where !tried.contains(p.id) && (p.lastImport == nil || Date().timeIntervalSince(p.lastImport!) > 86400) {
            tried.insert(p.id); refresh(p.id); break
        }
    }
}
