import SwiftUI

// MARK: - TV en direct : catégories à gauche, chaînes à droite (en ce moment + ensuite)

struct LiveHomeView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @State private var cats: [LiveCategory] = []
    @State private var selection: String = "fav"
    @State private var channels: [Channel] = []
    @State private var loading = false
    @State private var playing: PlayRequest?
    @State private var showGuide = false

    struct PlayRequest: Identifiable { let id = UUID(); let list: [Channel]; let index: Int }
    private let cols = Array(repeating: GridItem(.fixed(380), spacing: 34), count: 3)

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            sidebar.frame(width: 470).glass(34).focusSection()
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            LiveBadge()
                            Text("\(channels.count) CHAÎNE\(channels.count > 1 ? "S" : "")").font(P.font(20, .bold)).tracking(1.5).foregroundStyle(P.dim)
                        }
                        Text(title).font(P.font(52, .bold)).lineLimit(1)
                    }
                    Spacer()
                    Button { showGuide = true } label: { Label("Guide", systemImage: "calendar").font(P.font(25, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 18, minH: 70))
                        .disabled(channels.isEmpty)
                }
                if loading { ProgressView().frame(maxWidth: .infinity, minHeight: 300) }
                else if channels.isEmpty { emptyState }
                else {
                    ScrollView {
                        LazyVGrid(columns: cols, alignment: .leading, spacing: 40) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { i, ch in
                                ChannelCard(ch: ch, fav: prefs.favorites.contains(ch.id)) { playing = PlayRequest(list: channels, index: i) }
                                    .contextMenu {
                                        Button(prefs.favorites.contains(ch.id) ? "Retirer des favoris" : "Ajouter aux favoris") { prefs.toggleFavorite(ch.id) }
                                    }
                            }
                        }.padding(.vertical, 26).padding(.horizontal, 6)
                    }
                    .scrollClipDisabled()
                }
            }
        }
        .padding(.horizontal, 90).padding(.top, 170)
        .ignoresSafeArea(edges: .top)
        .task(id: store.catalogVersion) { await loadCats() }
        .onChange(of: selection) { _ in Task { await loadChannels() } }
        .fullScreenCover(item: $playing) { r in LivePlayerView(channels: r.list, start: r.index) }
        .fullScreenCover(isPresented: $showGuide) { GuideView(channels: channels, title: title) }
    }

    private var title: String {
        switch selection {
        case "fav": return "Favoris"
        case "recent": return "Récentes"
        default: return cats.first { $0.id == selection }?.name ?? "TV en direct"
        }
    }

    private var sidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                SideButton(title: "Favoris", count: prefs.favorites.count, icon: "star.fill", selected: selection == "fav") { selection = "fav" }
                SideButton(title: "Récentes", count: prefs.recent.count, icon: "clock.arrow.circlepath", selected: selection == "recent") { selection = "recent" }
                Text("CATÉGORIES").font(P.font(17, .bold)).tracking(2).foregroundStyle(P.faint).padding(.leading, 18).padding(.top, 14)
                let multi = Set(cats.map(\.pid)).count > 1
                ForEach(cats) { c in
                    SideButton(title: c.name, subtitle: multi ? store.provider(c.pid)?.name : nil, count: c.count, icon: nil, selected: selection == c.id) { selection = c.id }
                }
            }.padding(14)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv").font(P.font(64)).foregroundStyle(P.faint)
            if store.providers.isEmpty {
                Text("Ajoute un fournisseur dans Réglages pour voir tes chaînes.").font(P.font(30, .semibold))
            } else if store.importing != nil {
                Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(P.font(30, .semibold))
                Text(store.status).foregroundStyle(P.dim)
            } else if selection == "fav" {
                Text("Aucune chaîne en favori pour l'instant.").font(P.font(30, .semibold))
                Text("Maintiens le clic sur une chaîne pour l'ajouter.").foregroundStyle(P.dim)
            } else if selection == "recent" {
                Text("Les chaînes que tu regardes apparaîtront ici.").font(P.font(30, .semibold))
            } else {
                Text("Aucune chaîne dans cette catégorie.").font(P.font(30, .semibold))
            }
        }.font(P.font(24)).frame(maxWidth: .infinity, minHeight: 500)
    }

    private func loadCats() async {
        let list = await LiveStore.categories(providers: store.active.map(\.id))
        cats = list
        if let last = prefs.lastCategory, last == "recent" || list.contains(where: { $0.id == last }) { selection = last }
        else if prefs.favorites.isEmpty, let first = list.first { selection = first.id }
        await loadChannels()
    }

    private func loadChannels() async {
        prefs.lastCategory = selection
        loading = channels.isEmpty
        let sel = selection
        let list: [Channel]
        switch sel {
        case "fav": list = await LiveStore.channels(ids: prefs.favorites)
        case "recent": list = await LiveStore.channels(ids: prefs.recent)
        default:
            let parts = sel.split(separator: ":", maxSplits: 1).map(String.init)
            list = parts.count == 2 ? await LiveStore.channels(pid: parts[0], cid: parts[1]) : []
        }
        guard sel == selection else { return }
        let active = Set(store.active.map(\.id))
        channels = list.filter { active.contains($0.pid) }
        loading = false
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

/// Une chaîne en carte (comme « Explorer par univers » du simulateur) : nom, DIRECT, programme en cours, temps restant.
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
                Logo(url: ch.icon, name: ch.name, plain: true).frame(width: 170, height: 100).opacity(0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 20).padding(.bottom, 40)
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(ch.num > 0 ? "\(ch.num)  \(ch.name)" : ch.name).font(P.font(18, .heavy)).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        Spacer(minLength: 0)
                        if fav { Image(systemName: "star.fill").font(P.font(18)).foregroundStyle(P.star) }
                        if now != nil { LiveBadge(text: "DIRECT") }
                    }
                    Spacer(minLength: 0)
                    Text(now?.title ?? ch.name).font(P.font(27, .bold)).lineLimit(1)
                    Text(sub).font(P.font(18)).opacity(0.75).lineLimit(1)
                    if let now {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule().fill(P.live).frame(width: g.size.width * now.progress())
                            }
                        }.frame(height: 5).padding(.top, 4)
                    }
                }.foregroundStyle(.white).padding(18)
            }
            .frame(width: 380, height: 214)
        }
        .buttonStyle(TileStyle(radius: 20, zoom: 1.07))
        .task(id: ch.id) { let r = await LiveStore.nowNext(ch); now = r.0; next = r.1 }
    }

    private var sub: String {
        guard let now else { return "Programme non communiqué" }
        let left = max(0, Int(now.stopDate.timeIntervalSinceNow / 60))
        var s = "reste " + runtimeText(max(1, left))
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
    static let pxPerMin: CGFloat = 9   // 3 h = 1620 px

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
                    let w = max(60, CGFloat(z - a) / 60 * GuideView.pxPerMin - 6)
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
        }
        .frame(height: 86)
        .task(id: "\(ch.id)|\(start.timeIntervalSince1970)") {
            progs = await LiveStore.programs(ch, from: start, hours: GuideView.hours)
        }
    }
}
