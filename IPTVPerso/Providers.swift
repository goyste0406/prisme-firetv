import Foundation
import SwiftUI

/// Un fournisseur Xtream (plusieurs possibles). Les identifiants restent sur l'Apple TV.
struct Provider: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var server: String
    var username: String
    var password: String
    var on: Bool = true
    var lastImport: Date?
    var counts: [String: Int] = [:]   // "live", "vod", "series", "epg"
    var expires: Date?

    var account: XtreamAccount { XtreamAccount(server: server, username: username, password: password) }
}

/// Liste des fournisseurs + état de l'import en cours (affiché dans les réglages et sur l'accueil).
@MainActor
final class ProviderStore: ObservableObject {
    static let shared = ProviderStore()
    private let key = "prisme.providers"

    @Published var providers: [Provider] = [] { didSet { save() } }
    @Published var importing: String?          // id du fournisseur en cours d'import
    @Published var progress: Double = 0
    @Published var status: String = ""
    @Published var lastError: String?
    /// Change à chaque import terminé : les écrans se rechargent.
    @Published var catalogVersion = 0

    private var tried = Set<String>()
    private var pending: [String] = []
    private func next() { if !pending.isEmpty { refresh(pending.removeFirst()) } else { refreshIfStale() } }

    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode([Provider].self, from: d) {
            providers = p
        } else if let d = UserDefaults.standard.data(forKey: "xtream_account"),
                  let old = try? JSONDecoder().decode(XtreamAccount.self, from: d) {
            // compte de la version précédente : repris tel quel, rien n'est perdu
            providers = [Provider(id: "p1", name: "Mon fournisseur", server: old.server, username: old.username, password: old.password)]
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(providers) { UserDefaults.standard.set(d, forKey: key) }
    }

    var active: [Provider] { providers.filter { $0.on } }
    func provider(_ id: String) -> Provider? { providers.first { $0.id == id } }

    func add(name: String, server: String, user: String, pass: String) async throws {
        let p = Provider(id: "p" + String(Int(Date().timeIntervalSince1970)), name: name.isEmpty ? "Fournisseur \(providers.count + 1)" : name,
                         server: server, username: user, password: pass)
        try await XtreamAPI(account: p.account).authenticate()
        providers.append(p)
        refresh(p.id)
    }

    func remove(_ id: String) {
        providers.removeAll { $0.id == id }
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
    func refresh(_ id: String) {
        guard let p = provider(id) else { return }
        if importing != nil { if !pending.contains(id) && importing != id { pending.append(id) }; return }
        importing = id; progress = 0; status = "Connexion…"; lastError = nil
        Task.detached(priority: .utility) {
            do {
                let res = try await CatalogImporter(provider: p).run { pct, msg in
                    Task { @MainActor in ProviderStore.shared.progress = pct; ProviderStore.shared.status = msg }
                }
                await MainActor.run {
                    let s = ProviderStore.shared
                    if let i = s.providers.firstIndex(where: { $0.id == id }) {
                        s.providers[i].lastImport = Date(); s.providers[i].counts = res.counts; s.providers[i].expires = res.expires
                    }
                    s.importing = nil; s.status = ""; s.catalogVersion += 1
                    s.next()
                }
            } catch {
                await MainActor.run {
                    let s = ProviderStore.shared
                    s.importing = nil; s.status = ""; s.lastError = error.localizedDescription; s.catalogVersion += 1
                    s.next()
                }
            }
        }
    }

    /// Au lancement : actualise les fournisseurs dont le catalogue a plus de 24 h (ou jamais importé).
    func refreshIfStale() {
        for p in active where !tried.contains(p.id) && (p.lastImport == nil || Date().timeIntervalSince(p.lastImport!) > 86400) {
            tried.insert(p.id); refresh(p.id); break
        }
    }
}
