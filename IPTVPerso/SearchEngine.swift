import Foundation

// MARK: - Lot 3 : moteur de recherche (simulateur : wscore, ed1, parse, nlRes, actorIndex)
// La liste des titres (films et séries, un titre par œuvre) est gardée en mémoire, avec les genres, la durée,
// le réalisateur et les acteurs des fiches TMDB déjà téléchargées. Chaque lettre tapée recalcule les scores
// sur cette liste : pas de requête à la base, rapide même avec un très gros catalogue.

enum SearchText {
    /// minuscules, sans accents ni ponctuation (simulateur nz)
    static func norm(_ s: String) -> String { TitleTools.fold(s.lowercased()) }
    static func words(_ s: String) -> [String] { norm(s).split(separator: " ").map(String.init) }

    /// une lettre en trop, en moins ou différente (simulateur ed1)
    static func ed1(_ a: [Character], _ b: [Character]) -> Bool {
        let la = a.count, lb = b.count
        guard abs(la - lb) <= 1 else { return false }
        var i = 0
        while i < la && i < lb && a[i] == b[i] { i += 1 }
        if la == lb { return a.dropFirst(i + 1).elementsEqual(b.dropFirst(i + 1)) }
        if la > lb { return a.dropFirst(i + 1).elementsEqual(b.dropFirst(i)) }
        return a.dropFirst(i).elementsEqual(b.dropFirst(i + 1))
    }

    /// distance d'édition, seulement pour des mots de longueur proche (simulateur lev)
    static func lev(_ a: [Character], _ b: [Character]) -> Int {
        if abs(a.count - b.count) > 1 { return 9 }
        var d = Array(0...b.count)
        for i in 1...max(1, a.count) where !a.isEmpty {
            var p = d[0]; d[0] = i
            for j in stride(from: 1, through: b.count, by: 1) {
                let t = d[j]
                d[j] = min(d[j] + 1, d[j - 1] + 1, p + (a[i - 1] == b[j - 1] ? 0 : 1))
                p = t
            }
        }
        return d[b.count]
    }

    /// simulateur wscore : chaque mot cherché doit se retrouver (exact 3, début 2, à une lettre près 1,4)
    static func score(_ Q: [[Character]], _ W: [[Character]]) -> (s: Double, fuz: Bool)? {
        guard !Q.isEmpty else { return nil }
        var s = 0.0, fuz = false
        for w in Q {
            var b = 0.0
            for x in W {
                if x == w { b = 3; break }
                if x.starts(with: w) { b = max(b, 2) }
                else if (w.count >= 4 || (Q.count > 1 && w.count >= 2 && x.count <= w.count + 1))
                            && (ed1(w, x) || (w.count >= 4 && x.count >= w.count && ed1(w, Array(x.prefix(w.count))))) { b = max(b, 1.4) }
            }
            if b == 0 { return nil }
            if b == 1.4 { fuz = true }
            s += b
        }
        return (s / Double(Q.count), fuz)
    }
}

/// Ce que la recherche a compris d'une phrase (simulateur parse)
struct SearchAsk: Equatable {
    var genres: [String] = []
    var decade: Int?
    var short = false, tonight = false, vost = false, kids = false, live = false, match = false
    var actor: String?
    var kind: MediaKind?
    var any: Bool { !genres.isEmpty || decade != nil || short || tonight || vost || kids || live || actor != nil || kind != nil }
}

actor SearchIndex {
    static let shared = SearchIndex()

    struct Entry {
        let id: String
        let kind: MediaKind
        let key: String
        let title: String
        let year: Int
        let words: [[Character]]
        var vost = false
        var genres = ""          // fiche TMDB, sans accents
        var runtime = 0
        var director = ""
        var dirWords: [[Character]] = []
        var rating = 0.0
    }
    struct Actor { let name: String; let photo: String; let words: [[Character]]; var titles: [(key: String, title: String, year: Int)] }

    private(set) var entries: [Entry] = []
    private(set) var actors: [Actor] = []
    private var stamp = ""

    /// reconstruit la liste si les fournisseurs, le catalogue ou les fiches ont changé
    func ensure(pids: [String], catalog: Int, fiches: Int) async {
        let st = pids.joined(separator: ",") + "|\(catalog)|\(fiches / 10)"
        guard st != stamp, !pids.isEmpty else { return }
        let ph = "(" + pids.map { _ in "?" }.joined(separator: ",") + ")"
        let rows: [(MediaKind, String, String, String, Int, Double)] = await Database.shared.read { db in
            var out: [(MediaKind, String, String, String, Int, Double)] = []
            for (k, t) in [(MediaKind.film, "vod"), (.series, "series")] {
                db.query("SELECT pid,sid,name,year,rating FROM \(t) WHERE pid IN \(ph)", pids) { r in out.append((k, r.str(0), r.str(1), r.str(2), r.int(3), r.double(4))) }
            }
            return out
        }
        var byKey: [String: Int] = [:], list: [Entry] = []
        list.reserveCapacity(rows.count / 2)
        for (k, pid, sid, name, year, rating) in rows {
            let c = TitleTools.clean(name, year: year)
            let key = k.rawValue + "|" + c.key
            let vost = c.tags.contains("VOSTFR")
            if let i = byKey[key] { if vost { list[i].vost = true }; continue }
            byKey[key] = list.count
            list.append(Entry(id: k.rawValue + ":" + pid + ":" + sid, kind: k, key: c.key, title: c.title, year: c.year,
                              words: SearchText.words(c.title).map(Array.init), vost: vost, rating: rating))
        }
        // fiches TMDB : genres, durée, réalisateur, acteurs
        let fiches: [(String, String, String, Int, String, String, Int, Double)] = await Database.shared.read { db in
            var out: [(String, String, String, Int, String, String, Int, Double)] = []
            db.query("SELECT kind,ckey,genres,runtime,director,\"cast\",year,vote FROM fiche", []) { r in
                out.append((r.str(0), r.str(1), r.str(2), r.int(3), r.str(4), r.str(5), r.int(6), r.double(7)))
            }
            return out
        }
        var amap: [String: Actor] = [:]
        for (kind, ckey, genres, runtime, director, cast, year, vote) in fiches {
            guard let i = byKey[kind + "|" + ckey] else { continue }
            list[i].genres = SearchText.norm(genres)
            list[i].runtime = runtime
            if !director.isEmpty { list[i].director = director; list[i].dirWords = SearchText.words(director).map(Array.init) }
            if vote > 0 { list[i].rating = vote }
            if let d = cast.data(using: .utf8), let cs = try? JSONDecoder().decode([CastMember].self, from: d) {
                for m in cs.prefix(8) where !m.n.isEmpty {
                    let n = SearchText.norm(m.n)
                    if amap[n] == nil { amap[n] = Actor(name: m.n, photo: m.p, words: SearchText.words(m.n).map(Array.init), titles: []) }
                    amap[n]!.titles.append((ckey, list[i].title, year > 0 ? year : list[i].year))
                }
            }
        }
        entries = list
        actors = Array(amap.values)
        stamp = st
    }

    struct Result {
        var films: [String] = [], series: [String] = []
        var actors: [Actor] = []
        var fuzzy = false
        var ask: SearchAsk?
        var asked: [String] = []          // titres répondant à la phrase (ids)
        var why: [String] = []
    }

    private static let GEN: [(String, [String], String)] = [
        ("comedie", ["comedie", "comedies", "drole", "droles", "rire", "humour"], "comédie"), ("action", ["action"], "action"),
        ("policier", ["policier", "policiers", "polar", "enquete", "crime"], "policier"), ("animation", ["animation", "anime", "animes", "dessin", "dessins"], "animation"),
        ("drame", ["drame", "drames"], "drame"), ("science", ["sf", "science", "science-fiction"], "science-fiction"),
        ("horreur", ["horreur", "peur", "epouvante"], "horreur"), ("romance", ["romance", "romantique", "amour"], "romance"),
        ("thriller", ["thriller", "suspense"], "thriller"), ("aventure", ["aventure", "aventures"], "aventure"), ("documentaire", ["documentaire", "docu"], "documentaire"),
    ]

    /// simulateur parse : genres, décennie, court, ce soir, VOSTFR, enfants, en direct / match, film ou série, acteur
    func parse(_ q: String) -> SearchAsk? {
        let n = " " + SearchText.norm(q) + " "
        var f = SearchAsk()
        for (g, L, _) in Self.GEN where L.contains(where: { n.contains(" " + $0 + " ") }) { f.genres.append(g) }
        if [" enfant ", " enfants ", " famille ", " kids ", " jeunesse "].contains(where: n.contains) { f.kids = true }
        if let m = n.range(of: #" annees? (19)?([2-9]0) "#, options: .regularExpression) {
            let d = Int(n[m].filter(\.isNumber).suffix(2)) ?? 0
            f.decade = d < 30 ? 2000 + d : 1900 + d
        } else if let m = n.range(of: #" (19[5-9]0|20[0-2]0)s? "#, options: .regularExpression) {
            f.decade = Int(n[m].filter(\.isNumber).prefix(4))
        }
        if [" court ", " courte ", " courts ", " rapide ", " pas trop long "].contains(where: n.contains) { f.short = true }
        if [" ce soir ", " avant de dormir ", " avant le coucher "].contains(where: n.contains) { f.tonight = true }
        if [" vostfr ", " vost ", " version originale ", " en vo "].contains(where: n.contains) { f.vost = true }
        if [" a la tv ", " a la tele ", " en direct ", " qui passe "].contains(where: n.contains) { f.live = true }
        if [" match ", " foot ", " football ", " ligue ", " sport ", " rugby "].contains(where: n.contains) { f.match = true; f.live = true }
        if n.contains(" film ") || n.contains(" films ") { f.kind = .film }
        if n.contains(" serie ") || n.contains(" series ") { f.kind = .series }
        let qw = n.split(separator: " ").map { Array($0) }
        for a in actors where a.words.count > 1 {
            if a.words.allSatisfy({ w in n.contains(" " + String(w) + " ") || (w.count > 3 && qw.contains { $0.count > 3 && SearchText.lev($0, w) <= 1 }) }) { f.actor = a.name; break }
        }
        return f.any ? f : nil
    }

    func search(_ q0: String, bed: Int, now: Int) -> Result {
        var r = Result()
        let q = q0.trimmingCharacters(in: .whitespaces)
        let Q = SearchText.words(q).map(Array.init)
        guard !Q.isEmpty else { return r }
        var sc: [(Int, Double, Bool)] = [], ne = 0, nf = 0
        for (i, e) in entries.enumerated() {
            let a = SearchText.score(Q, e.words)
            let b = e.dirWords.isEmpty ? nil : SearchText.score(Q, e.dirWords)
            let m = max(a?.s ?? 0, (b?.s ?? 0) * 0.7)
            guard m > 0 else { continue }
            let fz = (a != nil && a!.fuz && a!.s == m) || (a == nil && b!.fuz)
            sc.append((i, m, fz))
            if fz { nf += 1 } else { ne += 1 }
        }
        sc.sort { x, y in x.1 != y.1 ? x.1 > y.1 : (entries[x.0].year, entries[x.0].rating) > (entries[y.0].year, entries[y.0].rating) }
        for (i, _, _) in sc {
            let e = entries[i]
            if e.kind == .film { if r.films.count < 40 { r.films.append(e.id) } } else if r.series.count < 40 { r.series.append(e.id) }
        }
        var A: [(Actor, Double, Bool)] = []
        for a in actors { if let s = SearchText.score(Q, a.words), s.s >= 1.4 { A.append((a, s.s, s.fuz)); if s.fuz { nf += 1 } else { ne += 1 } } }
        r.actors = A.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.titles.count > $1.0.titles.count }.prefix(12).map(\.0)
        r.fuzzy = nf > 0 && ne == 0
        // phrase : seulement si les titres ne répondent pas déjà très bien (simulateur)
        if let f = parse(q), sc.isEmpty || (sc.first?.1 ?? 0) < 2.5 || !f.genres.isEmpty || f.decade != nil || f.short || f.live || f.tonight || f.kids {
            r.ask = f
            if !f.live {
                var L = entries
                var why: [String] = []
                if let k = f.kind { L = L.filter { $0.kind == k } }
                if let a = f.actor, let x = actors.first(where: { $0.name == a }) {
                    let keys = Set(x.titles.map(\.key)); L = L.filter { keys.contains($0.key) }; why.append("avec " + a)
                }
                if !f.genres.isEmpty {
                    L = L.filter { e in f.genres.allSatisfy { e.genres.contains($0) } }
                    why.append(f.genres.map { g in Self.GEN.first { $0.0 == g }?.2 ?? g }.joined(separator: " et "))
                }
                if f.kids { L = L.filter { $0.genres.contains("anim") || $0.genres.contains("famil") }; why.append("pour les enfants") }
                if let d = f.decade { L = L.filter { $0.year >= d && $0.year < d + 10 }; why.append("des années " + String(String(d).suffix(2))) }
                if f.vost { L = L.filter(\.vost); why.append("en VOSTFR") }
                if f.short { L = L.filter { $0.kind == .film && $0.runtime > 0 && $0.runtime <= 105 }; why.append("de moins d'1 h 45") }
                if f.tonight {
                    L = L.filter { $0.kind != .film || ($0.runtime > 0 && now + $0.runtime <= bed) }
                    why.append("finis avant \((bed / 60) % 24) h \(String(format: "%02d", bed % 60)), ton heure du coucher")
                }
                r.asked = L.sorted { $0.rating > $1.rating }.prefix(40).map(\.id)
                r.why = why
            } else {
                r.why = [f.match ? "les matchs en direct maintenant" : "à la TV maintenant"]
            }
        }
        return r
    }

    /// pour l'aperçu d'un acteur et la phrase « films avec … »
    func actor(named n: String) -> Actor? { actors.first { $0.name == n } }
}

/// 6 dernières recherches, par profil (simulateur remember)
@MainActor
enum SearchRecent {
    private static var key: String { ProfileStore.shared.key("prisme.search.recent") }
    static var list: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
    static func remember(_ q0: String) {
        let q = q0.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        let n = SearchText.norm(q)
        UserDefaults.standard.set(Array(([q] + list.filter { SearchText.norm($0) != n }).prefix(6)), forKey: key)
        DataCount.write("recherche [\(ProfileStore.shared.me.id)] : retenue « \(q) »")
    }
}
