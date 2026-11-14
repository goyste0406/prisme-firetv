import SwiftUI

// MARK: - TV en direct (structure du simulateur) : colonne d'icônes à gauche, en-tête sur la dernière chaîne,
// « Pour toi, maintenant », « Explorer par univers », « Commence bientôt ».

struct LiveHomeView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var section: String = Debug.liveSection ?? "home"
    @State private var playing: PlayRequest?
    @State private var guide: GuideRequest?
    @State private var index: [LiveIndex.Entry] = []
    @State private var replay: VodRequest?

    struct PlayRequest: Identifiable { let id = UUID(); let list: [Channel]; let index: Int }
    struct GuideRequest: Identifiable { let id = UUID(); let list: [Channel]; let title: String }

    private var rail: [(String, String, String)] {
        var r: [(String, String, String)] = [("home", "house.fill", "Accueil"), ("guide", "tablecells", "Guide TV"), ("search", "magnifyingglass", "Rechercher"), ("replay", "clock.arrow.circlepath", "Replay")]
        for u in Univers.allCases where index.contains(where: { $0.univers == u }) { r.append(("u:" + u.rawValue, u.icon, u.label)) }
        r.append(("fav", "star.fill", "Favoris"))
        r.append(("all", "square.grid.2x2", "Catégories du fournisseur"))
        return r
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(claimFocus: true)
            HStack(alignment: .top, spacing: 34) {
                railView
                content
                    .id(section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
            }
            .padding(.leading, 60).padding(.trailing, 40)
        }
        .ignoresSafeArea(edges: .top)
        // Retour depuis une catégorie (Info, Sport…) ou une autre rubrique de la colonne : revenir à l'accueil
        // de la TV en direct, au lieu de quitter prisme (seulement depuis l'accueil, Retour garde son effet habituel)
        .onExitCommand(perform: section == "home" ? nil : { section = "home" })
        .fullScreenCover(item: $playing) { r in LivePlayerView(channels: r.list, start: r.index) }
        .fullScreenCover(item: $guide) { g in GuideView(channels: g.list, title: g.title) }
        .fullScreenCover(item: $replay) { r in VodPlayerView(request: r) }
        .task(id: store.catalogVersion) { index = await LiveIndex.all(pids: store.active.map(\.id), version: store.catalogVersion) }
    }

    @ViewBuilder private var content: some View {
        if section.hasPrefix("u:"), let u = Univers(rawValue: String(section.dropFirst(2))) {
            let list = index.filter { $0.univers == u }.map(\.ch)
            ChannelGrid(title: u.label, channels: list, loaded: true, empty: "Aucune chaîne dans cet univers.", play: play, guide: openGuide, columns: 5)
        } else {
            switch section {
            case "search": ChannelSearchView(play: play)
            case "replay": ReplayView(index: index, play: { replay = $0 })
            case "fav": ChannelListView(mode: .fav, play: play, guide: openGuide)
            case "recent": ChannelListView(mode: .recent, play: play, guide: openGuide)
            case "all": AllCategoriesView(play: play, guide: openGuide)
            default: LiveFrontView(index: index, play: play, guide: openGuide, openSection: { section = $0 })
            }
        }
    }

    private func play(_ list: [Channel], _ i: Int) { playing = PlayRequest(list: list, index: i) }
    private func openGuide(_ list: [Channel], _ title: String) { guide = GuideRequest(list: list, title: title) }

    /// Colonne d'icônes à gauche (simulateur) : accueil, guide, recherche, un univers par icône, favoris, catégories.
    private var railView: some View {
        let items = rail
        return ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<items.count, id: \.self) { i in
                    let r = items[i]
                    Button {
                        if r.0 == "guide" { Task { await guideFromRail() } } else { section = r.0 }
                    } label: { Image(systemName: r.1).font(P.font(26, .semibold)).frame(width: 64, height: 58) }
                    .buttonStyle(RailStyle(selected: section == r.0))
                    .accessibilityLabel(r.2)
                }
            }
            .padding(.vertical, 16).padding(.horizontal, 10)
        }
        .frame(width: 104).frame(maxHeight: .infinity, alignment: .top)
        // les icônes du bas (Musique, Autres, Favoris…) défilent DANS la colonne au lieu de déborder dessous
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .glass(30)
        .padding(.bottom, 50)
        .focusSection()
    }

    /// Guide depuis la colonne : tes favoris, sinon tes chaînes récentes, sinon toutes les chaînes.
    private func guideFromRail() async {
        if !prefs.favorites.isEmpty { openGuide(ChannelTools.dedupe(await LiveStore.channels(ids: prefs.favorites)), "Favoris"); return }
        if !prefs.recent.isEmpty { openGuide(ChannelTools.dedupe(await LiveStore.channels(ids: prefs.recent)), "Récentes"); return }
        openGuide(Array(index.prefix(200).map(\.ch)), "Toutes les chaînes")
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

// MARK: - Accueil de la TV en direct

struct LiveFrontView: View {
    let index: [LiveIndex.Entry]
    let play: ([Channel], Int) -> Void
    let guide: ([Channel], String) -> Void
    let openSection: (String) -> Void
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var recent: [Channel] = []
    @State private var favs: [Channel] = []
    @State private var soon: [LiveStore.Airing] = []
    @State private var headNow: Program?
    @State private var headNext: Program?
    @State private var openFav = false
    @State private var openRecent = false
    @State private var loaded = false
    @State private var nowGenres: [(Univers, [Channel])] = []
    @State private var nowOpen: Univers?
    @State private var nowShown = false

    private var head: Channel? { recent.first ?? favs.first }
    private func entry(_ c: Channel) -> LiveIndex.Entry? { index.first { ChannelTools.key($0.ch) == ChannelTools.key(c) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                if let h = head { header(h) }
                else if let a = soon.first { soonHeader(a) }
                if !recent.isEmpty {
                    rowTitle("Pour toi, maintenant", "tes chaînes récentes, en ce moment")
                    row {
                        ForEach(Array(recent.prefix(10).enumerated()), id: \.element.id) { i, ch in
                            VStack(alignment: .leading, spacing: 10) {
                                ChannelCard(ch: ch, fav: prefs.favorites.contains(ch.id)) { play(recent, i) }
                                    .contextMenu { favButton(ch) }
                                Text("Tu l'as regardée récemment").font(P.font(17)).foregroundStyle(P.faint)
                            }
                        }
                    }
                }
                if !index.isEmpty {
                    rowTitle("Explorer par univers", "OK pour voir toutes les chaînes")
                    row {
                        if !recent.isEmpty { UniverseCard(label: "Reprendre", icon: "arrow.counterclockwise", channels: recent, count: recent.count) { openRecent = true } }
                        if !favs.isEmpty { UniverseCard(label: "Favoris", icon: "star.fill", channels: favs, count: favs.count) { openFav = true } }
                        ForEach(Univers.allCases) { u in
                            let L = index.filter { $0.univers == u }.map(\.ch)
                            if !L.isEmpty { UniverseCard(label: u.label, icon: u.icon, channels: L, count: L.count) { openSection("u:" + u.rawValue) } }
                        }
                    }
                }
                if !nowGenres.isEmpty {
                    // regroupement du simulateur : selon le programme diffusé maintenant (TF1 pendant un match → Sport),
                    // à part des catégories fixes ci-dessus
                    rowTitle("En ce moment à la télé", "selon le guide des programmes · OK pour voir les chaînes")
                    row {
                        ForEach(nowGenres, id: \.0) { g in
                            UniverseCard(label: g.0.label, icon: g.0.icon, channels: g.1, count: g.1.count) { nowOpen = g.0; nowShown = true }
                        }
                    }
                }
                if !soon.isEmpty {
                    rowTitle("Commence bientôt", "dans l'heure · OK pour regarder la chaîne")
                    row { ForEach(soon) { a in SoonCard(a: a) { play([a.ch], 0) } } }
                }
                if loaded && index.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "tv").font(P.font(64)).foregroundStyle(P.faint)
                        Text(store.importing != nil ? "Chargement du catalogue… \(Int(store.progress * 100)) %" : "Aucune chaîne pour le moment.").font(P.font(30, .semibold))
                        Text(store.providers.isEmpty ? "Ajoute un fournisseur dans Réglages." : "Les chaînes de tes fournisseurs apparaîtront ici.").font(P.font(23)).foregroundStyle(P.dim)
                    }.frame(maxWidth: .infinity, minHeight: 500)
                }
            }
            .padding(.top, 12).padding(.bottom, 80)
        }
        .clipped()
        .navigationDestination(isPresented: $openFav) {
            CategoryChannelsView(title: "Favoris", loader: { ChannelTools.dedupe(await LiveStore.channels(ids: LivePrefs.shared.favorites)) }, play: play, guide: guide)
        }
        .navigationDestination(isPresented: $nowShown) {
            let u = nowOpen ?? .divert
            CategoryChannelsView(title: u.label + " en ce moment", loader: { nowGenres.first { $0.0 == u }?.1 ?? [] }, play: play, guide: guide)
        }
        .navigationDestination(isPresented: $openRecent) {
            CategoryChannelsView(title: "Reprendre", loader: { ChannelTools.dedupe(await LiveStore.channels(ids: LivePrefs.shared.recent)) }, play: play, guide: guide)
        }
        .task(id: "\(store.catalogVersion)|\(prefs.recent.first ?? "")|\(prefs.favorites.count)") { await load() }
    }

    private func row<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 28) { c() }.padding(.vertical, 20).padding(.horizontal, 18)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    private func load() async {
        let pids = store.active.map(\.id)
        let active = Set(pids)
        async let r = LiveStore.channels(ids: prefs.recent)
        async let f = LiveStore.channels(ids: prefs.favorites)
        async let s = LiveStore.startingSoon(providers: pids)
        async let g = LiveStore.airingNowByGenre(providers: pids)
        let (r1, f1, s1, g1) = await (r, f, s, g)
        nowGenres = g1
        recent = ChannelTools.dedupe(r1.filter { active.contains($0.pid) })
        favs = ChannelTools.dedupe(f1.filter { active.contains($0.pid) })
        var seen = Set<String>()
        soon = s1.filter { seen.insert(ChannelTools.key($0.ch) + "|\($0.p.start)").inserted }
        if let h = head { let nn = await LiveStore.nowNext(h); headNow = nn.0; headNext = nn.1 }
        loaded = true
    }

    private func rowTitle(_ t: String, _ sub: String) -> some View { SectionTitle(title: t, sub: sub).padding(.leading, 18) }

    private func favButton(_ ch: Channel) -> some View {
        Button(prefs.favorites.contains(ch.id) ? "Retirer des favoris" : "Ajouter aux favoris") { prefs.toggleFavorite(ch.id) }
    }

    /// En-tête (simulateur) : la dernière chaîne regardée, son programme en cours et sa progression.
    private func header(_ ch: Channel) -> some View {
        Button { playHead(ch) } label: { headerLabel(ch) }
            .buttonStyle(TextBlockStyle())
            .focusSection()
    }

    private func soonHeader(_ a: LiveStore.Airing) -> some View {
        Button { play([a.ch], 0) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Text("À VENIR").font(P.font(18, .heavy)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color(red: 0.04, green: 0.52, blue: 1), in: RoundedRectangle(cornerRadius: 8))
                    Text(headKicker(a.ch)).font(P.font(20, .bold)).tracking(1.5).opacity(0.75)
                }
                Text(a.p.title).font(P.font(54, .bold)).lineLimit(1)
                Text(Fmt.hm(a.p.startDate) + " – " + Fmt.hm(a.p.stopDate) + " · dans " + runtimeText(max(1, Int(a.p.startDate.timeIntervalSinceNow / 60))) + sourcesText(a.ch))
                    .font(P.font(22)).opacity(0.75).lineLimit(1)
            }
            .padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TextBlockStyle())
        .focusSection()
    }

    private func playHead(_ ch: Channel) {
        if let i = recent.firstIndex(of: ch) { play(recent, i) } else { play([ch], 0) }
    }

    private func headKicker(_ ch: Channel) -> String {
        let e = entry(ch)
        return ((e?.name ?? ChannelTools.clean(ch.name)) + (e.map { " · " + $0.univers.label } ?? "")).uppercased()
    }

    private func sourcesText(_ ch: Channel) -> String {
        let n = entry(ch)?.sources ?? 1
        return " · \(n) source" + (n > 1 ? "s" : "")
    }

    private func headerLine(_ p: Program, _ ch: Channel) -> String {
        let since = max(1, Int(Date().timeIntervalSince(p.startDate) / 60))
        let left = max(1, Int(p.stopDate.timeIntervalSinceNow / 60))
        var s = Fmt.hm(p.startDate) + " – " + Fmt.hm(p.stopDate)
        s += " · depuis " + runtimeText(since) + " · reste " + runtimeText(left) + sourcesText(ch)
        if let n = headNext { s += " · ensuite " + n.title }
        return s
    }

    private func headerLabel(_ ch: Channel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if headNow != nil { LiveBadge() } else { LiveBadge(text: "DERNIÈRE CHAÎNE") }
                Text(headKicker(ch)).font(P.font(20, .bold)).tracking(1.5).opacity(0.75)
            }
            Text(headNow?.title ?? ChannelTools.clean(ch.name)).font(P.font(54, .bold)).lineLimit(1)
            if let p = headNow {
                Text(headerLine(p, ch)).font(P.font(22)).opacity(0.75).lineLimit(1)
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

/// Carte « univers » (simulateur) : la tuile de sa première chaîne en direct, puis le nom de l'univers,
/// le nombre de chaînes et leurs pastilles.
struct UniverseCard: View {
    let label: String
    let icon: String
    let channels: [Channel]
    let count: Int
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let first = channels.first {
                ChannelCard(ch: first, fav: false, action: action)
            }
            HStack(spacing: 8) {
                Image(systemName: icon).font(P.font(17, .semibold))
                // le nom de la catégorie reste entier (« Généraliste », « Divertissement ») ; le nombre se resserre
                Text(label).font(P.font(20, .bold)).lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                Text("\(count) chaîne" + (count > 1 ? "s" : "")).font(P.font(17)).foregroundStyle(P.dim).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: ChannelCard.size.width)
            HStack(spacing: 6) {
                ForEach(channels.prefix(3)) { c in ChannelChip(name: ChannelTools.clean(c.name), icon: c.icon, height: 28) }
                if count > 3 { Text("+\(count - 3)").font(P.font(15, .bold)).foregroundStyle(P.dim) }
            }
            .frame(width: ChannelCard.size.width, alignment: .leading)
        }
    }
}

/// « Commence bientôt » (simulateur) : pastille de la chaîne, heure de début en bleu, titre en filigrane ;
/// sous la carte : le titre et « chaîne · dans 11 min ».
struct SoonCard: View {
    let a: LiveStore.Airing
    let action: () -> Void
    var body: some View {
        let name = ChannelTools.clean(a.ch.name)
        let hue = P.hue(name)
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.4), Color(hue: hue, saturation: 0.5, brightness: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(a.p.title.uppercased()).font(P.font(26, .heavy)).foregroundStyle(.white.opacity(0.22)).lineLimit(2)
                        .padding(.horizontal, 16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    HStack {
                        ChannelChip(name: name, icon: a.ch.icon, height: 36)
                        Spacer(minLength: 6)
                        Text(Fmt.hm(a.p.startDate)).font(P.font(19, .heavy)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(red: 0.04, green: 0.52, blue: 1), in: RoundedRectangle(cornerRadius: 8))
                    }.padding(14)
                }
                .frame(width: ChannelCard.size.width, height: ChannelCard.size.height)
            }
            .buttonStyle(TileStyle(radius: 18, zoom: 1.06))
            Text(a.p.title).font(P.font(21, .bold)).lineLimit(1).frame(width: ChannelCard.size.width, alignment: .leading)
            Text(name + " · dans " + runtimeText(max(1, Int(a.p.startDate.timeIntervalSinceNow / 60)))).font(P.font(17)).foregroundStyle(P.dim).lineLimit(1)
        }
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
    /// sans doublon : une chaîne présente en FHD, HD et « secours » n'apparaît qu'une fois (la meilleure copie)
    var channels: [Channel] { ChannelTools.dedupe(raw) }
    let raw: [Channel]
    let loaded: Bool
    let empty: String
    let play: ([Channel], Int) -> Void
    let guide: (([Channel], String) -> Void)?
    var columns = 5
    @ObservedObject var prefs = LivePrefs.shared

    init(title: String, channels: [Channel], loaded: Bool, empty: String, play: @escaping ([Channel], Int) -> Void, guide: (([Channel], String) -> Void)?, columns: Int = 5) {
        self.title = title; self.raw = channels; self.loaded = loaded; self.empty = empty; self.play = play; self.guide = guide; self.columns = columns
    }

    var body: some View {
        let channels = self.channels
        return VStack(alignment: .leading, spacing: 10) {
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
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(ChannelCard.size.width), spacing: 28), count: columns), alignment: .leading, spacing: 36) {
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

/// Une chaîne en carte (simulateur) : logo de la chaîne en haut à gauche, DIRECT en haut à droite,
/// puis « vrai nom de la chaîne · reste 23 min » au-dessus du titre du programme, et la progression.
struct ChannelCard: View {
    static let size = CGSize(width: 300, height: 190)
    let ch: Channel
    let fav: Bool
    let action: () -> Void
    @State private var now: Program?
    @State private var next: Program?

    var body: some View {
        let name = ChannelTools.clean(ch.name)
        let hue = P.hue(name)
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.44), Color(hue: hue, saturation: 0.5, brightness: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text((now?.title ?? name).uppercased()).font(P.font(26, .heavy)).foregroundStyle(.white.opacity(0.16)).lineLimit(2)
                    .padding(.horizontal, 16).padding(.top, 54).frame(maxWidth: .infinity, alignment: .leading)
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ChannelChip(name: name, icon: ch.icon, height: 36)
                        Spacer(minLength: 4)
                        if fav { Image(systemName: "star.fill").font(P.font(17)).foregroundStyle(P.star) }
                        LiveBadge(text: "DIRECT")
                    }
                    Spacer(minLength: 0)
                    Text(sub(name)).font(P.font(17, .semibold)).opacity(0.8).lineLimit(1)
                    Text(now?.title ?? "Programme non communiqué").font(P.font(24, .bold)).lineLimit(1)
                    if let now { ProgressLine(value: now.progress()).frame(height: 5).padding(.top, 4) }
                }
                .foregroundStyle(.white).padding(14)
            }
            .frame(width: ChannelCard.size.width, height: ChannelCard.size.height)
        }
        .buttonStyle(TileStyle(radius: 18, zoom: 1.07))
        .task(id: ch.id) { let r = await LiveStore.nowNext(ch); now = r.0; next = r.1 }
    }

    private func sub(_ name: String) -> String {
        guard let now else { return name }
        return name + " · reste " + runtimeText(max(1, Int(now.stopDate.timeIntervalSinceNow / 60)))
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
    private static func fr(_ format: String) -> DateFormatter { let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = format; return f }
    private static let dayF = fr("EEEE"), dateF = fr("d MMMM yyyy"), dateTimeF = fr("d MMMM 'à' HH:mm")
    /// Jour de la semaine, toujours en français et en minuscules (« samedi »), quelle que soit la langue de l'Apple TV.
    static func day(_ d: Date) -> String { dayF.string(from: d).lowercased() }
    static func date(_ d: Date) -> String { dateF.string(from: d) }
    static func dateTime(_ d: Date) -> String { dateTimeF.string(from: d) }
}

// MARK: - Guide des programmes (grille : chaînes × heures)

struct GuideView: View {
    let channels: [Channel]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var start = GuideView.roundedNow()
    @State private var playing: LiveHomeView.PlayRequest?
    @State private var replay: VodRequest?
    @State private var msg: String?
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
                        GuideRow(ch: ch, start: start, play: { playing = .init(list: channels, index: i) }, past: { p in
                            // programme passé : replay s'il est dans l'archive de la chaîne, sinon on le dit
                            let a = LiveStore.Airing(ch: ch, p: p)
                            if let r = replayRequest(a) { replay = r } else { msg = ch.archive > 0 ? "Ce programme n'est plus dans l'archive de la chaîne." : "Cette chaîne ne propose pas le replay." }
                        })
                    }
                }.padding(.vertical, 10)
            }
        }
        .padding(60)
        .background(PrismeBackground())
        .onExitCommand { dismiss() }
        .fullScreenCover(item: $playing) { r in LivePlayerView(channels: r.list, start: r.index) }
        .fullScreenCover(item: $replay) { r in VodPlayerView(request: r) }
        .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) { Button("OK") {} }
    }
}

struct GuideRow: View {
    let ch: Channel
    let start: Date
    let play: () -> Void
    var past: ((Program) -> Void)? = nil
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
                    let isPast = p.stop <= Int(Date().timeIntervalSince1970)
                    Button { if isPast, let past { past(p) } else { play() } } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if p.start <= Int(Date().timeIntervalSince1970) && p.stop > Int(Date().timeIntervalSince1970) { Circle().fill(P.live).frame(width: 10, height: 10) }
                                if isPast && ch.archive > 0 { Image(systemName: "clock.arrow.circlepath").font(P.font(17, .bold)).foregroundStyle(Color(red: 0.8, green: 0.7, blue: 1)) }
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
