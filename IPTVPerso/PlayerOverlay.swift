import SwiftUI

// MARK: - Interface du lecteur (simulateur) : bandeau bas (titre, progression, « Qu'a-t-il dit ? »), heure et « fin à »,
// panneau « Raccourcis » (↑) puis « Lecture » (↑ encore ou OK), sous-listes (Audio, Sous-titres, Version, Image, Son de nuit,
// Infos du flux), « Tu regardes toujours ? » et les messages (fin de partie 1, arrêt au coucher).
// La lecture elle-même reste dans VLC (VodPlayerController) ; cet écran ne fait que montrer et transmettre les choix.

struct PlayerOption: Identifiable, Equatable { let id: Int32; let name: String }
/// Une chaîne de la liste du panneau (TV en direct) : programme en cours, avancement, ensuite.
struct LiveRow: Identifiable, Equatable { let id: Int; let name: String; let now: String; let progress: Double; let next: String }

@MainActor
final class PlayerUI: ObservableObject {
    enum Panel: Equatable { case none, shortcuts, full, sub(String) }

    @Published var panel: Panel = .none
    @Published var osd = true
    /// ↓ : la sélection va sur « Qu'a-t-il dit ? »
    @Published var options = false
    @Published var loading = true
    @Published var paused = false
    @Published var kicker = ""
    @Published var title = ""
    @Published var meta = ""
    @Published var pos: Double = 0
    @Published var dur: Double = 0
    @Published var pending: Double = 0
    @Published var audio: [PlayerOption] = []
    @Published var audioCur: Int32 = -1
    @Published var subs: [PlayerOption] = []
    @Published var subCur: Int32 = -1
    @Published var versions: [String] = []
    @Published var versionCur = 0
    @Published var aspect = "auto"
    @Published var night = "auto"
    @Published var nightActive = false
    @Published var bedStop = false
    @Published var info: [(String, String)] = []
    @Published var cast: [String] = []
    @Published var toast: String?
    @Published var sleepLeft: Int?
    @Published var message: String?
    @Published var hint = "↑ raccourcis puis tous les réglages · ↓ options · ⏯ pause · Retour ×2 : quitter"
    /// l'aide ne s'affiche que quelques secondes, à l'ouverture du lecteur (demande de Steven : interface sobre)
    @Published var hintVisible = true
    // TV en direct
    @Published var live = false
    @Published var cur = 0
    @Published var channels: [LiveRow] = []
    @Published var recent: [(Int, String)] = []
    @Published var liveStart: Date?
    @Published var liveStop: Date?
    var zapTo: (Int, Bool) -> Void = { _, _ in }
    // 1.8 phase 1 : cartes de fin de lecture (PlayerCards.swift)
    enum Card: Equatable { case none, intro, episode, film, post, encore, rate }
    @Published var card: Card = .none
    @Published var cardSel = 0
    @Published var countdown: Int?
    @Published var prepared = false
    @Published var introSub = ""
    @Published var endInfo = EndCardInfo()
    @Published var bingeCount = 0
    @Published var encoreEp = ""
    @Published var encoreEnd = ""
    @Published var encoreBed = ""
    @Published var encoreLate = false
    @Published var rateTitle = ""
    // séries : panneau « Épisodes » et « Réglages de cette série »
    @Published var series = false
    @Published var episodes: [PanelEpisode] = []
    @Published var epCur = ""
    @Published var epSeason = 1
    /// épisodes vus en entier, épisode à suivre (zéro spoiler : les suivants sont floutés)
    @Published var epSeen: Set<String> = []
    @Published var epProgress: [String: Double] = [:]
    @Published var stopAfter = false
    @Published var seriesAutoSkip = true
    @Published var introLearned = ""
    var playEpisode: (Int, Int) -> Void = { _, _ in }
    var nextEpisode: () -> Void = {}
    var setStopAfter: (Bool) -> Void = { _ in }
    var setSeriesAutoSkip: (Bool) -> Void = { _ in }
    var forgetIntro: () -> Void = {}
    /// zéro spoiler : épisode plus loin que celui en cours (et pas déjà vu)
    func spoiler(_ e: PanelEpisode) -> Bool {
        guard PlaybackPrefs.zeroSpoiler, !epSeen.contains(e.id), let c = episodes.firstIndex(where: { $0.id == epCur }),
              let i = episodes.firstIndex(of: e) else { return false }
        return i > c
    }

    /// dernière option utilisée (le panneau s'ouvre dessus)
    @Published var lastKey = "audio"
    var bedMinutes = 1380

    // actions (branchées par le lecteur)
    var setAudio: (Int32) -> Void = { _ in }
    var setSub: (Int32) -> Void = { _ in }
    var setVersion: (Int) -> Void = { _ in }
    var setAspect: (String) -> Void = { _ in }
    var setNight: (String) -> Void = { _ in }
    var setBedStop: (Bool) -> Void = { _ in }
    var whatSaid: () -> Void = {}
    var stillWatching: () -> Void = {}
    var pauseForLater: () -> Void = {}
    var togglePause: () -> Void = {}
    var touch: () -> Void = {}

    static let aspects: [(String, String)] = [("auto", "Auto"), ("fill", "Remplir l'écran"), ("16:9", "16:9"), ("4:3", "4:3"), ("21:9", "Cinéma 21:9")]
    static let nights: [(String, String)] = [("auto", "Auto après ton coucher"), ("on", "Toujours"), ("off", "Jamais")]

    var interactive: Bool { panel != .none || options || sleepLeft != nil }
    /// une carte qui attend un choix (la télécommande la pilote ; « Passer l'intro » laisse avancer/reculer)
    var cardActive: Bool { card != .none && card != .intro }

    // MARK: habitudes (par profil) : les 3 raccourcis = les 3 réglages les plus utilisés

    private static let order = ["audio", "subs", "version", "image", "night", "bedstop", "info", "stopafter"]
    private var usageKey: String { ProfileStore.shared.key("prisme.player.usage") }
    var shortcuts: [String] {
        let u = (UserDefaults.standard.dictionary(forKey: usageKey) as? [String: Int]) ?? [:]
        let L = PlayerUI.order.filter { ($0 != "version" || versions.count > 1) && ($0 != "stopafter" || series) && ($0 != "bedstop" || !series) }
        return Array(L.sorted { (u[$0] ?? 0, -(PlayerUI.order.firstIndex(of: $0) ?? 0)) > (u[$1] ?? 0, -(PlayerUI.order.firstIndex(of: $1) ?? 0)) }.prefix(3))
    }
    func used(_ k: String) {
        var u = (UserDefaults.standard.dictionary(forKey: usageKey) as? [String: Int]) ?? [:]
        u[k, default: 0] += 1
        UserDefaults.standard.set(u, forKey: usageKey)
        lastKey = k
        UserDefaults.standard.set(k, forKey: ProfileStore.shared.key("prisme.player.last"))
    }
    func loadHabits() {
        lastKey = UserDefaults.standard.string(forKey: ProfileStore.shared.key("prisme.player.last")) ?? "audio"
    }

    // MARK: textes

    func label(_ k: String) -> (icon: String, title: String, value: String) {
        switch k {
        case "audio": return ("waveform", "Audio", audio.first { $0.id == audioCur }?.name ?? (audio.isEmpty ? "Piste unique" : "—"))
        case "subs": return ("captions.bubble", "Sous-titres", subCur < 0 ? "Désactivés" : (subs.first { $0.id == subCur }?.name ?? "—"))
        case "version" where live: return ("antenna.radiowaves.left.and.right", "Source", versions.indices.contains(versionCur) ? versions[versionCur] + (versions.count > 1 ? " · \(versions.count) dispo" : "") : "Source unique")
        case "version": return ("square.stack.3d.up", "Version", versions.indices.contains(versionCur) ? versions[versionCur] + " · \(versions.count) dispo" : "Version unique")
        case "image": return ("viewfinder", "Image", PlayerUI.aspects.first { $0.0 == aspect }?.1 ?? "Auto")
        case "night": return ("moon", "Son de nuit", (night == "auto" ? "Auto après " + Self.hm(bedMinutes) : night == "on" ? "Toujours" : "Jamais") + (nightActive ? " · actif" : ""))
        case "bedstop": return ("bed.double", "Arrêt à " + Self.hm(bedMinutes), bedStop ? "Activé" : "Désactivé")
        case "stopafter": return ("moon.zzz", "Arrêt après cet épisode", stopAfter ? "Activé" : "Désactivé")
        default: return ("info.circle", "Infos du flux", info.first?.1 ?? "")
        }
    }

    static func hm(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
    static func hms(_ t: Double) -> String {
        let s = max(0, Int(t)), h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
    var endText: String { dur > 0 ? Fmt.hm(Date().addingTimeInterval(dur - pos)) : "" }

    /// simulateur de test uniquement : dernières touches Retour reçues, affichées en petit pour la visite automatique
    @Published var trace = ""
    func log(_ s: String) {
        guard Debug.demoServer != nil else { return }
        let t = String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100))
        trace = (trace.split(separator: "\n").suffix(7).map(String.init) + ["\(t) \(s)"]).joined(separator: "\n")
    }

    /// Retour : remonte d'un niveau (sous-liste → Lecture → Raccourcis → fermé)
    func back(_ from: String = "ui") {
        log("back(\(from)) \(panel) opt=\(options)")
        touch()
        switch panel {
        case .sub: panel = .full
        // comportement validé : Retour ferme le panneau ouvert (une sous-liste revient d'abord à sa liste)
        case .full: panel = .none
        case .shortcuts: panel = .none
        case .none: options = false
        }
    }
}

struct PlayerOverlay: View {
    @ObservedObject var m: PlayerUI
    @FocusState private var focus: String?
    @State private var now = Date()
    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if m.osd || m.interactive {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom).ignoresSafeArea()
                topRight
                bottomBar
            }
            if m.loading && m.message == nil { ProgressView().scaleEffect(2).tint(.white) }
            // cartes de fin (simulateur) : sous le panneau ; « Passer l'intro » se cache quand un panneau est ouvert
            if m.card != .none && !(m.card == .intro && m.panel != .none) && m.sleepLeft == nil { PlayerCardsLayer(m: m) }
            if m.panel != .none { panel.transition(.move(edge: .trailing).combined(with: .opacity)) }
            if let t = m.toast {
                Text(t).font(P.font(26, .semibold)).padding(.horizontal, 30).frame(height: 66).accessibilityIdentifier("toast")
                    .background(.ultraThinMaterial, in: Capsule()).environment(\.colorScheme, .dark)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 70)
            }
            if let s = m.sleepLeft { sleepModal(s) }
            // message masqué tant qu'un panneau est ouvert (il le recouvrait) ; il revient à la fermeture
            if let msg = m.message, m.sleepLeft == nil, m.panel == .none { messageCard(msg) }
        }
        .foregroundStyle(.white)
        .animation(.easeOut(duration: 0.25), value: m.panel)
        .animation(.easeOut(duration: 0.25), value: m.osd)
        .onReceive(clock) { now = $0 }
        .onChange(of: m.panel) { old, p in placeFocus(p, from: old) }
        .onChange(of: m.options) { _, o in if o { focus = "said" } }
        .task { try? await Task.sleep(nanoseconds: 6_000_000_000); withAnimation(.easeOut(duration: 0.6)) { m.hintVisible = false } }
        .onChange(of: m.sleepLeft == nil) { _, none in if !none { focus = "sleep-yes" } }
    }

    // MARK: heure, fin à

    private var topRight: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(Fmt.hm(now)).font(P.font(44, .bold)).monospacedDigit()
            if !m.endText.isEmpty { Text("fin à " + m.endText).font(P.font(24)).foregroundStyle(.white.opacity(0.75)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.top, 58).padding(.trailing, 86)
        .opacity(m.panel == .full || m.panel.isSub ? 0 : 1)
    }

    // MARK: bandeau du bas

    private var bottomBar: some View {
        let right: CGFloat = m.panel == .shortcuts ? 600 : (m.panel == .none ? 0 : 760)
        return VStack(alignment: .leading, spacing: 0) {
            Spacer()
            if !m.kicker.isEmpty { Text(m.kicker).font(P.font(21, .bold)).tracking(3).foregroundStyle(.white.opacity(0.75)) }
            Text(m.title).font(P.font(54, .bold)).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 4)
            if !m.meta.isEmpty { Text(m.meta).font(P.font(25)).foregroundStyle(.white.opacity(0.8)).padding(.top, 2) }
            HStack(spacing: 20) {
                Text(m.live ? (m.liveStart.map { Fmt.hm($0) } ?? "DIRECT") : PlayerUI.hms(shownPos)).font(P.font(28)).monospacedDigit()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18)).frame(height: 12)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: max(0, g.size.width * frac), height: 12)
                        Circle().fill(Color.white).frame(width: 38, height: 38).offset(x: max(0, g.size.width * frac - 19))
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 40)
                Text(m.live ? (m.liveStop.map { Fmt.hm($0) } ?? "") : "−" + PlayerUI.hms(max(0, m.dur - shownPos))).font(P.font(28)).monospacedDigit()
                    + Text(m.pending != 0 ? String(format: "  (%@%d s)", m.pending > 0 ? "+" : "−", Int(abs(m.pending))) : "").font(P.font(24, .bold))
            }
            .padding(.top, 22)
            if m.hintVisible {
                Text(m.live ? "↑ raccourcis puis chaînes · ↓ chaînes · ⏯ pause · Retour ×2 : quitter"
                     : m.series ? "↑ raccourcis puis épisodes · ↓ options · ⏯ pause · Retour ×2 : quitter" : m.hint)
                    .font(P.font(21)).foregroundStyle(.white.opacity(0.6)).padding(.top, 10).transition(.opacity)
            }
            if !m.live {
                HStack(spacing: 14) {
                    saidButton
                    if m.series {
                        // simulateur : « ⏩ Épisode suivant » à côté de « Qu'a-t-il dit ? »
                        Button { m.options = false; m.nextEpisode() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "forward.end.fill").font(.system(size: 22, weight: .semibold))
                                Text("Épisode suivant").font(P.font(25, .bold))
                            }
                            .padding(.horizontal, 28).frame(height: 62)
                        }
                        .buttonStyle(PlayerChipStyle())
                        .focused($focus, equals: "nextep")
                        .disabled(!m.options)
                        .padding(.top, 22)
                    }
                }
            }
        }
        .padding(.leading, 86).padding(.trailing, 86 + right).padding(.bottom, 58)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .onExitCommand { m.back("swiftui") }
    }

    private var saidButton: some View {
            Button { m.whatSaid() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 24, weight: .semibold))
                    Text("Qu'a-t-il dit ?").font(P.font(25, .bold))
                    Text("−10 s + sous-titres").font(P.font(20)).opacity(0.75)
                }
                .padding(.horizontal, 28).frame(height: 62)
            }
            .buttonStyle(PlayerChipStyle())
            .focused($focus, equals: "said")
            .disabled(!m.options)
            .padding(.top, 22)
    }

    private var shownPos: Double { m.pending != 0 ? max(0, min(m.dur, m.pos + m.pending)) : m.pos }
    private var frac: CGFloat { m.dur > 0 ? CGFloat(shownPos / m.dur) : 0 }

    // MARK: panneau

    @ViewBuilder private var panel: some View {
        switch m.panel {
        case .shortcuts:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Raccourcis").font(P.font(34, .bold))
                    Spacer()
                    Text("appris de tes habitudes").font(P.font(21)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 4)
                ForEach(m.shortcuts, id: \.self) { k in row(k) }
                Divider().overlay(Color.white.opacity(0.15))
                rowButton(icon: m.live || m.series ? "list.bullet.rectangle" : "rectangle.grid.1x2",
                          title: m.live ? "Chaînes et tout le reste" : m.series ? "Épisodes et tout le reste" : "Tous les réglages", value: "↑ ou OK", key: "all") { m.panel = .full }
            }
            .padding(28).frame(width: 565)
            .background(panelBG(36))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 37).padding(.bottom, 37)
            .onMoveCommand { d in if d == .up, focus == m.shortcuts.first { m.panel = .full } }
            .onExitCommand { m.back("swiftui") }
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if case let .sub(k) = m.panel {
                        Label(m.label(k).title, systemImage: "chevron.left").font(P.font(34, .bold))
                    } else {
                        Text(m.live ? "Chaînes" : m.series ? "Épisodes" : "Lecture").font(P.font(36, .bold))
                    }
                    Spacer()
                    Text(Fmt.hm(now)).font(P.font(34, .semibold)).monospacedDigit()
                }
                .padding(.bottom, 18)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if case let .sub(k) = m.panel { subList(k) } else { fullList }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 6)
                }
                // une sous-liste repart du haut (sinon elle gardait le défilement de la liste précédente : vide en haut)
                .id(m.panel.isSub ? "sub" : "full")
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 30).padding(.top, 34).padding(.bottom, 24)
            .frame(width: 720).frame(maxHeight: .infinity)
            .background(panelBG(44))
            .padding(.vertical, 37).padding(.trailing, 37)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onExitCommand { m.back("swiftui") }
        }
    }

    @ViewBuilder private var fullList: some View {
        if m.live { liveList } else if m.series { seriesList } else { vodList }
    }

    /// Série (simulateur) : saisons, épisodes, puis « RÉGLAGES DE CETTE SÉRIE » en pastilles
    @ViewBuilder private var seriesList: some View {
        let seasons = Array(Set(m.episodes.map(\.season))).sorted()
        if seasons.count > 1 {
            HStack(spacing: 12) {
                ForEach(seasons, id: \.self) { n in
                    Button { m.epSeason = n } label: { Text("Saison \(n)").font(P.font(21, .bold)).padding(.horizontal, 20).frame(height: 50) }
                        .buttonStyle(PlayerChipStyle(on: m.epSeason == n)).focused($focus, equals: "sea\(n)")
                }
            }
            .padding(.bottom, 10)
        }
        ForEach(m.episodes.filter { $0.season == m.epSeason }) { e in
            let hide = m.spoiler(e), cur = e.id == m.epCur
            Button { m.panel = .none; if !cur { m.playEpisode(e.season, e.number) } } label: {
                HStack(spacing: 18) {
                    ArtView(backdrop: e.image, poster: "", maxPixel: 300, posterWidthRatio: 0.3)
                        .frame(width: 150, height: 84).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .blur(radius: hide ? 8 : 0).clipped()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(e.number). " + (e.title.isEmpty ? "Épisode \(e.number)" : e.title)).font(P.font(24, .bold)).lineLimit(1)
                            .blur(radius: hide ? 6 : 0)
                        Text(epLine(e, cur: cur)).font(P.font(19)).opacity(0.7).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlayerRowStyle(current: cur))
            .focused($focus, equals: "ep" + e.id)
        }
        Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 12)
        Text("RÉGLAGES DE CETTE SÉRIE").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.65)).padding(.bottom, 6)
        HStack(spacing: 12) {
            chip("Audio : " + m.label("audio").value, key: "c-audio") { m.used("audio"); m.panel = .sub("audio") }
            chip("Sous-titres : " + (m.subCur < 0 ? "non" : m.label("subs").value), key: "c-subs") { m.used("subs"); m.panel = .sub("subs") }
        }
        HStack(spacing: 12) {
            chip(m.versions.indices.contains(m.versionCur) ? m.versions[m.versionCur] : "Version unique", key: "c-version") { m.used("version"); m.panel = .sub("version") }
            chip("Intro passée auto", key: "c-auto", on: m.seriesAutoSkip) { m.setSeriesAutoSkip(!m.seriesAutoSkip) }
        }
        HStack(spacing: 12) {
            chip("Arrêt après cet épisode", key: "c-stop", on: m.stopAfter) { m.used("stopafter"); m.setStopAfter(!m.stopAfter) }
            chip("Image : " + m.label("image").value, key: "c-image") { m.used("image"); m.panel = .sub("image") }
        }
        HStack(spacing: 12) {
            chip("Son de nuit : " + (m.night == "auto" ? "auto" : m.night == "on" ? "toujours" : "jamais"), key: "c-night") { m.used("night"); m.panel = .sub("night") }
            chip("Infos du flux", key: "c-info") { m.used("info"); m.panel = .sub("info") }
        }
        if !m.introLearned.isEmpty {
            Text("Intro apprise : " + m.introLearned).font(P.font(20)).foregroundStyle(.white.opacity(0.6)).padding(.top, 8)
            chip("Oublier le moment de l'intro", key: "c-forget") { m.forgetIntro() }
        }
    }

    private func epLine(_ e: PanelEpisode, cur: Bool) -> String {
        let d = e.minutes > 0 ? "\(e.minutes) min" : ""
        if cur { return "en cours" + (m.dur > 0 ? " · reste " + "\(max(1, Int((m.dur - m.pos) / 60))) min" : "") }
        if m.epSeen.contains(e.id) { return "✓ vu" + (d.isEmpty ? "" : " · " + d) }
        if let f = m.epProgress[e.id] { return "commencé · \(Int(f * 100)) %" }
        return d
    }

    private func chip(_ t: String, key: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button { m.touch(); action() } label: {
            HStack(spacing: 8) {
                if on { Image(systemName: "checkmark").font(.system(size: 17, weight: .bold)) }
                Text(t).font(P.font(21, .bold)).lineLimit(1)
            }
            .padding(.horizontal, 20).frame(height: 52)
        }
        .buttonStyle(PlayerChipStyle(on: on)).focused($focus, equals: key)
    }

    /// TV en direct (simulateur, variante « tv ») : récentes, liste des chaînes avec leur programme, puis les réglages
    @ViewBuilder private var liveList: some View {
        if !m.recent.isEmpty {
            HStack(spacing: 12) {
                Text("RÉCENTES").font(P.font(19, .bold)).tracking(2.5).foregroundStyle(.white.opacity(0.65))
                ForEach(m.recent, id: \.0) { r in
                    Button { m.zapTo(r.0, true); m.panel = .none } label: { Text(r.1).font(P.font(21, .bold)).lineLimit(1).padding(.horizontal, 18).frame(height: 50) }
                        .buttonStyle(PlayerChipStyle()).focused($focus, equals: "rc\(r.0)")
                }
            }
            .padding(.bottom, 10)
        }
        ForEach(m.channels) { c in
            Button { m.zapTo(c.id, true); m.panel = .none } label: {
                HStack(alignment: .top, spacing: 18) {
                    Text(c.name).font(P.font(22, .heavy)).lineLimit(2).frame(width: 150, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.now).font(P.font(23, .semibold)).lineLimit(1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            GeometryReader { g in Capsule().fill(Color(red: 0.9, green: 0.28, blue: 0.3)).frame(width: g.size.width * min(1, max(0, c.progress))) }
                        }.frame(height: 5)
                        Text((c.id == m.cur ? "tu regardes · " : "") + c.next).font(P.font(18)).opacity(0.7).lineLimit(1)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlayerRowStyle(current: c.id == m.cur))
            .focused($focus, equals: "ch\(c.id)")
            // passer sur une chaîne ne lance rien : seul OK change de chaîne (simulateur « OK pour regarder »)
        }
        Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 10)
        ForEach(["version", "audio", "subs", "image", "night"], id: \.self) { k in row(k) }
    }

    @ViewBuilder private var vodList: some View {
        ForEach(["audio", "subs", "version", "image", "night"], id: \.self) { k in row(k) }
        Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 10)
        Text("CE SOIR").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.65))
        Text(ceSoir).font(P.font(25)).padding(.top, 6).padding(.bottom, 8).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 14) {
            Button { m.used("bedstop"); m.setBedStop(!m.bedStop) } label: {
                HStack(spacing: 8) {
                    if m.bedStop { Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)) }
                    Text("Arrêt à " + PlayerUI.hm(m.bedMinutes)).font(P.font(22, .bold))
                }.padding(.horizontal, 20).frame(height: 54)
            }
            .buttonStyle(PlayerChipStyle(on: m.bedStop)).focused($focus, equals: "bedstop")
            Button { m.used("info"); m.panel = .sub("info") } label: { Text("Infos du flux").font(P.font(22, .bold)).padding(.horizontal, 20).frame(height: 54) }
                .buttonStyle(PlayerChipStyle()).focused($focus, equals: "info")
        }
        if !m.cast.isEmpty {
            Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 12)
            Text("CASTING").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.65))
            Text(m.cast.prefix(6).joined(separator: " · ")).font(P.font(24)).padding(.top, 6).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ceSoir: String {
        guard m.dur > 0 else { return "Durée inconnue." }
        let end = Date().addingTimeInterval(m.dur - m.pos)
        let c = Calendar.current.dateComponents([.hour, .minute], from: end)
        var em = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let nc = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nm = (nc.hour ?? 0) * 60 + (nc.minute ?? 0)
        if em < nm { em += 1440 }
        let bed = m.bedMinutes >= 1440 || nm >= 300 ? m.bedMinutes : m.bedMinutes + 1440
        let late = em - (nm < 300 && bed >= 1440 ? bed - 1440 : bed)
        return "Le film finit à " + Fmt.hm(end) + (late > 10 ? " · \(late / 60 > 0 ? "\(late / 60) h \(String(format: "%02d", late % 60))" : "\(late) min") après ton coucher." : ".")
    }

    @ViewBuilder private func subList(_ k: String) -> some View {
        switch k {
        case "audio":
            if m.audio.isEmpty { Text("Une seule piste audio dans ce fichier.").font(P.font(24)).foregroundStyle(.white.opacity(0.7)) }
            ForEach(m.audio) { o in choice(o.name, on: o.id == m.audioCur, key: "a\(o.id)") { m.setAudio(o.id); m.panel = .full } }
        case "subs":
            choice("Désactivés", on: m.subCur < 0, key: "s-1") { m.setSub(-1); m.panel = .full }
            ForEach(m.subs.filter { $0.id >= 0 }) { o in choice(o.name, on: o.id == m.subCur, key: "s\(o.id)") { m.setSub(o.id); m.panel = .full } }
            if m.subs.filter({ $0.id >= 0 }).isEmpty { Text("Pas de sous-titres dans ce fichier.").font(P.font(24)).foregroundStyle(.white.opacity(0.7)).padding(.top, 8) }
        case "version":
            ForEach(m.versions.indices, id: \.self) { i in choice(m.versions[i], on: i == m.versionCur, key: "v\(i)") { m.setVersion(i); if !m.live { m.panel = .full } } }
            Text("Changer de version reprend au même moment.").font(P.font(21)).foregroundStyle(.white.opacity(0.6)).padding(.top, 8)
        case "image":
            ForEach(PlayerUI.aspects, id: \.0) { a in choice(a.1, on: a.0 == m.aspect, key: "i" + a.0) { m.setAspect(a.0); m.panel = .full } }
        case "night":
            ForEach(PlayerUI.nights, id: \.0) { a in choice(a.1, on: a.0 == m.night, key: "n" + a.0) { m.setNight(a.0); m.panel = .full } }
            Text("Voix plus claires et sons forts adoucis (égaliseur et compresseur de VLC). L'activer ou le couper relance la lecture au même moment.")
                .font(P.font(21)).foregroundStyle(.white.opacity(0.6)).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
        default:
            ForEach(m.info, id: \.0) { r in
                HStack { Text(r.0).font(P.font(23)).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(r.1).font(P.font(23, .semibold)) }.padding(.vertical, 6)
            }
            Button { m.panel = .full } label: { Text("Retour").font(P.font(22, .bold)).padding(.horizontal, 24).frame(height: 54) }
                .buttonStyle(PlayerChipStyle()).focused($focus, equals: "info-back").padding(.top, 10)
        }
    }

    private func row(_ k: String) -> some View {
        let l = m.label(k)
        return rowButton(icon: l.icon, title: l.title, value: l.value, key: k) {
            m.used(k)
            if k == "bedstop" { m.setBedStop(!m.bedStop) } else if k == "stopafter" { m.setStopAfter(!m.stopAfter) } else { m.panel = .sub(k) }
        }
    }

    private func rowButton(icon: String, title: String, value: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: { m.touch(); action() }) {
            HStack(spacing: 22) {
                Image(systemName: icon).font(.system(size: 26, weight: .medium)).frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(P.font(27, .bold))
                    if !value.isEmpty { Text(value).font(P.font(21)).opacity(0.75).lineLimit(1) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold)).opacity(0.6)
            }
            .padding(.horizontal, 22).frame(height: 88)
        }
        .buttonStyle(PlayerRowStyle())
        .focused($focus, equals: key)
    }

    private func choice(_ t: String, on: Bool, key: String, action: @escaping () -> Void) -> some View {
        Button(action: { m.touch(); action() }) {
            HStack {
                Text(t).font(P.font(26, .semibold)).lineLimit(1)
                Spacer()
                if on { Image(systemName: "checkmark").font(.system(size: 22, weight: .bold)) }
            }
            .padding(.horizontal, 24).frame(height: 76)
        }
        .buttonStyle(PlayerRowStyle())
        .focused($focus, equals: key)
    }

    private func panelBG(_ r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
    }

    /// La sélection arrive sur la dernière option utilisée (« le panneau se souvient »), ou sur l'option choisie dans une sous-liste.
    private func placeFocus(_ p: PlayerUI.Panel, from old: PlayerUI.Panel = .none) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            switch p {
            case .shortcuts: focus = m.shortcuts.contains(m.lastKey) ? m.lastKey : m.shortcuts.first
            case .full where m.live: focus = "ch\(m.cur)"
            case .full where m.series:
                // retour d'une sous-liste : sur sa pastille ; sinon sur l'épisode en cours
                if case let .sub(k) = old { focus = "c-" + k; return }
                m.epSeason = m.episodes.first { $0.id == m.epCur }?.season ?? m.epSeason
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focus = "ep" + m.epCur }
            case .full: focus = ["audio", "subs", "version", "image", "night", "bedstop", "info"].contains(m.lastKey) ? m.lastKey : "audio"
            case let .sub(k):
                switch k {
                case "audio": focus = "a\(m.audioCur)"
                case "subs": focus = "s\(m.subCur)"
                case "version": focus = "v\(m.versionCur)"
                case "image": focus = "i" + m.aspect
                case "night": focus = "n" + m.night
                default: focus = "info-back"
                }
            case .none: focus = nil
            }
        }
    }

    // MARK: « Tu regardes toujours ? » et messages

    private func sleepModal(_ s: Int) -> some View {
        ZStack {
            // simulateur : fond noir 50 % + flou de ce qui est derrière (.modal)
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).overlay(Color.black.opacity(0.5)).ignoresSafeArea()
            VStack(spacing: 26) {
                Text("Tu regardes toujours ?").font(P.font(50, .bold))
                (Text("Aucune touche depuis 90 min. Sans réponse dans ") + Text("\(s)").bold() + Text(" s, prisme met en pause et garde ta place là où tu as arrêté de réagir."))
                    .font(P.font(25)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85)).frame(width: 920)
                HStack(spacing: 14) {
                    Button { m.stillWatching() } label: { Text("Oui, je regarde").font(P.font(26, .bold)).padding(.horizontal, 32).frame(height: 66) }
                        .buttonStyle(PlayerRowStyle()).focused($focus, equals: "sleep-yes")
                    Button { m.pauseForLater() } label: { Text("Pause, je reprendrai plus tard").font(P.font(26, .bold)).padding(.horizontal, 32).frame(height: 66) }
                        .buttonStyle(PlayerChipStyle()).focused($focus, equals: "sleep-no")
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 56).padding(.horizontal, 60).frame(width: 1034)
            .background(panelBG(44))
            .onExitCommand { m.stillWatching() }
        }
    }

    private func messageCard(_ t: String) -> some View {
        Text(t).font(P.font(30, .medium)).multilineTextAlignment(.center).lineSpacing(6)
            .padding(.vertical, 46).padding(.horizontal, 60).frame(maxWidth: 1100)
            .background(panelBG(40))
    }
}

private extension PlayerUI.Panel { var isSub: Bool { if case .sub = self { return true }; return false } }

struct PlayerRowStyle: ButtonStyle {
    /// chaîne en cours dans la liste du direct (simulateur .pb-ch.cur) : fond léger
    var current = false
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, current: current) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let current: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color.white.opacity(current ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(f ? 1.02 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

struct PlayerChipStyle: ButtonStyle {
    var on = false
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, on: on) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let on: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color.white.opacity(on ? 0.22 : 0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(f ? 0 : 0.25), lineWidth: 1.5))
                .scaleEffect(f ? 1.05 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}
