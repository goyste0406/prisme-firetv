import SwiftUI

// MARK: - TV en direct : catégories à gauche, chaînes à droite (en ce moment + ensuite)

struct LiveHomeView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var section: String = "home"
    @State private var playing: PlayRequest?
    @State private var guide: GuideRequest?

    struct PlayRequest: Identifiable { let id = UUID(); let list: [Channel]; let index: Int }
    struct GuideRequest: Identifiable { let id = UUID(); let list: [Channel]; let title: String }

    private static let rail: [(String, String, String)] = [
        ("home", "house.fill", "Accueil"), ("guide", "tablecells", "Guide"), ("search", "magnifyingglass", "Rechercher"),
        ("fav", "star.fill", "Favoris"), ("recent", "clock.arrow.circlepath", "Récentes"), ("all", "square.grid.2x2.fill", "Toutes les catégories"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(alignment: .top, spacing: 34) {
                railView
                Group {
                    switch section {
                    case "search": ChannelSearchView(play: play)
                    case "fav": ChannelListView(mode: .fav, play: play, guide: openGuide)
                    case "recent": ChannelListView(mode: .recent, play: play, guide: openGuide)
                    case "all": AllCategoriesView(play: play, guide: openGuide)
                    default: LiveFrontView(play: play, guide: openGuide)
                    }
                }
                .id(section)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.leading, 60).padding(.trailing, 40)
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(item: $playing) { r in LivePlayerView(channels: r.list, start: r.index) }
        .fullScreenCover(item: $guide) { g in GuideView(channels: g.list, title: g.title) }
    }

    private func play(_ list: [Channel], _ i: Int) { playing = PlayRequest(list: list, index: i) }
    private func openGuide(_ list: [Channel], _ title: String) { guide = GuideRequest(list: list, title: title) }

    /// Colonne d'icônes à gauche (simulateur) : chaque icône ouvre une partie de la TV en direct.
    private var railView: some View {
        VStack(spacing: 12) {
            ForEach(0..<LiveHomeView.rail.count, id: \.self) { i in
                let r = LiveHomeView.rail[i]
                Button {
                    if r.0 == "guide" { Task { await guideFromRail() } } else { section = r.0 }
                } label: { Image(systemName: r.1).font(P.font(27, .semibold)).frame(width: 64, height: 64) }
                .buttonStyle(RailStyle(selected: section == r.0))
                .accessibilityLabel(r.2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 18).padding(.horizontal, 10)
        .frame(width: 104).frame(maxHeight: .infinity, alignment: .top)
        .glass(30)
        .padding(.bottom, 50)
        .focusSection()
    }

    /// Guide depuis la colonne : tes favoris, sinon tes chaînes récentes, sinon la première catégorie.
    private func guideFromRail() async {
        if !prefs.favorites.isEmpty { openGuide(await LiveStore.channels(ids: prefs.favorites), "Favoris"); return }
        if !prefs.recent.isEmpty { openGuide(await LiveStore.channels(ids: prefs.recent), "Récentes"); return }
        let cats = await LiveStore.categories(providers: store.active.map(\.id))
        if let c = cats.first { openGuide(await LiveStore.channels(pid: c.pid, cid: c.cid), c.name) }
    }
}

struct RailStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : (selected ? Color.white : Color.white.opacity(0.62)))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(f ? Color.white : (selected ? Color.white.opacity(0.16) : .clear)))
                .scaleEffect(f ? 1.1 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

// MARK: - Accueil de la TV en direct : en ce moment, tes chaînes récentes, univers, ce qui commence bientôt

struct LiveFrontView: View {
    let play: ([Channel], Int) -> Void
    let guide: ([Channel], String) -> Void
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var cats: [LiveCategory] = []
    @State private var recent: [Channel] = []
    @State private var favs: [Channel] = []
    @State private var soon: [LiveStore.Airing] = []
    @State private var headNow: Program?
    @State private var headNext: Program?
    @State private var openCat: LiveCategory?
    @State private var openFav = false
    @State private var loaded = false

    private var head: Channel? { recent.first ?? favs.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if let h = head { header(h) }
                if !recent.isEmpty {
                    rowTitle("Pour toi, maintenant", "tes chaînes récentes, en ce moment")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 30) {
                            ForEach(Array(recent.prefix(10).enumerated()), id: \.element.id) { i, ch in
                                VStack(alignment: .leading, spacing: 10) {
                                    ChannelCard(ch: ch, fav: prefs.favorites.contains(ch.id)) { play(recent, i) }
                                        .contextMenu { favButton(ch) }
                                    Text("Tu l'as regardée récemment").font(P.font(17)).foregroundStyle(P.faint)
                                }
                            }
                        }.padding(.vertical, 24).padding(.horizontal, 18)
                    }.scrollClipDisabled().focusSection()
                }
                if !cats.isEmpty || !favs.isEmpty {
                    rowTitle("Explorer par univers", "OK pour voir toutes les chaînes")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 30) {
                            if !favs.isEmpty {
                                UniverseCard(name: "Favoris", tag: "FAVORIS", channels: favs) { openFav = true }
                            }
                            ForEach(cats) { c in
                                UniverseCardLoader(cat: c) { openCat = c }
                            }
                        }.padding(.vertical, 24).padding(.horizontal, 18)
                    }.scrollClipDisabled().focusSection()
                }
                if !soon.isEmpty {
                    rowTitle("Commence bientôt", "dans l'heure · OK pour regarder la chaîne")
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 30) {
                            ForEach(soon) { a in
                                SoonCard(a: a) { play([a.ch], 0) }
                            }
                        }.padding(.vertical, 24).padding(.horizontal, 18)
                    }.scrollClipDisabled().focusSection()
                }
                if loaded && cats.isEmpty && favs.isEmpty && recent.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "tv").font(P.font(64)).foregroundStyle(P.faint)
                        Text(store.importing != nil ? "Chargement du catalogue… \(Int(store.progress * 100)) %" : "Aucune chaîne pour le moment.").font(P.font(30, .semibold))
                        Text(store.providers.isEmpty ? "Ajoute un fournisseur dans Réglages." : "Les chaînes de tes fournisseurs apparaîtront ici.").font(P.font(23)).foregroundStyle(P.dim)
                    }.frame(maxWidth: .infinity, minHeight: 500)
                }
            }
            .padding(.top, 16).padding(.bottom, 80)
        }
        // la zone défile dans ses limites : rien ne passe sur la barre du haut ni sur la colonne d'icônes
        .clipped()
        .navigationDestination(item: $openCat) { c in
            CategoryChannelsView(title: c.name, loader: { await LiveStore.channels(pid: c.pid, cid: c.cid) }, play: play, guide: guide)
        }
        .navigationDestination(isPresented: $openFav) {
            CategoryChannelsView(title: "Favoris", loader: { await LiveStore.channels(ids: LivePrefs.shared.favorites) }, play: play, guide: guide)
        }
        .task(id: "\(store.catalogVersion)|\(prefs.recent.first ?? "")|\(prefs.favorites.count)") { await load() }
    }

    private func load() async {
        let pids = store.active.map(\.id)
        let active = Set(pids)
        async let c = LiveStore.categories(providers: pids)
        async let r = LiveStore.channels(ids: prefs.recent)
        async let f = LiveStore.channels(ids: prefs.favorites)
        async let s = LiveStore.startingSoon(providers: pids)
        let (c1, r1, f1, s1) = await (c, r, f, s)
        cats = c1; recent = r1.filter { active.contains($0.pid) }; favs = f1.filter { active.contains($0.pid) }; soon = s1
        if let h = head { let nn = await LiveStore.nowNext(h); headNow = nn.0; headNext = nn.1 }
        loaded = true
    }

    private func rowTitle(_ t: String, _ sub: String) -> some View { SectionTitle(title: t, sub: sub).padding(.leading, 8) }

    private func favButton(_ ch: Channel) -> some View {
        Button(prefs.favorites.contains(ch.id) ? "Retirer des favoris" : "Ajouter aux favoris") { prefs.toggleFavorite(ch.id) }
    }

    /// En-tête (simulateur) : la dernière chaîne regardée, son programme en cours et sa progression.
    private func header(_ ch: Channel) -> some View {
        Button { playHead(ch) } label: { headerLabel(ch) }
            .buttonStyle(TextBlockStyle())
            .focusSection()
    }

    private func playHead(_ ch: Channel) {
        if let i = recent.firstIndex(of: ch) { play(recent, i) } else { play([ch], 0) }
    }

    private func headerLine(_ p: Program) -> String {
        let since = max(1, Int(Date().timeIntervalSince(p.startDate) / 60))
        let left = max(1, Int(p.stopDate.timeIntervalSinceNow / 60))
        var s = Fmt.hm(p.startDate) + " – " + Fmt.hm(p.stopDate)
        s += " · depuis " + runtimeText(since) + " · reste " + runtimeText(left)
        if let n = headNext { s += " · ensuite " + n.title }
        return s
    }

    private func headerLabel(_ ch: Channel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if headNow != nil { LiveBadge() } else { LiveBadge(text: "DERNIÈRE CHAÎNE") }
                Text(ch.name.uppercased()).font(P.font(20, .bold)).tracking(1.5).opacity(0.75)
            }
            Text(headNow?.title ?? ch.name).font(P.font(54, .bold)).lineLimit(1)
            if let p = headNow {
                Text(headerLine(p)).font(P.font(22)).opacity(0.75).lineLimit(1)
                ProgressLine(value: p.progress()).frame(width: 620, height: 6)
            } else {
                Text("Programme non communiqué · OK pour regarder").font(P.font(22)).opacity(0.75)
            }
        }
        .padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Barre de progression rouge (programme en direct).
struct ProgressLine: View {
    let value: Double
    var color: Color = P.live
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.22))
                Capsule().fill(color).frame(width: g.size.width * max(0, min(1, value)))
            }
        }
    }
}

/// Carte « univers » : une catégorie, son programme du moment sur la première chaîne, le nombre de chaînes.
struct UniverseCardLoader: View {
    let cat: LiveCategory
    let action: () -> Void
    @State private var chans: [Channel] = []
    var body: some View {
        UniverseCard(name: cat.name, tag: "", channels: chans, count: cat.count, action: action)
            .task(id: cat.id) { chans = await LiveStore.firstChannels(pid: cat.pid, cid: cat.cid, limit: 4) }
    }
}

struct UniverseCard: View {
    let name: String
    let tag: String
    let channels: [Channel]
    var count: Int? = nil
    let action: () -> Void
    @State private var now: Program?
    private var countText: String { let n = count ?? channels.count; return "\(n) chaîne" + (n > 1 ? "s" : "") }
    var body: some View {
        let first = channels.first
        let hue = P.hue(name)
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(hue: hue, saturation: 0.5, brightness: 0.42), Color(hue: hue, saturation: 0.5, brightness: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let first { Logo(url: first.icon, name: first.name, plain: true).frame(width: 150, height: 90).opacity(0.35).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 18) }
                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if let first { Text(first.name).font(P.font(17, .heavy)).lineLimit(1).padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8)) }
                            Spacer(minLength: 6)
                            Text((tag.isEmpty ? name : tag).uppercased()).font(P.font(15, .heavy)).lineLimit(1)
                                .padding(.horizontal, 9).padding(.vertical, 4).background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 7)).foregroundStyle(.black)
                        }
                        Spacer(minLength: 0)
                        Text(now?.title ?? first?.name ?? name).font(P.font(25, .bold)).lineLimit(1)
                        if let first { Text(first.name).font(P.font(17)).opacity(0.7).lineLimit(1) }
                        if let now {
                            GeometryReader { g in
                                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.25)); Capsule().fill(P.live).frame(width: g.size.width * now.progress()) }
                            }.frame(height: 4)
                        }
                    }.foregroundStyle(.white).padding(16)
                }
                .frame(width: 360, height: 202)
            }
            .buttonStyle(TileStyle(radius: 20, zoom: 1.06))
            HStack {
                Text(name).font(P.font(20, .bold)).lineLimit(1)
                Spacer()
                Text(countText).font(P.font(17)).foregroundStyle(P.dim)
            }.frame(width: 360)
            HStack(spacing: 6) {
                ForEach(channels.prefix(3)) { c in
                    Text(String(c.name.prefix(5)).uppercased()).font(P.font(13, .heavy)).lineLimit(1)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(Color(hue: P.hue(c.name), saturation: 0.6, brightness: 0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .task(id: first?.id ?? name) { if let first { now = await LiveStore.nowNext(first).0 } }
    }
}

/// « Commence bientôt » : chaîne, heure de début, titre, « dans 11 min ».
struct SoonCard: View {
    let a: LiveStore.Airing
    let action: () -> Void
    var body: some View {
        let hue = P.hue(a.ch.name)
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.4), Color(hue: hue, saturation: 0.5, brightness: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(a.ch.name).font(P.font(17, .heavy)).lineLimit(1).padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        Spacer(minLength: 6)
                        Text(Fmt.hm(a.p.startDate)).font(P.font(19, .heavy)).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(red: 0.04, green: 0.52, blue: 1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer(minLength: 0)
                    Text(a.p.title).font(P.font(25, .bold)).lineLimit(1)
                    Text(a.ch.name + " · dans " + runtimeText(max(1, Int(a.p.startDate.timeIntervalSinceNow / 60)))).font(P.font(17)).opacity(0.75).lineLimit(1)
                }.foregroundStyle(.white).padding(16)
            }
            .frame(width: 360, height: 202)
        }
        .buttonStyle(TileStyle(radius: 20, zoom: 1.06))
    }
}

// MARK: - Listes de chaînes (une catégorie, les favoris, les récentes, la recherche)

struct CategoryChannelsView: View {
    let title: String
    let loader: () async -> [Channel]
    let play: ([Channel], Int) -> Void
    let guide: ([Channel], String) -> Void
    @State private var channels: [Channel] = []
    @State private var loaded = false
    var body: some View {
        ZStack {
            PrismeBackground()
            ChannelGrid(title: title, channels: channels, loaded: loaded, empty: "Aucune chaîne ici.", play: play, guide: guide)
                .padding(.horizontal, 100).padding(.top, 60)
        }
        .ignoresSafeArea()
        .task { channels = await loader(); loaded = true }
    }
}

struct ChannelListView: View {
    enum Mode { case fav, recent }
    let mode: Mode
    let play: ([Channel], Int) -> Void
    let guide: ([Channel], String) -> Void
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var channels: [Channel] = []
    @State private var loaded = false
    var body: some View {
        ChannelGrid(title: mode == .fav ? "Favoris" : "Récentes", channels: channels, loaded: loaded,
                    empty: mode == .fav ? "Aucune chaîne en favori pour l'instant. Maintiens le clic sur une chaîne pour l'ajouter." : "Les chaînes que tu regardes apparaîtront ici.",
                    play: play, guide: guide)
            .task(id: mode == .fav ? prefs.favorites.joined() : prefs.recent.joined()) {
                let active = Set(store.active.map(\.id))
                channels = await LiveStore.channels(ids: mode == .fav ? prefs.favorites : prefs.recent).filter { active.contains($0.pid) }
                loaded = true
            }
    }
}

struct ChannelSearchView: View {
    let play: ([Channel], Int) -> Void
    @EnvironmentObject var store: ProviderStore
    @State private var q = ""
    @State private var channels: [Channel] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Nom de la chaîne…", text: $q).font(P.font(30)).frame(maxWidth: 900).autocorrectionDisabled()
                .frame(maxWidth: .infinity, alignment: .leading).focusSection()
            ChannelGrid(title: q.count >= 2 ? "Chaînes" : "Rechercher une chaîne", channels: channels, loaded: q.count >= 2,
                        empty: "Aucune chaîne ne correspond à « \(q) ».", play: play, guide: nil)
        }
        .task(id: q) {
            let t = q.trimmingCharacters(in: .whitespaces)
            guard t.count >= 2 else { channels = []; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let r = await LiveStore.search(t, providers: store.active.map(\.id))
            if !Task.isCancelled { channels = r }
        }
    }
}

/// Toutes les catégories : la liste à gauche, les chaînes à droite.
struct AllCategoriesView: View {
    let play: ([Channel], Int) -> Void
    let guide: ([Channel], String) -> Void
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var cats: [LiveCategory] = []
    @State private var selection: String = ""
    @State private var channels: [Channel] = []
    @State private var loaded = false

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    let multi = Set(cats.map(\.pid)).count > 1
                    ForEach(cats) { c in
                        SideButton(title: c.name, subtitle: multi ? store.provider(c.pid)?.name : nil, count: c.count, icon: nil, selected: selection == c.id) { selection = c.id }
                    }
                }.padding(14)
            }
            .clipped()
            .frame(width: 420).glass(30).padding(.bottom, 50)
            .focusSection()
            ChannelGrid(title: cats.first { $0.id == selection }?.name ?? "Catégories", channels: channels, loaded: loaded, empty: "Aucune chaîne dans cette catégorie.",
                        play: play, guide: guide, columns: 3)
        }
        .task(id: store.catalogVersion) {
            cats = await LiveStore.categories(providers: store.active.map(\.id))
            if let last = prefs.lastCategory, cats.contains(where: { $0.id == last }) { selection = last } else { selection = cats.first?.id ?? "" }
        }
        .task(id: selection) {
            guard !selection.isEmpty else { return }
            prefs.lastCategory = selection
            let parts = selection.split(separator: ":", maxSplits: 1).map(String.init)
            channels = parts.count == 2 ? await LiveStore.channels(pid: parts[0], cid: parts[1]) : []
            loaded = true
        }
    }
}

/// Grille de chaînes en cartes, avec en-tête (titre, nombre, bouton Guide).
struct ChannelGrid: View {
    let title: String
    let channels: [Channel]
    let loaded: Bool
    let empty: String
    let play: ([Channel], Int) -> Void
    let guide: (([Channel], String) -> Void)?
    var columns = 4
    @ObservedObject var prefs = LivePrefs.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    if loaded { Text("\(channels.count) CHAÎNE\(channels.count > 1 ? "S" : "")").font(P.font(19, .bold)).tracking(1.5).foregroundStyle(P.dim) }
                    Text(title).font(P.font(48, .bold)).lineLimit(1)
                }
                Spacer()
                if let guide, !channels.isEmpty {
                    Button { guide(channels, title) } label: { Label("Guide", systemImage: "tablecells").font(P.font(24, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 18, minH: 66))
                }
            }
            .frame(maxWidth: .infinity)
            .focusSection()
            if !loaded { ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 300) }
            else if channels.isEmpty { Text(empty).font(P.font(26)).foregroundStyle(P.dim).padding(.top, 60).frame(maxWidth: .infinity) }
            else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(360), spacing: 30), count: columns), alignment: .leading, spacing: 36) {
                        ForEach(Array(channels.enumerated()), id: \.element.id) { i, ch in
                            ChannelCard(ch: ch, fav: prefs.favorites.contains(ch.id)) { play(channels, i) }
                                .contextMenu {
                                    Button(prefs.favorites.contains(ch.id) ? "Retirer des favoris" : "Ajouter aux favoris") { prefs.toggleFavorite(ch.id) }
                                }
                        }
                    }.padding(.vertical, 24).padding(.horizontal, 18).padding(.bottom, 60)
                }
                .clipped()
            }
        }
    }
}

/// Bouton de la colonne des catégories : blanc quand il est sélectionné, voilé quand c'est la catégorie affichée.
struct SideStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View {
        SideBody(c: c, selected: selected)
    }
    private struct SideBody: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : (selected ? Color.white : Color.white.opacity(0.75)))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(f ? Color.white : (selected ? Color.white.opacity(0.16) : .clear)))
                .scaleEffect(f ? 1.04 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 14, y: 8)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

struct SideButton: View {
    let title: String
    var subtitle: String? = nil
    let count: Int
    let icon: String?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon { Image(systemName: icon).frame(width: 30) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).lineLimit(1)
                    if let subtitle { Text(subtitle).font(P.font(17)).opacity(0.6) }
                }
                Spacer()
                Text("\(count)").font(P.font(20, .semibold)).opacity(0.55)
            }
            .font(P.font(25, selected ? .bold : .medium))
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .buttonStyle(SideStyle(selected: selected))
    }
}

/// Une chaîne en carte (simulateur) : nom, DIRECT, programme en cours, temps restant.
struct ChannelCard: View {
    let ch: Channel
    let fav: Bool
    let action: () -> Void
    @State private var now: Program?
    @State private var next: Program?

    var body: some View {
        let hue = P.hue(ch.name)
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.42), Color(hue: hue, saturation: 0.5, brightness: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Logo(url: ch.icon, name: ch.name, plain: true).frame(width: 160, height: 96).opacity(0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 20).padding(.bottom, 40)
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(ch.num > 0 ? "\(ch.num)  \(ch.name)" : ch.name).font(P.font(17, .heavy)).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        Spacer(minLength: 0)
                        if fav { Image(systemName: "star.fill").font(P.font(18)).foregroundStyle(P.star) }
                        if now != nil { LiveBadge(text: "DIRECT") }
                    }
                    Spacer(minLength: 0)
                    Text(now?.title ?? ch.name).font(P.font(26, .bold)).lineLimit(1)
                    Text(sub).font(P.font(17)).opacity(0.75).lineLimit(1)
                    if let now {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule().fill(P.live).frame(width: g.size.width * now.progress())
                            }
                        }.frame(height: 5).padding(.top, 4)
                    }
                }.foregroundStyle(.white).padding(16)
            }
            .frame(width: 360, height: 202)
        }
        .buttonStyle(TileStyle(radius: 20, zoom: 1.07))
        .task(id: ch.id) { let r = await LiveStore.nowNext(ch); now = r.0; next = r.1 }
    }

    private var sub: String {
        guard let now else { return "Programme non communiqué" }
        let left = max(0, Int(now.stopDate.timeIntervalSinceNow / 60))
        var s = ch.name + " · reste " + runtimeText(max(1, left))
        if let next { s += " · ensuite " + next.title }
        return s
    }
}

struct Logo: View {
    let url: String
    let name: String
    var plain = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(plain ? 0 : 0.08))
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { img in img.resizable().scaledToFit().padding(8) } placeholder: { initials }
            } else { initials }
        }
    }
    private var initials: some View {
        Text(String(name.prefix(2)).uppercased()).font(.system(size: 26, weight: .heavy)).foregroundStyle(.secondary)
    }
}

enum Fmt {
    static let hmF: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "HH:mm"; return f }()
    static func hm(_ d: Date) -> String { hmF.string(from: d) }
}

// MARK: - Guide des programmes (grille : chaînes × heures)

struct GuideView: View {
    let channels: [Channel]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var start = GuideView.roundedNow()
    @State private var playing: LiveHomeView.PlayRequest?
    static let hours: Double = 3
    static let pxPerMin: CGFloat = 8   // 3 h = 1440 px : la grille tient dans l'écran (avant, la fin dépassait à droite)

    static func roundedNow() -> Date {
        let t = Date().timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(t / 1800) * 1800)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GUIDE DES PROGRAMMES").font(P.font(19, .bold)).tracking(2).foregroundStyle(P.faint)
                    Text(title).font(P.font(46, .bold))
                }
                Spacer()
                Button { start = start.addingTimeInterval(-3600) } label: { Image(systemName: "chevron.left").font(P.font(24, .bold)) }.buttonStyle(GlassStyle(radius: 16, minH: 64))
                Text(Fmt.hm(start) + " – " + Fmt.hm(start.addingTimeInterval(GuideView.hours * 3600))).font(P.font(28, .semibold)).monospacedDigit().frame(width: 260)
                Button { start = start.addingTimeInterval(3600) } label: { Image(systemName: "chevron.right").font(P.font(24, .bold)) }.buttonStyle(GlassStyle(radius: 16, minH: 64))
                Button { start = GuideView.roundedNow() } label: { Text("Maintenant").font(P.font(24, .semibold)) }.buttonStyle(GlassStyle(radius: 16, minH: 64))
            }
            .frame(maxWidth: .infinity)
            .focusSection()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { i, ch in
                        GuideRow(ch: ch, start: start) { playing = .init(list: channels, index: i) }
                    }
                }.padding(.vertical, 10)
            }
        }
        .padding(60)
        .background(PrismeBackground())
        .onExitCommand { dismiss() }
        .fullScreenCover(item: $playing) { r in LivePlayerView(channels: r.list, start: r.index) }
    }
}

struct GuideRow: View {
    let ch: Channel
    let start: Date
    let play: () -> Void
    @State private var progs: [Program] = []

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                Logo(url: ch.icon, name: ch.name).frame(width: 90, height: 54)
                Text(ch.name).font(P.font(22, .semibold)).lineLimit(2)
            }.frame(width: 300, alignment: .leading)
            HStack(spacing: 6) {
                if progs.isEmpty {
                    Button(action: play) { Text("Programme non communiqué").font(P.font(20)).opacity(0.6).padding(14).frame(width: CGFloat(GuideView.hours * 60) * GuideView.pxPerMin - 6, height: 80, alignment: .leading) }
                        .buttonStyle(RowStyle())
                }
                ForEach(progs) { p in
                    let a = max(p.start, Int(start.timeIntervalSince1970)), z = min(p.stop, Int(start.timeIntervalSince1970 + GuideView.hours * 3600))
                    let w = max(40, CGFloat(z - a) / 60 * GuideView.pxPerMin - 6)
                    Button(action: play) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if p.start <= Int(Date().timeIntervalSince1970) && p.stop > Int(Date().timeIntervalSince1970) { Circle().fill(P.live).frame(width: 10, height: 10) }
                                Text(p.title).font(P.font(21, .semibold)).lineLimit(1)
                            }
                            Text(Fmt.hm(p.startDate) + " – " + Fmt.hm(p.stopDate)).font(P.font(17)).opacity(0.6)
                        }.padding(.horizontal, 12).frame(width: w, height: 80, alignment: .leading)
                    }
                    .buttonStyle(RowStyle())
                }
            }
            .frame(width: CGFloat(GuideView.hours * 60) * GuideView.pxPerMin, alignment: .leading)
            .clipped()
        }
        .frame(height: 86)
        .task(id: "\(ch.id)|\(start.timeIntervalSince1970)") {
            progs = await LiveStore.programs(ch, from: start, hours: GuideView.hours)
        }
    }
}
