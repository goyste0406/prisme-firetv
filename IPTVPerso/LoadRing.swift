import SwiftUI

// MARK: - 253 : anneau de chargement de la barre du haut (simulateur .fcring / .fcpop)
//
// Juste après l'avatar : le pourcentage pendant l'import des sources puis le téléchargement des fiches TMDB,
// ⏸ quand les fiches attendent la fin de la lecture, ✓ vert une fois fini (quelques secondes), puis il disparaît.
// Sélectionné : le détail (Sources, Films, Séries) ; OK ouvre Réglages › Accueils et notes (réglage des fiches).
//
// Stabilité : l'anneau garde toujours la même taille. Il n'apparaît qu'après 2 s d'activité et n'est redessiné
// qu'une fois par seconde, pour ne pas faire recalculer la zone de sélection de la barre du haut à chaque avancée.

@MainActor
final class LoadRing: ObservableObject {
    static let shared = LoadRing()
    enum Mode: Equatable { case hidden, running(Int), paused(Int), done }
    @Published private(set) var mode: Mode = .hidden
    /// détail : (libellé, fait, total, couleur)
    @Published private(set) var lines: [(String, Int, Int, Color)] = []
    @Published private(set) var status = ""
    /// l'anneau est sélectionné : le détail s'affiche par-dessus la page (MainTabView)
    @Published var focused = false
    private var activeSince: Date?
    private var doneAt: Date?
    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in Task { @MainActor in LoadRing.shared.tick() } }
    }

    private func tick() {
        // simulateur de test seulement : état forcé pour les captures (« running », « paused », « done »)
        if let d = Debug.arg("prisme.debug.ring") {
            let m: Mode = d == "paused" ? .paused(42) : d == "done" ? .done : .running(42)
            if mode != m {
                lines = [("Sources", 100, 100, Color(hex: "#f47a7a")), ("Films", 21, 50, Color(hex: "#7dd3fc")), ("Séries", 0, 30, Color(hex: "#a78bfa"))]
                status = d == "paused" ? "en pause pendant la lecture" : d == "done" ? "à jour · 80 fiches" : "21 / 80"
                mode = m
            }
            return
        }
        let st = ProviderStore.shared, f = FicheService.shared
        let importing = st.importing != nil
        let fiches = f.running && f.total > 0 && f.done < f.total
        var L: [(String, Int, Int, Color)] = []
        if importing { L.append(("Sources", Int(st.progress * 100), 100, Color(hex: "#f47a7a"))) }
        if f.total > 0 {
            for (k, n, c) in [("film", "Films", "#7dd3fc"), ("series", "Séries", "#a78bfa")] where (f.kindTotal[k] ?? 0) > 0 {
                L.append((n, f.kindDone[k] ?? 0, f.kindTotal[k] ?? 0, Color(hex: c)))
            }
        }
        let active = importing || fiches
        var next = mode
        if active {
            doneAt = nil
            if activeSince == nil { activeSince = Date() }
            // pas d'anneau pour une activité de moins de 2 s (évite qu'il clignote)
            if Date().timeIntervalSince(activeSince!) >= 2 {
                let pct = importing ? Int(st.progress * 100) : Int(Double(f.done) / Double(max(1, f.total)) * 100)
                let p = max(0, min(99, pct))
                next = (!importing && PlaybackActivity.playing && FicheGate.pausesForPlayback) ? .paused(p) : .running(p)
                status = importing ? (st.status.isEmpty ? "import des sources" : st.status)
                    : (PlaybackActivity.playing && FicheGate.pausesForPlayback ? "en pause pendant la lecture" : "\(f.done) / \(f.total)")
            }
        } else {
            activeSince = nil
            switch mode {
            case .running, .paused:
                next = .done; doneAt = Date()
                status = f.total > 0 ? "à jour · \(f.done) fiches" : "à jour"
            case .done:
                if let d = doneAt, Date().timeIntervalSince(d) > 8 { next = .hidden }
            case .hidden: break
            }
        }
        if next != mode { mode = next }
        if lines.map(\.0) != L.map(\.0) || zip(lines, L).contains(where: { $0.1 != $1.1 || $0.2 != $1.2 }) { lines = L }
    }
}

/// Bouton de la barre du haut (simulateur .tab.fcring : 46 × 46, anneau de 36, trait de 3).
struct LoadRingButton: View {
    @ObservedObject var ring = LoadRing.shared
    @ObservedObject var nav = Nav.shared
    @FocusState private var f: Bool
    var body: some View {
        if ring.mode != .hidden {
            Button {
                nav.openSettings = "homes"
                nav.tab = .settings
            } label: {
                ZStack {
                    Circle().stroke((f ? Color.black : Color.white).opacity(0.18), lineWidth: 4.5)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(ring.mode == .done ? Color(hex: "#22c55e") : Color(hex: f ? "#0a84ff" : "#7dd3fc"), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: fraction)
                    // simulateur .fcn : 13 px pour ⏸ / ✓, 11 px pour un pourcentage (× 1,5 sur la TV)
                    Text(label).font(P.font(label.first?.isNumber == true ? 16.5 : 19.5, .heavy)).monospacedDigit()
                        .foregroundStyle(f ? Color.black : Color.white)
                }
                .frame(width: 54, height: 54)
                .frame(width: 69, height: 69)
                .background(Circle().fill(f ? Color.white : .clear))
                .scaleEffect(f ? 1.08 : 1)
                .animation(.easeOut(duration: 0.18), value: f)
            }
            .buttonStyle(RingBareStyle())
            .focused($f)
            .accessibilityLabel("Chargement " + ring.status)
            .onChange(of: f) { _, v in ring.focused = v }
            .onDisappear { ring.focused = false }
        }
    }
    private var fraction: CGFloat {
        switch ring.mode {
        case .running(let p), .paused(let p): return CGFloat(p) / 100
        case .done: return 1
        case .hidden: return 0
        }
    }
    private var label: String {
        switch ring.mode {
        case .running(let p): return "\(p)"
        case .paused: return "⏸"
        case .done: return "✓"
        case .hidden: return ""
        }
    }
}

/// Détail (simulateur .fcpop : 380 px, verre sombre, une barre par sorte).
struct LoadRingPopup: View {
    @ObservedObject var ring = LoadRing.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ring.mode == .done ? "Fiches à jour" : "Chargement en cours").font(P.font(27, .bold)).padding(.bottom, 6)
            Text(ring.status).font(P.font(21)).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
            ForEach(Array(ring.lines.enumerated()), id: \.offset) { _, l in
                HStack(spacing: 15) {
                    Text(l.0).font(P.font(21)).frame(width: 93, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(l.3).frame(width: g.size.width * CGFloat(l.1) / CGFloat(max(1, l.2)))
                        }
                    }.frame(height: 9)
                    Text(l.0 == "Sources" ? "\(l.1) %" : "\(l.1) / \(l.2)").font(P.font(21)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.72)).frame(width: 165, alignment: .trailing)
                }
                .padding(.top, 15)
            }
            Text("OK : ouvrir le réglage").font(P.font(19)).foregroundStyle(.white.opacity(0.72)).padding(.top, 15)
        }
        .padding(.horizontal, 30).padding(.vertical, 27)
        .frame(width: 570, alignment: .leading)
        .background(Color(red: 28 / 255, green: 31 / 255, blue: 42 / 255).opacity(0.62), in: RoundedRectangle(cornerRadius: 33, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 33, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 33, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
    }
}

/// Bouton sans effet système : l'anneau dessine lui-même son état sélectionné (cercle blanc, comme les onglets).
struct RingBareStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { c.label }
}

struct RingPopupHost: View {
    @ObservedObject var ring = LoadRing.shared
    var body: some View {
        if ring.focused && ring.mode != .hidden { LoadRingPopup().transition(.opacity) }
    }
}
