import SwiftUI

// MARK: - Accueil Films / Séries (apparence du simulateur)

private struct HomeSnap { var newest: [MediaItem]; var best: [MediaItem]; var cats: [MediaStore.Cat]; var genres: [GenreRow] }
/// Les accueils déjà calculés : changer d'onglet ne relance pas les requêtes.
private enum HomeCache { static var map: [String: HomeSnap] = [:] }

struct MediaHomeView: View {
    let kind: MediaKind
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var hero: [MediaItem] = []
    @State private var newest: [MediaItem] = []
    @State private var best: [MediaItem] = []
    @State private var resume: [MediaItem] = []
    @State private var mine: [MediaItem] = []
    @State private var cats: [MediaStore.Cat] = []
    @State private var genres: [GenreRow] = []
    @ObservedObject var fiches = FicheService.shared
    @State private var open: MediaItem?
    @State private var openCat: MediaStore.Cat?
    @State private var heroIndex = 0
    @State private var playing: VodRequest?

    private var loadKey: String { "\(kind.rawValue)|\(store.catalogVersion)|\(store.active.map(\.id).joined())|\(fiches.version / 25)" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if !hero.isEmpty {
                    let h = hero[heroIndex % hero.count]
                    HeroView(item: h, index: heroIndex % hero.count, count: hero.count, provider: store.provider(h.pid)?.name ?? "",
                             play: { play(h) }, info: { open = h })
                } else {
                    Color.clear.frame(height: 200)
                }
                if store.importing != nil && newest.isEmpty {
                    Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(P.font(30, .semibold)).foregroundStyle(P.dim).padding(.horizontal, 120)
                }
                if !resume.isEmpty { MediaRow(title: "Reprendre", sub: "là où tu t'es arrêté", items: resume, open: { open = $0 }) }
                if !mine.isEmpty { MediaRow(title: "Ma liste", items: mine, open: { open = $0 }) }
                if !newest.isEmpty { MediaRow(title: "Nouveautés", sub: "ajoutés récemment", items: newest, open: { open = $0 }) }
                if !best.isEmpty { MediaRow(title: "Les mieux notés", items: best, open: { open = $0 }) }
                ForEach(genres) { g in MediaRow(title: g.name, items: g.items, open: { open = $0 }) }
                ForEach(cats) { c in
                    CategoryRow(kind: kind, cat: c, open: { open = $0 }, more: { openCat = c })
                }
            }
            .padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .navigationDestination(item: $openCat) { c in CategoryGridView(kind: kind, cat: c) }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .task(id: loadKey) { await load(loadKey) }
        .task(id: watch.entries.count) { await loadResume() }
        .task {
            // la grande affiche change toutes les 8 s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if hero.count > 1 { withAnimation(.easeInOut(duration: 0.7)) { heroIndex += 1 } }
            }
        }
    }

    private var pids: [String] { store.active.map(\.id) }

    private func apply(_ s: HomeSnap) {
        newest = s.newest; best = s.best; cats = s.cats; genres = s.genres
        let withArt = s.newest.filter { !$0.backdropURL.isEmpty }
        hero = Array((withArt.count >= 3 ? withArt : s.newest.filter { !$0.posterURL.isEmpty }).prefix(6))
    }

    private func load(_ key: String) async {
        if let s = HomeCache.map[key] { apply(s) }
        async let n = MediaStore.list(kind, pids: pids, order: "added DESC", limit: 30)
        async let b = MediaStore.list(kind, pids: pids, where: "rating>0", order: "rating DESC, added DESC", limit: 30)
        async let c = MediaStore.categories(kind, pids: pids)
        let (n1, b1, c1) = await (n, b, c)
        let G = kind == .film ? ["Action", "Comédie", "Drame", "Thriller", "Science-Fiction", "Animation", "Aventure", "Horreur", "Familial", "Romance", "Crime", "Documentaire"]
                              : ["Drame", "Comédie", "Crime", "Action & Adventure", "Science-Fiction & Fantastique", "Mystère", "Animation", "Familial", "Documentaire"]
        var gr: [GenreRow] = []
        for g in G { let L = await MediaStore.byGenre(kind, pids: pids, genre: g, limit: 20); if L.count >= 5 { gr.append(GenreRow(name: g, items: L)) } }
        let snap = HomeSnap(newest: n1, best: b1, cats: c1, genres: gr)
        HomeCache.map[key] = snap
        apply(snap)
        await loadResume()
    }

    private func loadResume() async {
        let prefix = kind.rawValue + ":"
        let ids = watch.inProgress.map(\.item).filter { $0.hasPrefix(prefix) }
        resume = await MediaStore.items(ids: Array(ids.prefix(20)))
        mine = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix(prefix) })
    }

    /// « Lecture » sur la grande affiche : un film démarre (en reprenant s'il a été commencé), une série ouvre sa fiche.
    private func play(_ it: MediaItem) {
        guard it.kind == .film, let p = store.provider(it.pid), let url = p.movieURL(it) else { open = it; return }
        playing = VodRequest(url: url, key: it.id, item: it.id, title: it.displayTitle, subtitle: "", icon: it.posterURL, startAt: watch.resume(it.id) ?? 0)
    }
}

struct GenreRow: Identifiable { let name: String; let items: [MediaItem]; var id: String { name } }

func runtimeText(_ m: Int) -> String { m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min" }

/// Grande affiche en haut de l'accueil : image plein écran, badge doré, titre, infos, Lecture.
struct HeroView: View {
    let item: MediaItem
    let index: Int
    let count: Int
    let provider: String
    let play: () -> Void
    let info: () -> Void
    @ObservedObject var watch = WatchStore.shared

    var body: some View {
        let c = item.clean
        let f = item.fiche
        ZStack(alignment: .bottomLeading) {
            Group {
                if item.backdropURL.isEmpty { Poster(url: item.posterURL).blur(radius: 50).opacity(0.6) }
                else { Poster(url: item.backdropURL) }
            }
            .frame(width: 1920, height: 840).clipped()
            LinearGradient(colors: [P.room.opacity(0.92), P.room.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, P.room], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 18) {
                Kicker(text: item.kind == .film ? "Nouveau dans prisme" : "Nouvelle série")
                Text(item.displayTitle).font(P.font(72, .bold)).lineLimit(2).minimumScaleFactor(0.7).frame(maxWidth: 1150, alignment: .leading)
                HStack(spacing: 18) {
                    if !provider.isEmpty { Pill(text: provider, bg: P.chip.opacity(0.45), stroke: P.chip) }
                    let y = (f?.year ?? 0) > 0 ? f!.year : c.year
                    if y > 0 { Text(String(y)) }
                    if let rt = f?.runtime, rt > 0 { Text(runtimeText(rt)) }
                    let r = (f?.vote ?? 0) > 0 ? f!.vote : item.rating
                    if r > 0 { Stars(value: r) }
                    if !c.tags.isEmpty { Pill(text: c.tags.joined(separator: " · "), bg: .clear) }
                }
                .font(P.font(25, .medium)).foregroundStyle(P.dim)
                let plot = (f?.overview.isEmpty == false) ? f!.overview : item.plot
                if !plot.isEmpty { Text(plot).font(P.font(26)).foregroundStyle(.white.opacity(0.8)).lineLimit(2).frame(maxWidth: 980, alignment: .leading) }
                HStack(spacing: 22) {
                    Button(action: play) { PlayLabel(title: watch.resume(item.id) != nil ? "Reprendre" : "Lecture", sub: endLine(f?.runtime ?? 0)) }
                        .buttonStyle(PrimaryStyle())
                    Button(action: info) { Label("Fiche", systemImage: "info.circle").font(P.font(27, .semibold)) }
                        .buttonStyle(GlassStyle())
                }
                .padding(.top, 10)
            }
            .padding(.leading, 120).padding(.bottom, 70)

            HStack(spacing: 8) {
                ForEach(0..<count, id: \.self) { i in Capsule().fill(.white.opacity(i == index ? 1 : 0.35)).frame(width: i == index ? 34 : 10, height: 10) }
                Text("\(index + 1)/\(count)").font(P.font(20, .semibold)).foregroundStyle(P.dim).padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 120).padding(.bottom, 90)
        }
        .frame(width: 1920, height: 840)
        .id(item.id)
        .transition(.opacity)
        .focusSection()
    }

    private func endLine(_ runtime: Int) -> String? {
        guard item.kind == .film, runtime > 0 else { return nil }
        let left = Double(runtime * 60) - (watch.resume(item.id) ?? 0)
        return "FINIT À " + Fmt.hm(Date().addingTimeInterval(max(60, left)))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                SectionTitle(title: title, sub: sub)
                if let more {
                    Button(action: more) { Text("Tout voir").font(P.font(21, .semibold)) }.buttonStyle(GlassStyle(radius: 14, minH: 48))
                }
            }.padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 34) {
                    ForEach(items) { it in PosterButton(item: it) { open(it) } }
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
            else { MediaRow(title: cat.name, items: items, open: open, more: cat.count > items.count ? more : nil) }
        }
        .task(id: cat.id) { items = await MediaStore.page(kind, cat: cat, offset: 0, limit: 20) }
    }
}

struct PosterButton: View {
    let item: MediaItem
    var width: CGFloat = 210
    let action: () -> Void
    var body: some View {
        Button(action: action) { PosterTile(item: item).frame(width: width, height: width * 1.5) }
            .buttonStyle(TileStyle())
            .accessibilityLabel(item.displayTitle)
    }
}

/// Affiche d'une rangée : titre et année apparaissent en bas quand elle est sélectionnée, barre de progression si commencé.
struct PosterTile: View {
    let item: MediaItem
    @Environment(\.isFocused) private var focused
    @ObservedObject var watch = WatchStore.shared
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: item.posterURL, title: item.displayTitle)
            if focused {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle).font(P.font(23, .bold)).lineLimit(2)
                    let y = (item.fiche?.year ?? 0) > 0 ? item.fiche!.year : item.clean.year
                    if y > 0 { Text(String(y)).font(P.font(18)).foregroundStyle(P.dim) }
                }.foregroundStyle(.white).padding(14).padding(.bottom, 6)
            }
            if let f = watch.fraction(item.id), f > 0.02, f < 0.92 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.25))
                        Rectangle().fill(P.live).frame(width: g.size.width * f)
                    }.frame(height: 6).frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

/// Affiche : image du fournisseur, sinon le titre sur un dégradé.
struct Poster: View {
    let url: String
    var title: String = ""
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.2), Color(white: 0.09)], startPoint: .top, endPoint: .bottom)
            if !title.isEmpty { Text(title).font(P.font(22, .bold)).multilineTextAlignment(.center).padding(14).foregroundStyle(P.dim) }
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u, transaction: Transaction(animation: .easeIn(duration: 0.2))) { ph in
                    if let img = ph.image { img.resizable().scaledToFill() }
                }
            }
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

// MARK: - Fiche (image plein écran, titre, boutons, panneau « Ta soirée »)

struct WhereGroup: Identifiable { let name: String; let list: [WP]; var id: String { name } }

struct DetailView: View {
    let item: MediaItem
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var fiche: Fiche?
    @State private var info = MediaInfo()
    @State private var versions: [MediaItem] = []
    @State private var chosen: MediaItem?
    @State private var season = 1
    @State private var playing: VodRequest?
    @State private var pickVersion = false
    @State private var sagaName = ""
    @State private var saga: [SagaPart] = []
    @State private var sagaAvail: [Int: MediaItem] = [:]
    @State private var universe: [MediaItem] = []
    @State private var openOther: MediaItem?
    @State private var launchMsg: String?

    private var cur: MediaItem { chosen ?? item }
    private var title: String { (fiche?.title.isEmpty == false) ? fiche!.title : item.clean.title }
    private var runtime: Int { (fiche?.runtime ?? 0) > 0 ? fiche!.runtime : 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 46) {
                header
                if item.kind == .series && !info.seasons.isEmpty { episodes.padding(.horizontal, 120) }
                if let f = fiche, !f.cast.isEmpty { castRow(f.cast) }
                if saga.count > 1 { sagaRow }
                if !universe.isEmpty { MediaRow(title: saga.count > 1 ? "Dans le même univers" : "Si tu hésites encore", items: universe, open: { openOther = $0 }) }
                if let f = fiche { whereRow(f).padding(.horizontal, 120) }
            }
            .padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .background(alignment: .top) { backdrop }
        .background(P.room)
        .ignoresSafeArea()
        .navigationDestination(item: $openOther) { it in DetailView(item: it) }
        .task(id: item.id) { await load() }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .confirmationDialog("Choisir la version", isPresented: $pickVersion) {
            ForEach(versions) { v in Button(versionLabel(v)) { chosen = v; if item.kind == .series { Task { info = await InfoLoader.load(v) } } } }
        }
        .alert(launchMsg ?? "", isPresented: Binding(get: { launchMsg != nil }, set: { if !$0 { launchMsg = nil } })) { Button("OK") {} }
    }

    // ---- image de fond plein écran
    private var backdrop: some View {
        let hasBd = fiche?.backdrop.isEmpty == false
        let bd = hasBd ? Fiche.img(fiche!.backdrop, "w1280") : (info.backdrop.isEmpty ? item.icon : info.backdrop)
        return ZStack {
            Poster(url: bd).frame(width: 1920, height: 1080).clipped().blur(radius: hasBd || !info.backdrop.isEmpty ? 0 : 60).opacity(hasBd ? 0.9 : 0.55)
            LinearGradient(colors: [P.room.opacity(0.95), P.room.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .clear, P.room], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: 1920, height: 1080)
    }

    // ---- haut de la fiche
    private var header: some View {
        let c = item.clean
        return HStack(alignment: .bottom, spacing: 50) {
            VStack(alignment: .leading, spacing: 18) {
                Text(item.kind == .film ? "FILM" : "SÉRIE").font(P.font(21, .bold)).tracking(2.5).foregroundStyle(P.dim)
                Text(title).font(P.font(84, .bold)).lineLimit(2).minimumScaleFactor(0.6)
                HStack(spacing: 20) {
                    let y = (fiche?.year ?? 0) > 0 ? fiche!.year : (c.year > 0 ? c.year : info.year)
                    if y > 0 { Text(String(y)) }
                    if runtime > 0 { Text(runtimeText(runtime)) } else if !info.duration.isEmpty { Text(info.duration) }
                    let g = (fiche?.genres.isEmpty == false) ? fiche!.genres : info.genre
                    if !g.isEmpty { Text(g).lineLimit(1) }
                    if !c.tags.isEmpty { Pill(text: c.tags.joined(separator: " · "), bg: .clear) }
                }.font(P.font(26, .medium)).foregroundStyle(P.dim)
                let r = (fiche?.vote ?? 0) > 0 ? fiche!.vote : (item.rating > 0 ? item.rating : info.rating)
                if r > 0 {
                    HStack(spacing: 10) { Image(systemName: "star.fill").foregroundStyle(P.star); Text(String(format: "%.1f", r) + " · " + ratingWord(r)) }
                        .font(P.font(22, .semibold)).padding(.horizontal, 16).padding(.vertical, 10).glass(14)
                }
                let plot = (fiche?.overview.isEmpty == false) ? fiche!.overview : (info.plot.isEmpty ? item.plot : info.plot)
                if !plot.isEmpty { Text(plot).font(P.font(27)).foregroundStyle(.white.opacity(0.85)).lineLimit(3).frame(maxWidth: 1050, alignment: .leading) }
                if fiche?.cast.isEmpty ?? true, !info.cast.isEmpty { Text("Avec " + info.cast).font(P.font(22)).foregroundStyle(P.dim).lineLimit(1).frame(maxWidth: 1050, alignment: .leading) }
                if !info.director.isEmpty { Text("Réalisation : " + info.director).font(P.font(22)).foregroundStyle(P.dim).lineLimit(1) }
                HStack(spacing: 22) {
                    if item.kind == .film { filmButtons } else { seriesButtons }
                    Button { watch.toggleFavorite(item.id) } label: {
                        Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus").font(P.font(30, .bold)).frame(width: 30)
                    }.buttonStyle(GlassStyle())
                    if versions.count > 1 {
                        Button { pickVersion = true } label: { Text(versionLabel(cur)).font(P.font(24, .semibold)).lineLimit(1) }.buttonStyle(GlassStyle())
                    }
                }.padding(.top, 12).focusSection()
            }
            Spacer(minLength: 0)
            if item.kind == .film, runtime > 0 { eveningPanel }
        }
        .padding(.horizontal, 120)
        .frame(minHeight: 960, alignment: .bottom)
    }

    private func ratingWord(_ r: Double) -> String { r >= 8 ? "excellent" : r >= 7 ? "très bien noté" : r >= 6 ? "bien noté" : "avis partagés" }

    // ---- panneau « Ta soirée » : à quelle heure le film se termine
    private var eveningPanel: some View {
        let left = max(60, Double(runtime * 60) - (watch.resume(cur.id) ?? watch.resume(item.id) ?? 0))
        let end = Date().addingTimeInterval(left)
        let frac = min(1, left / (4 * 3600))
        let elsewhere = fiche.map { Array(Set(($0.wp.f + $0.wp.g).map(\.n))).sorted() } ?? []
        return VStack(alignment: .leading, spacing: 20) {
            Text("TA SOIRÉE").font(P.font(19, .bold)).tracking(2).foregroundStyle(P.faint)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(LinearGradient(colors: [P.gold, Color(red: 1, green: 0.55, blue: 0.2)], startPoint: .leading, endPoint: .trailing)).frame(width: max(14, g.size.width * frac))
                }
            }.frame(height: 12)
            HStack { Text("maintenant"); Spacer(); Text("fin " + Fmt.hm(end)) }.font(P.font(18)).foregroundStyle(P.faint)
            (Text("Fin à " + Fmt.hm(end)).foregroundColor(P.gold).bold() + Text(" · dans " + runtimeText(Int(left / 60))).foregroundColor(P.dim))
                .font(P.font(24))
            if !elsewhere.isEmpty {
                HStack(spacing: 14) {
                    Text("AUSSI").font(P.font(17, .bold)).tracking(2).foregroundStyle(P.faint)
                    Text(elsewhere.joined(separator: " · ")).font(P.font(20, .semibold)).lineLimit(1)
                }.padding(.horizontal, 18).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(30).frame(width: 600).glass(30)
    }

    private func load() async {
        let pids = store.active.map(\.id)
        if item.fiche != nil { fiche = item.fiche }
        else { let k = item.kind, key = item.clean.key; fiche = await Database.shared.read { _ in FicheStore.byKeys(k, [key])[key] } }
        async let i = InfoLoader.load(item)
        async let v = MediaStore.versions(of: item, pids: pids)
        let (i1, v1) = await (i, v)
        info = i1; versions = v1
        if chosen == nil { chosen = v1.first }
        if item.kind == .series, let first = nextEpisode()?.season ?? i1.seasons.first?.number { season = first }
        var exclude = Set<Int>()
        if let f = fiche, f.coll > 0 {
            let (n, parts) = await SagaStore.parts(f.coll)
            sagaName = n; saga = parts
            sagaAvail = await MediaStore.items(kind: item.kind, tmdb: parts.map(\.tmdb), pids: pids)
            exclude = Set(parts.map(\.tmdb))
        }
        if let f = fiche { exclude.insert(f.tmdb) }
        var it = item; it.fiche = fiche
        universe = await MediaStore.universe(of: it, pids: pids, exclude: exclude)
    }

    // ---- distribution
    private func castRow(_ cast: [CastMember]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Distribution").padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 40) {
                    ForEach(cast, id: \.self) { a in
                        Button {} label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(LinearGradient(colors: [Color(hue: P.hue(a.n), saturation: 0.45, brightness: 0.55), P.room2], startPoint: .top, endPoint: .bottom))
                                    Text(String(a.n.prefix(1))).font(P.font(46, .bold)).foregroundStyle(.white.opacity(0.8))
                                    if !a.p.isEmpty {
                                        AsyncImage(url: URL(string: Fiche.img(a.p, "w185"))) { ph in if let img = ph.image { img.resizable().scaledToFill() } }
                                    }
                                }.frame(width: 160, height: 160).clipShape(Circle())
                                Text(a.n).font(P.font(22, .semibold)).lineLimit(1)
                                if !a.c.isEmpty { Text(a.c).font(P.font(18)).foregroundStyle(P.dim).lineLimit(1) }
                            }.frame(width: 200).padding(.vertical, 12)
                        }.buttonStyle(TileStyle(radius: 24, zoom: 1.06))
                    }
                }.padding(.horizontal, 120).padding(.vertical, 26)
            }.scrollClipDisabled()
        }.focusSection()
    }

    // ---- saga complète (films absents grisés)
    private var sagaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            let n = saga.filter { sagaAvail[$0.tmdb] != nil }.count
            SectionTitle(title: sagaName.isEmpty ? "La saga" : sagaName, sub: "\(saga.count) films" + (n < saga.count ? " · \(n) chez tes fournisseurs" : "")).padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 34) {
                    ForEach(Array(saga.enumerated()), id: \.element.tmdb) { i, p in
                        Button {
                            if let m = sagaAvail[p.tmdb] { if m.clean.key != item.clean.key { openOther = m } }
                            else { launchMsg = "« \(p.title) » n'est chez aucun de tes fournisseurs pour le moment." }
                        } label: {
                            ZStack(alignment: .topLeading) {
                                Poster(url: Fiche.img(p.poster), title: p.title).frame(width: 210, height: 315)
                                    .saturation(sagaAvail[p.tmdb] == nil ? 0 : 1).opacity(sagaAvail[p.tmdb] == nil ? 0.45 : 1)
                                Pill(text: "\(i + 1)" + (sagaAvail[p.tmdb] == nil ? " · absent" : ""), bg: .black.opacity(0.65), stroke: nil).padding(10)
                            }
                        }.buttonStyle(TileStyle())
                    }
                }.padding(.horizontal, 120).padding(.vertical, 34)
            }.scrollClipDisabled()
        }.focusSection()
    }

    // ---- où le regarder ailleurs
    @ViewBuilder private func whereRow(_ f: Fiche) -> some View {
        let groups: [WhereGroup] = [WhereGroup(name: "Inclus ou gratuit", list: f.wp.f + f.wp.g), WhereGroup(name: "Location", list: f.wp.r), WhereGroup(name: "Achat", list: f.wp.b)].filter { !$0.list.isEmpty }
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Où le regarder")
            HStack(spacing: 12) {
                Image(systemName: "play.fill").foregroundStyle(P.gold)
                Text("Déjà dans prisme · \(versions.count) version\(versions.count > 1 ? "s" : "") · sans frais en plus")
            }.font(P.font(23, .semibold)).padding(.horizontal, 20).padding(.vertical, 14).glass(18)
            if groups.isEmpty { Text("Pas disponible ailleurs en France pour le moment (TMDB).").font(P.font(22)).foregroundStyle(P.dim) }
            ForEach(groups) { g in
                Text(g.name.uppercased()).font(P.font(18, .bold)).tracking(2).foregroundStyle(P.faint).padding(.top, 8)
                ScrollView(.horizontal) {
                    HStack(spacing: 24) {
                        ForEach(Array(Set(g.list.map(\.n))).sorted(), id: \.self) { name in
                            let wp = g.list.first(where: { $0.n == name })!
                            Button {
                                Task { launchMsg = await AppLauncher.open(providerName: name, tmdb: f.tmdb, tv: item.kind == .series) }
                            } label: {
                                HStack(spacing: 14) {
                                    AsyncImage(url: URL(string: Fiche.img(wp.l, "w92"))) { ph in if let img = ph.image { img.resizable().scaledToFit() } else { Color.white.opacity(0.1) } }
                                        .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(name).font(P.font(24, .semibold))
                                }
                            }.buttonStyle(GlassStyle(radius: 20, minH: 80))
                        }
                    }.padding(.vertical, 16)
                }.scrollClipDisabled()
            }
            Text("Disponibilités en France : TMDB (source JustWatch). OK sur une app pour l'ouvrir sur ce titre.").font(P.font(18)).foregroundStyle(P.faint)
        }.focusSection()
    }

    private func versionLabel(_ v: MediaItem) -> String {
        let t = v.clean.tags
        let prov = store.provider(v.pid)?.name ?? ""
        return ([t.isEmpty ? "Version standard" : t.joined(separator: " · ")] + (Set(versions.map(\.pid)).count > 1 ? [prov] : [])).joined(separator: " · ")
    }

    // ---- films
    @ViewBuilder private var filmButtons: some View {
        let r = watch.resume(cur.id) ?? watch.resume(item.id)
        Button { play(from: r ?? 0) } label: {
            if let r { PlayLabel(title: "Reprendre", sub: runtime > 0 ? "RESTE " + runtimeText(max(1, (runtime * 60 - Int(r)) / 60)).uppercased() : "À " + hms(r).uppercased()) }
            else { PlayLabel(title: "Lecture", sub: runtime > 0 ? "FINIT À " + Fmt.hm(Date().addingTimeInterval(Double(runtime * 60))) : nil) }
        }.buttonStyle(PrimaryStyle())
        if r != nil {
            Button { play(from: 0) } label: { Label("Début", systemImage: "gobackward").font(P.font(27, .semibold)) }.buttonStyle(GlassStyle())
        }
    }

    private func play(from: Double) {
        guard let p = store.provider(cur.pid), let url = p.movieURL(cur) else { return }
        playing = VodRequest(url: url, key: item.id, item: item.id, title: title, subtitle: "", icon: item.posterURL, startAt: from)
    }

    // ---- séries
    private func nextEpisode() -> EpisodeInfo? {
        let all = info.seasons.flatMap(\.episodes)
        if let last = all.filter({ watch.fraction(epKey($0)) != nil }).max(by: { (watch.entries[epKey($0)]?.at ?? .distantPast) < (watch.entries[epKey($1)]?.at ?? .distantPast) }) {
            if !watch.watched(epKey(last)) { return last }
            if let i = all.firstIndex(of: last), i + 1 < all.count { return all[i + 1] }
            return last
        }
        return all.first
    }
    private func epKey(_ e: EpisodeInfo) -> String { item.id + ":e" + e.id }

    @ViewBuilder private var seriesButtons: some View {
        if let e = nextEpisode() {
            let r = watch.resume(epKey(e))
            Button { playEpisode(e, from: r ?? 0) } label: {
                PlayLabel(title: r != nil ? "Reprendre" : "Lecture", sub: "SAISON \(e.season) · ÉPISODE \(e.number)")
            }.buttonStyle(PrimaryStyle())
        }
    }

    private func playEpisode(_ e: EpisodeInfo, from: Double) { playing = request(for: e, from: from) }

    private func request(for e: EpisodeInfo, from: Double) -> VodRequest? {
        guard let p = store.provider(cur.pid), let url = p.episodeURL(e) else { return nil }
        let all = info.seasons.flatMap(\.episodes)
        var r = VodRequest(url: url, key: epKey(e), item: item.id, title: title,
                           subtitle: "Saison \(e.season) · Épisode \(e.number)" + (e.title.isEmpty ? "" : " · " + e.title), icon: item.posterURL, startAt: from)
        if let i = all.firstIndex(of: e), i + 1 < all.count {
            let n = all[i + 1]
            r.next = { self.request(for: n, from: 0) }
        }
        return r
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(title: "Épisodes")
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(info.seasons) { s in
                        Button { season = s.number } label: { Text("Saison \(s.number)").font(P.font(24, .semibold)) }
                            .buttonStyle(GlassStyle(radius: 40, minH: 60, on: season == s.number))
                    }
                }.padding(.vertical, 14)
            }.scrollClipDisabled().focusSection()
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(info.seasons.first { $0.number == season }?.episodes ?? []) { e in
                    Button { playEpisode(e, from: watch.resume(epKey(e)) ?? 0) } label: {
                        HStack(spacing: 28) {
                            ZStack(alignment: .bottom) {
                                Poster(url: e.image.isEmpty ? item.posterURL : e.image).frame(width: 300, height: 168).clipShape(RoundedRectangle(cornerRadius: 14))
                                if let f = watch.fraction(epKey(e)), f < 0.92 {
                                    GeometryReader { g in Rectangle().fill(P.live).frame(width: g.size.width * f, height: 6).frame(maxHeight: .infinity, alignment: .bottom) }
                                        .frame(width: 300, height: 168).clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(e.number). " + (e.title.isEmpty ? "Épisode \(e.number)" : e.title)).font(P.font(27, .semibold)).lineLimit(1)
                                if !e.plot.isEmpty { Text(e.plot).font(P.font(21)).opacity(0.7).lineLimit(2) }
                                if watch.watched(epKey(e)) { Label("Vu", systemImage: "checkmark").font(P.font(19, .semibold)).opacity(0.7) }
                            }
                            Spacer(minLength: 0)
                        }.padding(16)
                    }
                    .buttonStyle(RowStyle())
                }
            }
        }.focusSection()
    }

    private func hms(_ t: Double) -> String {
        let s = Int(t), h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
}

// MARK: - Ma liste (films et séries ajoutés avec +, et ceux commencés)

struct MineView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var resume: [MediaItem] = []
    @State private var films: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var open: MediaItem?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ma liste").font(P.font(64, .bold))
                    Text("Ce que tu as ajouté avec +, et ce que tu as commencé.").font(P.font(25)).foregroundStyle(P.dim)
                }.padding(.horizontal, 120).padding(.top, 200)
                if resume.isEmpty && films.isEmpty && series.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "plus.circle").font(P.font(70)).foregroundStyle(P.faint)
                        Text("Ta liste est vide").font(P.font(34, .bold))
                        Text("Sur la fiche d'un film ou d'une série, choisis + pour l'ajouter ici.").font(P.font(24)).foregroundStyle(P.dim)
                    }.frame(maxWidth: .infinity).padding(.top, 120)
                }
                if !resume.isEmpty { MediaRow(title: "Reprendre", items: resume, open: { open = $0 }) }
                if !films.isEmpty { MediaRow(title: "Films", sub: "\(films.count)", items: films, open: { open = $0 }) }
                if !series.isEmpty { MediaRow(title: "Séries", sub: "\(series.count)", items: series, open: { open = $0 }) }
            }.padding(.bottom, 100)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .task(id: "\(watch.favorites.count)|\(watch.entries.count)|\(store.catalogVersion)") {
            resume = await MediaStore.items(ids: Array(watch.inProgress.map(\.item).prefix(20)))
            films = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix("film:") })
            series = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix("series:") })
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
                VStack(alignment: .leading, spacing: 18) {
                    Text("Recherche").font(P.font(64, .bold))
                    TextField("Un film, une série…", text: $q).font(P.font(30)).frame(maxWidth: 1100)
                }.padding(.horizontal, 120).padding(.top, 200)
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
