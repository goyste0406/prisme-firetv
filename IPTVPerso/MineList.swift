import SwiftUI

// MARK: - Lot 2 : Ma liste et Ma semaine (simulateur « mine » : listHtml, weekHtml, mnduel, mnopt)
// Dimensions : celles du simulateur (écran logique 1280 × 720) × 1,5. Marge de la page : 56 → 84.
// Ma liste : envies (déduites des genres et de la durée), 3 propositions, Duel, « Tu l'avais oublié ? »,
// « Aussi pour cette envie », « Le reste de ta liste », « Plus disponible ». OK : lancer ; OK maintenu : options.
// Ma semaine : uniquement le journal réel du profil (aucune semaine d'exemple).

/// Une envie du simulateur (MOODS2).
struct MineMood: Identifiable, Equatable {
    let id: String, label: String
    static let all: [MineMood] = [.init(id: "rire", label: "😂 Envie de rire"), .init(id: "tension", label: "😱 Du suspense"),
                                  .init(id: "emo", label: "🥲 De l'émotion"), .init(id: "grand", label: "🎬 Grand spectacle"),
                                  .init(id: "deux", label: "👥 À deux"), .init(id: "court", label: "⏱ Moins d'une heure")]
}

/// Un titre de Ma liste (simulateur myList()).
struct MineEntry: Identifiable, Equatable {
    let item: MediaItem
    let moods: Set<String>
    let minutes: Int          // durée du film, ou d'un épisode ; 0 = inconnue
    let isNew: Bool           // série : nouvel épisode chez le fournisseur depuis ta dernière séance
    let info: MyListMeta.Info?
    let two: Bool             // aussi dans la liste d'un autre profil
    let prog: Double          // en cours (0 = pas commencé)
    let started: Bool
    var id: String { item.id }
    var title: String { item.displayTitle }
    var vote: Double { (item.fiche?.vote ?? 0) > 0 ? item.fiche!.vote : item.rating }
    static func == (a: MineEntry, b: MineEntry) -> Bool { a.id == b.id && a.prog == b.prog && a.isNew == b.isNew && a.info == b.info }
}

/// Titre retiré par le fournisseur (simulateur « Plus disponible ») : nom et affiche gardés à l'ajout.
struct MineGone: Identifiable, Equatable { let id: String; let title: String; let poster: String }

enum MineLogic {
    static func eveningNow() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let n = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return n < 300 ? n + 1440 : n
    }
    static func hm(_ m: Int) -> String { "\((m / 60) % 24) h \(String(format: "%02d", m % 60))" }
    static func dur(_ m: Int) -> String { m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min" }

    /// simulateur moodsOf : genres (TMDB, en français) et durée
    static func moods(genres g0: String, minutes: Int, series: Bool, two: Bool) -> Set<String> {
        let g = g0.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        var m = Set<String>()
        func has(_ l: [String]) -> Bool { l.contains { g.contains($0) } }
        if has(["comedie", "animation", "famil"]) { m.insert("rire") }
        if has(["thriller", "policier", "crime", "horreur", "action", "myst"]) { m.insert("tension") }
        if has(["drame", "romance"]) { m.insert("emo") }
        if has(["science", "aventure", "fantas", "guerre", "action"]) || minutes >= 130 { m.insert("grand") }
        if has(["romance", "comedie"]) || two { m.insert("deux") }
        if minutes > 0, (series && minutes <= 35) || (!series && minutes < 60) { m.insert("court") }
        return m
    }

    static func endOf(_ e: MineEntry) -> Int? { e.minutes > 0 ? eveningNow() + Int((Double(e.minutes) * (1 - e.prog)).rounded()) : nil }
    @MainActor static func late(_ e: MineEntry) -> Bool { (endOf(e) ?? 0) > ProfileStore.shared.bedMinutes }

    /// simulateur rank : d'abord ce qui finit avant le coucher, puis les nouveaux épisodes, puis la note
    @MainActor static func rank(_ l: [MineEntry]) -> [MineEntry] {
        l.sorted { a, b in
            let la = late(a), lb = late(b)
            if la != lb { return !la }
            if a.isNew != b.isNew { return a.isNew }
            return a.vote > b.vote
        }
    }

    /// simulateur why()
    static func why(_ e: MineEntry) -> String {
        if e.isNew { return "🔵 nouvel épisode" }
        if e.prog > 0 { return "↺ en cours · \(Int((e.prog * 100).rounded())) %" }
        if e.two { return "👥 aussi dans la liste d'un autre profil" }
        if let i = e.info, let at = i.at {
            let d = Int(Date().timeIntervalSince(at) / 86400)
            return "＋ ajouté " + (d < 1 ? "aujourd'hui" : d < 2 ? "hier" : "il y a \(d) j") + (i.from.isEmpty ? "" : " " + i.from)
        }
        return "＋ dans ta liste"
    }
}

// MARK: - Page

struct MineView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @ObservedObject var profiles = ProfileStore.shared
    @State private var sub = "list"
    @State private var mood = 0
    @State private var entries: [MineEntry] = []
    @State private var gone: [MineGone] = []
    @State private var loaded = false
    @State private var open: MineOpen?
    @State private var live: LiveLaunch?
    @State private var modal: MineModal?
    @State private var toast: String?
    @State private var week = MineWeekData()
    @State private var refresh = 0
    @FocusState private var focus: String?
    /// sélection à rendre à la page quand une fenêtre se ferme (simulateur « ret »)
    @State private var back: String?

    struct MineOpen: Identifiable, Hashable { let item: MediaItem; let play: Bool; var id: String { item.id + (play ? ":p" : "") } }

    var body: some View {
        ZStack {
            BarScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    TopBar(claimFocus: true).id(BarScrollView<EmptyView>.top)
                    HStack(spacing: 9) {
                        tabChip("list", "Ma liste")
                        tabChip("week", "Ma semaine")
                    }
                    .padding(.top, 6).padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading).focusSection()
                    if sub == "list" { listPage } else { weekPage }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 84)
            }
            .scrollClipDisabled()
            .disabled(modal != nil)
            if let m = modal { modalView(m) }
            if let t = toast {
                Text(t).font(P.font(27, .medium)).lineLimit(1).padding(.horizontal, 36).padding(.vertical, 21)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(red: 40 / 255, green: 40 / 255, blue: 48 / 255).opacity(0.75)))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1.5)))
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 60)
                    .accessibilityIdentifier("toast").transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.25), value: toast)
        .onChange(of: focus) { _, f in if let f, !f.hasPrefix("mno-"), !f.hasPrefix("mnd-") { back = f } }
        .onChange(of: modal == nil) { _, closed in
            if closed, let b = back { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = b } }
        }
        .navigationDestination(item: $open) { o in DetailView(item: o.item, autoPlay: o.play) }
        .fullScreenCover(item: $live) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .task(id: "\(watch.favorites.joined(separator: ","))|\(watch.entries.count)|\(store.catalogVersion)|\(profiles.version)|\(refresh)") { await load() }
    }

    // MARK: sous-onglets (simulateur .mn-tab : 15 → 22,5 ; le survol change de page)

    private func tabChip(_ k: String, _ t: String) -> some View {
        FocusTile(id: "mns-" + k, focus: $focus, label: "Sous-onglet " + t, tap: { sub = k }) { f in
            Text(t).font(P.font(22.5, .bold))
                .foregroundStyle(f ? Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255) : sub == k ? .white : .white.opacity(0.65))
                .padding(.vertical, 12).padding(.horizontal, 27)
                .background(Capsule().fill(f ? Color.white : sub == k ? Color.white.opacity(0.14) : .clear))
                .scaleEffect(f ? 1.06 : 1)
        }
        .onChange(of: focus) { _, n in if n == "mns-" + k, sub != k { sub = k } }
    }

    // MARK: Ma liste

    private var moodItems: [MineEntry] { entries.filter { $0.moods.contains(MineMood.all[mood].id) } }

    @ViewBuilder private var listPage: some View {
        if loaded && entries.isEmpty && gone.isEmpty {
            Text("Ta liste est vide. Sur n'importe quelle affiche, maintiens OK pour l'ajouter ici.")
                .font(P.font(24)).foregroundStyle(.white.opacity(0.65)).padding(.vertical, 45)
        } else if loaded {
            let ranked = MineLogic.rank(moodItems)
            let picks = Array(ranked.prefix(3)), rest = Array(ranked.dropFirst(3))
            let ids = Set(moodItems.map(\.id))
            let others = MineLogic.rank(entries.filter { !ids.contains($0.id) })
            heading("Qu'est-ce qui te ferait envie ?", "prisme choisit dans ta liste · OK maintenu sur une proposition : duel, retirer, vu")
            HStack(spacing: 12) {
                ForEach(Array(MineMood.all.enumerated()), id: \.offset) { j, m in moodChip(j, m) }
            }
            .padding(.top, 9).padding(.bottom, 21)
            .frame(maxWidth: .infinity, alignment: .leading).focusSection()
            if let old = forgotten {
                oldBanner(old).padding(.bottom, 18).frame(maxWidth: .infinity, alignment: .leading).focusSection()
            }
            if picks.isEmpty {
                Text("Rien dans ta liste pour cette envie : essaie une autre.").font(P.font(24)).foregroundStyle(.white.opacity(0.65)).padding(.vertical, 45)
            } else {
                HStack(spacing: 27) {
                    ForEach(Array(picks.enumerated()), id: \.element.id) { i, e in pickCard(e, i) }
                    ForEach(0..<(3 - picks.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 330) }
                }
                .padding(.bottom, 18).focusSection()
            }
            if picks.count >= 2 {
                FocusTile(id: "mn-duel", focus: $focus, label: "Duel", tap: { startDuel() }) { f in
                    Text("⚔︎ Duel : départage les titres de cette envie").font(P.font(21.75, .bold))
                        .foregroundStyle(f ? Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255) : .white)
                        .padding(.vertical, 15).padding(.horizontal, 24)
                        .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(Color.white.opacity(f ? 0 : 0.14), lineWidth: 1.5))
                        .scaleEffect(f ? 1.05 : 1)
                }
                .padding(.bottom, 9).frame(maxWidth: .infinity, alignment: .leading).focusSection()
            }
            if !rest.isEmpty { posterRow("Aussi pour cette envie", "\(rest.count)", rest, "mnr") }
            if !others.isEmpty { posterRow("Le reste de ta liste", "\(others.count)", others, "mnx") }
            if !gone.isEmpty { goneRow }
        }
    }

    private func heading(_ t: String, _ s: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(t).font(P.font(39, .heavy))
            Text(s).font(P.font(19.5, .medium)).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 3).padding(.bottom, 12)
    }

    // simulateur .mn-mc : 14,5 → 21,75 ; le nombre en petit ; le survol choisit l'envie
    private func moodChip(_ j: Int, _ m: MineMood) -> some View {
        let n = entries.filter { $0.moods.contains(m.id) }.count
        return FocusTile(id: "mnm-\(j)", focus: $focus, label: m.label, tap: { mood = j }) { f in
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(m.label).font(P.font(21.75, .semibold))
                Text("\(n)").font(P.font(18.75)).opacity(0.55)
            }
            .foregroundStyle(f ? Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255) : .white)
            .padding(.vertical, 13.5).padding(.horizontal, 21)
            .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(f ? Color.white : Color.white.opacity(j == mood ? 0.2 : 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(Color.white.opacity(f ? 0 : 0.14), lineWidth: 1.5))
            .scaleEffect(f ? 1.06 : 1)
        }
        .onChange(of: focus) { _, nf in if nf == "mnm-\(j)", mood != j { mood = j } }
    }

    /// simulateur : ajouté il y a plus de 3 mois, jamais lancé, pas « gardé »
    private var forgotten: MineEntry? {
        let kept = MyListMeta.kept
        return entries.first { e in
            guard let at = e.info?.at, !e.started, !kept.contains(e.id) else { return false }
            return Date().timeIntervalSince(at) > 90 * 86400
        }
    }

    // simulateur .mn-old : fond ambré, 14 → 21
    private func oldBanner(_ e: MineEntry) -> some View {
        HStack(spacing: 15) {
            Text("🕰 Tu l'avais oublié ? « \(e.title) » est dans ta liste depuis plus de 3 mois.").font(P.font(21)).lineLimit(1)
            smallButton("mno-keep", "Le garder") { MyListMeta.keep(e.id); say("Gardé dans ta liste"); refresh += 1 }
            smallButton("mno-del", "Le retirer") { remove(e.id) }
        }
        .padding(.vertical, 15).padding(.horizontal, 21)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.12)))
    }

    private func smallButton(_ id: String, _ t: String, _ a: @escaping () -> Void) -> some View {
        FocusTile(id: id, focus: $focus, label: t, tap: a) { f in
            Text(t).font(P.font(21, .bold)).foregroundStyle(f ? Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255) : .white)
                .padding(.vertical, 10.5).padding(.horizontal, 19.5)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.1)))
        }
    }

    // simulateur .mn-pk : hauteur 220 → 330, rayon 20 → 30, pastille en haut à gauche, texte en bas
    private func pickCard(_ e: MineEntry, _ i: Int) -> some View {
        let late = MineLogic.late(e)
        // durée inconnue : pas d'heure de fin (jamais inventée)
        let badge = i == 0 && !late ? "⭐ le plus adapté" : late ? "finit après ton coucher" : MineLogic.endOf(e).map { "finit à " + MineLogic.hm($0) } ?? ""
        return FocusTile(id: "mnp-\(i)", focus: $focus, label: e.title, tap: { play(e.item) }, long: { options(e) }) { f in
            ZStack(alignment: .bottomLeading) {
                ArtView(backdrop: e.item.backdropURL, poster: e.item.posterURL, maxPixel: 900, fill: true)
                LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.item.kind == .series ? "Série" + (e.minutes > 0 ? " · épisodes de \(e.minutes) min" : "") : "Film" + (e.minutes > 0 ? " · " + MineLogic.dur(e.minutes) : ""))
                        .font(P.font(18.75)).opacity(0.85)
                    Text(e.title).font(P.font(30, .bold)).lineLimit(2)
                    Text(MineLogic.why(e)).font(P.font(18.75)).opacity(0.85).lineLimit(1)
                }
                .padding(.horizontal, 24).padding(.bottom, 21)
                if !badge.isEmpty { Text(badge).font(P.font(18, .heavy)).padding(.vertical, 6).padding(.horizontal, 13.5)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(18) }
            }
            .frame(maxWidth: .infinity).frame(height: 330)
            .background(Color(red: 0x1b / 255, green: 0x1e / 255, blue: 0x27 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white, lineWidth: f ? 4.5 : 0))
            .scaleEffect(f ? 1.04 : 1)
            .shadow(color: .black.opacity(f ? 0.6 : 0), radius: 30, y: 21)
        }
    }

    // simulateur .lh + .row de .mn-po (130 × 195 → 195 × 292)
    private func posterRow(_ t: String, _ n: String, _ list: [MineEntry], _ row: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rowTitle(t, n)
            ScrollView(.horizontal) {
                HStack(spacing: 21) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                        FocusTile(id: "\(row)-\(i)", focus: $focus, label: e.title, tap: { play(e.item) }, long: { options(e) }) { f in
                            posterTile(title: e.title, poster: e.item.posterURL,
                                       tag: e.isNew ? "nouvel épisode" : nil, tagBlue: true,
                                       sub: MineLogic.late(e) ? "après ton coucher" : MineLogic.endOf(e).map { "fin " + MineLogic.hm($0) } ?? "",
                                       gone: false, f: f)
                        }
                    }
                }
                .padding(.vertical, 24).padding(.horizontal, 15)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -15)
            .focusSection()
        }
    }

    private var goneRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowTitle("Plus disponible", "retiré par ton fournisseur · revient tout seul, ou par ton autre fournisseur")
            ScrollView(.horizontal) {
                HStack(spacing: 21) {
                    ForEach(Array(gone.enumerated()), id: \.element.id) { i, g in
                        FocusTile(id: "mng-\(i)", focus: $focus, label: g.title,
                                  tap: { say("Ce titre revient tout seul dans ta liste s'il réapparaît chez ton fournisseur") },
                                  long: { modal = .options(title: g.title, history: false, actions: [("Retirer de Ma liste", { remove(g.id) })]) }) { f in
                            posterTile(title: g.title, poster: g.poster, tag: "plus disponible · surveillé", tagBlue: false,
                                       sub: "revient tout seul s'il réapparaît", gone: true, f: f)
                        }
                    }
                }
                .padding(.vertical, 24).padding(.horizontal, 15)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -15)
            .focusSection()
        }
    }

    private func rowTitle(_ t: String, _ n: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 15) {
            Text(t).font(P.font(25.5, .bold))
            Text(n).font(P.font(18.75, .medium)).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 18).padding(.bottom, 0)
    }

    private func posterTile(title: String, poster: String, tag: String?, tagBlue: Bool, sub: String, gone: Bool, f: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            if poster.isEmpty {
                LinearGradient(colors: [Color(hue: P.hue(title), saturation: 0.45, brightness: 0.4), Color(red: 0.05, green: 0.06, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(title).font(P.font(27, .heavy)).multilineTextAlignment(.center).opacity(0.35).padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ArtView(backdrop: "", poster: poster, maxPixel: 400, fill: true)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(P.font(20.25, .bold)).lineLimit(2)
                if !sub.isEmpty { Text(sub).font(P.font(16.5)).opacity(0.8).lineLimit(1) }
            }
            .padding(.horizontal, 12).padding(.bottom, 10)
            if let tag {
                Text(tag).font(P.font(15.75, .heavy)).lineLimit(2).padding(.vertical, 4.5).padding(.horizontal, 10.5)
                    .background(Capsule().fill(tagBlue ? Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255) : Color.black.opacity(0.65)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(9)
            }
        }
        .frame(width: 195, height: 292)
        .background(Color(red: 0x1b / 255, green: 0x1e / 255, blue: 0x27 / 255))
        .saturation(gone ? 0 : 1).brightness(gone ? -0.25 : 0)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white, lineWidth: f ? 4.5 : 0))
        .scaleEffect(f ? 1.08 : 1)
        .shadow(color: .black.opacity(f ? 0.6 : 0), radius: 21, y: 15)
    }

    // MARK: Ma semaine (simulateur weekHtml)

    @ViewBuilder private var weekPage: some View {
        let empty = week.days.allSatisfy { $0.list.isEmpty }
        heading("Ma semaine", (empty ? "ta semaine se remplira au fil de tes lectures · " : "") + "profil " + profiles.me.name + " · OK : reprendre · OK maintenu : options")
        HStack(spacing: 18) {
            ForEach(Array(week.stats.enumerated()), id: \.offset) { _, s in
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.0).font(P.font(33, .bold)).lineLimit(1)
                    Text(s.1).font(P.font(18.75)).opacity(0.7)
                }
                .padding(.vertical, 18).padding(.horizontal, 21).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1.5))
            }
        }
        .padding(.top, 9).padding(.bottom, 18)
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(week.days.enumerated()), id: \.offset) { j, d in
                VStack(alignment: .leading, spacing: 0) {
                    Text(d.label + " · " + (d.hours > 0 ? String(format: "%.1f", d.hours).replacingOccurrences(of: ".", with: ",") + " h" : "—"))
                        .font(P.font(17.25, .heavy)).opacity(0.7).padding(.bottom, 9)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)).frame(width: g.size.width * min(1, d.hours / 3))
                        }
                    }
                    .frame(height: 7.5).padding(.bottom, 12)
                    ForEach(Array(d.list.enumerated()), id: \.offset) { i, s in
                        FocusTile(id: "mnw-\(j)-\(i)", focus: $focus, label: s.title, tap: { resume(s) }, long: { weekOptions(s) }) { f in
                            Text(s.title).font(P.font(18, .semibold)).lineLimit(1)
                                .padding(.vertical, 10.5).padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 13.5, style: .continuous).fill(
                                    LinearGradient(colors: [Color(hue: P.hue(s.title), saturation: 0.55, brightness: 0.55), Color(hue: P.hue(s.title), saturation: 0.6, brightness: 0.22)],
                                                   startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1))))
                                .overlay(RoundedRectangle(cornerRadius: 13.5, style: .continuous).stroke(Color.white, lineWidth: f ? 4.5 : 0))
                                .scaleEffect(f ? 1.06 : 1)
                        }
                        .padding(.bottom, 9)
                    }
                    Spacer(minLength: 0)
                }
                .padding(13.5).frame(maxWidth: .infinity, minHeight: 375, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Color.white.opacity(j == 6 ? 0.08 : 0.04)))
                .focusSection()
            }
        }
    }

    // MARK: actions

    private func play(_ it: MediaItem) { open = MineOpen(item: it, play: true) }

    private func say(_ t: String) {
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { if toast == t { toast = nil } }
    }

    private func remove(_ id: String) {
        if watch.favorites.contains(id) { watch.toggleFavorite(id) }
        modal = nil
        say("Retiré de ta liste")
        DataCount.write("ma liste [\(profiles.me.id)] : retiré \(id)")
    }

    private func markSeen(_ it: MediaItem) {
        if it.kind == .film {
            watch.setWatched([it.id], watched: true, title: it.displayTitle, icon: it.posterURL, item: it.id)
        } else if let e = watch.inProgress.first(where: { $0.item == it.id }),
                  let k = watch.entries.first(where: { $0.value.item == it.id && $0.value.at == e.at })?.key {
            watch.setWatched([k], watched: true, title: e.title, icon: e.icon, item: it.id)
        } else {
            modal = nil
            say("Pour une série, marque les épisodes depuis sa fiche")
            return
        }
        modal = nil
        say("✓ Marqué comme vu")
        DataCount.write("ma liste [\(profiles.me.id)] : vu \(it.displayTitle)")
    }

    private func options(_ e: MineEntry) {
        modal = .options(title: e.title, history: false, actions: [
            ("⚔︎ Duel pour cette envie", { modal = nil; startDuel() }),
            ("Retirer de Ma liste", { remove(e.id) }),
            ("Marquer comme vu", { markSeen(e.item) }),
            ("Pourquoi il est là ?", { modal = nil; say(MineLogic.why(e)) }),
        ])
    }

    private func startDuel() {
        let l = MineLogic.rank(moodItems)
        guard l.count >= 2 else { say("Pas assez de titres pour un duel"); return }
        modal = .duel(MineDuel(pair: [l[0], l[1]], pool: Array(l.dropFirst(2)), round: 1, max: min(4, l.count - 1)))
    }

    private func win(_ d: MineDuel, _ j: Int) {
        let w = d.pair[j]
        let pool = d.pool.filter { $0.id != w.id }
        if pool.isEmpty || d.round >= d.max {
            modal = nil
            say("🏆 Gagnant : " + w.title)
            DataCount.write("duel : gagnant \(w.title)")
            play(w.item)
            return
        }
        modal = .duel(MineDuel(pair: [w, pool[0]], pool: Array(pool.dropFirst()), round: d.round + 1, max: d.max))
    }

    private func resume(_ s: MineWeekData.Entry) {
        if s.item.hasPrefix("live:") {
            Task { if let ch = await LiveIndex.resolve(ids: [String(s.item.dropFirst(5))]).first { live = LiveLaunch(ch: ch) } else { say("Cette chaîne n'est plus chez ton fournisseur") } }
            return
        }
        Task {
            if let it = await MediaStore.items(ids: [s.item]).first { open = MineOpen(item: it, play: true) }
            else { say("Ce titre n'est plus chez ton fournisseur") }
        }
    }

    private func weekOptions(_ s: MineWeekData.Entry) {
        let pid = profiles.me.id
        let unhist: (String, () -> Void) = ("Retirer de l'historique", {
            modal = nil
            Task { await WatchJournal.remove(profile: pid, item: s.item); say("Retiré de ton historique"); refresh += 1 }
        })
        guard !s.item.hasPrefix("live:") else {
            modal = .options(title: s.title, history: true, actions: [("Reprendre", { modal = nil; resume(s) }), unhist])
            return
        }
        func withItem(_ f: @escaping (MediaItem) -> Void) { Task { if let it = await MediaStore.items(ids: [s.item]).first { f(it) } else { modal = nil; say("Ce titre n'est plus chez ton fournisseur") } } }
        modal = .options(title: s.title, history: true, actions: [
            ("Reprendre", { modal = nil; resume(s) }),
            ("Marquer comme vu", { withItem { markSeen($0) } }),
            unhist,
            ("Ne plus proposer", { withItem { it in
                NotInterested.add(it.workKey, pid: pid); modal = nil
                Task { await WatchJournal.remove(profile: pid, item: s.item); refresh += 1 }
                say("Ne sera plus proposé dans « Pour toi »") } }),
            ("👍 J'ai aimé", { withItem { it in FilmRatings.rate(it, 1); modal = nil; say("👍 Noté : « Pour toi » s'affine") } }),
            ("👎 Pas pour moi", { withItem { it in FilmRatings.rate(it, -1); modal = nil; say("👎 Noté : moins de titres comme celui-ci") } }),
        ])
    }

    // MARK: fenêtres (simulateur mnduel, mnopt)

    @ViewBuilder private func modalView(_ m: MineModal) -> some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).overlay(Color.black.opacity(0.55)).ignoresSafeArea()
            switch m {
            case .duel(let d): duelView(d)
            case .options(let title, let history, let actions): optionsView(title, history, actions)
            }
        }
        .onExitCommand { modal = nil }
        .transition(.opacity)
    }

    // simulateur .mn-dbox : h2 28 → 42, affiches 280 × 360 → 420 × 540, « VS »
    private func duelView(_ d: MineDuel) -> some View {
        VStack(spacing: 0) {
            Text("Duel · \(d.round) / \(d.max)").font(P.font(42, .bold)).padding(.bottom, 6)
            Text("← ou → puis OK pour garder ton préféré").font(P.font(22.5)).opacity(0.7).padding(.bottom, 27)
            HStack(spacing: 45) {
                duelCard(d, 0)
                Text("VS").font(P.font(36, .heavy)).opacity(0.6)
                duelCard(d, 1)
            }
            .focusSection()
        }
        .id("duel-\(d.round)")
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focus = "mnd-0" } }
    }

    private func duelCard(_ d: MineDuel, _ j: Int) -> some View {
        let e = d.pair[j]
        return FocusTile(id: "mnd-\(j)", focus: $focus, label: e.title, tap: { win(d, j) }) { f in
            ZStack(alignment: .bottom) {
                ArtView(backdrop: e.item.backdropURL, poster: e.item.posterURL, maxPixel: 900, fill: true)
                LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom)
                VStack(spacing: 4) {
                    Text(e.item.kind == .series ? "Série" : "Film" + (e.minutes > 0 ? " · " + MineLogic.dur(e.minutes) : "")).font(P.font(18.75)).opacity(0.85)
                    Text(e.title).font(P.font(30, .bold)).multilineTextAlignment(.center).lineLimit(2)
                    if let end = MineLogic.endOf(e) { Text("fin " + MineLogic.hm(end)).font(P.font(18.75)).opacity(0.85) }
                }
                .padding(.horizontal, 24).padding(.bottom, 21)
            }
            .frame(width: 420, height: 540)
            .background(Color(red: 0x1b / 255, green: 0x1e / 255, blue: 0x27 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white, lineWidth: f ? 4.5 : 0))
            .scaleEffect(f ? 1.04 : 1)
            .shadow(color: .black.opacity(f ? 0.6 : 0), radius: 30, y: 21)
        }
    }

    // simulateur .mbox (800 → 1200) : « MA LISTE » / « HISTORIQUE », titre, une ligne par action (.msrc)
    private func optionsView(_ title: String, _ history: Bool, _ actions: [(String, () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(history ? "HISTORIQUE" : "MA LISTE").font(P.font(19.5, .bold)).tracking(2.5).opacity(0.75)
            Text(title).font(P.font(48, .bold)).lineLimit(1).padding(.bottom, 12)
            ForEach(Array(actions.enumerated()), id: \.offset) { i, a in
                FocusTile(id: "mno-\(i)", focus: $focus, label: a.0, tap: a.1) { f in
                    Text(a.0).font(P.font(28.5, .semibold)).foregroundStyle(f ? .black : .white)
                        .padding(.vertical, 18).padding(.horizontal, 24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.08)))
                        .scaleEffect(f ? 1.02 : 1)
                }
            }
        }
        .padding(.vertical, 45).padding(.horizontal, 51).frame(width: 1272)
        .background(RoundedRectangle(cornerRadius: 42, style: .continuous).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).fill(Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.72)))
            .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.6), radius: 60, y: 45))
        .focusSection()
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focus = "mno-0" } }
    }

    // MARK: chargement

    private func load() async {
        let pid = profiles.me.id
        let favs = watch.favorites
        let items = await MediaStore.items(ids: favs)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        MyListMeta.remember(items)
        let meta = MyListMeta.all(pid)
        // listes des autres profils (envie « À deux », « aussi dans la liste d'un autre profil »)
        var others = Set<String>()
        for p in profiles.profiles where p.id != pid {
            others.formUnion(UserDefaults.standard.stringArray(forKey: ProfileStore.storageKey("prisme.media.favs", for: p.id)) ?? [])
        }
        var out: [MineEntry] = [], lost: [MineGone] = []
        for id in favs {
            guard let it = byID[id] else {
                if let m = meta[id], !m.title.isEmpty { lost.append(MineGone(id: id, title: m.title, poster: m.poster)) }
                continue
            }
            guard it.allowedForProfile else { continue }
            let series = it.kind == .series
            let minutes = it.fiche?.runtime ?? 0
            let two = others.contains(id)
            var prog = 0.0, started = false, lastAt: Date?
            if series {
                let eps = watch.entries.values.filter { $0.item == id }
                started = !eps.isEmpty
                lastAt = eps.map(\.at).max()
                if let e = watch.inProgress.first(where: { $0.item == id }), e.dur > 0 { prog = min(0.99, e.pos / e.dur) }
            } else if let f = watch.fraction(id) {
                started = true
                if f < 0.92, (watch.entries[id]?.pos ?? 0) > 30 { prog = f }
            }
            // nouvel épisode : la série a changé chez le fournisseur ces 7 derniers jours, après ta dernière séance
            let isNew = series && started && it.added > 0 && Date().timeIntervalSince1970 - Double(it.added) < 7 * 86400
                && Double(it.added) > (lastAt?.timeIntervalSince1970 ?? .infinity)
            out.append(MineEntry(item: it, moods: MineLogic.moods(genres: it.fiche?.genres ?? "", minutes: minutes, series: series, two: two),
                                 minutes: minutes, isNew: isNew, info: meta[id], two: two, prog: prog, started: started || prog > 0))
        }
        entries = out; gone = lost
        week = await MineWeekData.load(profile: pid)
        loaded = true
        DataCount.write("ma liste [\(pid)] : \(out.count) titres, \(lost.count) plus disponibles · envies " + MineMood.all.map { m in "\(m.id)=\(out.filter { $0.moods.contains(m.id) }.count)" }.joined(separator: " ")
                        + " · semaine \(week.days.reduce(0) { $0 + $1.list.count }) titres, " + week.stats.map { $0.0 }.joined(separator: " | "))
    }
}

enum MineModal: Equatable {
    case duel(MineDuel)
    case options(title: String, history: Bool, actions: [(String, () -> Void)])
    static func == (a: MineModal, b: MineModal) -> Bool {
        switch (a, b) {
        case let (.duel(x), .duel(y)): return x == y
        case let (.options(t1, h1, a1), .options(t2, h2, a2)): return t1 == t2 && h1 == h2 && a1.map(\.0) == a2.map(\.0)
        default: return false
        }
    }
}

struct MineDuel: Equatable { let pair: [MineEntry]; let pool: [MineEntry]; let round: Int; let max: Int }

// MARK: - Ma semaine : données (journal réel du profil, 7 jours)

struct MineWeekData {
    struct Entry: Equatable { let item: String; let title: String }
    struct Day { let label: String; let hours: Double; let list: [Entry] }
    var days: [Day] = []
    var stats: [(String, String)] = [("—", "regardées ces 7 jours"), ("—", "genre de la semaine"), ("—", "série la plus suivie"), ("—", "ta soirée type")]

    @MainActor static func load(profile: String) async -> MineWeekData {
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: Date())
        let since = cal.date(byAdding: .day, value: -6, to: d0) ?? d0
        let sess = await WatchJournal.sessions(profile: profile, since: since)
        let names = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"]
        var w = MineWeekData()
        for i in (0...6).reversed() {
            let t = cal.date(byAdding: .day, value: -i, to: d0) ?? d0, t1 = cal.date(byAdding: .day, value: 1, to: t) ?? t
            let L = sess.filter { $0.start >= t && $0.start < t1 }
            var seen = Set<String>(), list: [Entry] = []
            for s in L where seen.insert(s.item).inserted { list.append(Entry(item: s.item, title: s.title)) }
            let label = i == 0 ? "AUJ." : names[cal.component(.weekday, from: t) - 1]
            w.days.append(Day(label: label, hours: Double(L.reduce(0) { $0 + $1.seconds }) / 3600, list: list))
        }
        guard !sess.isEmpty else { return w }
        let tot = Double(sess.reduce(0) { $0 + $1.seconds }) / 3600
        // genre : premier genre de la fiche du titre, pondéré par le temps regardé ; série : la plus regardée
        let ids = Array(Set(sess.map(\.item).filter { $0.hasPrefix("film:") || $0.hasPrefix("series:") }))
        let items = await MediaStore.items(ids: ids)
        let gOf = Dictionary(items.map { ($0.id, ($0.fiche?.genres ?? "").components(separatedBy: CharacterSet(charactersIn: ",/")).first?.trimmingCharacters(in: .whitespaces) ?? "") },
                             uniquingKeysWith: { a, _ in a })
        var g: [String: Int] = [:], sr: [String: Int] = [:]
        for s in sess {
            if let x = gOf[s.item], !x.isEmpty { g[x, default: 0] += s.seconds }
            if s.kind == "episode" { sr[s.title, default: 0] += s.seconds }
        }
        let hrs = sess.map { cal.component(.hour, from: $0.start) }.sorted()
        let hs = hrs[hrs.count / 2]
        w.stats = [(tot > 0 ? "\(Int(tot)) h \(String(format: "%02d", Int(((tot - Double(Int(tot))) * 60).rounded())))" : "—", "regardées ces 7 jours"),
                   (g.max { $0.value < $1.value }?.key ?? "—", "genre de la semaine"),
                   (sr.max { $0.value < $1.value }?.key ?? "—", "série la plus suivie"),
                   ("\(hs) h – \((hs + 2) % 24) h", "ta soirée type")]
        return w
    }
}

// MARK: - Élément sélectionnable : OK (tap) et OK maintenu (long), avec l'état de sélection pour le dessin

struct FocusTile<Content: View>: View {
    let id: String
    var focus: FocusState<String?>.Binding
    let label: String
    let tap: () -> Void
    var long: (() -> Void)? = nil
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        let f = focus.wrappedValue == id
        content(f)
            .animation(.easeOut(duration: 0.15), value: f)
            .focusable(true)
            .focused(focus, equals: id)
            .onLongPressGesture(minimumDuration: 0.6) { (long ?? tap)() }
            .onTapGesture { tap() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }
}
