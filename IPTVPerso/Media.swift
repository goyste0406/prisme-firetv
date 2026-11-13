import Foundation
import SwiftUI

enum MediaKind: String { case film, series }

/// Un film ou une série, tel que rangé dans la base.
struct MediaItem: Identifiable, Hashable {
    let kind: MediaKind
    let pid: String
    let sid: String
    let name: String       // nom brut chez le fournisseur
    let year: Int
    let icon: String
    let cid: String
    let ext: String
    let rating: Double
    let added: Int
    let tmdb: String
    let plot: String
    var fiche: Fiche? = nil
    var id: String { kind.rawValue + ":" + pid + ":" + sid }
    var clean: CleanTitle { TitleTools.clean(name, year: year) }
    /// Titre affiché : celui de TMDB (en français) s'il est connu.
    var displayTitle: String { fiche?.title.isEmpty == false ? fiche!.title : clean.title }
    var posterURL: String { (fiche?.poster.isEmpty == false) ? Fiche.img(fiche!.poster, "w500") : icon }
    var backdropURL: String { (fiche?.backdrop.isEmpty == false) ? Fiche.img(fiche!.backdrop, "w780") : "" }
    /// Image de fond plein écran : version d'origine TMDB (réduite à 1920 px au décodage, voir SharpImage).
    var backdropHD: String { (fiche?.backdrop.isEmpty == false) ? Fiche.img(fiche!.backdrop, "original") : "" }
}

extension MediaItem {
    /// Clé d'une œuvre : l'identifiant TMDB quand il est connu (fiche, sinon celui du fournisseur), sinon titre + année.
    /// Deux versions du même film (titre anglais/français, qualités, fournisseurs) ont la même clé ; deux films
    /// différents au titre proche restent distincts.
    var workKey: String {
        if let t = fiche?.tmdb, t > 0 { return "t\(t)" }
        if let t = Int(tmdb.trimmingCharacters(in: .whitespaces)), t > 0 { return "t\(t)" }
        return clean.key
    }
}

extension Array where Element == MediaItem {
    /// Sans doublon d'œuvre (garde le premier), en retirant éventuellement le titre de la fiche ouverte.
    func uniqueWorks(excluding: MediaItem? = nil) -> [MediaItem] {
        var seen = Set<String>()
        if let e = excluding { seen.insert(e.workKey); seen.insert(e.clean.key) }
        return filter { seen.insert($0.workKey).inserted && (excluding == nil || $0.clean.key != excluding!.clean.key) }
    }
}

extension Array where Element == MediaItem {
    /// Ajoute les fiches TMDB connues (une requête pour toute la liste). À appeler sur la file de la base.
    func withFiches() -> [MediaItem] {
        guard let k = first?.kind else { return self }
        let f = FicheStore.byKeys(k, map { $0.clean.key })
        return map { var m = $0; m.fiche = f[m.clean.key]; return m }
    }
}

struct CleanTitle {
    let title: String
    let year: Int
    let tags: [String]     // VF, MULTI, VOSTFR, 4K, 1080p…
    var key: String { TitleTools.fold(title) + "|" + String(year) }
}

/// Titres des fournisseurs (« FR| Dune (2021) 4K MULTI ») → titre propre + étiquettes.
enum TitleTools {
    private static let lead = try! NSRegularExpression(pattern: #"^\s*(\[[^\]]{1,12}\]|[A-Z]{2,4}\s*[|:\-–]\s*)+"#)
    private static let tagRx = try! NSRegularExpression(pattern: #"\b(4K|UHD|2160p|FHD|1080p|HD|720p|SD|MULTI|VOSTFR|VOST|VFF|VFQ|VF|TRUEFRENCH|FRENCH|HEVC|H265|x265|HDR|DV)\b"#, options: [.caseInsensitive])
    private static let yearRx = try! NSRegularExpression(pattern: #"[\(\[]?\b(19[2-9]\d|20[0-4]\d)\b[\)\]]?"#)

    // Règles reprises du simulateur (RI.title) : on retire, en partant de la fin, langue, qualité, source, son, année,
    // code pays et numéro de saison (« Brothers 2026 US » → « Brothers », « Lupin S01 » → « Lupin »).
    private static let leadLang = try! NSRegularExpression(pattern: #"^\s*([\[(|]?\s*(fr|fra|france|be|ch|ca|qc)\s*[\])|:\-–]+\s*)+"#, options: [.caseInsensitive])
    private static let leadCode = try! NSRegularExpression(pattern: #"^\s*(?:AS|ASIA|AF|EU|EN|UK|US|KR|JP|CN|IN|AR|TR|DE|ES|IT|PT|PL|NL|RU|LAT)\s*[-|:]\s+"#)
    private static let supers = try! NSRegularExpression(pattern: "[ᴴᴰᶠᵁ⁴ᴷˢ]+")
    private static let trail = try! NSRegularExpression(pattern: #"(?:^|[\s\-–:_.,|])(?:vost(?:-?fr)?|vostfr|vo|vf2?|vff|vfq|vfi|stfr|subfrench|truefrench|french|multi|eng|subs?|hdlight|hdr10\+?|hdr|dv|dolby ?vision|imax|3d|remux|web(?:-?dl|rip)?|blu-?ray|bdrip|brrip|dvdrip|x26[45]|h\.?26[45]|hevc|10 ?bits?|atmos|dts|ac3|aac|5\.1|7\.1|extended|uncut|remastered|director'?s ?cut|version longue|4k|uhd|fhd|hd|sd|1080[pi]?|720p?|2160p?|19[2-9]\d|20[0-3]\d)[\s\-–:_.,|]*$"#, options: [.caseInsensitive])
    private static let trailCode = try! NSRegularExpression(pattern: #"(?:[\s_\-–|.(\[]+)(?:FR|FRA|KR|KOR|PL|POL|US|USA|UK|GB|EN|ENG|DE|GER|ES|ESP|IT|ITA|TR|TUR|JP|JAP|CN|CHN|IN|IND|BR|PT|NL|AR|ARA|RU|RUS|SE|NO|DK|FI|BE|CA|QC|MX|LAT|LATINO|SUB|DUB|VOSTA)[\])]*\s*$"#)
    private static let trailLang = try! NSRegularExpression(pattern: #"(?:[_|(\[\-–]\s*|\s+)(?:fr|fra|kr|kor|pl|tr|jp|cn|ru|nl|dk|fi|gb|usa|ger|esp|ita|latino)[\])]*\s*$"#, options: [.caseInsensitive])
    private static let trailSeason = try! NSRegularExpression(pattern: #"[\s_\-–|.]+(?:s\d{1,2}|saison\s*\d{1,2}|season\s*\d{1,2}|partie\s*\d{1,2})\s*$"#, options: [.caseInsensitive])

    private static func sub(_ rx: NSRegularExpression, _ s: String, _ t: String = "") -> String {
        rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: t)
    }

    static func clean(_ raw: String, year: Int) -> CleanTitle {
        var s = raw
        s = lead.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        var tags: [String] = []
        for m in tagRx.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            if let r = Range(m.range, in: s) {
                var t = s[r].uppercased()
                if ["UHD", "2160P"].contains(t) { t = "4K" }
                if t == "FHD" { t = "1080P" }
                if ["TRUEFRENCH", "FRENCH", "VFF", "VFQ"].contains(t) { t = "VF" }
                if t == "VOST" { t = "VOSTFR" }
                if ["HEVC", "H265", "X265", "HDR", "DV", "SD", "HD", "720P"].contains(t) { continue }
                let label = t == "1080P" ? "1080p" : t
                if !tags.contains(label) { tags.append(label) }
            }
        }
        var y = year
        if y == 0, let m = yearRx.matches(in: s, range: NSRange(s.startIndex..., in: s)).last, let r = Range(m.range(at: 1), in: s) { y = Int(s[r]) ?? 0 }
        // titre propre (règles du simulateur)
        s = sub(leadLang, s)
        s = sub(supers, s, " ")
        s = tagRx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        s = s.replacingOccurrences(of: #"[\[\]()|]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"^[\s|:\-–]+"#, with: "", options: .regularExpression)
        s = sub(leadLang, s)
        s = sub(leadCode, s)
        var prev = ""
        var guardN = 0
        while s != prev && guardN < 12 {
            prev = s; guardN += 1
            var t = sub(trail, s); t = sub(trailCode, t); t = sub(trailLang, t); t = sub(trailSeason, t)
            t = t.replacingOccurrences(of: #"\s*[-–:|,]\s*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if t.count < 2 { break }
            s = t
        }
        s = s.replacingOccurrences(of: #"^\s*[-–:]\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if s.count < 2 { s = raw }
        return CleanTitle(title: s, year: y, tags: tags)
    }

    /// Nom de catégorie lisible (règle du simulateur) : « FR| FILMS NETFLIX » → « Films Netflix ».
    static func category(_ n: String) -> String {
        var c = n.replacingOccurrences(of: #"^\s*[\[(|]?\s*(france|french|fra|fr)\s*[\])|:\-–]+\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        c = c.replacingOccurrences(of: #"^(fra|fr)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        c = c.replacingOccurrences(of: #"^\s*[\[(|]?\s*(be|ca|ch|qc)\s*[\])|:\-–]+\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        c = c.replacingOccurrences(of: #"^[|:\-–\s]+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if c.isEmpty { c = n.isEmpty ? "Divers" : n }
        if c == c.uppercased() {
            c = c.lowercased().split(separator: " ", omittingEmptySubsequences: false).map { w -> String in
                let u = String(w)
                if ["tnt", "sat", "hd", "fhd", "uhd", "vod", "ppv", "tv", "hbo", "ocs"].contains(u) { return u.uppercased() }
                return u.prefix(1).uppercased() + u.dropFirst()
            }.joined(separator: " ")
        }
        return c
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Lectures dans la base

enum MediaStore {
    private static let filmCols = "pid,sid,name,year,icon,cid,ext,rating,added,tmdb,''"
    private static let seriesCols = "pid,sid,name,year,cover,cid,'',rating,added,tmdb,plot"
    private static func table(_ k: MediaKind) -> String { k == .film ? "vod" : "series" }
    private static func cols(_ k: MediaKind) -> String { k == .film ? filmCols : seriesCols }

    private static func row(_ k: MediaKind, _ r: Database.Statement) -> MediaItem {
        MediaItem(kind: k, pid: r.str(0), sid: r.str(1), name: r.str(2), year: r.int(3), icon: r.str(4), cid: r.str(5),
                  ext: r.str(6), rating: r.double(7), added: r.int(8), tmdb: r.str(9), plot: r.str(10))
    }

    private static func inList(_ pids: [String]) -> String { "(" + pids.map { _ in "?" }.joined(separator: ",") + ")" }

    /// Une rangée, sans doublons (même titre chez plusieurs fournisseurs ou en plusieurs qualités = une seule affiche).
    static func list(_ k: MediaKind, pids: [String], where cond: String = "1", args: [Any?] = [], order: String, limit: Int) async -> [MediaItem] {
        guard !pids.isEmpty else { return [] }
        let sql = "SELECT \(cols(k)) FROM \(table(k)) WHERE pid IN \(inList(pids)) AND \(cond) ORDER BY \(order) LIMIT \(limit * 3)"
        return await Database.shared.read { db in
            var out: [MediaItem] = [], seen = Set<String>()
            db.query(sql, pids + args) { r in
                let it = row(k, r)
                if seen.insert(it.clean.key).inserted { out.append(it) }
            }
            return Array(Array(out.prefix(limit * 2)).withFiches().uniqueWorks().prefix(limit))
        }
    }

    /// Titres choisis d'après leur fiche TMDB (collections « Moins de 2 h », « ★ 8 et plus », une saga…).
    static func ficheList(_ k: MediaKind, pids: [String], cond: String, args: [Any?] = [], order: String, limit: Int) async -> [MediaItem] {
        guard !pids.isEmpty else { return [] }
        let t = table(k), c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let sql = "SELECT \(c) FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND (\(cond)) AND m.pid IN \(inList(pids)) ORDER BY \(order) LIMIT \(limit * 3)"
        let all: [Any?] = [k.rawValue] + args + pids.map { $0 as Any? }
        return await Database.shared.read { db in
            var out: [MediaItem] = [], seen = Set<String>()
            db.query(sql, all) { r in let it = row(k, r); if seen.insert(it.clean.key).inserted { out.append(it) } }
            return Array(Array(out.prefix(limit * 2)).withFiches().uniqueWorks().prefix(limit))
        }
    }

    /// Nombre de titres d'une condition sur la fiche (pour « 12 films » sur une tuile).
    static func ficheCount(_ k: MediaKind, pids: [String], cond: String, args: [Any?] = []) async -> Int {
        guard !pids.isEmpty else { return 0 }
        let t = table(k)
        let sql = "SELECT COUNT(DISTINCT f.ckey) FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND (\(cond)) AND m.pid IN \(inList(pids))"
        let all: [Any?] = [k.rawValue] + args + pids.map { $0 as Any? }
        return await Database.shared.read { db in
            var n = 0
            db.query(sql, all) { r in n = r.int(0) }
            return n
        }
    }

    struct SagaInfo: Identifiable, Hashable { let id: Int; let name: String; let count: Int }

    /// Sagas (collections TMDB) dont au moins 2 films sont chez tes fournisseurs.
    static func sagas(pids: [String]) async -> [SagaInfo] {
        guard !pids.isEmpty else { return [] }
        let sql = "SELECT f.coll, MAX(f.collname), COUNT(DISTINCT f.ckey) AS n FROM fiche f JOIN vod m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind='film' AND f.coll>0 AND m.pid IN \(inList(pids)) GROUP BY f.coll HAVING n>=2 ORDER BY n DESC LIMIT 60"
        return await Database.shared.read { db in
            var out: [SagaInfo] = []
            db.query(sql, pids.map { $0 as Any? }) { r in out.append(SagaInfo(id: r.int(0), name: r.str(1), count: r.int(2))) }
            return out
        }
    }

    /// Une rangée par genre (genres TMDB), les mieux notés d'abord.
    static func byGenre(_ k: MediaKind, pids: [String], genre: String, limit: Int) async -> [MediaItem] {
        guard !pids.isEmpty else { return [] }
        let t = table(k), c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let sql = "SELECT \(c) FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND f.genres LIKE ? AND m.pid IN \(inList(pids)) ORDER BY f.vote DESC LIMIT \(limit * 2)"
        return await Database.shared.read { db in
            var out: [MediaItem] = [], seen = Set<String>()
            db.query(sql, [k.rawValue, "%" + genre + "%"] + pids) { r in let it = row(k, r); if seen.insert(it.clean.key).inserted { out.append(it) } }
            return Array(Array(out.prefix(limit * 2)).withFiches().uniqueWorks().prefix(limit))
        }
    }

    /// Titres disponibles correspondant à des fiches TMDB (sagas, même univers).
    static func items(kind k: MediaKind, tmdb ids: [Int], pids: [String]) async -> [Int: MediaItem] {
        guard !ids.isEmpty, !pids.isEmpty else { return [:] }
        let t = table(k), c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let sql = "SELECT \(c), f.tmdb FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND f.tmdb IN (" + ids.map { _ in "?" }.joined(separator: ",") + ") AND m.pid IN \(inList(pids))"
        return await Database.shared.read { db in
            var out: [Int: MediaItem] = [:]
            db.query(sql, [k.rawValue] + ids.map { $0 as Any? } + pids) { r in let it = row(k, r); out[r.int(11)] = it }
            // titres sans fiche téléchargée : l'identifiant TMDB donné par le fournisseur suffit
            let missing = ids.filter { out[$0] == nil }
            if !missing.isEmpty {
                let sql2 = "SELECT \(cols(k)), tmdb FROM \(t) WHERE tmdb IN (" + missing.map { _ in "?" }.joined(separator: ",") + ") AND pid IN \(inList(pids))"
                db.query(sql2, missing.map { String($0) as Any? } + pids.map { $0 as Any? }) { r in let id = r.int(11); if out[id] == nil { out[id] = row(k, r) } }
            }
            let withF = Array(out).map { ($0.key, $0.value) }
            let filled = withF.map { $0.1 }.withFiches()
            var res: [Int: MediaItem] = [:]
            for (i, m) in filled.enumerated() { res[m.fiche?.tmdb ?? withF[i].0] = m }
            return res
        }
    }

    /// Même univers : titres dont le début (avant « : ») ou un mot composé (« spider-man ») est le même.
    static func universe(of it: MediaItem, pids: [String], exclude: Set<Int>) async -> [MediaItem] {
        let base = it.displayTitle.components(separatedBy: CharacterSet(charactersIn: ":–(")).first?.trimmingCharacters(in: .whitespaces) ?? ""
        var terms: [String] = []
        let core = base.replacingOccurrences(of: #"\s+\d+$"#, with: "", options: .regularExpression).replacingOccurrences(of: #"^(The|Le|La|Les|L')\s+"#, with: "", options: .regularExpression)
        if core.count >= 4 { terms.append(core) }
        for w in base.split(separator: " ") where w.contains("-") && w.count >= 5 { terms.append(String(w)) }
        guard !terms.isEmpty, !pids.isEmpty else { return [] }
        let k = it.kind, t = table(k), c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let cond = terms.map { _ in "(f.title LIKE ? OR f.title LIKE ?)" }.joined(separator: " OR ")
        let args: [Any?] = terms.flatMap { [$0 + "%", "% " + $0 + "%"] as [Any?] }
        let sql = "SELECT \(c), f.tmdb FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND (\(cond)) AND m.pid IN \(inList(pids)) ORDER BY f.year LIMIT 60"
        return await Database.shared.read { db in
            var out: [MediaItem] = [], seen = Set<String>()
            db.query(sql, [k.rawValue] + args + pids) { r in
                let m = row(k, r)
                if !exclude.contains(r.int(11)), m.clean.key != it.clean.key, seen.insert(m.clean.key).inserted { out.append(m) }
            }
            return Array(Array(out.prefix(40)).withFiches().uniqueWorks(excluding: it).prefix(24))
        }
    }

    /// « Si tu hésites encore » / « Séries proches » : titres qui partagent le plus de genres TMDB, les mieux notés d'abord.
    /// Sans fiche TMDB : les mieux notés de la même catégorie chez le fournisseur. Renvoie aussi les genres en commun.
    static func similar(of it: MediaItem, genres: [String], pids: [String], limit: Int) async -> [(MediaItem, [String])] {
        guard !pids.isEmpty else { return [] }
        let k = it.kind, t = table(k)
        if genres.isEmpty {
            let list = await Database.shared.read { db -> [MediaItem] in
                var out: [MediaItem] = [], seen = Set<String>([it.clean.key])
                db.query("SELECT \(cols(k)) FROM \(t) WHERE pid=? AND cid=? ORDER BY rating DESC, added DESC LIMIT \(limit * 3)", [it.pid, it.cid]) { r in
                    let m = row(k, r); if seen.insert(m.clean.key).inserted { out.append(m) }
                }
                return Array(Array(out.prefix(limit * 2)).withFiches().uniqueWorks(excluding: it).prefix(limit))
            }
            return list.map { ($0, []) }
        }
        let c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let G = Array(genres.prefix(3))
        let cond = G.map { _ in "f.genres LIKE ?" }.joined(separator: " OR ")
        let sql = "SELECT \(c), f.genres FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND (\(cond)) AND m.pid IN \(inList(pids)) ORDER BY f.vote DESC LIMIT 240"
        let args: [Any?] = [k.rawValue] + G.map { ("%" + $0 + "%") as Any? } + pids.map { $0 as Any? }
        return await Database.shared.read { db in
            var out: [(MediaItem, [String], Int)] = [], seen = Set<String>([it.clean.key])
            var i = 0
            db.query(sql, args) { r in
                let m = row(k, r)
                guard seen.insert(m.clean.key).inserted else { return }
                let theirs = r.str(11).components(separatedBy: ", ")
                let common = genres.filter { theirs.contains($0) }
                out.append((m, common, i)); i += 1
            }
            let best = Array(out.sorted { $0.1.count != $1.1.count ? $0.1.count > $1.1.count : $0.2 < $1.2 }.prefix(limit * 3))
            let withF = best.map { $0.0 }.withFiches()
            // une seule affiche par œuvre (identifiant TMDB), jamais le film de la fiche lui-même
            var keys = Set<String>([it.workKey])
            var res: [(MediaItem, [String])] = []
            for (m, b) in zip(withF, best) where keys.insert(m.workKey).inserted { res.append((m, b.1)); if res.count >= limit { break } }
            return res
        }
    }

    /// Les autres films / séries d'un acteur dans tes abonnements (d'après la distribution des fiches TMDB).
    static func withActor(_ name: String, kind k: MediaKind, pids: [String], excluding key: String) async -> [MediaItem] {
        guard !pids.isEmpty, !name.isEmpty else { return [] }
        let enc = String(data: (try? JSONEncoder().encode(name)) ?? Data(), encoding: .utf8) ?? "\"\(name)\""
        let t = table(k), c = cols(k).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
        let sql = "SELECT \(c) FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND f.cast LIKE ? AND m.pid IN \(inList(pids)) ORDER BY f.year DESC LIMIT 80"
        let args: [Any?] = [k.rawValue, "%\"n\":" + enc + "%"] + pids.map { $0 as Any? }
        return await Database.shared.read { db in
            var out: [MediaItem] = [], seen = Set<String>([key])
            db.query(sql, args) { r in let m = row(k, r); if seen.insert(m.clean.key).inserted { out.append(m) } }
            return Array(Array(out.prefix(50)).withFiches().uniqueWorks().prefix(30))
        }
    }

    struct Cat: Identifiable, Hashable { let pid: String; let cid: String; let name: String; let count: Int; var id: String { pid + ":" + cid } }

    static func categories(_ k: MediaKind, pids: [String]) async -> [Cat] {
        guard !pids.isEmpty else { return [] }
        let type = k == .film ? "vod" : "series"
        let sql = """
            SELECT c.pid, c.cid, c.name, COUNT(m.sid) FROM category c JOIN \(table(k)) m ON m.pid=c.pid AND m.cid=c.cid
            WHERE c.type='\(type)' AND c.pid IN \(inList(pids)) GROUP BY c.pid, c.cid HAVING COUNT(m.sid)>0 ORDER BY c.pid, c.pos
            """
        return await Database.shared.read { db in
            var out: [Cat] = []
            db.query(sql, pids) { r in out.append(Cat(pid: r.str(0), cid: r.str(1), name: TitleTools.category(r.str(2)), count: r.int(3))) }
            return out
        }
    }

    static func page(_ k: MediaKind, cat: Cat, offset: Int, limit: Int) async -> [MediaItem] {
        await Database.shared.read { db in
            var out: [MediaItem] = []
            db.query("SELECT \(cols(k)) FROM \(table(k)) WHERE pid=? AND cid=? ORDER BY added DESC LIMIT ? OFFSET ?", [cat.pid, cat.cid, limit, offset]) { r in out.append(row(k, r)) }
            return out.withFiches()
        }
    }

    static func items(ids: [String]) async -> [MediaItem] {
        var films: [(String, String)] = [], series: [(String, String)] = []
        for id in ids {
            let p = id.split(separator: ":", maxSplits: 2).map(String.init)
            guard p.count == 3 else { continue }
            if p[0] == "film" { films.append((p[1], p[2])) } else { series.append((p[1], p[2])) }
        }
        let byID: [String: MediaItem] = await Database.shared.read { db in
            var m: [String: MediaItem] = [:]
            for (k, L) in [(MediaKind.film, films), (.series, series)] where !L.isEmpty {
                for chunk in stride(from: 0, to: L.count, by: 300) {
                    let part = Array(L[chunk..<min(L.count, chunk + 300)])
                    let cond = part.map { _ in "(pid=? AND sid=?)" }.joined(separator: " OR ")
                    db.query("SELECT \(cols(k)) FROM \(table(k)) WHERE \(cond)", part.flatMap { [$0.0, $0.1] as [Any?] }) { r in let it = row(k, r); m[it.id] = it }
                }
            }
            let f1 = Array(m.values.filter { $0.kind == .film }).withFiches(), f2 = Array(m.values.filter { $0.kind == .series }).withFiches()
            var all: [String: MediaItem] = [:]
            for x in f1 + f2 { all[x.id] = x }
            return all
        }
        return ids.compactMap { byID[$0] }
    }

    /// Toutes les versions d'un titre (fournisseurs, langues, qualités), la plus adaptée en premier.
    static func versions(of it: MediaItem, pids: [String]) async -> [MediaItem] {
        let c = it.clean
        let words = c.title.split(separator: " ").prefix(3).joined(separator: " ")
        guard !pids.isEmpty, !words.isEmpty else { return [it] }
        let like = "%" + words.replacingOccurrences(of: "%", with: "") + "%"
        // même œuvre sous un autre nom (titre français / anglais) : même identifiant TMDB (fiche ou fournisseur)
        let tm = it.workKey.hasPrefix("t") ? String(it.workKey.dropFirst()) : ""
        let found = await Database.shared.read { db -> [MediaItem] in
            var out: [MediaItem] = [], ids = Set<String>()
            db.query("SELECT \(cols(it.kind)) FROM \(table(it.kind)) WHERE pid IN \(inList(pids)) AND name LIKE ? LIMIT 200", pids + [like]) { r in let m = row(it.kind, r); if ids.insert(m.id).inserted { out.append(m) } }
            if !tm.isEmpty {
                db.query("SELECT \(cols(it.kind)) FROM \(table(it.kind)) WHERE pid IN \(inList(pids)) AND tmdb=? LIMIT 50", pids + [tm]) { r in let m = row(it.kind, r); if ids.insert(m.id).inserted { out.append(m) } }
                let t = table(it.kind), cc = cols(it.kind).split(separator: ",").map { $0.hasPrefix("'") ? String($0) : "m." + $0 }.joined(separator: ",")
                db.query("SELECT \(cc) FROM fiche f JOIN \(t) m ON m.pid=f.pid AND m.sid=f.sid WHERE f.kind=? AND f.tmdb=? AND m.pid IN \(inList(pids)) LIMIT 50", ([it.kind.rawValue, Int(tm)] as [Any?]) + pids.map { $0 as Any? }) { r in let m = row(it.kind, r); if ids.insert(m.id).inserted { out.append(m) } }
            }
            return out.withFiches()
        }
        var same = found.filter { $0.clean.key == c.key || (!tm.isEmpty && $0.workKey == it.workKey) }.map { var x = $0; x.fiche = x.fiche ?? it.fiche; return x }
        if !same.contains(where: { $0.id == it.id }) { same.insert(it, at: 0) }
        func score(_ m: MediaItem) -> Int {
            let t = m.clean.tags
            return (t.contains("MULTI") ? 30 : t.contains("VF") ? 25 : t.contains("VOSTFR") ? 5 : 15) + (t.contains("4K") ? 6 : t.contains("1080p") ? 4 : 2)
        }
        return same.sorted { score($0) > score($1) }
    }
}

// MARK: - Reprise de lecture et historique (données à toi : gardées d'une version à l'autre)

@MainActor
final class WatchStore: ObservableObject {
    static let shared = WatchStore()
    struct Entry: Codable { var pos: Double; var dur: Double; var at: Date; var title: String; var icon: String; var item: String; var ep: String? }
    @Published private(set) var entries: [String: Entry] = [:]   // clé : id du film ou de l'épisode
    @Published var favorites: [String] = [] { didSet { UserDefaults.standard.set(favorites, forKey: "prisme.media.favs") } }

    /// Test du simulateur uniquement (argument de lancement) : historique de visionnage factice pour voir « Reprendre ».
    func debugSeed(_ list: [(String, Entry)]) { for (k, e) in list { entries[k] = e } }

    private init() {
        if let d = UserDefaults.standard.data(forKey: "prisme.watch"), let e = try? JSONDecoder().decode([String: Entry].self, from: d) { entries = e }
        favorites = UserDefaults.standard.stringArray(forKey: "prisme.media.favs") ?? []
    }

    func save(key: String, pos: Double, dur: Double, title: String, icon: String, item: String, ep: String? = nil) {
        guard dur > 0 else { return }
        entries[key] = Entry(pos: pos, dur: dur, at: Date(), title: title, icon: icon, item: item, ep: ep)
        if entries.count > 600 {
            let old = entries.sorted { $0.value.at < $1.value.at }.prefix(entries.count - 600).map(\.key)
            old.forEach { entries.removeValue(forKey: $0) }
        }
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: "prisme.watch") }
    }

    func resume(_ key: String) -> Double? {
        guard let e = entries[key], e.dur > 0, e.pos > 30, e.pos / e.dur < 0.92 else { return nil }
        return e.pos
    }
    func fraction(_ key: String) -> Double? {
        guard let e = entries[key], e.dur > 0 else { return nil }
        return min(1, e.pos / e.dur)
    }
    func watched(_ key: String) -> Bool { (fraction(key) ?? 0) >= 0.92 }

    /// « Reprendre » : ce qui a été commencé et pas fini, le plus récent d'abord (un seul épisode par série).
    var inProgress: [Entry] {
        var seen = Set<String>()
        return entries.values.filter { $0.dur > 0 && $0.pos > 30 && $0.pos / $0.dur < 0.92 && !$0.item.hasPrefix("replay:") }.sorted { $0.at > $1.at }
            .filter { seen.insert($0.item).inserted }
    }

    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.insert(id, at: 0) }
    }

    /// « Saison vue » / « Saison non vue » sur la fiche d'une série.
    func setWatched(_ keys: [String], watched: Bool, title: String, icon: String, item: String) {
        for k in keys {
            if watched { entries[k] = Entry(pos: 1, dur: 1, at: Date(), title: title, icon: icon, item: item, ep: nil) }
            else { entries.removeValue(forKey: k) }
        }
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: "prisme.watch") }
    }
}

// MARK: - Infos détaillées chez le fournisseur (résumé, distribution, durée, image de fond, épisodes)

struct MediaInfo {
    var plot = "", cast = "", director = "", genre = "", duration = "", backdrop = "", rating = 0.0, year = 0
    var seasons: [Season] = []
    var seconds = 0          // durée exacte donnée par le fournisseur (0 = inconnue)
    var trailer = ""         // identifiant YouTube de la bande-annonce (fournisseur)
    var age = ""             // classification (« 12+ »…) si le fournisseur la donne
    var country = ""
    var tmdb = 0             // identifiant TMDB donné par le fournisseur
    /// Durée en minutes : la valeur exacte, sinon « 01:52:00 » / « 112 min » lu dans le texte.
    var minutes: Int {
        if seconds > 0 { return Int((Double(seconds) / 60).rounded()) }
        return MediaInfo.parseMinutes(duration)
    }
    static func parseMinutes(_ d: String) -> Int {
        let t = d.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return 0 }
        let parts = t.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 3 { return parts[0] * 60 + parts[1] + (parts[2] >= 30 ? 1 : 0) }
        if parts.count == 2 { return parts[0] * 60 + parts[1] }
        let digits = t.prefix { $0.isNumber }
        if let n = Int(digits), n > 0 { return t.lowercased().contains("h") && !t.lowercased().contains("min") ? n * 60 : n }
        return 0
    }
}
struct Season: Identifiable { let number: Int; let episodes: [EpisodeInfo]; var id: Int { number } }
struct EpisodeInfo: Identifiable, Hashable {
    let id: String; let season: Int; let number: Int; let title: String; let ext: String; let plot: String; let image: String; let duration: String
    var seconds = 0
    var rating = 0.0
    var minutes: Int { seconds > 0 ? Int((Double(seconds) / 60).rounded()) : MediaInfo.parseMinutes(duration) }
}

enum InfoLoader {
    private static let cache = NSCache<NSString, Box>()
    final class Box { let v: MediaInfo; init(_ v: MediaInfo) { self.v = v } }

    static func load(_ it: MediaItem) async -> MediaInfo {
        if let b = cache.object(forKey: it.id as NSString) { return b.v }
        guard let prov = await ProviderStore.shared.provider(it.pid) else { return MediaInfo() }
        var c = URLComponents(string: prov.account.baseURL + "/player_api.php")
        c?.queryItems = [URLQueryItem(name: "username", value: prov.username), URLQueryItem(name: "password", value: prov.password),
                         URLQueryItem(name: "action", value: it.kind == .film ? "get_vod_info" : "get_series_info"),
                         URLQueryItem(name: it.kind == .film ? "vod_id" : "series_id", value: it.sid)]
        let q0 = c?.percentEncodedQuery
        c?.percentEncodedQuery = q0?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = c?.url, let res = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: res.0) as? [String: Any] else { return MediaInfo() }
        var m = MediaInfo()
        let info = root["info"] as? [String: Any] ?? [:]
        func s(_ k: String) -> String {
            switch info[k] { case let v as String: return v; case let n as NSNumber: return n.stringValue; default: return "" }
        }
        m.plot = s("plot").isEmpty ? s("description") : s("plot")
        m.cast = s("cast").isEmpty ? s("actors") : s("cast")
        m.director = s("director")
        m.genre = s("genre")
        m.duration = s("duration")
        if let bd = info["backdrop_path"] as? [String], let f = bd.first { m.backdrop = f } else { m.backdrop = s("backdrop_path") }
        m.rating = Double(s("rating")) ?? 0
        m.year = Int((s("releasedate").isEmpty ? s("releaseDate") : s("releasedate")).prefix(4)) ?? 0
        m.seconds = Int(s("duration_secs")) ?? 0
        if m.seconds == 0, let rt = Int(s("episode_run_time")), rt > 0, it.kind == .series { m.seconds = rt * 60 }
        m.trailer = s("youtube_trailer")
        m.age = s("mpaa_rating").isEmpty ? s("age") : s("mpaa_rating")
        m.country = s("country")
        m.tmdb = Int(s("tmdb_id").isEmpty ? s("tmdb") : s("tmdb_id")) ?? 0
        if it.kind == .series {
            var seasons: [Int: [EpisodeInfo]] = [:]
            func add(_ arr: [[String: Any]], season: Int) {
                for e in arr {
                    func es(_ k: String) -> String { switch e[k] { case let v as String: return v; case let n as NSNumber: return n.stringValue; default: return "" } }
                    let inf = e["info"] as? [String: Any] ?? [:]
                    func isf(_ k: String) -> String { switch inf[k] { case let v as String: return v; case let n as NSNumber: return n.stringValue; default: return "" } }
                    let sn = Int(es("season")) ?? season
                    seasons[sn, default: []].append(EpisodeInfo(id: es("id"), season: sn, number: Int(es("episode_num")) ?? (seasons[sn]?.count ?? 0) + 1,
                        title: es("title"), ext: es("container_extension").isEmpty ? "mp4" : es("container_extension"),
                        plot: isf("plot"), image: isf("movie_image"), duration: isf("duration"),
                        seconds: Int(isf("duration_secs")) ?? 0, rating: Double(isf("rating")) ?? 0))
                }
            }
            if let d = root["episodes"] as? [String: Any] {
                for (k, v) in d { if let arr = v as? [[String: Any]] { add(arr, season: Int(k) ?? 1) } }
            } else if let a = root["episodes"] as? [[[String: Any]]] {
                for (i, arr) in a.enumerated() { add(arr, season: i + 1) }
            }
            m.seasons = seasons.keys.sorted().map { Season(number: $0, episodes: seasons[$0]!.sorted { $0.number < $1.number }) }
        }
        cache.setObject(Box(m), forKey: it.id as NSString)
        return m
    }
}

extension Provider {
    private var userEnc: String { username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username }
    private var passEnc: String { password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? password }
    func movieURL(_ it: MediaItem) -> URL? { URL(string: "\(account.baseURL)/movie/\(userEnc)/\(passEnc)/\(it.sid).\(it.ext.isEmpty ? "mp4" : it.ext)") }
    func episodeURL(_ e: EpisodeInfo) -> URL? { URL(string: "\(account.baseURL)/series/\(userEnc)/\(passEnc)/\(e.id).\(e.ext)") }
}
