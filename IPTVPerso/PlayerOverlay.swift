import SwiftUI

// MARK: - Interface du lecteur (simulateur) : bandeau bas (titre, progression, « Qu'a-t-il dit ? »), heure et « fin à »,
// panneau « Raccourcis » (↑) puis « Lecture » (↑ encore ou OK), sous-listes (Audio, Sous-titres, Version, Image, Son de nuit,
// Infos du flux), « Tu regardes toujours ? » et les messages (fin de partie 1, arrêt au coucher).
// La lecture elle-même reste dans VLC (VodPlayerController) ; cet écran ne fait que montrer et transmettre les choix.

struct PlayerOption: Identifiable, Equatable { let id: Int32; let name: String }

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
    @Published var hint = "↑ raccourcis puis tous les réglages · ↓ options · ⏯ pause · Retour maintenu : quitter"
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

    // MARK: habitudes (par profil) : les 3 raccourcis = les 3 réglages les plus utilisés

    private static let order = ["audio", "subs", "version", "image", "night", "bedstop", "info"]
    private var usageKey: String { ProfileStore.shared.key("prisme.player.usage") }
    var shortcuts: [String] {
        let u = (UserDefaults.standard.dictionary(forKey: usageKey) as? [String: Int]) ?? [:]
        let L = PlayerUI.order.filter { $0 != "version" || versions.count > 1 }
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
        case "version": return ("square.stack.3d.up", "Version", versions.indices.contains(versionCur) ? versions[versionCur] + " · \(versions.count) dispo" : "Version unique")
        case "image": return ("viewfinder", "Image", PlayerUI.aspects.first { $0.0 == aspect }?.1 ?? "Auto")
        case "night": return ("moon", "Son de nuit", (night == "auto" ? "Auto après " + Self.hm(bedMinutes) : night == "on" ? "Toujours" : "Jamais") + (nightActive ? " · actif" : ""))
        case "bedstop": return ("bed.double", "Arrêt à " + Self.hm(bedMinutes), bedStop ? "Activé" : "Désactivé")
        default: return ("info.circle", "Infos du flux", info.first?.1 ?? "")
        }
    }

    static func hm(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
    static func hms(_ t: Double) -> String {
        let s = max(0, Int(t)), h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
    var endText: String { dur > 0 ? Fmt.hm(Date().addingTimeInterval(dur - pos)) : "" }

    /// Retour : remonte d'un niveau (sous-liste → Lecture → Raccourcis → fermé)
    func back() {
        touch()
        switch panel {
        case .sub: panel = .full
        case .full: panel = .shortcuts
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
            if m.panel != .none { panel.transition(.move(edge: .trailing).combined(with: .opacity)) }
            if let t = m.toast {
                Text(t).font(P.font(26, .semibold)).padding(.horizontal, 30).frame(height: 66)
                    .background(.ultraThinMaterial, in: Capsule()).environment(\.colorScheme, .dark)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 70)
            }
            if let s = m.sleepLeft { sleepModal(s) }
            if let msg = m.message, m.sleepLeft == nil { messageCard(msg) }
        }
        .foregroundStyle(.white)
        .animation(.easeOut(duration: 0.25), value: m.panel)
        .animation(.easeOut(duration: 0.25), value: m.osd)
        .onReceive(clock) { now = $0 }
        .onChange(of: m.panel) { _, p in placeFocus(p) }
        .onChange(of: m.options) { _, o in if o { focus = "said" } }
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
                Text(PlayerUI.hms(shownPos)).font(P.font(28)).monospacedDigit()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18)).frame(height: 12)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: max(0, g.size.width * frac), height: 12)
                        Circle().fill(Color.white).frame(width: 38, height: 38).offset(x: max(0, g.size.width * frac - 19))
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 40)
                Text("−" + PlayerUI.hms(max(0, m.dur - shownPos))).font(P.font(28)).monospacedDigit()
                    + Text(m.pending != 0 ? String(format: "  (%@%d s)", m.pending > 0 ? "+" : "−", Int(abs(m.pending))) : "").font(P.font(24, .bold))
            }
            .padding(.top, 22)
            Text(m.hint).font(P.font(21)).foregroundStyle(.white.opacity(0.6)).padding(.top, 10)
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
        .padding(.leading, 86).padding(.trailing, 86 + right).padding(.bottom, 58)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .onExitCommand { m.back() }
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
                rowButton(icon: "rectangle.grid.1x2", title: "Tous les réglages", value: "↑ ou OK", key: "all") { m.panel = .full }
            }
            .padding(28).frame(width: 565)
            .background(panelBG(36))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 37).padding(.bottom, 37)
            .onMoveCommand { d in if d == .up, focus == m.shortcuts.first { m.panel = .full } }
            .onExitCommand { m.back() }
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if case let .sub(k) = m.panel {
                        Label(m.label(k).title, systemImage: "chevron.left").font(P.font(34, .bold))
                    } else {
                        Text("Lecture").font(P.font(36, .bold))
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
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 30).padding(.top, 34).padding(.bottom, 24)
            .frame(width: 720).frame(maxHeight: .infinity)
            .background(panelBG(44))
            .padding(.vertical, 37).padding(.trailing, 37)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onExitCommand { m.back() }
        }
    }

    @ViewBuilder private var fullList: some View {
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
            ForEach(m.versions.indices, id: \.self) { i in choice(m.versions[i], on: i == m.versionCur, key: "v\(i)") { m.setVersion(i); m.panel = .full } }
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
            if k == "bedstop" { m.setBedStop(!m.bedStop) } else { m.panel = .sub(k) }
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
    private func placeFocus(_ p: PlayerUI.Panel) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            switch p {
            case .shortcuts: focus = m.shortcuts.contains(m.lastKey) ? m.lastKey : m.shortcuts.first
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
            Color.black.opacity(0.6).ignoresSafeArea()
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
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
