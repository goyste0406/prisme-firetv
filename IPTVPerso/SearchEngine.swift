import Foundation

// MARK: - Lot 3 : moteur de recherche (simulateur : wscore, ed1, parse, nlRes, actorIndex)
// La liste des titres (films et séries, un titre par œuvre) est gardée en mémoire, avec les genres, la durée,
// le réalisateur et les acteurs des fiches TMDB déjà téléchargées. Chaque lettre tapée recalcule les scores
// sur cette liste : pas de requête à la base, rapide même avec un très gros catalogue.

enum SearchText {
    /// un mot normalisé (lettres a-z et chiffres) sous forme d'octets : comparaisons bien plus rapides que des caractères
    typealias Word = [UInt8]
    /// minuscules, sans accents ni ponctuation (simulateur nz)
    static func norm(_ s: String) -> String { TitleTools.fold(s.lowercased()) }
    static func words(_ s: String) -> [String] { norm(s).split(separator: " ").map(String.init) }
    static func keys(_ s: String) -> [Word] { words(s).map { Array($0.utf8) } }

    private static let noise: Set<String> = ["4k", "uhd", "2160p", "fhd", "1080p", "1080i", "hd", "720p", "sd", "multi", "vostfr", "vost", "vff", "vfq",
                                             "vf", "vf2", "vo", "truefrench", "french", "hevc", "h265", "x265", "x264", "hdr", "hdr10", "dv", "imax", "remux"]
    private static let lead: Set<String> = ["fr", "fra", "be", "ch", "ca", "qc", "uk", "en", "us", "es", "it", "de", "pt", "ar", "tr", "pl", "nl", "ru",
                                            "kr", "jp", "cn", "in", "eu", "as", "af", "asia", "lat", "vod"]

    /// Mots d'un nom de fournisseur sans expressions régulières (« FR| Dune (2021) 4K MULTI » → dune) :
    /// sert à chercher tout de suite pendant que le nettoyage complet des titres se fait en arrière-plan.
    static func quickWords(_ raw: String) -> (words: [Word], vost: Bool) {
        let f = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var toks: [Word] = [], cur: Word = []
        cur.reserveCapacity(16)
        for c in f.utf8 {
            if c >= 97 && c <= 122 || c >= 48 && c <= 57 { cur.append(c) }
            else if c >= 65 && c <= 90 { cur.append(c + 32) }
            else if !cur.isEmpty { toks.append(cur); cur.removeAll(keepingCapacity: true) }
        }
        if !cur.isEmpty { toks.append(cur) }
        var vost = false
        var out: [Word] = []
        for (i, t) in toks.enumerated() {
            let w = String(decoding: t, as: UTF8.self)
            if w == "vostfr" || w == "vost" { vost = true }
            if i == 0 && toks.count > 1 && lead.contains(w) { continue }
            if noise.contains(w) { continue }
            if t.count == 4, let y = Int(w), y >= 1920 && y < 2050 { continue }
            out.append(t)
        }
        return (out.isEmpty ? toks : out, vost)
    }

    /// une lettre en trop, en moins ou différente (simulateur ed1)
    static func ed1(_ a: Word, _ b: Word) -> Bool {
        let la = a.count, lb = b.count
        guard abs(la - lb) <= 1 else { return false }
        var i = 0
        while i < la && i < lb && a[i] == b[i] { i += 1 }
        func same(_ x: Int, _ y: Int) -> Bool {     // a[x...] == b[y...]
            guard la - x == lb - y else { return false }
            var p = x, q = y
            while p < la { if a[p] != b[q] { return false }; p += 1; q += 1 }
            return true
        }
        if la == lb {
            if i >= la || same(i + 1, i + 1) { return true }
            // deux lettres inversées (« inceptoin » → inception) : comptée comme une seule faute
            return i + 1 < la && a[i] == b[i + 1] && a[i + 1] == b[i] && same(i + 2, i + 2)
        }
        if la > lb { return same(i + 1, i) }
        return same(i, i + 1)
    }

    /// distance d'édition, seulement pour des mots de longueur proche (simulateur lev)
    static func lev(_ a: Word, _ b: Word) -> Int {
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

    private static func starts(_ x: Word, _ w: Word) -> Bool {
        guard x.count >= w.count else { return false }
        var i = 0
        while i < w.count { if x[i] != w[i] { return false }; i += 1 }
        return true
    }

    /// simulateur wscore : chaque mot cherché doit se retrouver (exact 3, début 2, à une lettre près 1,4)
    static func score(_ Q: [Word], _ W: [Word]) -> (s: Double, fuz: Bool)? {
        guard !Q.isEmpty else { return nil }
        var s = 0.0, fuz = false
        for w in Q {
            var b = 0.0
            for x in W {
                if x == w { b = 3; break }
                if starts(x, w) { b = max(b, 2) }
                else if b < 1.4, (w.count >= 4 || (Q.count > 1 && w.count >= 2 && x.count <= w.count + 1))
                            && (ed1(w, x) || (w.count >= 4 && x.count >= w.count && ed1(w, Array(x.prefix(w.count))))) { b = 1.4 }
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
        let words: [SearchText.Word]
        var vost = false
        var genres = ""          // fiche TMDB, sans accents
        var runtime = 0
        var director = ""
        var dirWords: [SearchText.Word] = []
        var rating = 0.0
    }
    struct Actor { let name: String; let photo: String; let words: [SearchText.Word]; var titles: [(key: String, title: String, year: Int)] }

    private(set) var entries: [Entry] = []
    private(set) var actors: [Actor] = []
    private var stamp = ""              // ce que contient entries : « base|tranche de fiches » ou « base|rapide »
    private var base: (b: String, list: [Entry], byKey: [String: Int])?   // titres nettoyés, sans les fiches
    private var quick: (b: String, task: Task<[Entry], Never>)?
    private var full: (b: String, task: Task<Void, Never>)?   // nettoyage complet en cours
    /// envoyé quand l'index complet (titres nettoyés + fiches) remplace l'index rapide : la page relance la recherche affichée
    static let changed = Notification.Name("prisme.searchIndexChanged")
    private var ficheBusy = false
    private var lastFiche = Date.distantPast

    private typealias Row = (kind: MediaKind, pid: String, sid: String, name: String, year: Int, rating: Double)

    /// Prépare la liste des titres pour les fournisseurs, le catalogue et les fiches donnés.
    /// 1. Index rapide (sans expressions régulières, ~1 s pour 60 000 titres) : on peut chercher tout de suite.
    /// 2. En arrière-plan, nettoyage complet des titres sur tous les cœurs, puis ajout des fiches TMDB.
    /// 3. Quand seules les fiches changent : on les réapplique (au plus toutes les 30 s), sans tout refaire.
    /// Une seule construction de chaque sorte à la fois ; la recherche n'attend jamais le nettoyage complet.
    func ensure(pids: [String], catalog: Int, fiches: Int) async {
        guard !pids.isEmpty else { return }
        let b = pids.joined(separator: ",") + "|\(catalog)"
        let st = b + "|\(fiches / 10)"
        if st == stamp { return }
        if let bs = base, bs.b == b {
            if !ficheBusy && Date().timeIntervalSince(lastFiche) >= 30 {
                ficheBusy = true
                let (list, byKey) = (bs.list, bs.byKey)
                Task.detached(priority: .utility) {
                    let (l, a) = await Self.applyFiches(list, byKey)
                    await self.doneFiches(b, st, l, a)
                }
            }
            return
        }
        if full?.b != b {
            let t = Task.detached(priority: .utility) {
                let rows = await Self.rows(pids)
                let (list, byKey) = Self.clean(rows)
                let (l, a) = await Self.applyFiches(list, byKey)
                await self.doneFull(b, st, list, byKey, l, a)
            }
            full = (b, t)
        }
        if stamp.hasPrefix(b + "|") { return }
        let task: Task<[Entry], Never>
        if let q = quick, q.b == b { task = q.task } else {
            task = Task.detached(priority: .userInitiated) { Self.quickList(await Self.rows(pids)) }
            quick = (b, task)
        }
        let l = await task.value
        if quick?.b == b { quick = nil }
        // petit catalogue : le nettoyage complet ne prend qu'un instant, on l'attend (genres, acteurs, phrases dès la 1re lettre)
        if l.count < 8000, let f = full, f.b == b { await f.task.value; if stamp.hasPrefix(b + "|") { return } }
        if !stamp.hasPrefix(b + "|") { entries = l; actors = []; stamp = b + "|rapide" }
    }

    private func doneFull(_ b: String, _ st: String, _ list: [Entry], _ byKey: [String: Int], _ l: [Entry], _ a: [Actor]) {
        guard full?.b == b else { return }
        full = nil
        let wasQuick = stamp == b + "|rapide"
        base = (b, list, byKey); entries = l; actors = a; stamp = st; lastFiche = Date()
        if wasQuick { Task { @MainActor in NotificationCenter.default.post(name: Self.changed, object: nil) } }
    }

    private func doneFiches(_ b: String, _ st: String, _ l: [Entry], _ a: [Actor]) {
        ficheBusy = false; lastFiche = Date()
        guard base?.b == b else { return }
        entries = l; actors = a; stamp = st
    }

    private static func rows(_ pids: [String]) async -> [Row] {
        let ph = "(" + pids.map { _ in "?" }.joined(separator: ",") + ")"
        return await Database.shared.read { db in
            var out: [Row] = []
            for (k, t) in [(MediaKind.film, "vod"), (.series, "series")] {
                db.query("SELECT pid,sid,name,year,rating FROM \(t) WHERE pid IN \(ph)", pids) { r in out.append((k, r.str(0), r.str(1), r.str(2), r.int(3), r.double(4))) }
            }
            return out
        }
    }

    /// index rapide : mots du nom brut, un titre par nom
    private static func quickList(_ rows: [Row]) -> [Entry] {
        let t0 = Date()
        var seen: [String: Int] = [:], list: [Entry] = []
        list.reserveCapacity(rows.count)
        for r in rows {
            let (w, vost) = SearchText.quickWords(r.name)
            guard !w.isEmpty else { continue }
            let k = r.kind.rawValue + "|" + w.map { String(decoding: $0, as: UTF8.self) }.joined(separator: " ") + "|\(r.year)"
            if let i = seen[k] { if vost { list[i].vost = true }; continue }
            seen[k] = list.count
            list.append(Entry(id: r.kind.rawValue + ":" + r.pid + ":" + r.sid, kind: r.kind, key: "", title: r.name, year: r.year,
                              words: w, vost: vost, rating: r.rating))
        }
        PerfLog.ev("Index de recherche rapide : \(list.count) titres · \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        return list
    }

    /// nettoyage complet (règles du simulateur), réparti sur tous les cœurs
    private static func clean(_ rows: [Row]) -> ([Entry], [String: Int]) {
        let t0 = Date()
        let n = rows.count
        var cl = [CleanTitle](repeating: CleanTitle(title: "", year: 0, tags: []), count: n)
        let parts = max(1, ProcessInfo.processInfo.activeProcessorCount * 4)
        cl.withUnsafeMutableBufferPointer { buf in
            let p = buf
            DispatchQueue.concurrentPerform(iterations: parts) { c in
                var i = c * n / parts
                let e = (c + 1) * n / parts
                while i < e { p[i] = TitleTools.clean(rows[i].name, year: rows[i].year); i += 1 }
            }
        }
        var byKey: [String: Int] = [:], list: [Entry] = []
        list.reserveCapacity(n / 2)
        for (r, c) in zip(rows, cl) {
            let key = r.kind.rawValue + "|" + c.key
            let vost = c.tags.contains("VOSTFR")
            if let i = byKey[key] { if vost { list[i].vost = true }; continue }
            byKey[key] = list.count
            list.append(Entry(id: r.kind.rawValue + ":" + r.pid + ":" + r.sid, kind: r.kind, key: c.key, title: c.title, year: c.year,
                              words: SearchText.keys(c.title), vost: vost, rating: r.rating))
        }
        PerfLog.ev("Index de recherche complet : \(list.count) titres · \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        return (list, byKey)
    }

    /// fiches TMDB : genres, durée, réalisateur, acteurs
    private static func applyFiches(_ list0: [Entry], _ byKey: [String: Int]) async -> ([Entry], [Actor]) {
        let t0 = Date()
        var list = list0
        let fiches: [(String, String, String, Int, String, String, Int, Double)] = await Database.shared.read { db in
            var out: [(String, String, String, Int, String, String, Int, Double)] = []
            db.query("SELECT kind,ckey,genres,runtime,director,\"cast\",year,vote FROM fiche", []) { r in
                out.append((r.str(0), r.str(1), r.str(2), r.int(3), r.str(4), r.str(5), r.int(6), r.double(7)))
            }
            return out
        }
        var amap: [String: Actor] = [:]
        let dec = JSONDecoder()
        for (kind, ckey, genres, runtime, director, cast, year, vote) in fiches {
            guard let i = byKey[kind + "|" + ckey] else { continue }
            list[i].genres = SearchText.norm(genres)
            list[i].runtime = runtime
            if !director.isEmpty { list[i].director = director; list[i].dirWords = SearchText.keys(director) }
            if vote > 0 { list[i].rating = vote }
            if let d = cast.data(using: .utf8), let cs = try? dec.decode([CastMember].self, from: d) {
                for m in cs.prefix(8) where !m.n.isEmpty {
                    let n = SearchText.norm(m.n)
                    if amap[n] == nil { amap[n] = Actor(name: m.n, photo: m.p, words: SearchText.keys(m.n), titles: []) }
                    amap[n]!.titles.append((ckey, list[i].title, year > 0 ? year : list[i].year))
                }
            }
        }
        PerfLog.ev("Index de recherche, fiches : \(fiches.count) fiches, \(amap.count) acteurs · \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        return (list, Array(amap.values))
    }

    /// chaînes et programmes en cours qui répondent à la recherche (mots calculés une fois par liste)
    private var liveSig = ""
    private var liveWords: [([SearchText.Word], [SearchText.Word])] = []
    func liveMatch(_ Q: [SearchText.Word], _ all: [LiveStore.Airing]) -> [Int] {
        let sig = "\(all.count)|\(all.first?.id ?? "")|\(all.last?.id ?? "")"
        if sig != liveSig {
            liveWords = all.map { (SearchText.keys(ChannelTools.clean($0.ch.name)), SearchText.keys($0.p.title)) }
            liveSig = sig
        }
        var out: [Int] = []
        for (i, w) in liveWords.enumerated() where SearchText.score(Q, w.0) != nil || SearchText.score(Q, w.1) != nil { out.append(i) }
        return out
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
        let qw = n.split(separator: " ").map { Array($0.utf8) }
        for a in actors where a.words.count > 1 {
            if a.words.allSatisfy({ w in n.contains(" " + String(decoding: w, as: UTF8.self) + " ") || (w.count > 3 && qw.contains { $0.count > 3 && SearchText.lev($0, w) <= 1 }) }) { f.actor = a.name; break }
        }
        return f.any ? f : nil
    }

    func search(_ q0: String, bed: Int, now: Int) -> Result {
        var r = Result()
        let q = q0.trimmingCharacters(in: .whitespaces)
        let Q = SearchText.keys(q)
        guard !Q.isEmpty else { return r }
        // on ne garde que les 40 meilleurs films et les 40 meilleures séries (pas de tri de toute la liste)
        typealias Cand = (m: Double, y: Int, r: Double, i: Int)
        func better(_ a: Cand, _ b: Cand) -> Bool { a.m != b.m ? a.m > b.m : (a.y != b.y ? a.y > b.y : a.r > b.r) }
        func push(_ t: inout [Cand], _ c: Cand) {
            if t.count == 40 { if !better(c, t[39]) { return }; t.removeLast() }
            t.insert(c, at: t.firstIndex { better(c, $0) } ?? t.count)
        }
        var topF: [Cand] = [], topS: [Cand] = [], best = 0.0, ne = 0, nf = 0
        let ents = entries
        for i in ents.indices {
            let e = ents[i]
            let a = SearchText.score(Q, e.words)
            let b = e.dirWords.isEmpty ? nil : SearchText.score(Q, e.dirWords)
            let m = max(a?.s ?? 0, (b?.s ?? 0) * 0.7)
            guard m > 0 else { continue }
            let fz = (a != nil && a!.fuz && a!.s == m) || (a == nil && b!.fuz)
            if fz { nf += 1 } else { ne += 1 }
            best = max(best, m)
            if e.kind == .film { push(&topF, (m, e.year, e.rating, i)) } else { push(&topS, (m, e.year, e.rating, i)) }
        }
        r.films = topF.map { ents[$0.i].id }
        r.series = topS.map { ents[$0.i].id }
        let titleHits = ne + nf
        var A: [(Actor, Double, Bool)] = []
        for a in actors { if let s = SearchText.score(Q, a.words), s.s >= 1.4 { A.append((a, s.s, s.fuz)); if s.fuz { nf += 1 } else { ne += 1 } } }
        r.actors = A.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.titles.count > $1.0.titles.count }.prefix(12).map(\.0)
        r.fuzzy = nf > 0 && ne == 0
        // phrase : seulement si les titres ne répondent pas déjà très bien (simulateur)
        if let f = parse(q), titleHits == 0 || best < 2.5 || !f.genres.isEmpty || f.decade != nil || f.short || f.live || f.tonight || f.kids {
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
