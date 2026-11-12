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

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar.frame(width: 420)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(title).font(.system(size: 44, weight: .bold))
                    Spacer()
                    Button { showGuide = true } label: { Label("Guide des programmes", systemImage: "calendar") }
                        .disabled(channels.isEmpty)
                }
                if loading { ProgressView().frame(maxWidth: .infinity, minHeight: 300) }
                else if channels.isEmpty { emptyState }
                else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { i, ch in
                                ChannelRow(ch: ch, fav: prefs.favorites.contains(ch.id)) { playing = PlayRequest(list: channels, index: i) }
                                    .contextMenu {
                                        Button(prefs.favorites.contains(ch.id) ? "Retirer des favoris" : "Ajouter aux favoris") { prefs.toggleFavorite(ch.id) }
                                    }
                            }
                        }.padding(.vertical, 20).padding(.horizontal, 10)
                    }
                }
            }.padding(.leading, 40)
        }
        .padding(.horizontal, 60)
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
            LazyVStack(alignment: .leading, spacing: 8) {
                SideButton(title: "Favoris", count: prefs.favorites.count, icon: "heart.fill", selected: selection == "fav") { selection = "fav" }
                SideButton(title: "Récentes", count: prefs.recent.count, icon: "clock", selected: selection == "recent") { selection = "recent" }
                let multi = Set(cats.map(\.pid)).count > 1
                ForEach(cats) { c in
                    SideButton(title: c.name, subtitle: multi ? store.provider(c.pid)?.name : nil, count: c.count, icon: nil, selected: selection == c.id) { selection = c.id }
                }
            }.padding(.vertical, 20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if store.providers.isEmpty {
                Text("Ajoute un fournisseur dans Réglages pour voir tes chaînes.").font(.title3)
            } else if store.importing != nil {
                Text("Chargement du catalogue… \(Int(store.progress * 100)) %").font(.title3)
                Text(store.status).foregroundStyle(.secondary)
            } else if selection == "fav" {
                Text("Aucune chaîne en favori pour l'instant.").font(.title3)
                Text("Maintiens le clic sur une chaîne pour l'ajouter.").foregroundStyle(.secondary)
            } else if selection == "recent" {
                Text("Les chaînes que tu regardes apparaîtront ici.").font(.title3)
            } else {
                Text("Aucune chaîne dans cette catégorie.").font(.title3)
            }
        }.frame(maxWidth: .infinity, minHeight: 400)
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
                    if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Text("\(count)").font(.callout).foregroundStyle(.secondary)
            }
            .font(.system(size: 26, weight: selected ? .bold : .medium))
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Color.white.opacity(0.14) : .clear))
    }
}

/// Une chaîne : logo, nom, programme en cours avec sa progression, programme suivant.
struct ChannelRow: View {
    let ch: Channel
    let fav: Bool
    let action: () -> Void
    @State private var now: Program?
    @State private var next: Program?
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                Logo(url: ch.icon, name: ch.name).frame(width: 120, height: 72)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        if ch.num > 0 { Text("\(ch.num)").foregroundStyle(.secondary) }
                        Text(ch.name).fontWeight(.semibold).lineLimit(1)
                        if fav { Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink) }
                    }.font(.system(size: 24))
                    Text(now?.title ?? "Programme non communiqué").font(.system(size: 30, weight: .bold)).lineLimit(1)
                    if let now {
                        ProgressView(value: now.progress()).tint(.white).frame(maxWidth: 520)
                    }
                    if let next { Text("Ensuite \(Fmt.hm(next.startDate)) · \(next.title)").font(.system(size: 22)).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.card)
        .task(id: ch.id) { let r = await LiveStore.nowNext(ch); now = r.0; next = r.1 }
    }
}

struct Logo: View {
    let url: String
    let name: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
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
                Text("Guide · \(title)").font(.system(size: 40, weight: .bold))
                Spacer()
                Button { start = start.addingTimeInterval(-3600) } label: { Image(systemName: "chevron.left") }
                Text(Fmt.hm(start) + " – " + Fmt.hm(start.addingTimeInterval(GuideView.hours * 3600))).font(.title3).frame(width: 260)
                Button { start = start.addingTimeInterval(3600) } label: { Image(systemName: "chevron.right") }
                Button("Maintenant") { start = GuideView.roundedNow() }
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
        .background(Color.black.ignoresSafeArea())
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
                Text(ch.name).font(.system(size: 22, weight: .semibold)).lineLimit(2)
            }.frame(width: 300, alignment: .leading)
            HStack(spacing: 6) {
                if progs.isEmpty {
                    Button(action: play) { Text("Programme non communiqué").font(.system(size: 20)).foregroundStyle(.secondary).padding(14).frame(width: CGFloat(GuideView.hours * 60) * GuideView.pxPerMin - 6, alignment: .leading) }
                        .buttonStyle(.card)
                }
                ForEach(progs) { p in
                    let a = max(p.start, Int(start.timeIntervalSince1970)), z = min(p.stop, Int(start.timeIntervalSince1970 + GuideView.hours * 3600))
                    let w = max(60, CGFloat(z - a) / 60 * GuideView.pxPerMin - 6)
                    Button(action: play) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.title).font(.system(size: 21, weight: .semibold)).lineLimit(1)
                            Text(Fmt.hm(p.startDate) + " – " + Fmt.hm(p.stopDate)).font(.system(size: 17)).foregroundStyle(.secondary)
                        }.padding(.horizontal, 12).padding(.vertical, 10).frame(width: w, alignment: .leading)
                    }
                    .buttonStyle(.card)
                }
            }
        }
        .frame(height: 86)
        .task(id: "\(ch.id)|\(start.timeIntervalSince1970)") {
            progs = await LiveStore.programs(ch, from: start, hours: GuideView.hours)
        }
    }
}
