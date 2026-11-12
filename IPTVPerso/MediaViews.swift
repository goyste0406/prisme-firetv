import SwiftUI

// MARK: - Accueil Films / Séries

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
    @State private var open: MediaItem?
    @State private var openCat: MediaStore.Cat?
    @State private var heroIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 44) {
                    if !hero.isEmpty { HeroView(item: hero[heroIndex % hero.count]) { open = hero[heroIndex % hero.count] } }
                    if store.importing != nil && newest.isEmpty {
                        Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(.title3).padding(.horizontal, 80)
                    }
                    if !resume.isEmpty { MediaRow(title: "Reprendre", items: resume, open: { open = $0 }) }
                    if !mine.isEmpty { MediaRow(title: "Ma liste", items: mine, open: { open = $0 }) }
                    if !newest.isEmpty { MediaRow(title: "Nouveautés", items: newest, open: { open = $0 }) }
                    if !best.isEmpty { MediaRow(title: "Les mieux notés", items: best, open: { open = $0 }) }
                    ForEach(cats) { c in
                        CategoryRow(kind: kind, cat: c, open: { open = $0 }, more: { openCat = c })
                    }
                }
                .padding(.bottom, 80)
            }
            .navigationDestination(item: $open) { it in DetailView(item: it) }
            .navigationDestination(item: $openCat) { c in CategoryGridView(kind: kind, cat: c) }
        }
        .task(id: "\(store.catalogVersion)|\(store.active.map(\.id).joined())") { await load() }
        .task(id: watch.entries.count) { await loadResume() }
        .task {
            // la grande affiche change toutes les 8 s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if !hero.isEmpty { withAnimation(.easeInOut(duration: 0.6)) { heroIndex += 1 } }
            }
        }
    }

    private var pids: [String] { store.active.map(\.id) }

    private func load() async {
        async let n = MediaStore.list(kind, pids: pids, order: "added DESC", limit: 30)
        async let b = MediaStore.list(kind, pids: pids, where: "rating>0", order: "rating DESC, added DESC", limit: 30)
        async let c = MediaStore.categories(kind, pids: pids)
        let (n1, b1, c1) = await (n, b, c)
        newest = n1; best = b1; cats = c1
        hero = Array(n1.filter { !$0.icon.isEmpty }.prefix(6))
        await loadResume()
    }

    private func loadResume() async {
        let prefix = kind.rawValue + ":"
        let ids = watch.inProgress.map(\.item).filter { $0.hasPrefix(prefix) }
        resume = await MediaStore.items(ids: Array(ids.prefix(20)))
        mine = await MediaStore.items(ids: watch.favorites.filter { $0.hasPrefix(prefix) })
    }
}

struct HeroView: View {
    let item: MediaItem
    let action: () -> Void
    var body: some View {
        let c = item.clean
        ZStack(alignment: .bottomLeading) {
            Poster(url: item.icon).frame(maxWidth: .infinity).frame(height: 520).blur(radius: 40).opacity(0.55).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 40) {
                Poster(url: item.icon).frame(width: 260, height: 390).clipShape(RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 14) {
                    Text("NOUVEAU").font(.caption).bold().foregroundStyle(.secondary)
                    Text(c.title).font(.system(size: 60, weight: .heavy)).lineLimit(2)
                    HStack(spacing: 14) {
                        if c.year > 0 { Text(String(c.year)) }
                        if item.rating > 0 { Label(String(format: "%.1f", item.rating), systemImage: "star.fill") }
                        ForEach(c.tags, id: \.self) { Text($0).font(.caption).padding(.horizontal, 8).padding(.vertical, 3).overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.5))) }
                    }.foregroundStyle(.secondary)
                    Button(action: action) { Label("Voir la fiche", systemImage: "info.circle") }
                }
            }.padding(.horizontal, 80).padding(.bottom, 30)
        }
        .frame(height: 520)
        .id(item.id)
        .transition(.opacity)
    }
}

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    let open: (MediaItem) -> Void
    var more: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.system(size: 34, weight: .bold))
                if let more { Button("Tout voir", action: more).font(.callout) }
            }.padding(.horizontal, 80)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 40) {
                    ForEach(items) { it in PosterButton(item: it) { open(it) } }
                }.padding(.horizontal, 80).padding(.vertical, 30)
            }
        }
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
    let action: () -> Void
    @ObservedObject var watch = WatchStore.shared
    var body: some View {
        let c = item.clean
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Poster(url: item.icon, title: c.title)
                if let f = watch.fraction(item.id), f > 0.02, f < 0.92 {
                    GeometryReader { g in
                        Rectangle().fill(.white).frame(width: g.size.width * f, height: 6).frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .frame(width: 220, height: 330)
        }
        .buttonStyle(.card)
        .accessibilityLabel(c.title)
    }
}

/// Affiche : image du fournisseur, sinon le titre sur un dégradé.
struct Poster: View {
    let url: String
    var title: String = ""
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.22), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
            if !title.isEmpty { Text(title).font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center).padding(14).foregroundStyle(.secondary) }
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
    private let cols = Array(repeating: GridItem(.fixed(220), spacing: 40), count: 7)

    var body: some View {
        ScrollView {
            Text(cat.name).font(.system(size: 44, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 60)
            LazyVGrid(columns: cols, spacing: 50) {
                ForEach(items) { it in
                    PosterButton(item: it) { open = it }
                        .onAppear { if it.id == items.last?.id { Task { await more() } } }
                }
            }.padding(40)
        }
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

// MARK: - Fiche

struct DetailView: View {
    let item: MediaItem
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var info = MediaInfo()
    @State private var versions: [MediaItem] = []
    @State private var chosen: MediaItem?
    @State private var season = 1
    @State private var playing: VodRequest?
    @State private var pickVersion = false

    private var cur: MediaItem { chosen ?? item }

    var body: some View {
        let c = item.clean
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top, spacing: 50) {
                    Poster(url: item.icon, title: c.title).frame(width: 300, height: 450).clipShape(RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.kind == .film ? "FILM" : "SÉRIE").font(.caption).bold().foregroundStyle(.secondary)
                        Text(c.title).font(.system(size: 56, weight: .heavy)).lineLimit(2)
                        HStack(spacing: 18) {
                            let y = c.year > 0 ? c.year : info.year
                            if y > 0 { Text(String(y)) }
                            if !info.duration.isEmpty { Text(info.duration) }
                            if !info.genre.isEmpty { Text(info.genre).lineLimit(1) }
                            let r = item.rating > 0 ? item.rating : info.rating
                            if r > 0 { Label(String(format: "%.1f", r), systemImage: "star.fill") }
                        }.font(.title3).foregroundStyle(.secondary)
                        let plot = info.plot.isEmpty ? item.plot : info.plot
                        if !plot.isEmpty { Text(plot).font(.system(size: 26)).lineLimit(5).frame(maxWidth: 1100, alignment: .leading) }
                        if !info.cast.isEmpty { Text("Avec " + info.cast).font(.callout).foregroundStyle(.secondary).lineLimit(2) }
                        if !info.director.isEmpty { Text("Réalisation : " + info.director).font(.callout).foregroundStyle(.secondary).lineLimit(1) }
                        HStack(spacing: 24) {
                            if item.kind == .film { filmButtons } else { seriesButtons }
                            Button { watch.toggleFavorite(item.id) } label: {
                                Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus")
                            }
                            if versions.count > 1 {
                                Button { pickVersion = true } label: { Text(versionLabel(cur)) }
                            }
                        }.padding(.top, 10)
                    }
                }
                if item.kind == .series && !info.seasons.isEmpty { episodes }
            }
            .padding(60)
        }
        .background(alignment: .top) {
            Poster(url: info.backdrop.isEmpty ? item.icon : info.backdrop).frame(height: 700).blur(radius: 50).opacity(0.35).ignoresSafeArea()
        }
        .task(id: item.id) {
            async let i = InfoLoader.load(item)
            async let v = MediaStore.versions(of: item, pids: store.active.map(\.id))
            let (i1, v1) = await (i, v)
            info = i1; versions = v1
            if chosen == nil { chosen = v1.first }
            if item.kind == .series, let first = nextEpisode()?.season ?? i1.seasons.first?.number { season = first }
        }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .confirmationDialog("Choisir la version", isPresented: $pickVersion) {
            ForEach(versions) { v in Button(versionLabel(v)) { chosen = v; if item.kind == .series { Task { info = await InfoLoader.load(v) } } } }
        }
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
            Label(r != nil ? "Reprendre à " + hms(r!) : "Lecture", systemImage: "play.fill")
        }
        if r != nil { Button { play(from: 0) } label: { Label("Depuis le début", systemImage: "gobackward") } }
    }

    private func play(from: Double) {
        guard let p = store.provider(cur.pid), let url = p.movieURL(cur) else { return }
        playing = VodRequest(url: url, key: item.id, item: item.id, title: item.clean.title, subtitle: "", icon: item.icon, startAt: from)
    }

    // ---- séries
    private func nextEpisode() -> EpisodeInfo? {
        let all = info.seasons.flatMap(\.episodes)
        // le dernier épisode commencé, sinon le suivant du dernier vu, sinon le premier
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
                Label((r != nil ? "Reprendre " : "Lecture ") + "S\(e.season) É\(e.number)", systemImage: "play.fill")
            }
        }
    }

    private func playEpisode(_ e: EpisodeInfo, from: Double) {
        playing = request(for: e, from: from)
    }

    private func request(for e: EpisodeInfo, from: Double) -> VodRequest? {
        guard let p = store.provider(cur.pid), let url = p.episodeURL(e) else { return nil }
        let all = info.seasons.flatMap(\.episodes)
        var r = VodRequest(url: url, key: epKey(e), item: item.id, title: item.clean.title,
                           subtitle: "Saison \(e.season) · Épisode \(e.number)" + (e.title.isEmpty ? "" : " · " + e.title), icon: item.icon, startAt: from)
        if let i = all.firstIndex(of: e), i + 1 < all.count {
            let n = all[i + 1]
            r.next = { self.request(for: n, from: 0) }
        }
        return r
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(info.seasons) { s in
                        Button("Saison \(s.number)") { season = s.number }
                            .font(.system(size: 26, weight: season == s.number ? .bold : .regular))
                    }
                }.padding(.vertical, 20)
            }
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(info.seasons.first { $0.number == season }?.episodes ?? []) { e in
                    Button { playEpisode(e, from: watch.resume(epKey(e)) ?? 0) } label: {
                        HStack(spacing: 24) {
                            Poster(url: e.image.isEmpty ? item.icon : e.image).frame(width: 260, height: 146).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(e.number). " + (e.title.isEmpty ? "Épisode \(e.number)" : e.title)).font(.system(size: 26, weight: .semibold)).lineLimit(1)
                                if !e.plot.isEmpty { Text(e.plot).font(.system(size: 20)).foregroundStyle(.secondary).lineLimit(2) }
                                if let f = watch.fraction(epKey(e)) {
                                    if f >= 0.92 { Label("Vu", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary) }
                                    else { ProgressView(value: f).tint(.white).frame(width: 300) }
                                }
                            }
                            Spacer(minLength: 0)
                        }.padding(14)
                    }
                    .buttonStyle(.card)
                }
            }
        }
    }

    private func hms(_ t: Double) -> String {
        let s = Int(t), h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
}
