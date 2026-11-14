import SwiftUI

// MARK: - Accueil Films / Séries (structure et ordre du simulateur)
// Films  : grande affiche · bande « Ce soir ? » · Reprendre · Top 10 du moment · Nouveau sur prisme · Ma liste · Explorer · Parcourir
// Séries : grande affiche · bande « À suivre / Ce soir ? / Cette semaine » · Top 10 séries · Ma liste · Parcourir

private struct HomeSnap {
    var newest: [MediaItem] = []
    var tonight: [MediaItem] = []
    var week: [MediaItem] = []
    var top: [TrendStore.Ranked] = []
    var topSub = ""
    var colls: [CollInfo] = []
    var lics: [CollInfo] = []
    var genres: [CollInfo] = []
    var cats: [MediaStore.Cat] = []
}
/// Les accueils déjà calculés : changer d'onglet ne relance pas les requêtes.
private enum HomeCache { static var map: [String: HomeSnap] = [:] }
/// Vide les accueils gardés en mémoire au changement de profil (ils dépendent de sa liste et de sa limite d'âge).
enum HomeCacheHook { static func install() { HomeCacheReset.run = { HomeCache.map = [:] } } }

/// Envies et durées de « Ce soir ? » (simulateur).
enum Tonight {
    static let durations: [(String, String, Int)] = [("all", "Peu importe", 0), ("105", "Moins de 1 h 45", 105), ("150", "Moins de 2 h 30", 150)]
    static let moods: [(String, String, String)] = [
        ("rire", "Rire", "comed|anim|famil"), ("frisson", "Frisson", "thriller|horreur|horror|crime|polic|myst"),
        ("evasion", "Évasion", "aventure|science|fantas|action"), ("reflechir", "Réfléchir", "docu|histo|guerre|biograph"),
        ("emotion", "Émotion", "drame|romance|musi"),
    ]
}

struct MediaHomeView: View {
    let kind: MediaKind
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @ObservedObject var fiches = FicheService.shared
    @State private var snap = HomeSnap()
    @State private var hero: [MediaItem] = []
    @State private var resume: [ResumeEntry] = []
    @State private var mine: [MediaItem] = []
    @State private var open: MediaItem?
    @State private var openCat: MediaStore.Cat?
    @State private var openColl: CollInfo?
    @State private var heroIndex = 0
    @State private var playing: VodRequest?
    @State private var dur = "all"
    @State private var mood = ""
    @State private var askDur = false
    @State private var askMood = false
    @State private var because: MediaItem?
    @State private var becauseList: [MediaItem] = []
    @State private var browseTab = ""
    @State private var showAllNew = false
    @State private var forYou: [MediaItem] = []
    @ObservedObject var ps = ProfileStore.shared
    @ObservedObject var tasteStore = TasteStore.shared
    @FocusState private var heroFocus: Bool

    private var loadKey: String { "\(kind.rawValue)|\(store.catalogVersion)|\(store.active.map(\.id).joined())|\(fiches.running ? fiches.version / 25 : fiches.version)" }
    private var pids: [String] { store.active.map(\.id) }
    private var providerNames: String { store.active.map(\.name).joined(separator: ", ") }
    private var unit: String { kind == .film ? "films" : "séries" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 44) {
                ZStack(alignment: .top) {
                    heroBlock
                    TopBar()
                }
                // ordre du simulateur — Films : Ce soir ? · Reprendre · Top 10 · Nouveau · Parce que tu as aimé · Ma liste · Explorer · Parcourir
                //                       Séries : Ce soir ? · Reprendre · Top 10 · Nouveau · Ma liste · Parcourir
                tonightBand
                if !resume.isEmpty { resumeSection }
                if !forYou.isEmpty {
                    // « Pour toi » (« Pour vous deux » à deux) : seulement quand des goûts sont connus (test ou historique)
                    MediaRow(title: ps.isDuo ? "Pour vous deux" : "Pour toi",
                             sub: ps.isDuo ? "ce qui plaît à " + ps.watchersName + " · selon vos goûts" : "selon tes goûts · le test et ce que tu regardes",
                             items: forYou, open: { open = $0 })
                }
                if !snap.top.isEmpty {
                    Top10Row(title: kind == .film ? "Top 10 du moment" : "Top 10 séries", sub: nil, items: snap.top, open: { open = $0 })
                }
                if !snap.newest.isEmpty { newSection }
                if kind == .film, let b = because, !becauseList.isEmpty {
                    MediaRow(title: "Parce que tu as aimé " + b.displayTitle, items: becauseList, open: { open = $0 })
                }
                if !mine.isEmpty {
                    MediaRow(title: "Ma liste", items: mine, open: { open = $0 })
                }
                if kind == .film && !snap.colls.isEmpty { exploreSection }
                browseSection
                if store.importing != nil && snap.newest.isEmpty {
                    Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(P.font(28, .semibold)).foregroundStyle(P.dim).padding(.horizontal, 120)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        // à l'ouverture de la page, et en descendant depuis la barre : la grande affiche et son bouton
        .defaultFocus($heroFocus, true)
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .navigationDestination(item: $openCat) { c in CategoryGridView(kind: kind, cat: c) }
        .navigationDestination(item: $openColl) { c in
            CollectionGridView(kicker: (kind == .film ? "FILMS · " : "SÉRIES · ") + c.kind.uppercased(), title: c.name, why: c.why, loader: c.loader)
        }
        .navigationDestination(isPresented: $showAllNew) {
            CollectionGridView(kicker: kind == .film ? "FILMS" : "SÉRIES", title: "Nouveau sur prisme", why: "Les ajouts des deux dernières semaines chez " + providerNames, loader: { snap.newest })
        }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .confirmationDialog("Durée", isPresented: $askDur) {
            ForEach(0..<Tonight.durations.count, id: \.self) { i in Button(Tonight.durations[i].1) { dur = Tonight.durations[i].0 } }
        }
        .confirmationDialog("Envie", isPresented: $askMood) {
            Button("Toutes les envies") { mood = "" }
            ForEach(0..<Tonight.moods.count, id: \.self) { i in Button(Tonight.moods[i].1) { mood = Tonight.moods[i].0 } }
        }
        .task(id: loadKey) { await load(loadKey) }
        .task(id: watch.entries.count) { await loadResume() }
        .task(id: "\(snap.tonight.count)|\(ps.version)|\(tasteStore.version)|\(watch.entries.count)") { await loadForYou() }
        .task {
            // la grande affiche change toutes les 8 s, sauf quand son bouton est sélectionné
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if hero.count > 1 && !heroFocus { withAnimation(.easeInOut(duration: 0.7)) { heroIndex += 1 } }
            }
        }
    }

    // MARK: grande affiche

    @ViewBuilder private var heroBlock: some View {
        if !hero.isEmpty {
            let h = hero[heroIndex % hero.count]
            HeroView(item: h, index: heroIndex % hero.count, count: hero.count, provider: store.provider(h.pid)?.name ?? "",
                     focus: $heroFocus,
                     play: { info in play(h, info) }, info: { open = h },
                     step: { d in withAnimation(.easeInOut(duration: 0.45)) { heroIndex = (heroIndex + d + hero.count) % hero.count } })
        } else {
            Color.clear.frame(height: 260)
        }
    }

    // MARK: films — bande « Ce soir ? »

    private var tonightList: [MediaItem] {
        let maxD = Tonight.durations.first { $0.0 == dur }?.2 ?? 0
        let rx = Tonight.moods.first { $0.0 == mood }?.2
        return snap.tonight.filter { it in
            let rt = it.fiche?.runtime ?? 0
            if maxD > 0 && (rt == 0 || rt > maxD) { return false }
            if let rx, (it.fiche?.genres ?? "").lowercased().folding(options: .diacriticInsensitive, locale: nil).range(of: rx, options: .regularExpression) == nil { return false }
            if it.kind == .series { return !watch.inProgress.contains { $0.item == it.id } }
            return watch.fraction(it.id) == nil
        }
    }

    @ViewBuilder private var tonightBand: some View {
        let L = tonightList
        if !snap.tonight.isEmpty {
            GlassBand(head: {
                HStack(spacing: 16) {
                    Image(systemName: "moon").font(P.font(28, .semibold))
                    Text("Ce soir ?").font(P.font(33, .bold))
                    Text("\(L.count) \(unit) · il est " + Fmt.hm(Date())).font(P.font(19)).foregroundStyle(P.faint)
                    Spacer(minLength: 20)
                    if kind == .film {
                        BandChip(icon: "timer", text: Tonight.durations.first { $0.0 == dur }?.1 ?? "Peu importe", menu: true) { askDur = true }
                    }
                    BandChip(icon: "sparkles", text: Tonight.moods.first { $0.0 == mood }?.1 ?? "Toutes les envies", menu: true) { askMood = true }
                    BandChip(icon: "dice", text: "Surprends-moi") { if let pick = L.prefix(6).randomElement() { open = pick } }
                }
            }, row: {
                LazyHStack(spacing: 30) {
                    if L.isEmpty { Text("Aucun titre avec ces choix · change la durée ou l'envie").font(P.font(22)).foregroundStyle(P.dim).frame(height: 300) }
                    ForEach(L.prefix(24)) { it in PosterButton(item: it) { open = it } }
                }
            })
        }
    }

    private func tonightSub(_ it: MediaItem) -> String {
        guard let rt = it.fiche?.runtime, rt > 0 else { return it.fiche.map { "★ " + String(format: "%.1f", $0.vote) } ?? "" }
        return runtimeText(rt) + " · fin " + Fmt.hm(Date().addingTimeInterval(Double(rt * 60)))
    }

    private func versionTag(_ it: MediaItem) -> String? {
        let t = it.clean.tags
        guard !t.isEmpty else { return nil }
        return t.joined(separator: " · ")
    }

    // MARK: Reprendre (cartes larges)

    private var resumeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(title: "Reprendre")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 30) { ForEach(resume) { r in resumeCard(r) } }
                    .padding(.horizontal, 120).padding(.vertical, 30)
            }.scrollClipDisabled()
        }.focusSection()
    }

    private func resumeCard(_ r: ResumeEntry) -> ResumeCard {
        ResumeCard(r: r, corner: versionTag(r.item)) { open = r.item }
    }

    // MARK: Nouveau sur prisme (cartes larges, « NOUVEAU · IL Y A 5 J »)

    private var newSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(icon: "sparkles", title: "Nouveau sur prisme")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 30) {
                    ForEach(snap.newest.prefix(12)) { it in
                        NewCard(item: it, chip: store.provider(it.pid)?.name) { open = it }
                    }
                    if snap.newest.count > 12 { AllCard(count: snap.newest.count, unit: unit, height: 298) { showAllNew = true } }
                }
                .padding(.horizontal, 120).padding(.vertical, 30)
            }.scrollClipDisabled()
        }.focusSection()
    }

    private func newSub(_ it: MediaItem) -> String {
        var p: [String] = []
        let y = (it.fiche?.year ?? 0) > 0 ? it.fiche!.year : it.clean.year
        if y > 0 { p.append(String(y)) }
        if let rt = it.fiche?.runtime, rt > 0 { p.append(runtimeText(rt)) }
        if let g = it.fiche?.genres.components(separatedBy: ", ").first, !g.isEmpty { p.append(g) }
        return p.joined(separator: " · ")
    }

    // MARK: Explorer

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(title: "Explorer")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 30) { ForEach(snap.colls) { c in CollTile(c: c, unit: unit) { openColl = c } } }
                    .padding(.horizontal, 120).padding(.vertical, 30)
            }.scrollClipDisabled()
        }.focusSection()
    }

    // MARK: Parcourir (Catégories · Licences et sagas / Collections · Catégories · Chaînes)

    private var browseTabs: [(String, String, Int)] {
        if kind == .film { return [("cat", "Catégories", snap.genres.count + snap.cats.count), ("lic", "Licences et sagas", snap.lics.count)] }
        return [("col", "Collections", snap.colls.count), ("cat", "Catégories", snap.genres.count + snap.cats.count), ("lic", "Chaînes", snap.lics.count)].filter { $0.2 > 0 }
    }

    @ViewBuilder private var browseSection: some View {
        let tabs = browseTabs.filter { $0.2 > 0 }
        if !tabs.isEmpty {
            let cur = tabs.contains(where: { $0.0 == browseTab }) ? browseTab : tabs[0].0
            VStack(alignment: .leading, spacing: 18) {
                HomeHeader(title: "Parcourir")
                HStack(spacing: 10) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        Button { browseTab = tabs[i].0 } label: {
                            HStack(spacing: 8) { Text(tabs[i].1); Text("\(tabs[i].2)").font(P.font(17)).opacity(0.55) }.font(P.font(23, .semibold))
                        }
                        .buttonStyle(TabPillStyle(selected: cur == tabs[i].0))
                    }
                }
                .padding(.horizontal, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 26) { browseRow(cur) }
                        .padding(.horizontal, 120).padding(.vertical, 26)
                }
                .scrollClipDisabled()
                .focusSection()
            }
        }
    }

    @ViewBuilder private func browseRow(_ t: String) -> some View {
        switch t {
        case "lic":
            ForEach(snap.lics) { c in LicenceTile(c: c, unit: unit) { openColl = c } }
        case "col":
            ForEach(snap.colls) { c in CollTile(c: c, unit: unit) { openColl = c } }
        default:
            ForEach(snap.genres) { g in WordTile(title: g.name, sub: "\(g.count) \(unit)") { openColl = g } }
            ForEach(snap.cats) { c in
                WordTile(title: c.name, sub: "catégorie · \(c.count) \(unit)" + (store.active.count > 1 ? " · " + (store.provider(c.pid)?.name ?? "") : "")) { openCat = c }
            }
        }
    }

    // MARK: données

    /// Accueil en deux temps : les rangées principales (nouveautés, ce soir, top 10) s'affichent dès qu'elles sont prêtes,
    /// puis Explorer, genres, catégories et Licences arrivent. Le dernier accueil calculé reste affiché pendant ce temps.
    private func load(_ key: String) async {
        let t0 = Date(), q0 = Database.queryCount
        let cached = HomeCache.map[key]
        if let c = cached { snap = c; pickHero(c) }
        let k = kind, p = pids
        let twoWeeks = Int(Date().timeIntervalSince1970) - 14 * 86400
        var s = cached ?? HomeSnap()
        var n = await MediaStore.list(k, pids: p, where: "added > ?", args: [twoWeeks], order: "added DESC", limit: 40)
        if n.isEmpty { n = await MediaStore.list(k, pids: p, order: "added DESC", limit: 20) }
        s.newest = n
        if k == .film {
            s.tonight = await MediaStore.ficheList(.film, pids: p, cond: "f.vote>=6.5", order: "f.vote DESC", limit: 160)
        } else {
            s.tonight = await MediaStore.ficheList(.series, pids: p, cond: "f.vote>=7.5", order: "f.vote DESC", limit: 40)
            let week = Int(Date().timeIntervalSince1970) - 7 * 86400
            s.week = await MediaStore.list(.series, pids: p, where: "added > ?", args: [week], order: "added DESC", limit: 30)
        }
        s.top = await TrendStore.top(k, pids: p)
        if !s.top.isEmpty {
            s.topSub = k == .film ? "films populaires en France cette semaine · chez ton fournisseur" : "séries populaires cette semaine · chez ton fournisseur"
        } else {
            // sans TMDB : les mieux notés des ajouts des 3 derniers mois chez le fournisseur (données réelles, dites comme telles)
            let since = Int(Date().timeIntervalSince1970) - 90 * 86400
            var L = await MediaStore.list(k, pids: p, where: "rating>0 AND added > ?", args: [since], order: "rating DESC, added DESC", limit: 10)
            if L.count < 5 { L = await MediaStore.list(k, pids: p, where: "rating>0", order: "rating DESC, added DESC", limit: 10) }
            s.top = L.enumerated().map { TrendStore.Ranked(item: $0.element, rank: $0.offset + 1, move: nil) }
            s.topSub = "les mieux notés des ajouts récents chez " + providerNames
        }
        guard !Task.isCancelled else { return }
        snap = s
        pickHero(s)
        let t1 = Date(), q1 = Database.queryCount
        await loadResume()
        s.colls = await collections(k, p)
        let tg = Date(), qg = Database.queryCount
        s.genres = await genreTiles(k, p)
        PerfLog.newParts = (Date().timeIntervalSince(tg), Database.queryCount - qg)
        s.cats = await MediaStore.categories(k, pids: p)
        guard !Task.isCancelled else { return }
        snap = s
        s.lics = await licences(k, p, top: s.top)
        guard !Task.isCancelled else { return }
        HomeCache.map[key] = s
        snap = s
        if Debug.demoServer != nil {
            let t2 = Date(), q2 = Database.queryCount
            await PerfLog.home(kind: k, first: t1.timeIntervalSince(t0), full: t2.timeIntervalSince(t0), q1: q1 - q0, q2: q2 - q0,
                               cached: cached != nil, old: { await oldMethodCost(k, p, lics: s.lics, top: s.top) })
        }
    }

    /// Simulateur de test seulement : coût de l'ANCIENNE méthode (1.6 build 117) sur les mêmes données, pour la comparaison
    /// avant / après — pastille 🔥 en chargeant chaque tuile (jusqu'à 300 titres chacune) et 18 comptages de genres.
    private func oldMethodCost(_ k: MediaKind, _ p: [String], lics: [CollInfo], top: [TrendStore.Ranked]) async -> (Double, Int) {
        let t = Date(), q = Database.queryCount
        if !top.isEmpty { for c in lics { _ = await c.loader() } }
        let G = k == .film ? ["Action", "Aventure", "Animation", "Comédie", "Crime", "Documentaire", "Drame", "Familial", "Fantastique", "Histoire", "Horreur", "Musique", "Mystère", "Romance", "Science-Fiction", "Thriller", "Guerre", "Western"]
                           : ["Action & Adventure", "Animation", "Comédie", "Crime", "Documentaire", "Drame", "Familial", "Kids", "Mystère", "Science-Fiction & Fantastique", "War & Politics", "Western", "Reality", "Soap"]
        for g in G { _ = await MediaStore.ficheCount(k, pids: p, cond: "f.genres LIKE ?", args: ["%" + g + "%"]) }
        return (Date().timeIntervalSince(t), Database.queryCount - q)
    }

    private func pickHero(_ s: HomeSnap) {
        let withArt = s.newest.filter { !$0.backdropURL.isEmpty }
        let base = withArt.count >= 3 ? withArt : (s.newest.isEmpty ? s.tonight : s.newest)
        hero = Array(base.filter { !$0.posterURL.isEmpty || !$0.backdropURL.isEmpty }.prefix(6))
    }

    /// « Explorer » : collections tirées des vraies données (fiches TMDB) ; une collection n'apparaît que si elle
    /// contient assez de titres (4 au moins, 3 pour « Signé … » comme le simulateur).
    private func collections(_ k: MediaKind, _ p: [String]) async -> [CollInfo] {
        var out: [CollInfo] = []
        let fr = "(','||f.country||',') LIKE '%,FR,%'"
        let defs: [(String, String, String, String, String, String)] = k == .film ? [
            ("court", "timer", "Moins de 2 h", "Pour un film qui ne finit pas trop tard", "f.runtime>0 AND f.runtime<120", "f.vote DESC"),
            ("fr", "flag", "Cinéma français", "Films produits en France (TMDB)", fr, "f.vote DESC"),
            ("top", "trophy", "★ 8 et plus", "Les mieux notés de ton abonnement (TMDB)", "f.vote>=8", "f.vote DESC"),
        ] : [
            ("top", "trophy", "★ 8,5 et plus", "Les séries les mieux notées de ton abonnement (TMDB)", "f.vote>=8.5", "f.vote DESC"),
            ("fr", "flag", "Séries françaises", "Séries produites en France (TMDB)", fr, "f.vote DESC"),
            ("court", "timer", "Épisodes de 30 min", "Des épisodes courts, pour une soirée légère", "f.runtime>0 AND f.runtime<=30", "f.vote DESC"),
        ]
        for d in defs {
            let n = await MediaStore.ficheCount(k, pids: p, cond: d.4)
            guard n >= 4 else { continue }
            let prev = await MediaStore.ficheList(k, pids: p, cond: d.4, order: d.5, limit: 3)
            let cond = d.4, order = d.5
            out.append(CollInfo(id: d.0, icon: d.1, name: d.2, why: d.3, count: n, preview: prev,
                                loader: { await MediaStore.ficheList(k, pids: p, cond: cond, order: order, limit: 300) }))
        }
        // « Signé Nolan » : réalisateurs (ou créateurs) présents au moins 3 fois
        for (dname, n) in await MediaStore.directors(k, pids: p, min: 3).prefix(4) where !dname.contains(",") {
            let last = dname.split(separator: " ").last.map(String.init) ?? dname
            let prev = await MediaStore.ficheList(k, pids: p, cond: "f.director=?", args: [dname], order: "f.year", limit: 3)
            out.append(CollInfo(id: "dir:" + dname, icon: "film", name: (k == .film ? "Signé " : "Créé par ") + last, why: "\(dname) · \(n) " + (k == .film ? "films" : "séries") + " chez ton fournisseur",
                                count: n, preview: prev, loader: { await MediaStore.ficheList(k, pids: p, cond: "f.director=?", args: [dname], order: "f.year", limit: 100) }))
        }
        return out
    }

    private func licences(_ k: MediaKind, _ p: [String], top: [TrendStore.Ranked]) async -> [CollInfo] {
        var out: [CollInfo] = []
        if k == .film {
            for sg in await MediaStore.sagas(pids: p) {
                let id = sg.id
                out.append(CollInfo(id: "col:\(id)", icon: "square.stack.3d.up", name: sg.name.isEmpty ? "Saga" : sg.name.replacingOccurrences(of: " - Saga", with: "").replacingOccurrences(of: " - Collection", with: ""),
                                    why: "Saga complète (collection TMDB), dans l'ordre", count: sg.count, preview: [],
                                    loader: { await MediaStore.ficheList(.film, pids: p, cond: "f.coll=?", args: [id], order: "f.year", limit: 60) }, kind: "Saga", logo: sg.logo))
            }
        }
        // plateformes : catégories du fournisseur qui portent le nom d'un service (logo : icône TMDB du service)
        var plat: [String: [MediaStore.Cat]] = [:]
        for c in await MediaStore.categories(k, pids: p) { if let sv = Services.match(c.name) { plat[sv, default: []].append(c) } }
        for (name, cats) in plat {
            var total = 0
            for c in cats { total += c.count }
            guard total >= 2 else { continue }
            let logo = await MediaStore.serviceLogo(name)
            out.append(CollInfo(id: "pf:" + name, icon: "tv", name: name, why: "Les titres de ton fournisseur rangés dans sa catégorie " + name,
                                count: total, preview: [], loader: {
                var all: [MediaItem] = []
                for c in cats { all += await MediaStore.page(k, cat: c, offset: 0, limit: 300) }
                return all
            }, kind: "Plateforme", logo: logo, logoIsIcon: true))
        }
        // studios (films) ou chaînes d'origine (séries) d'après les fiches TMDB, avec leur logo
        for st in await MediaStore.studios(k, pids: p, min: 3) {
            let like1 = "%\"id\":\(st.id),%", like2 = "%\"id\":\(st.id)}%"
            out.append(CollInfo(id: "co:\(st.id)", icon: "building.2", name: st.name, why: (k == .film ? "Studio" : "Chaîne d'origine") + " · \(st.count) titres chez ton fournisseur",
                                count: st.count, preview: [], loader: { await MediaStore.ficheList(k, pids: p, cond: "(f.companies LIKE ? OR f.companies LIKE ?)", args: [like1, like2], order: "f.vote DESC", limit: 300) },
                                kind: k == .film ? "Studio" : "Chaîne", logo: st.logo))
        }
        // pastille 🔥 : seulement si un de ses titres est dans le Top 10 de la semaine (donnée réelle).
        // Calculée à partir des 10 titres du Top (leur saga, leurs studios, leurs catégories chez le fournisseur),
        // sans charger le contenu de chaque tuile.
        if !top.isEmpty {
            let tt = Date(), qt = Database.queryCount
            let tr = await MediaStore.topLinks(k, pids: p, top: top)
            PerfLog.newParts.0 += Date().timeIntervalSince(tt); PerfLog.newParts.1 += Database.queryCount - qt
            for i in out.indices {
                let id = out[i].id
                if id.hasPrefix("col:"), let c = Int(id.dropFirst(4)) { out[i].trend = tr.coll[c] ?? 0 }
                else if id.hasPrefix("co:"), let c = Int(id.dropFirst(3)) { out[i].trend = tr.company[c] ?? 0 }
                else if id.hasPrefix("pf:"), let cats = plat[String(id.dropFirst(3))] { out[i].trend = cats.compactMap { tr.cat[$0.id] }.min() ?? 0 }
            }
        }
        let sorted = out.sorted { ($0.trend > 0 ? 100 - $0.trend : 0, $0.count) > ($1.trend > 0 ? 100 - $1.trend : 0, $1.count) }
        // le classement 🔥 suit l'ordre des meilleures places du Top 10
        var r = 0
        return sorted.map { var c = $0; if c.trend > 0 { r += 1; c.trend = r }; return c }
    }

    private func genreTiles(_ k: MediaKind, _ p: [String]) async -> [CollInfo] {
        let G = k == .film ? ["Action", "Aventure", "Animation", "Comédie", "Crime", "Documentaire", "Drame", "Familial", "Fantastique", "Histoire", "Horreur", "Musique", "Mystère", "Romance", "Science-Fiction", "Thriller", "Guerre", "Western"]
                           : ["Action & Adventure", "Animation", "Comédie", "Crime", "Documentaire", "Drame", "Familial", "Kids", "Mystère", "Science-Fiction & Fantastique", "War & Politics", "Western", "Reality", "Soap"]
        // une seule lecture des genres (au lieu d'un comptage complet du catalogue par genre)
        let counts = await MediaStore.genreCounts(k, pids: p, genres: G)
        var out: [CollInfo] = []
        for g in G {
            let n = counts[g] ?? 0
            guard n >= 2 else { continue }
            out.append(CollInfo(id: "g:" + g, icon: "square.grid.2x2", name: g, why: "Genre TMDB · les mieux notés d'abord", count: n, preview: [],
                                loader: { await MediaStore.ficheList(k, pids: p, cond: "f.genres LIKE ?", args: ["%" + g + "%"], order: "f.vote DESC", limit: 300) }, kind: "Catégorie"))
        }
        return out.sorted { $0.count > $1.count }
    }

    /// « Pour toi » : titres pas encore vus, hors « jamais de… », les plus proches des goûts du profil
    /// (à deux : le goût le moins favorable des deux doit rester bon).
    private func loadForYou() async {
        let watchers = ps.watchers.filter { $0.id != ProfileStore.guestID }
        guard !watchers.isEmpty else { forYou = []; return }
        var models: [TasteModel] = []
        for w in watchers { models.append(await TasteStore.shared.model(w.id)) }
        guard models.allSatisfy({ !$0.isEmpty }) else { forYou = []; return }
        let seen = Set(watch.entries.values.filter { $0.dur > 0 && $0.pos / $0.dur >= 0.85 }.map(\.item))
        let scored: [(MediaItem, Int)] = snap.tonight.compactMap { it in
            guard !seen.contains(it.id), let f = it.fiche else { return nil }
            let v = models.compactMap { $0.fit(f, kind: kind) }
            guard v.count == models.count, let m = v.min(), m >= 60 else { return nil }
            return (it, m)
        }
        forYou = Array(scored.sorted { $0.1 > $1.1 }.prefix(16).map(\.0))
    }

    private func loadResume() async {
        let prefix = kind.rawValue + ":"
        let list = watch.inProgress.filter { $0.item.hasPrefix(prefix) }.prefix(20)
        let items = await MediaStore.items(ids: list.map(\.item))
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        resume = list.compactMap { e in
            guard seen.insert(e.item).inserted else { return nil }
            return byID[e.item].map { ResumeEntry(item: $0, entry: e) }
        }
        mine = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix(prefix) })
        await loadBecause()
    }

    /// « Parce que tu as aimé » : le dernier film regardé presque en entier (85 % ou plus, comme le simulateur)
    /// et les films qui partagent ses genres, sans ceux déjà proposés plus haut ni ceux déjà vus.
    private func loadBecause() async {
        guard kind == .film else { return }
        let done = watch.entries.values.filter { $0.item.hasPrefix("film:") && $0.dur > 0 && $0.pos / $0.dur >= 0.85 }.sorted { $0.at > $1.at }
        guard let last = done.first, let it = await MediaStore.items(ids: [last.item]).first else { because = nil; becauseList = []; return }
        let genres = (it.fiche?.genres ?? "").components(separatedBy: ", ").filter { !$0.isEmpty }
        var skip = Set(snap.top.map(\.item.clean.key)).union(snap.newest.prefix(12).map(\.clean.key)).union(tonightList.prefix(12).map(\.clean.key))
        skip.insert(it.clean.key)
        let L = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 30).map { $0.0 }
        because = it
        becauseList = Array(L.filter { !skip.contains($0.clean.key) && watch.fraction($0.id) == nil }.prefix(12))
    }

    /// « Lecture » sur la grande affiche : un film démarre (en reprenant s'il a été commencé),
    /// une série démarre à l'épisode à suivre ; sans épisodes connus, la fiche s'ouvre.
    private func play(_ it: MediaItem, _ info: MediaInfo) {
        guard let p = store.provider(it.pid) else { open = it; return }
        if it.kind == .film {
            guard let url = p.movieURL(it) else { open = it; return }
            playing = VodRequest(url: url, key: it.id, item: it.id, title: it.displayTitle, subtitle: "", icon: it.posterURL, startAt: watch.resume(it.id) ?? 0)
        } else {
            guard let e = EpisodeLogic.next(it, info, watch),
                  let r = EpisodeLogic.request(it, title: it.displayTitle, info: info, provider: p, episode: e, from: watch.resume(EpisodeLogic.key(it, e)) ?? 0) else { open = it; return }
            playing = r
        }
    }
}

extension CollInfo: Hashable {
    static func == (a: CollInfo, b: CollInfo) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Grande affiche en haut de l'accueil : image nette plein écran, badge doré, titre, infos, bouton blanc avec l'heure de fin.
struct HeroView: View {
    let item: MediaItem
    let index: Int
    let count: Int
    let provider: String
    var focus: FocusState<Bool>.Binding
    let play: (MediaInfo) -> Void
    let info: () -> Void
    let step: (Int) -> Void
    @ObservedObject var watch = WatchStore.shared
    @State private var mi = MediaInfo()
    @State private var miFor = ""

    private var details: MediaInfo { miFor == item.id ? mi : MediaInfo() }
    /// Durée : TMDB, sinon le fournisseur. 0 = inconnue → pas d'heure de fin.
    private var minutes: Int { (item.fiche?.runtime ?? 0) > 0 ? item.fiche!.runtime : details.minutes }
    /// Image de fond : TMDB (version d'origine), sinon celle du fournisseur.
    private var art: String { !item.backdropHD.isEmpty ? item.backdropHD : details.backdrop }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ArtView(backdrop: art, poster: item.posterURL, maxPixel: 1920, posterWidthRatio: 0.2)
                .frame(width: 1920, height: 880).clipped()
                .id(item.id).transition(.opacity)
            LinearGradient(colors: [P.room.opacity(0.92), P.room.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.6), .clear, .clear, P.room], startPoint: .top, endPoint: .bottom)
            content
                .padding(.leading, 120).padding(.trailing, 120).padding(.top, 220)
                // toute la largeur sous la barre : en descendant depuis n'importe quel onglet, on arrive sur le bouton
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
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
        .task(id: item.id) {
            let id = item.id
            let m = await InfoLoader.load(item)
            if id == item.id { mi = m; miFor = id }
        }
    }

    private var content: some View {
        let c = item.clean
        let f = item.fiche
        return VStack(alignment: .leading, spacing: 16) {
            Kicker(text: (agoDays ?? 99) <= 7 ? "L'arrivée de la semaine" : (item.kind == .film ? "Nouveau dans prisme" : "Nouvelle série"))
            Text(item.displayTitle).font(P.font(item.kind == .series ? 84 : 72, item.kind == .series ? .heavy : .bold)).lineLimit(2).minimumScaleFactor(0.7).frame(maxWidth: 1150, alignment: .leading)
            HStack(spacing: 18) {
                if !provider.isEmpty { Pill(text: provider, bg: P.chip.opacity(0.45), stroke: P.chip) }
                if let a = agoText(item.added) { Text(a) }
                let y = (f?.year ?? 0) > 0 ? f!.year : c.year
                if y > 0 && item.kind == .film { Text(String(y)) }
                if item.kind == .film, minutes > 0 { Text(runtimeText(minutes)) }
                if item.kind == .series, !details.seasons.isEmpty { Text(seasonLine) }
                let r = (f?.vote ?? 0) > 0 ? f!.vote : item.rating
                if r > 0 { Stars(value: r) }
                if !c.tags.isEmpty { Pill(text: c.tags.joined(separator: " · "), bg: .clear) }
            }
            .font(P.font(25, .medium)).foregroundStyle(P.dim)
            Text(subLine).font(P.font(25)).foregroundStyle(.white.opacity(0.8)).lineLimit(2).frame(maxWidth: 980, alignment: .leading)
            Button { play(details) } label: { PlayLabel(title: playTitle, sub: playSub) }
                .buttonStyle(PrimaryStyle())
                .focused(focus)
                .contextMenu {
                    Button { info() } label: { Label("Voir la fiche", systemImage: "info.circle") }
                    Button { watch.toggleFavorite(item.id) } label: {
                        Label(watch.favorites.contains(item.id) ? "Retirer de ma liste" : "Ajouter à ma liste", systemImage: watch.favorites.contains(item.id) ? "checkmark" : "plus")
                    }
                }
                .onMoveCommand { d in
                    if d == .left { step(-1) } else if d == .right { step(1) }
                }
                .padding(.top, 8)
            Text("OK maintenu : voir la fiche · " + (watch.favorites.contains(item.id) ? "retirer de ma liste" : "ajouter à ma liste") + (count > 1 ? " · ‹ › autre titre" : ""))
                .font(P.font(19)).foregroundStyle(P.faint)
        }
    }

    private var seasonLine: String {
        let n = details.seasons.flatMap(\.episodes).count
        return "\(details.seasons.count) saison\(details.seasons.count > 1 ? "s" : "") · \(n) ép."
    }

    /// Ligne sous les infos : le résumé pour un film ; pour une série, comme le simulateur, où tu en es.
    private var subLine: String {
        let f = item.fiche
        let plot = (f?.overview.isEmpty == false) ? f!.overview : (item.plot.isEmpty ? details.plot : item.plot)
        if item.kind == .series, !details.seasons.isEmpty {
            let all = details.seasons.flatMap(\.episodes)
            let started = all.contains { watch.fraction(EpisodeLogic.key(item, $0)) != nil }
            if !started { return "Toute la série est disponible, tu peux commencer ce soir" }
        }
        return plot
    }

    private var agoDays: Int? { item.added > 0 ? (Int(Date().timeIntervalSince1970) - item.added) / 86400 : nil }

    private var nextEp: EpisodeInfo? { item.kind == .series ? EpisodeLogic.next(item, details, watch) : nil }

    private var playTitle: String {
        if item.kind == .film { return watch.resume(item.id) != nil ? "Reprendre" : "Lecture" }
        guard let e = nextEp else { return "Lecture" }
        let started = details.seasons.flatMap(\.episodes).contains { watch.fraction(EpisodeLogic.key(item, $0)) != nil }
        return (watch.resume(EpisodeLogic.key(item, e)) != nil ? "Reprendre" : started ? "Regarder" : "Commencer") + " S\(e.season) · É\(e.number)"
    }

    /// Petite ligne du bouton blanc : heure de fin (seulement si la durée est connue).
    private var playSub: String? {
        if item.kind == .film {
            guard minutes > 0 else { return nil }
            let r = watch.resume(item.id) ?? 0
            let left = max(60, Double(minutes * 60) - r)
            return (r > 0 ? "RESTE " + runtimeText(Int(left / 60)).uppercased() + " · FIN " : "FINIT À ") + Fmt.hm(Date().addingTimeInterval(left))
        }
        guard let e = nextEp else { return nil }
        let m = EpisodeLogic.minutes(e, info: details, fiche: item.fiche)
        guard m > 0 else { return nil }
        let r = watch.resume(EpisodeLogic.key(item, e)) ?? 0
        let left = max(60, Double(m * 60) - r)
        return ((r > 0 ? "RESTE " : "") + runtimeText(Int(left / 60)) + " · FIN " + Fmt.hm(Date().addingTimeInterval(left))).uppercased()
    }
}

/// Texte du bouton blanc : « ▶ Lecture » + petite ligne (FINIT À 23:42, RESTE 30 MIN…).
struct PlayLabel: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "play.fill").font(P.font(28, .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(P.font(30, .bold))
                if let sub { Text(sub).font(P.font(16, .semibold)).tracking(0.8).opacity(0.6) }
            }
        }
    }
}

struct MediaRow: View {
    let title: String
    var sub: String? = nil
    let items: [MediaItem]
    let open: (MediaItem) -> Void
    var more: (() -> Void)? = nil
    var moreCount: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeHeader(title: title, sub: sub)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 34) {
                    ForEach(items) { it in
                        PosterButton(item: it) { open(it) }
                    }
                    if let more { AllCard(count: moreCount ?? items.count, unit: "titres", height: 330, action: more) }
                }.padding(.horizontal, 120).padding(.vertical, 34)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

struct CategoryRow: View {
    let kind: MediaKind
    let cat: MediaStore.Cat
    let open: (MediaItem) -> Void
    let more: () -> Void
    @State private var items: [MediaItem] = []
    var body: some View {
        Group {
            if items.isEmpty { Color.clear.frame(height: 1) }
            else { MediaRow(title: cat.name, sub: "\(cat.count)", items: items, open: open, more: cat.count > items.count ? more : nil, moreCount: cat.count) }
        }
        .task(id: cat.id) { items = await MediaStore.page(kind, cat: cat, offset: 0, limit: 20) }
    }
}

// MARK: - « Reprendre » (Ma liste) et affiches

struct ResumeEntry: Identifiable {
    let item: MediaItem
    let entry: WatchStore.Entry
    var id: String { item.id }
    /// « Saison 2 · Épisode 3 · … » → « S2 · É3 ».
    static func episodeTag(_ s: String?) -> String? {
        guard let s, let m = s.range(of: #"Saison (\d+) · Épisode (\d+)"#, options: .regularExpression) else { return nil }
        let nums = s[m].split(whereSeparator: { !$0.isNumber }).map(String.init)
        return nums.count >= 2 ? "S\(nums[0]) · É\(nums[1])" : nil
    }
}

struct ResumeRow: View {
    let entries: [ResumeEntry]
    let open: (MediaItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(title: "Reprendre")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 30) {
                    ForEach(entries) { r in ResumeCard(r: r) { open(r.item) } }
                }.padding(.horizontal, 120).padding(.vertical, 30)
            }.scrollClipDisabled()
        }.focusSection()
    }
}

struct PosterButton: View {
    let item: MediaItem
    var width: CGFloat = 220
    let action: () -> Void
    var body: some View {
        Button(action: action) { PosterTile(item: item).frame(width: width, height: width * 1.5) }
            .buttonStyle(TileStyle())
            .accessibilityLabel(item.displayTitle)
    }
}

/// Affiche d'une rangée, comme le simulateur avec de vraies affiches : l'image seule (le titre est déjà dessus),
/// bandeau bleu « NOUVEAU » en haut si le titre vient d'arriver, « fin hh:mm » si la durée est connue,
/// barre de progression si le titre est commencé. Sans image : le titre propre sur un dégradé.
struct PosterTile: View {
    let item: MediaItem
    var showNew = true
    @ObservedObject var watch = WatchStore.shared
    var body: some View {
        ZStack(alignment: .top) {
            Poster(url: item.posterURL, title: item.posterURL.isEmpty ? item.displayTitle : "")
            if let n = newLabel {
                Text(n).font(P.font(15, .heavy)).tracking(0.9).foregroundStyle(.white).lineLimit(1)
                    .padding(.vertical, 7).frame(maxWidth: .infinity)
                    .background(Color(red: 0.04, green: 0.52, blue: 1))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
            }
            if item.kind == .film, let rt = item.fiche?.runtime, rt > 0 {
                let left = max(60, Double(rt * 60) - (watch.resume(item.id) ?? 0))
                HStack(spacing: 5) {
                    Text("fin " + Fmt.hm(Date().addingTimeInterval(left)))
                    Image(systemName: "moon.fill").font(P.font(12))
                }
                .font(P.font(15, .bold)).foregroundStyle(P.gold)
                .padding(.horizontal, 8).padding(.vertical, 4).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
                .padding(10).padding(.top, newLabel == nil ? 0 : 30)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let f = watch.fraction(item.id), f > 0.02, f < 0.92 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.25))
                        Rectangle().fill(.white).frame(width: g.size.width * f)
                    }.frame(height: 6).frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    /// « NOUVEAU · AUJOURD'HUI » pendant 7 jours après l'ajout chez le fournisseur.
    private var newLabel: String? {
        guard showNew, item.added > 0 else { return nil }
        let d = (Int(Date().timeIntervalSince1970) - item.added) / 86400
        guard d >= 0 && d <= 7 else { return nil }
        return "NOUVEAU · " + (agoText(item.added) ?? "").uppercased()
    }
}

/// Affiche : image du fournisseur ou de TMDB (décodée à la bonne taille), sinon le titre sur un dégradé.
struct Poster: View {
    let url: String
    var title: String = ""
    var maxPixel: CGFloat = 500
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.2), Color(white: 0.09)], startPoint: .top, endPoint: .bottom)
            if !title.isEmpty { Text(title).font(P.font(22, .bold)).multilineTextAlignment(.center).padding(14).foregroundStyle(P.dim) }
            if !url.isEmpty { SharpImage(url: url, maxPixel: maxPixel) }
        }
        .clipped()
    }
}

// MARK: - Tous les titres d'une catégorie (chargés par pages de 60)

struct CategoryGridView: View {
    let kind: MediaKind
    let cat: MediaStore.Cat
    @State private var items: [MediaItem] = []
    @State private var done = false
    @State private var open: MediaItem?
    private let cols = Array(repeating: GridItem(.fixed(210), spacing: 36), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(kind == .film ? "FILMS" : "SÉRIES").font(P.font(20, .bold)).tracking(2).foregroundStyle(P.faint)
                Text(cat.name).font(P.font(56, .bold)).foregroundStyle(P.ink)
                Text("\(cat.count) titres").font(P.font(24)).foregroundStyle(P.dim)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 120).padding(.top, 80)
            LazyVGrid(columns: cols, spacing: 50) {
                ForEach(items) { it in
                    PosterButton(item: it) { open = it }
                        .onAppear { if it.id == items.last?.id { Task { await more() } } }
                }
            }.padding(.horizontal, 100).padding(.vertical, 40)
        }
        .scrollClipDisabled()
        .background(PrismeBackground())
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .task { await more() }
    }

    private func more() async {
        guard !done else { return }
        let page = await MediaStore.page(kind, cat: cat, offset: items.count, limit: 60)
        if page.count < 60 { done = true }
        items += page
    }
}

// MARK: - Ma liste (films et séries ajoutés avec +, et ceux commencés)

struct MineView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var resume: [ResumeEntry] = []
    @State private var films: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var open: MediaItem?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                TopBar(claimFocus: true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ma liste").font(P.font(64, .bold))
                    Text("Ce que tu as ajouté avec +, et ce que tu as commencé.").font(P.font(25)).foregroundStyle(P.dim)
                }.padding(.horizontal, 120)
                if loaded && resume.isEmpty && films.isEmpty && series.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "plus.circle").font(P.font(70)).foregroundStyle(P.faint)
                        Text("Ta liste est vide").font(P.font(34, .bold))
                        Text("Sur la fiche d'un film ou d'une série, choisis + pour l'ajouter ici.").font(P.font(24)).foregroundStyle(P.dim)
                    }.frame(maxWidth: .infinity).padding(.top, 100)
                }
                if !resume.isEmpty { ResumeRow(entries: resume, open: { open = $0 }) }
                if !films.isEmpty { MediaRow(title: "Films", sub: "\(films.count)", items: films, open: { open = $0 }) }
                if !series.isEmpty { MediaRow(title: "Séries", sub: "\(series.count)", items: series, open: { open = $0 }) }
            }.padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .task(id: "\(watch.favorites.count)|\(watch.entries.count)|\(store.catalogVersion)") {
            let list = Array(watch.inProgress.prefix(20))
            let items = await MediaStore.items(ids: list.map(\.item))
            let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            resume = list.compactMap { e in byID[e.item].map { ResumeEntry(item: $0, entry: e) } }
            films = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix("film:") })
            series = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix("series:") })
            loaded = true
        }
    }
}

// MARK: - Recherche (titres des films et séries)

struct SearchView: View {
    @EnvironmentObject var store: ProviderStore
    @State private var q = ""
    @State private var films: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var open: MediaItem?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                TopBar(claimFocus: true)
                VStack(alignment: .leading, spacing: 18) {
                    Text("Recherche").font(P.font(64, .bold))
                    TextField("Un film, une série…", text: $q).font(P.font(30)).frame(maxWidth: 1100)
                }
                .padding(.horizontal, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
                if !films.isEmpty { MediaRow(title: "Films", sub: "\(films.count)", items: films, open: { open = $0 }) }
                if !series.isEmpty { MediaRow(title: "Séries", sub: "\(series.count)", items: series, open: { open = $0 }) }
                if q.count >= 2 && films.isEmpty && series.isEmpty {
                    Text("Aucun titre ne correspond à « \(q) ».").font(P.font(26)).foregroundStyle(P.dim).padding(.horizontal, 120)
                }
            }.padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        .autocorrectionDisabled()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .task(id: q) {
            let t = q.trimmingCharacters(in: .whitespaces)
            guard t.count >= 2 else { films = []; series = []; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let pids = store.active.map(\.id), like = "%" + t + "%"
            async let f = MediaStore.list(.film, pids: pids, where: "name LIKE ?", args: [like], order: "rating DESC, added DESC", limit: 40)
            async let s = MediaStore.list(.series, pids: pids, where: "name LIKE ?", args: [like], order: "rating DESC, added DESC", limit: 40)
            let (f1, s1) = await (f, s)
            if !Task.isCancelled { films = f1; series = s1 }
        }
    }
}
