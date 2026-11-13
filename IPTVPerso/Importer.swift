import Foundation

/// Télécharge le catalogue d'un fournisseur et le range dans la base, en arrière-plan.
/// Rien d'adulte n'est jamais chargé (catégories et titres marqués adultes écartés).
struct CatalogImporter {
    let provider: Provider

    struct Result { var counts: [String: Int] = [:]; var expires: Date?; var tz: String? }

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
        let info = try await json(nil) as? [String: Any]
        let ui = info?["user_info"] as? [String: Any]
        guard str(ui?["auth"]) == "1" else { throw XtreamError.authFailed }
        if let e = Double(str(ui?["exp_date"])), e > 0 { res.expires = Date(timeIntervalSince1970: e) }
        // fuseau horaire du serveur : les adresses de replay (timeshift) s'écrivent à l'heure du serveur
        if let si = info?["server_info"] as? [String: Any], let tz = si["timezone"] as? String, TimeZone(identifier: tz) != nil { res.tz = tz }

        // ---- catégories
        var blocked = Set<String>()
        for (i, (type, action)) in [("live", "get_live_categories"), ("vod", "get_vod_categories"), ("series", "get_series_categories")].enumerated() {
            progress(0.04 + Double(i) * 0.02, "Catégories…")
            let arr = (try? await json(action)) as? [[String: Any]] ?? []
            var rows: [[Any?]] = []
            for (pos, c) in arr.enumerated() {
                let cid = str(c["category_id"]), name = str(c["category_name"])
                if Self.isAdult(name) { blocked.insert(type + ":" + cid); continue }
                rows.append([pid, type, cid, name, pos])
            }
            await db.read { db in
                db.run("DELETE FROM category WHERE pid=? AND type=?", [pid, type])
                db.insertMany("INSERT OR REPLACE INTO category VALUES(?,?,?,?,?)", rows)
            }
        }

        // ---- chaînes
        progress(0.12, "Chaînes de TV…")
        let live = (try await json("get_live_streams")) as? [[String: Any]] ?? []
        var lrows: [[Any?]] = []; lrows.reserveCapacity(live.count)
        var epgIDs = Set<String>()
        for s in live {
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("live:" + cid) || str(s["is_adult"]) == "1" || Self.isAdult(name) { continue }
            let epg = str(s["epg_channel_id"])
            if !epg.isEmpty { epgIDs.insert(epg) }
            let arch = str(s["tv_archive"]) == "1" ? (Int(str(s["tv_archive_duration"])) ?? 1) : 0
            lrows.append([pid, str(s["stream_id"]), name, Int(str(s["num"])) ?? 0, str(s["stream_icon"]), cid, epg, arch])
        }
        await db.read { db in
            db.run("DELETE FROM live WHERE pid=?", [pid])
            db.insertMany("INSERT OR REPLACE INTO live VALUES(?,?,?,?,?,?,?,?)", lrows)
        }
        res.counts["live"] = lrows.count

        // ---- films
        progress(0.30, "Films…")
        let vod = (try await json("get_vod_streams")) as? [[String: Any]] ?? []
        var vrows: [[Any?]] = []; vrows.reserveCapacity(vod.count)
        for s in vod {
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("vod:" + cid) || str(s["is_adult"]) == "1" || Self.isAdult(name) { continue }
            let tmdb = str(s["tmdb"]).isEmpty ? str(s["tmdb_id"]) : str(s["tmdb"])
            vrows.append([pid, str(s["stream_id"]), name, Int(str(s["year"])) ?? Self.year(in: name), str(s["stream_icon"]), cid,
                          str(s["container_extension"]).isEmpty ? "mp4" : str(s["container_extension"]),
                          Double(str(s["rating"])) ?? 0, Int(str(s["added"])) ?? 0, tmdb])
        }
        await db.read { db in
            db.run("DELETE FROM vod WHERE pid=?", [pid])
            db.insertMany("INSERT OR REPLACE INTO vod VALUES(?,?,?,?,?,?,?,?,?,?)", vrows)
        }
        res.counts["vod"] = vrows.count

        // ---- séries
        progress(0.50, "Séries…")
        let ser = (try await json("get_series")) as? [[String: Any]] ?? []
        var srows: [[Any?]] = []; srows.reserveCapacity(ser.count)
        for s in ser {
            let cid = str(s["category_id"]), name = str(s["name"])
            if blocked.contains("series:" + cid) || Self.isAdult(name) { continue }
            let rel = str(s["releaseDate"]).isEmpty ? str(s["release_date"]) : str(s["releaseDate"])
            srows.append([pid, str(s["series_id"]), name, Int(rel.prefix(4)) ?? Self.year(in: name), str(s["cover"]), cid, str(s["plot"]),
                          Double(str(s["rating"])) ?? 0, Int(str(s["last_modified"])) ?? 0, str(s["tmdb"])])
        }
        await db.read { db in
            db.run("DELETE FROM series WHERE pid=?", [pid])
            db.insertMany("INSERT OR REPLACE INTO series VALUES(?,?,?,?,?,?,?,?,?,?)", srows)
        }
        res.counts["series"] = srows.count

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

    private func xmltvURL() -> URL? {
        var c = URLComponents(string: provider.account.baseURL + "/xmltv.php")
        c?.queryItems = [URLQueryItem(name: "username", value: provider.username), URLQueryItem(name: "password", value: provider.password)]
        let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        return c?.url
    }

    private func json(_ action: String?) async throws -> Any {
        var c = URLComponents(string: provider.account.baseURL + "/player_api.php")
        var q = [URLQueryItem(name: "username", value: provider.username), URLQueryItem(name: "password", value: provider.password)]
        if let action { q.append(URLQueryItem(name: "action", value: action)) }
        c?.queryItems = q
        let q0 = c?.percentEncodedQuery; c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = c?.url else { throw XtreamError.badURL }
        var req = URLRequest(url: url); req.timeoutInterval = 120
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
