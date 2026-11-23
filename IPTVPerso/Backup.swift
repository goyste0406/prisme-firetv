import Foundation
import Network
import SwiftUI

// MARK: - Sauvegarde (1.7.1)
//
// iCloud est impossible avec un compte Apple gratuit (droit réservé aux comptes développeur payants). À la place :
//  • sauvegarde sur l'iPhone : l'Apple TV ouvre une petite page sur le Wi-Fi (même principe que l'ajout de fournisseur) ;
//    l'iPhone y télécharge la sauvegarde, ou y renvoie une sauvegarde à restaurer ;
//  • synchronisation entre Apple TV : l'une se met « en réception » (visible sur le Wi-Fi), l'autre lui envoie ses données.
// Contenu : profils, Ma liste, reprises et historique, goûts, réglages, fournisseurs (avec leurs mots de passe).
// Pas le catalogue ni les fiches : ils se rechargent depuis les fournisseurs et TMDB.
// Une restauration remplace les données de cette Apple TV : elle est toujours confirmée sur la TV, et une copie des
// données d'avant est gardée sur l'Apple TV (« Annuler la dernière restauration »).

enum Backup {
    /// clés jamais copiées : propres à cet appareil ou recalculées
    private static let skip: Set<String> = ["prisme.tab", "prisme.xfr.last", "prisme.guide.last"]
    /// réglages de test (arguments de lancement du simulateur) : jamais sauvegardés ni restaurés
    private static func kept(_ k: String) -> Bool { k.hasPrefix("prisme.") && !k.hasPrefix("prisme.debug.") && !skip.contains(k) }
    private static var undoURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("prisme-avant-restauration.json") }

    /// Données de PRISME sous forme de fichier JSON (lisible, une sauvegarde par fichier).
    @MainActor static func export() -> Data {
        var keys: [String: Any] = [:]
        for (k, v) in UserDefaults.standard.dictionaryRepresentation() where kept(k) { keys[k] = v }
        let plist = (try? PropertyListSerialization.data(fromPropertyList: keys, format: .binary, options: 0)) ?? Data()
        // mots de passe des fournisseurs (gardés dans le trousseau, donc absents des réglages)
        var pw: [String: String] = [:]
        for p in ProviderStore.shared.providers { pw[p.id] = p.password }
        let o: [String: Any] = ["prisme": 1, "app": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                                "date": ISO8601DateFormatter().string(from: Date()), "device": UIDevice.current.name,
                                "profiles": ProfileStore.shared.profiles.map(\.name), "data": plist.base64EncodedString(), "pw": pw]
        return (try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted])) ?? Data()
    }

    struct Summary: Equatable { let date: String; let device: String; let profiles: [String]; let raw: Data }

    static func read(_ d: Data) -> Summary? {
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], o["prisme"] as? Int == 1, o["data"] is String else { return nil }
        let date = (o["date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }.map { Fmt.dateTime($0) } ?? "?"
        return Summary(date: date, device: o["device"] as? String ?? "?", profiles: o["profiles"] as? [String] ?? [], raw: d)
    }

    /// Remplace les données de cette Apple TV par la sauvegarde (copie des données d'avant gardée pour annuler).
    @MainActor static func restore(_ s: Summary) -> Bool {
        guard let o = try? JSONSerialization.jsonObject(with: s.raw) as? [String: Any], let b64 = o["data"] as? String, let plist = Data(base64Encoded: b64),
              let keys = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any] else { return false }
        try? export().write(to: undoURL, options: .atomic)
        let ud = UserDefaults.standard
        for k in ud.dictionaryRepresentation().keys where kept(k) { ud.removeObject(forKey: k) }
        for (k, v) in keys where kept(k) { ud.set(v, forKey: k) }
        for (id, p) in (o["pw"] as? [String: String]) ?? [:] where !p.isEmpty { _ = Keychain.set(p, for: id) }
        ud.synchronize()
        return true
    }

    static var canUndo: Bool { FileManager.default.fileExists(atPath: undoURL.path) }
    @MainActor static func undo() -> Bool {
        guard let d = try? Data(contentsOf: undoURL), let s = read(d) else { return false }
        let ok = restore(s)
        try? FileManager.default.removeItem(at: undoURL)
        return ok
    }
}

/// Petit serveur sur le Wi-Fi : page iPhone (télécharger / restaurer) et réception depuis une autre Apple TV.
@MainActor
final class BackupLink: ObservableObject {
    enum Mode { case phone, receive }
    @Published private(set) var address: String?
    @Published private(set) var failed: String?
    /// sauvegarde reçue (iPhone ou autre Apple TV), en attente de confirmation sur la TV
    @Published var received: Backup.Summary?
    @Published private(set) var downloads = 0
    private var listener: NWListener?
    private let token = String(UUID().uuidString.prefix(8)).lowercased()
    private let queue = DispatchQueue(label: "prisme.backup")
    let mode: Mode
    init(mode: Mode) { self.mode = mode }

    var qr: UIImage? { address.flatMap { PhonePairing.qrImage($0) } }

    func start() {
        guard listener == nil else { return }
        guard let ip = PhonePairing.wifiAddress() else { failed = "L'Apple TV n'a pas d'adresse sur le réseau local."; return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: 0)
            // en réception : visible des autres Apple TV de la maison (Bonjour)
            if mode == .receive { l.service = NWListener.Service(name: "prisme · " + UIDevice.current.name, type: "_prisme._tcp") }
            l.newConnectionHandler = { [weak self] c in self?.handle(c) }
            l.stateUpdateHandler = { [weak self] st in
                Task { @MainActor in
                    guard let self else { return }
                    switch st {
                    case .ready: if let p = l.port?.rawValue { self.address = "http://\(ip):\(p)/\(self.token)" }
                    case .failed(let e): self.failed = "Wi-Fi indisponible (\(e.localizedDescription))."
                    default: break
                    }
                }
            }
            l.start(queue: queue)
            listener = l
        } catch { failed = "Wi-Fi indisponible (\(error.localizedDescription))." }
    }

    func stop() { listener?.cancel(); listener = nil; address = nil }

    nonisolated private func handle(_ c: NWConnection) { c.start(queue: queue); receive(c, buffer: Data()) }

    nonisolated private func receive(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, err in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = BackupLink.request(buf) {
                Task { @MainActor in self.respond(c, req) }
            } else if done || err != nil || buf.count > 30_000_000 {
                c.cancel()
            } else {
                self.receive(c, buffer: buf)
            }
        }
    }

    nonisolated private static func request(_ d: Data) -> (String, String, Data)? {
        guard let end = d.range(of: Data("\r\n\r\n".utf8)), let head = String(data: d[..<end.lowerBound], encoding: .utf8) else { return nil }
        let body = d[end.upperBound...]
        let lines = head.split(separator: "\r\n")
        let parts = (lines.first.map(String.init) ?? "").split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        let len = lines.first { $0.lowercased().hasPrefix("content-length:") }.flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        guard body.count >= len else { return nil }
        return (parts[0], parts[1], Data(body.prefix(len)))
    }

    private func respond(_ c: NWConnection, _ r: (String, String, Data)) {
        let (method, path, body) = r
        var data: Data, type = "text/html; charset=utf-8", extra = ""
        // une autre Apple TV envoie sur « /sync » (elle ne connaît pas le code) : seulement en réception, toujours confirmé sur la TV
        let fromTV = mode == .receive && method == "POST" && path == "/sync"
        if !path.hasPrefix("/" + token) && !fromTV {
            data = Data(BackupLink.page("Code périmé", "Affiche à nouveau le code sur ta TV.", form: false).utf8)
        } else if method == "POST" {
            if let s = Backup.read(body) {
                received = s
                DataCount.write("sauvegarde reçue par le Wi-Fi (\(body.count) octets)")
                data = Data(BackupLink.page("Envoyé à la TV ✓", "Regarde ta TV : confirme la restauration avec la télécommande.", form: false).utf8)
            } else {
                DataCount.write("fichier refusé (\(body.count) octets)")
                data = Data(BackupLink.page("Fichier refusé", "Ce fichier n'est pas une sauvegarde de prisme.", form: false).utf8)
            }
        } else if path.hasSuffix("/prisme-chaines.txt") {
            // 253 : noms des chaînes et de leurs catégories, tels que les donne le fournisseur (pour régler le
            // regroupement des chaînes en double : Ligue 1+, beIN, Canal+ Sport…) — sans adresse ni mot de passe
            Task {
                let d = Data(await BackupLink.channelList().utf8)
                let h = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(d.count)\r\nContent-Disposition: attachment; filename=\"prisme-chaines.txt\"\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
                c.send(content: Data(h.utf8) + d, completion: .contentProcessed { _ in c.cancel() })
            }
            return
        } else if path.hasSuffix("/prisme-journal.txt") {
            // 253 : journal de diagnostic (écrans, blocages, fermetures inattendues) — sans mot de passe
            data = Data(DiagLog.text.utf8); type = "text/plain; charset=utf-8"
            extra = "Content-Disposition: attachment; filename=\"prisme-journal.txt\"\r\n"
        } else if path.hasSuffix("/prisme-sauvegarde.json") {
            data = Backup.export(); type = "application/json"
            extra = "Content-Disposition: attachment; filename=\"prisme-sauvegarde-\(Fmt.date(Date()).replacingOccurrences(of: " ", with: "-")).json\"\r\n"
            downloads += 1
        } else {
            data = Data(BackupLink.page("Sauvegarde de prisme", "", form: true).utf8)
        }
        let headStr = "HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\n\(extra)Connection: close\r\nCache-Control: no-store\r\n\r\n"
        c.send(content: Data(headStr.utf8) + data, completion: .contentProcessed { _ in c.cancel() })
    }

    /// fournisseur · catégorie · nom · clé de regroupement (deux chaînes de même clé sont regroupées)
    static func channelList() async -> String {
        let names = Dictionary(ProviderStore.shared.providers.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let rows: [(String, String, String)] = await Database.shared.read { db in
            var cats: [String: String] = [:]
            db.query("SELECT pid,cid,name FROM category WHERE type='live'", []) { r in cats[r.str(0) + ":" + r.str(1)] = r.str(2) }
            var L: [(String, String, String)] = []
            db.query("SELECT pid,cid,name FROM live ORDER BY pid,cid,num", []) { r in L.append((r.str(0), cats[r.str(0) + ":" + r.str(1)] ?? "?", r.str(2))) }
            return L
        }
        var out = "Chaînes de prisme (fournisseur · catégorie · nom de la chaîne · regroupée sous)\n\n"
        for (pid, cat, name) in rows {
            let ch = Channel(pid: pid, sid: "", name: name, num: 0, icon: "", cid: "", epg: "", archive: 0)
            out += (names[pid] ?? pid) + " · " + cat + " · " + name + " · " + ChannelTools.key(ch) + "\n"
        }
        return out
    }

    nonisolated static func page(_ title: String, _ msg: String, form: Bool) -> String {
        let css = """
        body{margin:0;background:#f2f2f7;color:#111;font-family:-apple-system,system-ui,sans-serif}
        .w{max-width:420px;margin:0 auto;padding:28px 18px;display:flex;flex-direction:column;gap:14px}
        h3{margin:0;font-size:22px}p{margin:0;font-size:14px;color:#555;line-height:1.45}
        a.go,button.go{display:block;text-align:center;text-decoration:none;border:0;background:#0a84ff;color:#fff;font-weight:700;font-size:17px;padding:14px;border-radius:14px}
        .card{background:#fff;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px}
        """
        let head = "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><title>prisme</title><style>\(css)</style><div class=w><h3>\(title)</h3>"
        guard form else { return head + "<p>\(msg)</p></div>" }
        return head + """
        <div class=card><b>Garder une copie sur l'iPhone</b><p>Profils, Ma liste, reprises, goûts, réglages et fournisseurs (avec leurs mots de passe : range ce fichier en lieu sûr, par exemple dans Fichiers › Sur mon iPhone).</p>
        <a class=go href="prisme-sauvegarde.json" download>Télécharger la sauvegarde</a></div>
        <div class=card><b>Liste des chaînes</b><p>Noms des chaînes et de leurs catégories chez tes fournisseurs (sans adresse ni mot de passe), pour régler le regroupement des chaînes en double.</p>
        <a class=go href="prisme-chaines.txt" download>Télécharger la liste</a></div>
        <div class=card><b>Journal de diagnostic</b><p>Écrans ouverts, blocages et fermetures inattendues de prisme (sans mot de passe). Utile pour comprendre un problème.</p>
        <a class=go href="prisme-journal.txt" download>Télécharger le journal</a></div>
        <div class=card><b>Restaurer une sauvegarde</b><p>Choisis un fichier « prisme-sauvegarde… .json ». La TV te demandera de confirmer : ses données actuelles seront remplacées (une copie est gardée pour annuler).</p>
        <input type=file id=f accept=".json,application/json"><button class=go id=b>Envoyer à la TV</button><p id=m></p></div></div>
        <script>b.onclick=async()=>{const x=f.files[0];if(!x){m.textContent='Choisis d\\'abord un fichier.';return}
        m.textContent='Envoi…';const r=await fetch(location.pathname,{method:'POST',body:await x.text()});document.open();document.write(await r.text());document.close()}</script>
        """
    }
}

/// Envoi vers une autre Apple TV : recherche des Apple TV « en réception » sur le Wi-Fi, puis envoi de la sauvegarde.
@MainActor
final class TVSender: ObservableObject {
    struct Peer: Identifiable, Hashable { let name: String; let endpoint: NWEndpoint; var id: String { name } }
    @Published private(set) var peers: [Peer] = []
    @Published var state: String?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "prisme.sync")

    func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: "_prisme._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] res, _ in
            let L = res.compactMap { r -> Peer? in
                if case let .service(name, _, _, _) = r.endpoint { return Peer(name: name, endpoint: r.endpoint) }
                return nil
            }.sorted { $0.name < $1.name }
            Task { @MainActor in self?.peers = L }
        }
        b.start(queue: queue)
        browser = b
    }
    func stop() { browser?.cancel(); browser = nil }

    /// Envoie la sauvegarde à l'Apple TV choisie (qui demande confirmation de son côté).
    func send(to p: Peer) {
        state = "Envoi à « \(p.name) »…"
        let payload = Backup.export()
        let c = NWConnection(to: p.endpoint, using: .tcp)
        c.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:
                // le chemin doit commencer par le code de la TV en réception : il est publié dans le nom du service
                // (Bonjour ne le donne pas) — la TV en réception accepte donc aussi « /sync »
                let head = "POST /sync HTTP/1.1\r\nHost: prisme\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
                c.send(content: Data(head.utf8) + payload, completion: .contentProcessed { err in
                    Task { @MainActor in self?.state = err == nil ? "Envoyé ✓ · confirme sur l'autre Apple TV" : "Envoi impossible." }
                    c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in c.cancel() }
                })
            case .failed, .cancelled:
                Task { @MainActor in if self?.state?.hasPrefix("Envoi à") == true { self?.state = "Envoi impossible." } }
            default: break
            }
        }
        c.start(queue: queue)
    }
}
