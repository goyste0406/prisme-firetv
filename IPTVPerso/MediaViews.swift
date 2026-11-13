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
    @State private var resume: [ResumeEntry] = []
    @State private var mine: [MediaItem] = []
    @State private var cats: [MediaStore.Cat] = []
    @State private var genres: [GenreRow] = []
    @ObservedObject var fiches = FicheService.shared
    @State private var open: MediaItem?
    @State private var openCat: MediaStore.Cat?
    @State private var heroIndex = 0
    @State private var playing: VodRequest?
    @FocusState private var heroFocus: Bool

    private var loadKey: String { "\(kind.rawValue)|\(store.catalogVersion)|\(store.active.map(\.id).joined())|\(fiches.version / 25)" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                ZStack(alignment: .top) {
                    if !hero.isEmpty {
                        let h = hero[heroIndex % hero.count]
                        HeroView(item: h, index: heroIndex % hero.count, count: hero.count, provider: store.provider(h.pid)?.name ?? "",
                                 focus: $heroFocus,
                                 play: { info in play(h, info) }, info: { open = h },
                                 step: { d in withAnimation(.easeInOut(duration: 0.45)) { heroIndex = (heroIndex + d + hero.count) % hero.count } })
                    } else {
                        Color.clear.frame(height: 240)
                    }
                    TopBar()
                }
                if store.importing != nil && newest.isEmpty {
                    Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(P.font(30, .semibold)).foregroundStyle(P.dim).padding(.horizontal, 120)
                }
                if !resume.isEmpty { ResumeRow(entries: resume, open: { open = $0 }) }
                if !mine.isEmpty { MediaRow(title: "Ma liste", sub: "\(mine.count)", items: mine, open: { open = $0 }) }
                if !newest.isEmpty {
                    MediaRow(title: "Nouveau sur prisme", sub: "ajouts récents chez " + providerNames, items: newest, open: { open = $0 }, showAdded: true)
                }
                if !best.isEmpty { MediaRow(title: "Les mieux notés", sub: "selon les notes du fournisseur", items: best, open: { open = $0 }) }
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
            // la grande affiche change toutes les 8 s, sauf quand le bouton Lecture est sélectionné
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if hero.count > 1 && !heroFocus { withAnimation(.easeInOut(duration: 0.7)) { heroIndex += 1 } }
            }
        }
    }

    private var pids: [String] { store.active.map(\.id) }
    private var providerNames: String { store.active.map(\.name).joined(separator: ", ") }

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
        let list = watch.inProgress.filter { $0.item.hasPrefix(prefix) }.prefix(20)
        let items = await MediaStore.items(ids: list.map(\.item))
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        resume = list.compactMap { e in byID[e.item].map { ResumeEntry(item: $0, entry: e) } }
        mine = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix(prefix) })
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

struct GenreRow: Identifiable { let name: String; let items: [MediaItem]; var id: String { name } }

/// Grande affiche en haut de l'accueil : image plein écran, badge doré, titre, infos, Lecture (avec l'heure de fin).
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

    var body: some View {
        let c = item.clean
        let f = item.fiche
        ZStack(alignment: .bottomLeading) {
            ZStack {
                if item.backdropURL.isEmpty { Poster(url: item.posterURL).blur(radius: 50).opacity(0.6) }
                else { Poster(url: item.backdropURL) }
            }
            .frame(width: 1920, height: 860).clipped()
            .id(item.id).transition(.opacity)
            LinearGradient(colors: [P.room.opacity(0.92), P.room.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.6), .clear, .clear, P.room], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 16) {
                Kicker(text: (agoDays ?? 99) <= 7 ? "L'arrivée de la semaine" : (item.kind == .film ? "Nouveau dans prisme" : "Nouvelle série"))
                Text(item.displayTitle).font(P.font(74, .bold)).lineLimit(2).minimumScaleFactor(0.7).frame(maxWidth: 1150, alignment: .leading)
                HStack(spacing: 18) {
                    if !provider.isEmpty { Pill(text: provider, bg: P.chip.opacity(0.45), stroke: P.chip) }
                    if let a = agoText(item.added) { Text(a) }
                    let y = (f?.year ?? 0) > 0 ? f!.year : c.year
                    if y > 0 { Text(String(y)) }
                    if item.kind == .film, minutes > 0 { Text(runtimeText(minutes)) }
                    if item.kind == .series, !details.seasons.isEmpty {
                        let n = details.seasons.flatMap(\.episodes).count
                        Text("\(details.seasons.count) saison\(details.seasons.count > 1 ? "s" : "") · \(n) ép.")
                    }
                    let r = (f?.vote ?? 0) > 0 ? f!.vote : item.rating
                    if r > 0 { Stars(value: r) }
                    if !c.tags.isEmpty { Pill(text: c.tags.joined(separator: " · "), bg: .clear) }
                }
                .font(P.font(25, .medium)).foregroundStyle(P.dim)
                let plot = (f?.overview.isEmpty == false) ? f!.overview : (item.plot.isEmpty ? details.plot : item.plot)
                if !plot.isEmpty { Text(plot).font(P.font(26)).foregroundStyle(.white.opacity(0.8)).lineLimit(2).frame(maxWidth: 980, alignment: .leading) }
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
            .padding(.leading, 120).padding(.bottom, 64)

            if count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<count, id: \.self) { i in Capsule().fill(.white.opacity(i == index ? 1 : 0.35)).frame(width: i == index ? 34 : 10, height: 10) }
                    Text("\(index + 1) / \(count)").font(P.font(20, .semibold)).foregroundStyle(P.dim).padding(.leading, 8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 120).padding(.bottom, 150)
            }
        }
        .frame(width: 1920, height: 860)
        .focusSection()
        .task(id: item.id) {
            let id = item.id
            let m = await InfoLoader.load(item)
            if id == item.id { mi = m; miFor = id }
        }
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
    var showAdded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                SectionTitle(title: title, sub: sub)
                if let more {
                    Button(action: more) { Text("Tout voir").font(P.font(21, .semibold)) }.buttonStyle(GlassStyle(radius: 14, minH: 48))
                }
            }.padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 34) {
                    ForEach(items) { it in
                        VStack(alignment: .leading, spacing: 10) {
                            PosterButton(item: it) { open(it) }
                            if showAdded, let a = agoText(it.added) {
                                Text("NOUVEAU · " + a.uppercased()).font(P.font(15, .bold)).tracking(1).foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1))
                            }
                        }
                    }
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
            else { MediaRow(title: cat.name, sub: "\(cat.count)", items: items, open: open, more: cat.count > items.count ? more : nil) }
        }
        .task(id: cat.id) { items = await MediaStore.page(kind, cat: cat, offset: 0, limit: 20) }
    }
}

// MARK: - « Reprendre » : cartes larges avec le temps restant (simulateur)

struct ResumeEntry: Identifiable { let item: MediaItem; let entry: WatchStore.Entry; var id: String { item.id } }

struct ResumeRow: View {
    let entries: [ResumeEntry]
    let open: (MediaItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Reprendre", sub: "\(entries.count) en cours").padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 34) {
                    ForEach(entries) { r in
                        Button { open(r.item) } label: { card(r) }.buttonStyle(TileStyle(radius: 20, zoom: 1.06))
                    }
                }.padding(.horizontal, 120).padding(.vertical, 34)
            }.scrollClipDisabled()
        }.focusSection()
    }

    private func card(_ r: ResumeEntry) -> some View {
        let e = r.entry
        let left = max(60, e.dur - e.pos)
        let ep = episodeTag(e.ep)
        return ZStack(alignment: .bottomLeading) {
            Poster(url: r.item.backdropURL.isEmpty ? r.item.posterURL : r.item.backdropURL).blur(radius: r.item.backdropURL.isEmpty ? 30 : 0)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(r.item.displayTitle).font(P.font(25, .bold)).lineLimit(1)
                Text((ep.map { $0 + " · " } ?? "") + "reste " + runtimeText(Int(left / 60))).font(P.font(18)).opacity(0.75)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: g.size.width * min(1, e.pos / max(1, e.dur)))
                    }
                }.frame(height: 5).padding(.top, 6)
            }.foregroundStyle(.white).padding(18)
        }
        .frame(width: 420, height: 236)
    }

    /// « Saison 2 · Épisode 3 · … » → « S2 · É3 ».
    private func episodeTag(_ s: String?) -> String? {
        guard let s, let m = s.range(of: #"Saison (\d+) · Épisode (\d+)"#, options: .regularExpression) else { return nil }
        let nums = s[m].split(whereSeparator: { !$0.isNumber }).map(String.init)
        return nums.count >= 2 ? "S\(nums[0]) · É\(nums[1])" : nil
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

/// Affiche d'une rangée (simulateur) : titre et année en bas, « fin hh:mm » en haut si la durée est connue,
/// barre de progression si le titre est commencé.
struct PosterTile: View {
    let item: MediaItem
    @ObservedObject var watch = WatchStore.shared
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: item.posterURL, title: item.posterURL.isEmpty ? item.displayTitle : "")
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle).font(P.font(22, .bold)).lineLimit(3).minimumScaleFactor(0.8)
                let y = (item.fiche?.year ?? 0) > 0 ? item.fiche!.year : item.clean.year
                if y > 0 { Text(String(y)).font(P.font(16, .bold)).opacity(0.7) }
            }
            .foregroundStyle(.white).padding(14).padding(.bottom, 4)
            if item.kind == .film, let rt = item.fiche?.runtime, rt > 0 {
                VStack {
                    HStack {
                        Spacer()
                        let left = max(60, Double(rt * 60) - (watch.resume(item.id) ?? 0))
                        Text("fin " + Fmt.hm(Date().addingTimeInterval(left))).font(P.font(15, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
                    }
                    Spacer()
                }.padding(10)
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
                TopBar()
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
                TopBar()
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
