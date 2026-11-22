import SwiftUI

// MARK: - Lot 4 : la grande affiche des accueils (simulateur fhSlides / slides)
// Films  : 📺 Ce soir à la télé · ✦ L'arrivée de la semaine · Le moment · 🎬 À l'honneur cette semaine · 🔔 Bientôt chez toi
// Séries : ✦ L'arrivée de la semaine · 📺 Ce soir à la télé · Le moment · 📡 À l'honneur · (rien : On reprend ? / La mieux notée)
// Le soir (17 h – 21 h 30), la télé passe en premier. Une diapositive sans vrai contenu n'apparaît pas.

/// Film au cinéma, pas encore chez le fournisseur (TMDB « now_playing », France).
struct SoonFilm: Equatable {
    let tmdb: Int
    let title: String
    let year: Int
    let vote: Double
    let overview: String
    let backdrop: String
    let cinema: String      // AAAA-MM-JJ
    var vod: String = ""    // sortie en streaming connue (TMDB, France), sinon ''
}

struct HeroSlide: Identifiable {
    enum K: String { case tv, arr, mom, hon, soon, rep }
    let k: K
    var id: String { k.rawValue + "|" + (item?.id ?? title) }
    /// diapositives d'un titre (télé, arrivée, on reprend) : la grande affiche du titre
    var item: MediaItem?
    var airing: LiveStore.Airing?
    /// étiquette (« LE MOMENT · DIMANCHE »)
    var tag = ""
    /// diapositives de collection (moment, à l'honneur) : mosaïque d'affiches
    var title = ""
    var mosaic: [MediaItem] = []
    var meta: [String] = []
    var sub = ""
    var subBold = ""
    var subTail = ""
    var next: MediaItem?          // à l'honneur : le prochain à voir (bouton blanc)
    var coll: CollInfo?           // « Voir la collection », « Tous ses films »
    var collLabel = ""
    var pool: [MediaItem] = []    // « Un au hasard »
    var duo = false               // « Passer en mode à deux »
    var soon: SoonFilm?
}

// MARK: construction

@MainActor
enum HeroSlides {
    private static var soonMemo: (day: String, list: [[String: Any]])?
    private static var vodMemo: [Int: String] = [:]

    static func build(kind: MediaKind, pids: [String], newest: [MediaItem]) async -> [HeroSlide] {
        guard !pids.isEmpty else { return [] }
        let watch = WatchStore.shared, ps = ProfileStore.shared
        let notInt = NotInterested.list(ps.me.id)
        let now = Int(Date().timeIntervalSince1970)
        func started(_ it: MediaItem) -> Bool { watch.entries.values.contains { $0.item == it.id } }
        func seen(_ it: MediaItem, _ ent: [String: WatchStore.Entry]) -> Bool {
            if let e = ent[it.id], e.dur > 0, e.pos / e.dur >= 0.85 { return true }
            let t = TitleTools.fold(it.displayTitle)
            return ent.values.contains { $0.dur > 0 && $0.pos / $0.dur >= 0.85 && $0.item.hasPrefix(it.kind.rawValue + ":") && TitleTools.fold($0.title) == t }
        }
        let mine = watch.entries
        var L: [HeroSlide] = []

        // ✦ L'arrivée de la semaine : ajouts des 2 dernières semaines, la plus populaire des 5 plus récentes
        let fresh = newest.filter { $0.added > now - 14 * 86400 && !notInt.contains($0.workKey) && !(kind == .series && started($0)) }
        let arr = fresh.prefix(5).sorted { ($0.fiche?.pop ?? $0.rating) > ($1.fiche?.pop ?? $1.rating) }.first
        if let a = arr { L.append(HeroSlide(k: .arr, item: a, tag: "✦ L'ARRIVÉE DE LA SEMAINE")) }

        // 📺 Ce soir à la télé : un titre du fournisseur qui passe à la télé d'ici 2 h du matin
        let tv = await tonightOnTV(kind: kind, pids: pids).filter { $0.0.id != arr?.id && !notInt.contains($0.0.workKey) }
        if let x = tv.first(where: { $0.1.p.start > now }) ?? tv.first {
            L.append(HeroSlide(k: .tv, item: x.0, airing: x.1, tag: "📺 CE SOIR À LA TÉLÉ"))
        }

        // Le moment
        if kind == .film { if let m = await filmMoment(pids: pids, seen: seen, notInt: notInt) { L.append(m) } }
        else if let m = await seriesMoment(pids: pids, started: started, notInt: notInt) { L.append(m) }

        // À l'honneur cette semaine
        if kind == .film { if let h = await filmHonour(pids: pids, seen: { seen($0, mine) }) { L.append(h) } }
        else if let h = await seriesHonour(pids: pids, started: started, used: Set(L.compactMap { $0.item?.id })) { L.append(h) }

        // 🔔 Bientôt chez toi (films : TMDB, au cinéma et pas encore chez le fournisseur)
        if kind == .film, let s = await soonFilm() {
            L.append(HeroSlide(k: .soon, tag: "🔔 BIENTÔT CHEZ TOI", title: s.title, soon: s))
        }

        let ord: [HeroSlide.K] = DiscoverClock.evening ? [.tv, .arr, .mom, .hon, .soon] : [.arr, .mom, .hon, .tv, .soon]
        var out = ord.compactMap { k in L.first { $0.k == k } }
        if out.isEmpty && kind == .series {
            // rien à mettre en avant : la mieux notée pas commencée, sinon « On reprend ? »
            let best = await MediaStore.ficheList(.series, pids: pids, cond: "f.vote>=7", order: "f.vote DESC", limit: 20).first { !started($0) && !notInt.contains($0.workKey) }
            if let b = best { out.append(HeroSlide(k: .rep, item: b, tag: "★ LA MIEUX NOTÉE CHEZ TOI")) }
            else if let r = watch.inProgress.first(where: { $0.item.hasPrefix("series:") }), let it = await MediaStore.items(ids: [r.item]).first {
                out.append(HeroSlide(k: .rep, item: it, tag: "↺ ON REPREND ?"))
            }
        }
        DataCount.write("grande affiche \(kind.rawValue) : " + out.map { $0.k.rawValue + "(" + ($0.item?.displayTitle ?? $0.title) + ")" }.joined(separator: ", "))
        return out
    }

    // MARK: télé

    /// Titres du fournisseur qui passent à la télé d'ici 2 h du matin (même titre exact), une chaîne par titre,
    /// dans l'ordre des chaînes ; 6 au plus.
    static func tonightOnTV(kind: MediaKind, pids: [String]) async -> [(MediaItem, LiveStore.Airing)] {
        let now = Int(Date().timeIntervalSince1970)
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date()); c.hour = 2
        var end = Calendar.current.date(from: c).map { Int($0.timeIntervalSince1970) } ?? now + 6 * 3600
        if end <= now { end += 86400 }
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        let titles: [String] = await Database.shared.read { db in
            var out: [String] = []
            db.query("SELECT DISTINCT e.title FROM epg e JOIN live l ON l.epg=e.ch WHERE e.stop>? AND e.start<=? AND l.pid IN (\(ph)) LIMIT 20000",
                     ([now, end] as [Any?]) + pids.map { $0 as Any? }) { r in out.append(r.str(0)) }
            return out
        }
        guard !titles.isEmpty else { return [] }
        let idx = await SearchIndex.shared.exactTitles(kind)
        var matched: [String: String] = [:]   // titre du guide → id
        for t in titles {
            let w = TitleTools.fold(t).replacingOccurrences(of: " ", with: "")
            if w.count >= 3, let id = idx[w] { matched[t] = id }
        }
        guard !matched.isEmpty else { return [] }
        let keys = Array(matched.keys.prefix(200))
        let rows: [LiveStore.Airing] = await Database.shared.read { db in
            var out: [LiveStore.Airing] = []
            db.query("""
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr,COALESCE(e.img,''),COALESCE(e.cat,'') FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.stop>? AND e.start<=? AND l.pid IN (\(ph)) AND e.title IN (\(keys.map { _ in "?" }.joined(separator: ","))) ORDER BY l.num, e.start LIMIT 400
                """, ([now, end] as [Any?]) + pids.map { $0 as Any? } + keys.map { $0 as Any? }) { r in
                out.append(LiveStore.Airing(ch: LiveStore.row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11), img: r.str(12), cat: r.str(13))))
            }
            return out
        }
        var byItem: [String: LiveStore.Airing] = [:], order: [String] = []
        for a in rows {
            guard let id = matched[a.p.title], byItem[id] == nil else { continue }
            byItem[id] = a; order.append(id)
            if order.count >= 6 { break }
        }
        let items = await MediaStore.items(ids: order)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var out = order.compactMap { id in byID[id].flatMap { it in byItem[id].map { (it, $0) } } }
        out.sort { ($0.1.p.start <= now ? 0 : 1, $0.1.p.start) < ($1.1.p.start <= now ? 0 : 1, $1.1.p.start) }
        return out
    }

    // MARK: Le moment

    struct Moment { let key: String; let icon: String; let tag: String; let title: String; let sub: String; let cond: String; let duo: Bool }
    static let moments: [String: Moment] = [
        "sem": Moment(key: "sem", icon: "🏆", tag: "LE MOMENT · EN SEMAINE", title: "Les valeurs sûres",
                      sub: "En semaine, pas besoin de prendre de risque : que des films notés 8 et plus, que tu n'as pas vus.", cond: "f.vote>=8", duo: false),
        "duo": Moment(key: "duo", icon: "🍿", tag: "LE MOMENT · VENDREDI SOIR", title: "Soirée à deux",
                      sub: "Des films qu'aucun des deux profils n'a vus, et qui plaisent à vous deux.", cond: "f.vote>=7.3", duo: true),
        "fam": Moment(key: "fam", icon: "☀️", tag: "LE MOMENT · DIMANCHE", title: "Dimanche en famille",
                      sub: "Pour tous les âges ou dès 10 ans, à regarder l'après-midi.",
                      cond: "(f.cert IN ('0','10') OR ((f.cert IS NULL OR f.cert='') AND (f.genres LIKE '%Animation%' OR f.genres LIKE '%Familial%')))", duo: false),
        "noel": Moment(key: "noel", icon: "🎄", tag: "LE MOMENT · DÉCEMBRE", title: "Les grands films des fêtes",
                       sub: "Longs, beaux, à partager : de quoi tenir jusqu'au réveillon.", cond: "f.runtime>=140 AND f.vote>=7.6", duo: false),
    ]

    /// simulateur fhMomKey : décembre, vendredi / samedi (2 profils ou plus), dimanche, sinon la semaine
    static func momentKey() -> String {
        let d = DiscoverClock.now, cal = Calendar.current, w = cal.component(.weekday, from: d)
        if cal.component(.month, from: d) == 12 { return "noel" }
        if (w == 6 || w == 7) && duoPair() != nil { return "duo" }
        if w == 1 { return "fam" }
        return "sem"
    }

    /// les deux profils de « Soirée à deux » : ceux qui regardent à deux, sinon le profil actif et le premier autre
    static func duoPair() -> (Profile, Profile)? {
        let ps = ProfileStore.shared
        if let p = ps.partnerProfile { return (ps.me, p) }
        guard let o = ps.profiles.first(where: { $0.id != ps.me.id && $0.id != ProfileStore.guestID }) else { return nil }
        return (ps.me, o)
    }

    static func momentList(_ mk: String, pids: [String], seen: (MediaItem, [String: WatchStore.Entry]) -> Bool, notInt: Set<String>) async -> [MediaItem] {
        guard let M = moments[mk] else { return [] }
        let L = await MediaStore.ficheList(.film, pids: pids, cond: M.cond, order: "f.vote DESC", limit: 300)
        let me = WatchStore.shared.entries
        var other: [String: WatchStore.Entry] = [:]
        if M.duo, let (_, o) = duoPair() { other = WatchStore.entries(for: o.id) }
        return L.filter { it in
            guard it.allowedForProfile, !notInt.contains(it.workKey) else { return false }
            if mk == "fam" { return true }
            if seen(it, me) { return false }
            if M.duo && seen(it, other) { return false }
            return true
        }
    }

    private static func filmMoment(pids: [String], seen: @escaping (MediaItem, [String: WatchStore.Entry]) -> Bool, notInt: Set<String>) async -> HeroSlide? {
        let mk = momentKey()
        guard let M = moments[mk] else { return nil }
        let mi = await momentList(mk, pids: pids, seen: seen, notInt: notInt)
        guard mi.count >= 3 else { return nil }
        let coll = CollInfo(id: "mom:" + mk, icon: "sparkles", name: M.title, why: M.sub, count: mi.count, preview: Array(mi.prefix(3)), loader: { mi })
        return HeroSlide(k: .mom, tag: M.tag, title: M.icon + " " + M.title, mosaic: Array(mi.prefix(6)),
                         meta: ["\(mi.count) films", mi.prefix(3).map(\.displayTitle).joined(separator: " · ") + "…"],
                         sub: M.sub, coll: coll, collLabel: "Voir la collection", pool: mi, duo: M.duo)
    }

    private static func seriesMoment(pids: [String], started: (MediaItem) -> Bool, notInt: Set<String>) async -> HeroSlide? {
        let w = Calendar.current.component(.weekday, from: DiscoverClock.now)
        let short = await MediaStore.ficheList(.series, pids: pids, cond: "f.runtime>0 AND f.runtime<=35", order: "f.vote DESC", limit: 200)
            .filter { $0.allowedForProfile && !notInt.contains($0.workKey) }
        var we = w == 6 || w == 7 || w == 1
        if !we && short.count < 3 { we = true }
        let mi: [MediaItem]
        if we {
            // séries terminées (TMDB) ou en une seule saison, pas encore finies
            mi = await MediaStore.ficheList(.series, pids: pids, cond: "(f.status IN ('Ended','Canceled') OR f.seasons=1)", order: "f.vote DESC", limit: 200)
                .filter { $0.allowedForProfile && !notInt.contains($0.workKey) }
        } else { mi = short }
        guard mi.count >= 3 else { return nil }
        let t = we ? "🍿 Séries à finir ce week-end" : "⏱ Un épisode, pas plus"
        let why = we ? "Des séries terminées : tout est disponible, avec une vraie fin" : "Des épisodes courts pour une soirée de semaine"
        let coll = CollInfo(id: "mom:" + (we ? "fini" : "court"), icon: "sparkles", name: String(t.dropFirst(2)), why: why, count: mi.count, preview: Array(mi.prefix(3)), loader: { mi })
        return HeroSlide(k: .mom, tag: we ? "🍿 LE WEEK-END · À DÉVORER" : "⏱ EN SEMAINE · ÉPISODES COURTS", title: t, mosaic: Array(mi.prefix(6)),
                         meta: ["\(mi.count) séries", mi.prefix(3).map(\.displayTitle).joined(separator: " · ")],
                         sub: why, coll: coll, collLabel: "Voir la collection", pool: mi)
    }

    // MARK: À l'honneur

    private static func filmHonour(pids: [String], seen: (MediaItem) -> Bool) async -> HeroSlide? {
        var C: [(String, [MediaItem], Int)] = []
        for (d, _) in await MediaStore.directors(.film, pids: pids, min: 3) where !d.contains(",") {
            let L = await MediaStore.ficheList(.film, pids: pids, cond: "f.director=?", args: [d], order: "f.year", limit: 60).filter(\.allowedForProfile)
            guard L.count >= 3 else { continue }
            C.append((d, L, L.filter(seen).count))
        }
        C.sort { ($0.2, $0.1.count) > ($1.2, $1.1.count) }
        C = Array(C.prefix(4))
        guard !C.isEmpty else { return nil }
        let wk = Int(Date().timeIntervalSince1970) / (7 * 86400)
        let (who, L, _) = C[wk % C.count]
        let sn = L.filter(seen)
        let nx = L.first { !seen($0) && WatchStore.shared.resume($0.id) == nil } ?? L[0]
        let coll = CollInfo(id: "dir:" + who, icon: "film", name: "Signé " + (who.split(separator: " ").last.map(String.init) ?? who),
                            why: "\(who) · \(L.count) films chez ton fournisseur", count: L.count, preview: Array(L.prefix(3)), loader: { L })
        return HeroSlide(k: .hon, tag: "🎬 À L'HONNEUR CETTE SEMAINE", title: who, mosaic: Array(L.prefix(6)),
                         meta: ["\(L.count) films chez ton fournisseur", "tu en as vu \(sn.count)"],
                         sub: (sn.isEmpty ? "" : "Tu as vu " + sn.prefix(2).map(\.displayTitle).joined(separator: " et ") + ". ") + "Le prochain à voir : ",
                         subBold: nx.displayTitle, subTail: ".", next: nx, coll: coll, collLabel: "Tous ses films")
    }

    private static func seriesHonour(pids: [String], started: (MediaItem) -> Bool, used: Set<String>) async -> HeroSlide? {
        var best: (MediaStore.Studio, [MediaItem], Int)?
        for st in await MediaStore.studios(.series, pids: pids, min: 2).prefix(6) {
            let like1 = "%\"id\":\(st.id),%", like2 = "%\"id\":\(st.id)}%"
            let G = await MediaStore.ficheList(.series, pids: pids, cond: "(f.companies LIKE ? OR f.companies LIKE ?)", args: [like1, like2], order: "f.vote DESC", limit: 60).filter(\.allowedForProfile)
            guard G.count >= 2 else { continue }
            let s = G.filter(started).count
            if best == nil || (s, G.count) > (best!.2, best!.1.count) { best = (st, G, s) }
        }
        guard let (st, G, s) = best, let nx = G.first(where: { !started($0) && !used.contains($0.id) }) else { return nil }
        let like1 = "%\"id\":\(st.id),%", like2 = "%\"id\":\(st.id)}%"
        let coll = CollInfo(id: "co:\(st.id)", icon: "building.2", name: "Les séries " + st.name, why: "Chaîne d'origine · \(G.count) séries chez ton fournisseur", count: G.count, preview: [],
                            loader: { await MediaStore.ficheList(.series, pids: pids, cond: "(f.companies LIKE ? OR f.companies LIKE ?)", args: [like1, like2], order: "f.vote DESC", limit: 300) })
        return HeroSlide(k: .hon, tag: "📡 À L'HONNEUR CETTE SEMAINE", title: "Les séries " + st.name, mosaic: Array(G.prefix(6)),
                         meta: ["\(G.count) séries chez ton fournisseur", "tu en as vu \(s)"],
                         sub: "La prochaine à voir selon toi : ", subBold: nx.displayTitle, next: nx, coll: coll, collLabel: "Toutes les séries " + st.name)
    }

    // MARK: Bientôt chez toi

    /// Le film au cinéma (France) le plus en vue qui n'est pas chez le fournisseur ; une fois par jour.
    static func soonFilm() async -> SoonFilm? {
        let day = Fiche.dayFormat.string(from: Date())
        var res: [[String: Any]]
        if let m = soonMemo, m.day == day { res = m.list } else {
            guard let key = TmdbKey.value,
                  let r = await TmdbAPI(key: key).get("/movie/now_playing", [("language", "fr-FR"), ("region", "FR")])?["results"] as? [[String: Any]] else { return nil }
            res = r; soonMemo = (day, r)
        }
        // à chaque fois : ce que le fournisseur a déjà (ses fiches TMDB arrivent au fil de l'eau)
        let have: Set<Int> = await Database.shared.read { db in
            var s = Set<Int>()
            db.query("SELECT tmdb FROM fiche WHERE kind='film' AND tmdb>0") { r in s.insert(r.int(0)) }
            return s
        }
        for r in res.prefix(12) {
            guard let id = r["id"] as? Int, !have.contains(id), let t = r["title"] as? String, !t.isEmpty,
                  let rd = r["release_date"] as? String, !rd.isEmpty, let d = Fiche.dayFormat.date(from: rd), d <= Date(),
                  Date().timeIntervalSince(d) < 120 * 86400 else { continue }
            var s = SoonFilm(tmdb: id, title: t, year: Int(rd.prefix(4)) ?? 0, vote: (r["vote_average"] as? Double) ?? 0,
                             overview: (r["overview"] as? String) ?? "", backdrop: Fiche.img((r["backdrop_path"] as? String) ?? "", "w1280"), cinema: rd)
            if let v = vodMemo[id] { s.vod = v } else if let key = TmdbKey.value, let rel = await TmdbAPI(key: key).get("/movie/\(id)/release_dates") {
                for x in (rel["results"] as? [[String: Any]]) ?? [] where (x["iso_3166_1"] as? String) == "FR" {
                    for e in (x["release_dates"] as? [[String: Any]]) ?? [] where (e["type"] as? Int) == 4 {
                        if let v = e["release_date"] as? String { s.vod = String(v.prefix(10)) }
                    }
                }
                vodMemo[id] = s.vod
            }
            return s
        }
        return nil
    }
}

// MARK: - Affichage des diapositives de collection et « Bientôt chez toi »

/// Étiquette de diapositive (simulateur .htag : 12,5 px, 800, espacement .14em, rayon 9, liseré blanc 22 %).
struct SlideTag: View {
    let text: String
    let k: HeroSlide.K
    private var colors: (Color, Color) {
        switch k {
        case .tv: return (Color(red: 31 / 255, green: 95 / 255, blue: 214 / 255).opacity(0.35), .white)
        case .arr: return (Color(red: 1, green: 211 / 255, blue: 107 / 255).opacity(0.22), Color(red: 1, green: 211 / 255, blue: 107 / 255))
        case .soon: return (Color(red: 94 / 255, green: 224 / 255, blue: 200 / 255).opacity(0.2), Color(red: 94 / 255, green: 224 / 255, blue: 200 / 255))
        case .hon: return (Color(red: 1, green: 107 / 255, blue: 154 / 255).opacity(0.2), Color(red: 1, green: 159 / 255, blue: 189 / 255))
        default: return (Color.white.opacity(0.12), .white)
        }
    }
    var body: some View {
        Text(text).font(P.font(19, .heavy)).tracking(2.6).foregroundStyle(colors.1)
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(colors.0, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.22), lineWidth: 1.5))
    }
}

/// Mosaïque d'affiches inclinée à droite (simulateur .mosa : 62 % de large, 3 colonnes, 2 rangées, rotation −4°, ×1,15).
struct SlideMosaic: View {
    let items: [MediaItem]
    var body: some View {
        GeometryReader { g in
            let w = g.size.width * 0.62, gap: CGFloat = 9
            let cw = (w - 2 * gap) / 3, ch = (g.size.height - gap) / 2
            VStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<3, id: \.self) { c in
                            let i = r * 3 + c
                            ZStack(alignment: .bottomLeading) {
                                if i < items.count {
                                    ArtView(backdrop: items[i].backdropURL, poster: items[i].posterURL, maxPixel: 700, posterWidthRatio: 1, fill: true)
                                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                                    Text(items[i].displayTitle).font(P.font(30, .bold)).lineLimit(2).shadow(color: .black.opacity(0.7), radius: 8, y: 2)
                                        .padding(.leading, 18).padding(.bottom, 15).padding(.trailing, 15)
                                } else { Color.white.opacity(0.04) }
                            }
                            .frame(width: cw, height: ch).clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
            }
            .frame(width: w, height: g.size.height)
            .rotationEffect(.degrees(-4)).scaleEffect(1.15)
            .offset(x: w * 0.04, y: -g.size.height * 0.02)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .allowsHitTesting(false)
    }
}

/// Grande affiche d'une collection (Le moment, À l'honneur) ou de « Bientôt chez toi ».
struct PanelHeroView: View {
    let s: HeroSlide
    let index: Int
    let count: Int
    var alertOn = false
    var focus: FocusState<Bool>.Binding
    let primary: () -> Void
    let alts: [(String, () -> Void)]
    let step: (Int) -> Void
    var trailerLayer: AnyView? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let so = s.soon {
                    ArtView(backdrop: so.backdrop, poster: "", maxPixel: 1920)
                } else {
                    P.room
                    SlideMosaic(items: s.mosaic).opacity(0.75)
                }
            }
            .frame(width: 1920, height: 880).clipped()
            if let t = trailerLayer { t }
            LinearGradient(colors: [P.room.opacity(0.95), P.room.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.6), .clear, .clear, P.room], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 16) {
                SlideTag(text: s.tag, k: s.k)
                Text(s.title).font(s.soon != nil ? TitleFace.bebas.font(110) : P.font(93, .bold))
                    .lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: 1250, alignment: .leading)
                HStack(spacing: 18) { metaRow }.font(P.font(22.5, .medium)).foregroundStyle(P.dim)
                subText.font(P.font(22.5)).foregroundStyle(.white.opacity(0.85)).lineLimit(3).frame(maxWidth: 1000, alignment: .leading)
                Button(action: primary) { primaryLabel }
                    .buttonStyle(PrimaryStyle())
                    .focused(focus)
                    .contextMenu { ForEach(0..<alts.count, id: \.self) { i in Button(alts[i].0) { alts[i].1() } } }
                    .onMoveCommand { d in if d == .left { step(-1) } else if d == .right { step(1) } }
                    .accessibilityIdentifier("hero-b0")
                    .padding(.top, 8)
                if !alts.isEmpty {
                    Text("OK maintenu : " + alts.map(\.0).joined(separator: " · ") + (count > 1 ? " · ‹ › autre affiche" : "")).font(P.font(19)).foregroundStyle(P.faint)
                }
            }
            .padding(.leading, 120).padding(.trailing, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
            .padding(.top, 220)
            if count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<count, id: \.self) { i in Capsule().fill(.white.opacity(i == index ? 1 : 0.35)).frame(width: i == index ? 34 : 10, height: 10) }
                    Text("\(index + 1) / \(count)").font(P.font(20, .semibold)).foregroundStyle(P.dim).padding(.leading, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 120).padding(.bottom, 190)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 1920, height: 880)
    }

    @ViewBuilder private var metaRow: some View {
        if let so = s.soon {
            if so.year > 0 { Text(String(so.year)) }
            if so.vote > 0 { Stars(value: so.vote) }
            Text("au cinéma depuis le " + Self.day(so.cinema)).foregroundStyle(Color(red: 94 / 255, green: 224 / 255, blue: 200 / 255))
        } else {
            ForEach(0..<s.meta.count, id: \.self) { i in Text(s.meta[i]).lineLimit(1) }
        }
    }

    private var subText: Text {
        if let so = s.soon {
            let ov = so.overview.count > 130 ? String(so.overview.prefix(130)) + "…" : so.overview
            let vod = so.vod.isEmpty ? "" : " · en streaming vers " + Self.month(so.vod)
            return Text(ov + "\n") + Text("Pas encore chez ton fournisseur" + vod + ". prisme te prévient dès qu'il arrive.").font(P.font(19)).foregroundColor(P.dim)
        }
        return Text(s.sub) + Text(s.subBold).bold() + Text(s.subTail)
    }

    @ViewBuilder private var primaryLabel: some View {
        if s.soon != nil {
            let on = alertOn
            HStack(spacing: 14) { Image(systemName: on ? "checkmark" : "bell"); Text(on ? "Alerte activée" : "Préviens-moi") }.font(P.font(30, .semibold))
        } else if let nx = s.next {
            PlayLabel(title: nx.displayTitle, sub: Self.nextSub(nx))
        } else {
            Text(s.collLabel).font(P.font(30, .semibold))
        }
    }

    static func nextSub(_ it: MediaItem) -> String? {
        let m = it.fiche?.runtime ?? 0
        if it.kind == .series { return m > 0 ? ("S1 · É1 · " + runtimeText(m)).uppercased() : "S1 · É1" }
        guard m > 0 else { return nil }
        return (runtimeText(m) + " · FIN " + Fmt.hm(Date().addingTimeInterval(Double(m * 60)))).uppercased()
    }
    static func day(_ s: String) -> String {
        guard let d = Fiche.dayFormat.date(from: s) else { return s }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d MMMM"
        return f.string(from: d)
    }
    static func month(_ s: String) -> String {
        guard let d = Fiche.dayFormat.date(from: s) else { return s }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }
}
