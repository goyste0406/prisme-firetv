import Foundation
import SwiftUI
import Network
import CoreImage
import CoreImage.CIFilterBuiltins

// Ajout d'un fournisseur (simulateur : Connexion › Vérification › Contenu › Importation) : outils sans écran.

// MARK: - Lien collé (get.php, player_api.php, M3U, lien de chaîne)

struct LinkInfo: Equatable {
    var url: String
    var user: String
    var pass: String
    var m3u: Bool

    /// Même lecture que le simulateur (parseLink) : serveur, utilisateur et mot de passe trouvés dans le lien.
    static func parse(_ raw: String) -> LinkInfo? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let m = t.range(of: #"^https?://[^/?#\s]+"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let url = String(t[m])
        func q(_ k: String) -> String {
            guard let r = t.range(of: #"[?&]\#(k)=([^&\s#]+)"#, options: [.regularExpression, .caseInsensitive]) else { return "" }
            let v = t[r].split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
            return v.removingPercentEncoding ?? v
        }
        var user = q("username"), pass = q("password")
        if user.isEmpty, let r = t.range(of: #"^https?://[^/]+/(?:live|movie|series)/[^/\s]+/[^/\s]+/"#, options: [.regularExpression, .caseInsensitive]) {
            let parts = t[r].split(separator: "/").map(String.init)   // ["http:", "hôte", "live", "u", "p"]
            if parts.count >= 5 { user = parts[3].removingPercentEncoding ?? parts[3]; pass = parts[4].removingPercentEncoding ?? parts[4] }
        }
        let m3u = t.range(of: #"\.m3u8?(\?|$)|type=m3u"#, options: [.regularExpression, .caseInsensitive]) != nil
        return LinkInfo(url: url, user: user, pass: pass, m3u: m3u)
    }

    static func host(_ u: String) -> String {
        u.replacingOccurrences(of: #"^https?://"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"/.*$"#, with: "", options: .regularExpression)
    }
    /// Nom proposé d'après l'adresse (« monserveur.com » → « Monserveur »)
    static func serverName(_ u: String) -> String {
        let h = host(u).split(separator: ":").first.map(String.init) ?? ""
        let parts = h.split(separator: ".").map(String.init)
        guard parts.count > 1, Int(parts.last!) == nil else { return "" }
        let n = parts[parts.count - 2]
        return n.prefix(1).uppercased() + n.dropFirst()
    }
    static func normalized(_ u: String) -> String {
        var s = u.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"/(get|player_api)\.php.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        while s.hasSuffix("/") { s.removeLast() }
        if !s.isEmpty && s.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) == nil { s = "http://" + s }
        return s
    }
    static func urlOK(_ u: String) -> Bool {
        let n = normalized(u)
        return n.range(of: #"^https?://([\w-]+\.)+[a-z0-9-]{2,}(:\d{2,5})?$"#, options: [.regularExpression, .caseInsensitive]) != nil
            || n.range(of: #"^https?://\d{1,3}(\.\d{1,3}){3}(:\d{2,5})?$"#, options: .regularExpression) != nil
    }
    static func urlHint(_ u: String) -> (String, Bool) {
        if u.isEmpty { return ("", true) }
        if !urlOK(u) { return ("adresse incomplète", false) }
        return (normalized(u).range(of: #":\d+$"#, options: .regularExpression) != nil ? "✓ adresse complète" : "✓ adresse complète · sans port (souvent :8080)", true)
    }
}

// MARK: - Langue des catégories (simulateur : RL)

/// Classement d'une catégorie du fournisseur : française, francophone, à vérifier, autre langue, adultes.
struct CatLang: Equatable {
    enum Group: String { case fr, fo, chk, xx, adult }
    var g: Group
    var why: String
    var pct: Int = 0

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }
    static let FR = re(#"(^|[^a-z0-9])(fr|fra|fre|france|french|truefrench|vf|vff|vfq|vfi|vf2|vostfr|vost|stfr|subfrench|francais|francaises?)(?=$|[^a-z0-9])"#)
    static let FO = re(#"(^|[^a-z0-9])(be|bel|belgique|belgium|ca|qc|quebec|ch|suisse|swiss|lu|luxembourg|afrique|africain|francophones?|maghreb|dom-?tom|antilles|reunion)(?=$|[^a-z0-9])"#)
    static let XX = re(#"(^|[^a-z0-9])(en|eng|english|uk|gb|us|usa|american|de|ger|german|deutsch|deutschland|at|it|ita|italia|italian|italy|es|esp|spa|espana|spanish|latino|latam|mx|mexico|pt|por|portugal|portuguese|br|brasil|brazil|ar|arab|arabic|arabe|tr|tur|turk|turkish|turkiye|turkey|nl|dutch|nederland|pl|polska|polish|ru|rus|russia|russian|hindi|india|indian|pk|pakistan|urdu|punjabi|tamil|bangla|ex-?yu|yu|balkan|albania|greek|gr|ro|romania|bg|bulgaria|hu|hungary|cz|sk|se|swe|swedish|no|nor|dk|den|fi|fin|kurd|persian|iran|af|afghan|il|israel|cn|china|chinese|jp|japan|kr|korea|korean|vn|viet|thai|ph|filipino|id|indonesia|my|malay|africa)(?=$|[^a-z0-9])"#)
    static let WFR = re(#"(^|[^a-z0-9])(jeunesse|enfants|cinema|chaines|dessins?|animes|documentaires?|policiers?|comedies|nouveautes|emissions|telefilms?|actualites|divertissements?|regions|regionales?|feuilletons|sagas|horreur|aventures|integrales?|nouveaux?)(?=$|[^a-z0-9])"#)
    static let ACC = try! NSRegularExpression(pattern: "[éèêàçùâîôûœ]", options: [.caseInsensitive])
    static let MULTI = re(#"(^|[^a-z0-9])(multi|multilang|multi-?langues?|multi-?audio|multi-?subs?)(?=$|[^a-z0-9])"#)
    static let CHFR = re(#"(^|[^a-z0-9])(tf1|tmc|tfx|lci|m6|w9|6ter|gulli|c8|cstar|cnews|canal\+?|canal plus|arte|france ?[2345]|france ?o|franceinfo|bfm|rmc|nrj ?12|cherie ?25|l ?equipe|lcp|public senat|paris premiere|teva|ocs|cine\+?|comedie\+?|planete\+?|ushuaia|seasons|mcm|tv5|tv5monde|rtl ?9|novelas|game one|tiji|piwi|boing|toonami|infosport|equidia|nautical|trace|mangas|serieclub|13e ?rue|syfy france|polar\+?)"#)
    static let TFR = re(#"(^|[^a-z0-9'])(le|la|les|des|du|de|une|un|et|au|aux|pour|dans|sur|chez|avec|sans|qui|mon|ma|mes|ton|ta|nos|vos|est|pas|tout|toute|nous|vous|ou|quand|comme|plus|petit|petite|grand|grande|amour|vie|nuit|jour|monde|femme|homme|fille|fils|enfant|histoire|retour|dernier|derniere|rien|deux|trois|l|d)(?=$|[^a-z0-9])"#)

    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
    private static func cap(_ r: NSRegularExpression, _ s: String) -> String? {
        guard let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let x = Range(m.range(at: 2), in: s) else { return nil }
        return String(s[x])
    }
    /// minuscules sans accents, ponctuation gardée (comme RI.strip du simulateur)
    static func n(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")) }

    static func of(_ name: String, samples: [String], kind: String) -> CatLang {
        let raw = name, s = n(raw)
        if CatalogImporter.isAdult(raw) { return CatLang(g: .adult, why: "jamais chargée") }
        if let m = cap(FR, s) { return CatLang(g: .fr, why: ["vost", "stfr", "subfrench"].contains(where: { m.hasPrefix($0) }) ? "sous-titrée en français" : "marquée « \(m.uppercased()) »") }
        if cap(FO, s) != nil { return CatLang(g: .fo, why: "pays francophone") }
        if has(MULTI, s) && !has(XX, s) { return CatLang(g: .fr, why: "MULTI : le français est souvent inclus") }
        if let m = cap(XX, s) { return CatLang(g: .xx, why: "marquée « \(m.uppercased()) »") }
        if has(ACC, raw) || has(WFR, s) { return CatLang(g: .fr, why: "nom écrit en français") }
        let S = samples.prefix(60)
        let pct = S.isEmpty ? 0 : S.filter { frTitle($0, kind: kind) }.count * 100 / S.count
        return CatLang(g: .chk, why: S.isEmpty ? "catégorie vide" : "\(pct) % de titres français repérés", pct: pct)
    }

    static func frTitle(_ t: String, kind: String) -> Bool {
        let s = n(t)
        if has(FR, s) || has(ACC, t) || (has(MULTI, s) && !has(XX, s)) { return true }
        if kind == "live" { return has(CHFR, s) }
        if has(XX, s) { return false }
        return has(TFR, s.replacingOccurrences(of: "'", with: " "))
    }

    /// sélection proposée par prisme
    func proposed(_ name: String) -> Bool {
        g == .fr || (g == .fo && CatLang.n(name).range(of: #"belg|quebec|qc|(^|[^a-z])(be|ca)([^a-z]|$)"#, options: .regularExpression) != nil) || (g == .chk && pct >= 50)
    }
}

// MARK: - Vérification d'un compte (sans ouvrir aucune chaîne)

/// Ce que l'Apple TV apprend du fournisseur avant l'import : abonnement, guide, replay, catégories et leur langue.
struct ProviderAnalysis {
    struct Cat: Identifiable, Equatable {
        let id: String        // identifiant de la catégorie chez le fournisseur
        let type: String      // live, vod, series
        let name: String
        let count: Int
        let lang: CatLang
        /// titres déjà présents chez les autres fournisseurs (réunis ensuite)
        var dup: Int = 0
        var on: Bool
    }
    var ms = 0
    var auth = false
    var status = ""
    var expires: Date?
    var trial = false
    var maxConn = 0
    var activeConn = 0
    var epgBytes = 0
    var replay = 0
    var cats: [Cat] = []
    var totals: [String: Int] = [:]

    enum Level { case ok, warn, bad }
    struct Check: Identifiable { let id = UUID(); let title: String; let detail: String; let level: Level }

    /// Lignes de la vérification, dans l'ordre du simulateur.
    func checks(user: String) -> [Check] {
        var L: [Check] = [Check(title: "Serveur joignable", detail: "\(ms) ms · Xtream Codes", level: .ok)]
        L.append(Check(title: auth ? "Identifiants acceptés" : "Identifiants refusés", detail: auth ? "compte " + user : "refusés par le serveur", level: auth ? .ok : .bad))
        guard auth else { return L }
        var s: String, k: Level = .ok
        if !status.isEmpty && status.lowercased() != "active" {
            s = ["expired": "expiré", "banned": "bloqué", "disabled": "désactivé"][status.lowercased()] ?? status; k = .bad
        } else if let e = expires {
            let d = Int(ceil(e.timeIntervalSinceNow / 86400))
            s = "jusqu'au " + Fmt.date(e) + " · \(d) jour" + (d > 1 ? "s" : "")
            if d <= 7 { k = .warn }
        } else { s = "sans date de fin" }
        L.append(Check(title: "Abonnement " + (k == .bad ? "inactif" : "actif"), detail: s + (trial ? " · essai" : ""), level: k))
        L.append(Check(title: "Connexions", detail: maxConn > 0 ? "\(maxConn) autorisée" + (maxConn > 1 ? "s" : "") + " · \(activeConn) utilisée" + (activeConn > 1 ? "s" : "") + " en ce moment" : "non indiqué",
                       level: maxConn > 0 && activeConn >= maxConn ? .warn : .ok))
        L.append(Check(title: "Guide TV", detail: epgBytes > 2000 ? "fourni" + (epgBytes > 50_000 ? " · " + String(format: "%.1f", Double(epgBytes) / 1_048_576).replacingOccurrences(of: ".", with: ",") + " Mo de programmes" : "") : "absent : la TV aura moins d'infos",
                       level: epgBytes > 2000 ? .ok : .warn))
        L.append(Check(title: "Replay", detail: replay > 0 ? "disponible sur \(replay) chaîne" + (replay > 1 ? "s" : "") : "non indiqué par le fournisseur", level: replay > 0 ? .ok : .warn))
        return L
    }

    /// Interroge le serveur. `step` est appelé à chaque étape franchie (affichage progressif des lignes).
    static func run(_ acc: XtreamAccount, others: [String], step: @escaping @MainActor (ProviderAnalysis) -> Void) async throws -> ProviderAnalysis {
        var a = ProviderAnalysis()
        func url(_ action: String?) -> URL? {
            var c = URLComponents(string: acc.baseURL + "/player_api.php")
            var q = [URLQueryItem(name: "username", value: acc.username), URLQueryItem(name: "password", value: acc.password)]
            if let action { q.append(URLQueryItem(name: "action", value: action)) }
            c?.queryItems = q
            let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
            return c?.url
        }
        func json(_ action: String?, _ timeout: Double) async throws -> Any {
            guard let u = url(action) else { throw XtreamError.badURL }
            var r = URLRequest(url: u); r.timeoutInterval = timeout
            let (d, resp) = try await URLSession.shared.data(for: r)
            if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw XtreamError.badStatus(h.statusCode) }
            return try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
        }
        func str(_ v: Any?) -> String { if let s = v as? String { return s }; if let n = v as? NSNumber { return n.stringValue }; return "" }

        let t0 = Date()
        let info = try await json(nil, 20) as? [String: Any]
        a.ms = Int(Date().timeIntervalSince(t0) * 1000)
        let ui = info?["user_info"] as? [String: Any]
        a.auth = str(ui?["auth"]) == "1"
        a.status = str(ui?["status"])
        if let e = Double(str(ui?["exp_date"])), e > 0 { a.expires = Date(timeIntervalSince1970: e) }
        a.trial = str(ui?["is_trial"]) == "1"
        a.maxConn = Int(str(ui?["max_connections"])) ?? 0
        a.activeConn = Int(str(ui?["active_cons"])) ?? 0
        await step(a)
        guard a.auth else { return a }

        // guide : taille annoncée (ou premiers octets), sans tout télécharger
        if var c = URLComponents(string: acc.baseURL + "/xmltv.php") {
            c.queryItems = [URLQueryItem(name: "username", value: acc.username), URLQueryItem(name: "password", value: acc.password)]
            if let u = c.url {
                var r = URLRequest(url: u); r.timeoutInterval = 20; r.httpMethod = "HEAD"
                if let (_, resp) = try? await URLSession.shared.data(for: r), let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) {
                    a.epgBytes = Int(h.expectedContentLength)
                }
                if a.epgBytes <= 0, let (bytes, resp) = try? await URLSession.shared.bytes(from: u), (resp as? HTTPURLResponse)?.statusCode ?? 0 < 300 {
                    var n = 0
                    for try await _ in bytes { n += 1; if n > 60_000 { break } }
                    a.epgBytes = n
                }
            }
        }

        // catégories, contenus, langue des catégories et doublons avec les autres fournisseurs
        let otherKeys = await ProviderAnalysis.existingKeys(others)
        for (type, catAction, listAction) in [("live", "get_live_categories", "get_live_streams"), ("vod", "get_vod_categories", "get_vod_streams"), ("series", "get_series_categories", "get_series")] {
            PerfLog.mem("vérification \(type) : avant")
            let cats = (try? await json(catAction, 60)) as? [[String: Any]] ?? []
            // la liste est enregistrée dans un fichier (l'import la réutilise ensuite) et lue titre par titre :
            // seuls les comptes et quelques exemples par catégorie restent en mémoire
            var count: [String: Int] = [:], samples: [String: [String]] = [:], dup: [String: Int] = [:], total = 0
            if let u = url(listAction) {
                let file = ListFiles.file(account: acc, action: listAction)
                do { try await ListFiles.download(u, to: file) } catch { try? FileManager.default.removeItem(at: file) }
                let others = otherKeys[type]
                _ = JSONStream.forEachObject(file: file) { x in
                    let cid = str(x["category_id"]), name = str(x["name"])
                    total += 1
                    count[cid, default: 0] += 1
                    if (samples[cid]?.count ?? 0) < 60 { samples[cid, default: []].append(name) }
                    if type == "live" && str(x["tv_archive"]) == "1" { a.replay += 1 }
                    if let others, !others.isEmpty {
                        let k = type == "live" ? ChannelTools.key(Channel(pid: "", sid: "", name: name, num: 0, icon: "", cid: "", epg: "", archive: 0)) : TitleTools.clean(name, year: CatalogImporter.year(in: name)).key
                        if others.contains(k) { dup[cid, default: 0] += 1 }
                    }
                }
            }
            PerfLog.mem("vérification \(type) : liste lue (\(cats.count) catégories, \(total) lignes)")
            var L: [(String, String)] = cats.map { (str($0["category_id"]), str($0["category_name"]).isEmpty ? "Sans nom" : str($0["category_name"])) }
            if L.isEmpty && total > 0 {
                L = [("*", "Toutes les " + (type == "live" ? "chaînes" : type == "vod" ? "films" : "séries"))]
                count["*"] = total; samples["*"] = Array(samples.values.joined().prefix(60))
            }
            for (id, name) in L {
                let lang = CatLang.of(name, samples: samples[id] ?? [], kind: type)
                a.cats.append(Cat(id: id, type: type, name: name, count: count[id] ?? 0, lang: lang, dup: dup[id] ?? 0, on: lang.g != .adult && lang.proposed(name)))
            }
            a.totals[type] = total
            PerfLog.mem("vérification \(type) : analysée")
            await step(a)
        }
        return a
    }

    /// Identités déjà connues chez les autres fournisseurs (chaînes : pays + nom ; films et séries : titre + année)
    static func existingKeys(_ pids: [String]) async -> [String: Set<String>] {
        guard !pids.isEmpty else { return [:] }
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        // lecture brute dans la base (rapide), calcul des clés en dehors : la base reste libre pour le reste de l'appli
        let raw: [String: [String]] = await Database.shared.read { db in
            var out: [String: [String]] = ["live": [], "vod": [], "series": []]
            for t in ["live", "vod", "series"] {
                db.query("SELECT name FROM \(t) WHERE pid IN (\(ph))", pids.map { $0 as Any? }) { r in out[t]!.append(r.str(0)) }
            }
            return out
        }
        var out: [String: Set<String>] = [:]
        out["live"] = Set(raw["live", default: []].map { ChannelTools.key(Channel(pid: "", sid: "", name: $0, num: 0, icon: "", cid: "", epg: "", archive: 0)) })
        for t in ["vod", "series"] { out[t] = Set(raw[t, default: []].map { TitleTools.clean($0, year: CatalogImporter.year(in: $0)).key }) }
        return out
    }
}

// MARK: - Journal des incidents (simulateur : Réglages › Fournisseurs › Journal des incidents)

/// Heure, fournisseur, titre, cause et solution utilisée : à montrer au fournisseur si ça se répète.
@MainActor
final class Incidents: ObservableObject {
    static let shared = Incidents()
    struct Item: Codable, Identifiable { var id = UUID(); var at: Date; var provider: String; var title: String; var cause: String; var fix: String }
    private let key = "prisme.incidents"
    @Published private(set) var items: [Item] = []
    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let L = try? JSONDecoder().decode([Item].self, from: d) { items = L }
    }
    func add(provider: String, title: String, cause: String, fix: String) {
        items.insert(Item(at: Date(), provider: provider, title: title, cause: cause, fix: fix), at: 0)
        if items.count > 60 { items.removeLast(items.count - 60) }
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) }
    }
    func clear() { items = []; UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: - Avec mon iPhone : petite page servie par l'Apple TV sur le Wi-Fi, ouverte en scannant un code

/// Ce que l'iPhone envoie à la TV.
struct PhoneSubmission: Equatable { var link = ""; var server = ""; var user = ""; var pass = ""; var name = "" }

@MainActor
final class PhonePairing: ObservableObject {
    @Published private(set) var address: String?
    @Published private(set) var failed: String?
    @Published var received: PhoneSubmission?
    private var listener: NWListener?
    private let token = String(UUID().uuidString.prefix(8)).lowercased()
    private let queue = DispatchQueue(label: "prisme.pairing")

    var qr: UIImage? { address.flatMap { PhonePairing.qrImage($0) } }

    func start() {
        guard listener == nil else { return }
        guard let ip = PhonePairing.wifiAddress() else { failed = "L'Apple TV n'a pas d'adresse sur le réseau local."; return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: 0)
            l.newConnectionHandler = { [weak self] c in self?.handle(c) }
            l.stateUpdateHandler = { [weak self] st in
                Task { @MainActor in
                    guard let self else { return }
                    switch st {
                    case .ready: if let p = l.port?.rawValue { self.address = "http://\(ip):\(p)/\(self.token)" }
                    case .failed(let e): self.failed = "Page iPhone indisponible (\(e.localizedDescription))."
                    default: break
                    }
                }
            }
            l.start(queue: queue)
            listener = l
        } catch { failed = "Page iPhone indisponible (\(error.localizedDescription))." }
    }

    func stop() { listener?.cancel(); listener = nil; address = nil }

    nonisolated private func handle(_ c: NWConnection) {
        c.start(queue: queue)
        receive(c, buffer: Data())
    }

    nonisolated private func receive(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, err in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = PhonePairing.request(buf) {
                Task { @MainActor in self.respond(c, req) }
            } else if done || err != nil || buf.count > 200_000 {
                c.cancel()
            } else {
                self.receive(c, buffer: buf)
            }
        }
    }

    /// Requête HTTP complète : (méthode, chemin, corps)
    nonisolated private static func request(_ d: Data) -> (String, String, String)? {
        guard let s = String(data: d, encoding: .utf8), let end = s.range(of: "\r\n\r\n") else { return nil }
        let head = s[..<end.lowerBound], body = String(s[end.upperBound...])
        let first = head.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = first.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        let len = head.split(separator: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }.flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        guard body.utf8.count >= len else { return nil }
        return (parts[0], parts[1], body)
    }

    private func respond(_ c: NWConnection, _ r: (String, String, String)) {
        let (method, path, body) = r
        var html: String
        if !path.hasPrefix("/" + token) {
            html = PhonePairing.page(sent: false, wrong: true)
        } else if method == "POST" {
            var f: [String: String] = [:]
            for kv in body.split(separator: "&") {
                let p = kv.split(separator: "=", maxSplits: 1).map { String($0).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String($0) }
                if p.count == 2 { f[p[0]] = p[1] }
            }
            received = PhoneSubmission(link: f["link"] ?? "", server: f["server"] ?? "", user: f["user"] ?? "", pass: f["pass"] ?? "", name: f["name"] ?? "")
            html = PhonePairing.page(sent: true, wrong: false)
        } else {
            html = PhonePairing.page(sent: false, wrong: false)
        }
        let data = Data(html.utf8)
        let head = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(data.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
        c.send(content: Data(head.utf8) + data, completion: .contentProcessed { _ in c.cancel() })
    }

    /// Page de l'iPhone (simulateur : « Ajouter à prisme », lien ou identifiants, « Envoyer à la TV »)
    nonisolated static func page(sent: Bool, wrong: Bool) -> String {
        let css = """
        body{margin:0;background:#f2f2f7;color:#111;font-family:-apple-system,system-ui,sans-serif}
        .w{max-width:420px;margin:0 auto;padding:28px 18px;display:flex;flex-direction:column;gap:12px}
        h3{margin:0;font-size:22px}p{margin:0;font-size:14px;color:#555;line-height:1.4}
        label{font-size:12px;font-weight:600;color:#666;text-transform:uppercase;letter-spacing:.04em}
        input,textarea{width:100%;box-sizing:border-box;font:16px -apple-system,system-ui,sans-serif;padding:12px;border-radius:12px;border:1px solid #d1d1d6;background:#fff;color:#111}
        textarea{height:90px;resize:none}
        .seg{display:grid;grid-template-columns:1fr 1fr;background:#e3e3e8;border-radius:10px;padding:3px;gap:3px}
        .seg button{border:0;background:transparent;padding:8px;border-radius:8px;font-weight:600;font-size:14px;color:#333}
        .seg button[aria-pressed=true]{background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.15)}
        .go{border:0;background:#0a84ff;color:#fff;font-weight:700;font-size:17px;padding:14px;border-radius:14px}
        .ok{font-size:15px;color:#1f7a3b;background:#e2f6e8;border-radius:12px;padding:12px}
        """
        if wrong { return "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><style>\(css)</style><div class=w><h3>Code périmé</h3><p>Scanne à nouveau le code affiché sur ta TV.</p></div>" }
        if sent { return "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><style>\(css)</style><div class=w><h3>Envoyé à la TV ✓</h3><div class=ok>Regarde ta TV : prisme vérifie ton abonnement.</div></div>" }
        return """
        <!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>Ajouter à prisme</title><style>\(css)</style>
        <form class=w method=post>
        <h3>Ajouter à prisme</h3><p>Page ouverte en scannant le code de la TV. Ce que tu saisis part directement à ton Apple TV, sur le même Wi-Fi.</p>
        <div class=seg><button type=button id=bl aria-pressed=true>Coller un lien</button><button type=button id=bi aria-pressed=false>Identifiants</button></div>
        <div id=pl style="display:flex;flex-direction:column;gap:6px"><label>Lien du fournisseur</label><textarea name=link placeholder="http://…/get.php?username=…&password=…" spellcheck=false autocapitalize=off></textarea></div>
        <div id=pi style="display:none;flex-direction:column;gap:6px"><label>Serveur</label><input name=server placeholder="http://monserveur.com:8080" autocapitalize=off autocorrect=off spellcheck=false>
        <label>Utilisateur</label><input name=user autocapitalize=off autocorrect=off spellcheck=false><label>Mot de passe</label><input name=pass type=password>
        <label>Nom (facultatif)</label><input name=name></div>
        <p>Ton mot de passe est envoyé à la TV et gardé dans le trousseau Apple.</p>
        <button class=go type=submit>Envoyer à la TV</button></form>
        <script>const s=m=>{bl.setAttribute('aria-pressed',m=='l');bi.setAttribute('aria-pressed',m!='l');pl.style.display=m=='l'?'flex':'none';pi.style.display=m=='l'?'none':'flex'};bl.onclick=()=>s('l');bi.onclick=()=>s('i')</script>
        """
    }

    nonisolated static func qrImage(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Adresse IPv4 de l'Apple TV sur le réseau local (Wi-Fi ou Ethernet)
    nonisolated static func wifiAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var best: String?
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let sa = i.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: i.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if name == "en0" { return ip }
                best = best ?? ip
            }
        }
        return best
    }
}
