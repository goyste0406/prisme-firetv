import Foundation

/// Télécharge le catalogue d'un fournisseur et le range dans la base, en arrière-plan.
/// Rien d'adulte n'est jamais chargé (catégories et titres marqués adultes écartés).
struct CatalogImporter {
    let provider: Provider

    struct Result {
        var counts: [String: Int] = [:]; var expires: Date?; var tz: String?
        /// temps de réponse, connexions autorisées, état de l'abonnement (réglages › Fournisseurs)
        var ping: Int?; var maxConn: Int?; var subStatus: String?
        /// avertissement sans échec (une liste vide gardée à l'identique, par exemple)
        var warning: String?
    }

    static let adult = try! NSRegularExpression(pattern: #"adult|xxx|porn|\+ ?18|18 ?\+|for adults|erotic|\bsex|\bhot\b"#, options: [.caseInsensitive])
    static func isAdult(_ s: String) -> Bool {
        adult.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private var api: XtreamAPI { XtreamAPI(account: provider.account) }

    func run(progress: @escaping (Double, String) -> Void) async throws -> Result {
        var res = Result()
        let db = Database.shared
        let pid = provider.id

        progress(0.02, "Connexion à \(provider.name)…")
        let t0 = Date()
        let info = try await json(nil, timeout: 20) as? [String: Any]
        res.ping = Int(Date().timeIntervalSince(t0) * 1000)
        let ui = info?["user_info"] as? [String: Any]
        guard str(ui?["auth"]) == "1" else { throw XtreamError.authFailed }
        res.maxConn = Int(str(ui?["max_connections"])); res.subStatus = str(ui?["status"]).isEmpty ? nil : str(ui?["status"])
        if let e = Double(str(ui?["exp_date"])), e > 0 { res.expires = Date(timeIntervalSince1970: e) }
        // fuseau horaire du serveur : les adresses de replay (timeshift) s'écrivent à l'heure du serveur
        if let si = info?["server_info"] as? [String: Any], let tz = si["timezone"] as? String, TimeZone(identifier: tz) != nil { res.tz = tz }

        // ---- catégories
        var blocked = Set<String>()
        var liveCats: [String: String] = [:]
        for (i, (type, action)) in [("live", "get_live_categories"), ("vod", "get_vod_categories"), ("series", "get_series_categories")].enumerated() {
            progress(0.04 + Double(i) * 0.02, "Catégories…")
            let arr = (try? await json(action)) as? [[String: Any]] ?? []
            var rows: [[Any?]] = []
            for (pos, c) in arr.enumerated() {
                let cid = str(c["category_id"]), name = str(c["category_name"])
                if Self.isAdult(name) { blocked.insert(type + ":" + cid); continue }
                // catégorie masquée dans « Gérer » : gardée dans la liste des catégories, ses contenus ne sont pas chargés
                if (provider.hidden ?? []).contains(type + ":" + cid) { blocked.insert(type + ":" + cid) }
                rows.append([pid, type, cid, name, pos])
                if type == "live" { liveCats[cid] = name }
            }
            await db.read { db in
                // liste vide (panne passagère du serveur) : les catégories déjà connues sont gardées
                if rows.isEmpty, (db.intValue("SELECT COUNT(*) FROM category WHERE pid=? AND type=?", [pid, type]) ?? 0) > 0 { return }
                // une seule transaction : l'effacement et la nouvelle liste ensemble (le COMMIT de insertMany clôt les deux)
                db.exec("BEGIN IMMEDIATE")
                db.run("DELETE FROM category WHERE pid=? AND type=?", [pid, type])
                if rows.isEmpty { db.exec("COMMIT") } else { db.insertMany("INSERT OR REPLACE INTO category VALUES(?,?,?,?,?)", rows) }
            }
        }

        // ---- chaînes, films, séries : chaque liste est enregistrée dans un fichier, lue titre par titre et rangée par lots
        // (la mémoire reste stable, même avec des centaines de milliers de titres), puis remplace l'ancienne d'un coup
        var epgIDs = Set<String>()
        progress(0.12, "Chaînes de TV…")
        res.counts["live"] = try await importList("live", action: "get_live_streams", what: "chaînes", p0: 0.12, p1: 0.30, progress: progress, &res) { s in
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("live:" + cid) || str(s["is_adult"]) == "1" || Self.isAdult(name) { return nil }
            let epg = str(s["epg_channel_id"])
            if !epg.isEmpty { epgIDs.insert(epg) }
            let arch = str(s["tv_archive"]) == "1" ? (Int(str(s["tv_archive_duration"])) ?? 1) : 0
            // identité de la chaîne calculée ici, une fois (lue telle quelle par l'index des chaînes)
            let id = LiveIndex.identity(name: name, category: liveCats[cid] ?? "")
            return [pid, str(s["stream_id"]), name, Int(str(s["num"])) ?? 0, str(s["stream_icon"]), cid, epg, arch,
                    id.name, id.key, id.q, id.u.rawValue, LiveIndex.rulesVersion]
        }
        // liste gardée à l'identique (reçue vide ou coupée) : le guide suit les chaînes déjà connues
        if epgIDs.isEmpty {
            await db.read { db in db.query("SELECT DISTINCT epg FROM live WHERE pid=? AND epg<>''", [pid]) { r in epgIDs.insert(r.str(0)) } }
        }

        progress(0.30, "Films…")
        res.counts["vod"] = try await importList("vod", action: "get_vod_streams", what: "films", p0: 0.30, p1: 0.50, progress: progress, &res) { s in
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("vod:" + cid) || str(s["is_adult"]) == "1" || Self.isAdult(name) { return nil }
            let tmdb = str(s["tmdb"]).isEmpty ? str(s["tmdb_id"]) : str(s["tmdb"])
            return [pid, str(s["stream_id"]), name, Int(str(s["year"])) ?? Self.year(in: name), str(s["stream_icon"]), cid,
                    str(s["container_extension"]).isEmpty ? "mp4" : str(s["container_extension"]),
                    Double(str(s["rating"])) ?? 0, Int(str(s["added"])) ?? 0, tmdb]
        }

        progress(0.50, "Séries…")
        res.counts["series"] = try await importList("series", action: "get_series", what: "séries", p0: 0.50, p1: 0.62, progress: progress, &res) { s in
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("series:" + cid) || Self.isAdult(name) { return nil }
            let rel = str(s["releaseDate"]).isEmpty ? str(s["release_date"]) : str(s["releaseDate"])
            return [pid, str(s["series_id"]), name, Int(rel.prefix(4)) ?? Self.year(in: name), str(s["cover"]), cid, str(s["plot"]),
                    Double(str(s["rating"])) ?? 0, Int(str(s["last_modified"])) ?? 0, str(s["tmdb"])]
        }

        // ---- guide des programmes (XMLTV), lu au fil de l'eau : jamais tout en mémoire
        progress(0.62, "Guide des programmes…")
        if !epgIDs.isEmpty, let url = xmltvURL() {
            do {
                let (file, _) = try await URLSession.shared.download(from: url)
                progress(0.80, "Guide des programmes : lecture…")
                let n = await db.read { db in EPGParser(file: file, keep: epgIDs, db: db).run() }
                res.counts["epg"] = n
                try? FileManager.default.removeItem(at: file)
            } catch {
                res.counts["epg"] = 0 // pas de guide chez ce fournisseur : le reste fonctionne
            }
        }
        // ménage : programmes de plus de 3 jours
        await db.read { db in db.run("DELETE FROM epg WHERE stop<?", [Int(Date().timeIntervalSince1970) - 3 * 86400]) }
        progress(1, "Terminé")
        return res
    }

    // MARK: outils

    /// Remplace d'un seul coup (une transaction) le contenu d'une table pour ce fournisseur.
    /// Une liste reçue vide alors qu'il y avait du contenu n'efface rien : c'est presque toujours une panne passagère du serveur.
    private func skipped(_ type: String) -> Bool { (provider.skip ?? []).contains(type) }

    /// Une liste du fournisseur (chaînes, films ou séries) : fichier → lecture titre par titre → table d'attente par lots
    /// de 2 000 → remplacement de l'ancienne liste en une seule transaction.
    /// Liste reçue vide, coupée ou illisible alors qu'il y avait du contenu : l'ancienne est gardée (panne passagère).
    private func importList(_ table: String, action: String, what: String, p0: Double, p1: Double,
                            progress: @escaping (Double, String) -> Void, _ res: inout Result,
                            row: ([String: Any]) -> [Any?]?) async throws -> Int {
        let pid = provider.id
        // type non importé (choisi à l'ajout) : son contenu éventuel est retiré
        if skipped(table) {
            await Database.shared.read { db in db.replaceProvider(table: table, pid: pid, sql: "", rows: []) }
            return 0
        }
        // fichier laissé par la vérification (moins d'une heure) ou téléchargé maintenant
        let acc = provider.account
        let file: URL
        if let f = ListFiles.fresh(account: acc, action: action) { file = f } else {
            guard let u = apiURL(action) else { throw XtreamError.badURL }
            file = ListFiles.file(account: acc, action: action)
            try await ListFiles.download(u, to: file)
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let size = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue ?? 0
        PerfLog.mem("import \(what) : fichier reçu (\(size / 1_048_576) Mo)")

        let db = Database.shared
        let stage = table + "_stage"
        db.sync { db in db.run("DELETE FROM \(stage) WHERE pid=?", [pid]) }
        var batch: [[Any?]] = []; batch.reserveCapacity(2000)
        var kept = 0, cols = 0, lastTick = Date()
        func flush() {
            guard !batch.isEmpty else { return }
            let sql = "INSERT INTO \(stage) VALUES(" + Array(repeating: "?", count: cols).joined(separator: ",") + ")"
            let b = batch
            db.sync { db in db.insertMany(sql, b) }
            batch.removeAll(keepingCapacity: true)
        }
        let outcome = JSONStream.forEachObject(file: file) { o in
            guard let r = row(o) else { return }
            cols = r.count; batch.append(r); kept += 1
            if batch.count >= 2000 {
                flush()
                if Date().timeIntervalSince(lastTick) > 0.5 {
                    lastTick = Date()
                    progress(p0 + (p1 - p0) * 0.8, "\(what.prefix(1).uppercased() + what.dropFirst()) : \(Fmt.n(kept)) lus…")
                }
            }
        }
        flush()
        PerfLog.mem("import \(what) : lus et rangés (\(kept))")

        let received: Int
        switch outcome {
        case .complete(let n): received = n
        case .truncated, .notList: received = -1
        }
        let before = await db.read { db in db.intValue("SELECT COUNT(*) FROM \(table) WHERE pid=?", [pid]) ?? 0 }
        if received <= 0 && before > 0 {
            db.sync { db in db.run("DELETE FROM \(stage) WHERE pid=?", [pid]) }
            res.warning = received < 0 ? "Liste des \(what) reçue incomplète : l'ancienne est gardée." : "Liste des \(what) reçue vide : l'ancienne est gardée."
            return before
        }
        if received < 0 {
            // premier import et liste coupée : on garde ce qui a pu être lu, et on le signale
            res.warning = "Liste des \(what) reçue incomplète : \(Fmt.n(kept)) gardés."
        }
        progress(p1 - 0.01, "\(what.prefix(1).uppercased() + what.dropFirst()) : enregistrement…")
        // remplacement d'un coup : l'ancienne liste et la nouvelle dans la même transaction
        await db.read { db in
            db.exec("BEGIN IMMEDIATE")
            db.run("DELETE FROM \(table) WHERE pid=?", [pid])
            db.run("INSERT OR REPLACE INTO \(table) SELECT * FROM \(stage) WHERE pid=?", [pid])
            db.run("DELETE FROM \(stage) WHERE pid=?", [pid])
            db.exec("COMMIT")
        }
        PerfLog.mem("import \(what) : enregistrés")
        return kept
    }

    private func apiURL(_ action: String) -> URL? {
        var c = URLComponents(string: provider.account.baseURL + "/player_api.php")
        c?.queryItems = [URLQueryItem(name: "username", value: provider.username), URLQueryItem(name: "password", value: provider.password),
                         URLQueryItem(name: "action", value: action)]
        let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        return c?.url
    }

    private func xmltvURL() -> URL? {
        var c = URLComponents(string: provider.account.baseURL + "/xmltv.php")
        c?.queryItems = [URLQueryItem(name: "username", value: provider.username), URLQueryItem(name: "password", value: provider.password)]
        let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        return c?.url
    }

    private func json(_ action: String?, timeout: Double = 120) async throws -> Any {
        var c = URLComponents(string: provider.account.baseURL + "/player_api.php")
        var q = [URLQueryItem(name: "username", value: provider.username), URLQueryItem(name: "password", value: provider.password)]
        if let action { q.append(URLQueryItem(name: "action", value: action)) }
        c?.queryItems = q
        let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = c?.url else { throw XtreamError.badURL }
        var req = URLRequest(url: url); req.timeoutInterval = timeout
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw XtreamError.badStatus(h.statusCode) }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private func str(_ v: Any?) -> String {
        switch v {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    static func year(in name: String) -> Int {
        guard let r = name.range(of: #"(19|20)\d{2}"#, options: .regularExpression) else { return 0 }
        return Int(name[r]) ?? 0
    }
}

/// Lecture du guide XMLTV au fil de l'eau (SAX) : seules les chaînes du fournisseur et
/// les programmes de « il y a 2 jours » à « dans 2 jours » sont gardés.
final class EPGParser: NSObject, XMLParserDelegate {
    private let file: URL
    private let keep: Set<String>
    private let db: Database
    private var rows: [[Any?]] = []
    private var cur: (ch: String, start: Int, stop: Int)?
    private var title = "", descr = "", text = "", cat = ""
    private var inTitle = false, inDesc = false, inCat = false, catFr = false, curFr = false
    private var count = 0
    private var cleared = false
    private let from = Int(Date().timeIntervalSince1970) - 2 * 86400
    private let to = Int(Date().timeIntervalSince1970) + 2 * 86400

    init(file: URL, keep: Set<String>, db: Database) { self.file = file; self.keep = keep; self.db = db }

    func run() -> Int {
        guard let stream = InputStream(url: file) else { return 0 }
        let p = XMLParser(stream: stream)
        p.delegate = self
        p.parse()
        flush()
        return count
    }

    private func flush() {
        if !cleared {
            // les anciens programmes de ces chaînes sont remplacés par les nouveaux
            let ids = Array(keep)
            db.exec("BEGIN")
            for chunk in stride(from: 0, to: ids.count, by: 500) {
                let part = ids[chunk..<min(ids.count, chunk + 500)]
                db.run("DELETE FROM epg WHERE ch IN (" + part.map { _ in "?" }.joined(separator: ",") + ")", Array(part))
            }
            db.exec("COMMIT")
            cleared = true
        }
        db.insertMany("INSERT INTO epg(ch,start,stop,title,descr,cat) VALUES(?,?,?,?,?,?)", rows)
        rows.removeAll(keepingCapacity: true)
    }

    static func time(_ s: String) -> Int {
        // « 20261112210000 +0100 »
        let d = s.prefix(14).compactMap { $0.wholeNumberValue }
        guard d.count == 14 else { return 0 }
        func n(_ a: Int, _ b: Int) -> Int { d[a..<b].reduce(0) { $0 * 10 + $1 } }
        var c = DateComponents()
        c.year = n(0, 4); c.month = n(4, 6); c.day = n(6, 8); c.hour = n(8, 10); c.minute = n(10, 12); c.second = n(12, 14)
        var off = 0
        let parts = s.split(separator: " ")
        if parts.count > 1, let z = parts.last, z.count == 5, let h = Int(z.dropFirst().prefix(2)), let m = Int(z.suffix(2)) {
            off = (h * 3600 + m * 60) * (z.first == "-" ? -1 : 1)
        }
        c.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = Calendar(identifier: .gregorian).date(from: c) else { return 0 }
        return Int(date.timeIntervalSince1970) - off
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        switch name {
        case "programme":
            let ch = a["channel"] ?? ""
            guard keep.contains(ch) else { cur = nil; return }
            let st = Self.time(a["start"] ?? ""), sp = Self.time(a["stop"] ?? "")
            cur = (sp > from && st < to && sp > st) ? (ch, st, sp) : nil
            title = ""; descr = ""; cat = ""; catFr = false
        case "title": if cur != nil { inTitle = true; text = "" }
        case "category": if cur != nil { inCat = true; text = ""; curFr = (a["lang"] ?? "").lowercased().hasPrefix("fr") }
        case "desc": if cur != nil { inDesc = true; text = "" }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTitle || inDesc || inCat { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "title": if inTitle { if title.isEmpty { title = text }; inTitle = false }
        case "desc": if inDesc { if descr.isEmpty { descr = String(text.prefix(400)) }; inDesc = false }
        case "category":
            // le premier genre, ou le premier en français s'il y en a un
            if inCat { let t = text.trimmingCharacters(in: .whitespacesAndNewlines); if !t.isEmpty, cat.isEmpty || (curFr && !catFr) { cat = String(t.prefix(60)); catFr = curFr } ; inCat = false }
        case "programme":
            if let c = cur {
                rows.append([c.ch, c.start, c.stop, title, descr, cat.isEmpty ? nil : cat]); count += 1
                if rows.count >= 5000 { flush() }
            }
            cur = nil
        default: break
        }
    }
}
