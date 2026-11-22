import SwiftUI
import TVVLCKit

// MARK: - Lot 5 : TV en direct (simulateur lopen, LMODAL.lstart, lbgPlay)
// - choix de la source quand « Toujours ouvrir la meilleure source » est désactivé, sources mémorisées après 3 choix identiques
// - « Depuis le début ? » quand le programme a commencé et que la chaîne a le replay
// - aperçu vidéo en fond (muet) de la chaîne de l'en-tête

/// Ce que le lanceur de chaîne doit faire avant de lire.
enum LiveGate {
    enum Step { case play([Channel], Int), pickSource([Channel], Int, LiveIndex.Entry), askStart([Channel], Int, LiveStore.Airing) }

    /// décide : reprise au début ? choix de la source ? source mémorisée ?
    @MainActor static func decide(_ list: [Channel], _ i: Int, skipStart: Bool = false) async -> Step {
        guard list.indices.contains(i) else { return .play(list, i) }
        let ch = list[i]
        if !skipStart, (UserDefaults.standard.object(forKey: "prisme.pref.startAsk") as? Bool ?? true), let a = await startable(ch) {
            return .askStart(list, i, a)
        }
        guard let e = LiveIndex.entry(ch), e.sources > 1 else { return .play(list, i) }
        if let d = LiveMemory.shared.direct[e.key], let c = e.copies.first(where: { $0.id == d }) {
            var L = list; L[i] = c
            AppToast.shared.say("Source habituelle : " + LiveSourceLabel.text(c))
            return .play(L, i)
        }
        if !(UserDefaults.standard.object(forKey: "prisme.pref.lbest") as? Bool ?? true) { return .pickSource(list, i, e) }
        return .play(list, i)
    }

    /// programme en cours depuis au moins 3 minutes, sur une chaîne (ou une copie) qui a le replay
    @MainActor static func startable(_ ch: Channel) async -> LiveStore.Airing? {
        let copies = LiveIndex.entry(ch)?.copies ?? [ch]
        guard let c = copies.first(where: { $0.archive > 0 }) ?? (ch.archive > 0 ? ch : nil) else { return nil }
        let progs = await LiveStore.programs(c.epg.isEmpty ? ch : c, from: Date().addingTimeInterval(-6 * 3600), hours: 8)
        let now = Date()
        guard let p = progs.first(where: { $0.startDate <= now && $0.stopDate > now }), now.timeIntervalSince(p.startDate) >= 180 else { return nil }
        return LiveStore.Airing(ch: c, p: p)
    }
}

/// « Depuis le début ? » (simulateur lstartm) : chaîne, programme, frise début → maintenant → fin, deux boutons et « Ne plus demander ».
struct LiveStartModal: View {
    let a: LiveStore.Airing
    let univers: String
    let begin: () -> Void
    let live: () -> Void
    let never: () -> Void
    @FocusState private var f: String?
    private var pct: Double { a.p.progress() }
    private var ago: Int { max(1, Int(Date().timeIntervalSince(a.p.startDate) / 60)) }
    /// cinéma, séries, découverte, jeunesse : « Depuis le début » sélectionné d'office (sinon le direct)
    private var begFirst: Bool { ["Cinéma", "Séries", "Découverte", "Jeunesse"].contains(univers) }
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 22) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)).frame(width: 180, height: 102)
                        ChannelChip(name: ChannelTools.clean(a.ch.name), icon: a.ch.icon, height: 44).padding(12)
                        Text("DIRECT").font(P.font(15, .heavy)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(P.live, in: RoundedRectangle(cornerRadius: 6)).padding(8)
                            .frame(width: 180, height: 102, alignment: .bottomTrailing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text((ChannelTools.clean(a.ch.name) + " · " + univers).uppercased()).font(P.font(18, .heavy)).tracking(1.8).opacity(0.7)
                        Text(a.p.title).font(P.font(33, .bold)).lineLimit(1)
                        Text("a commencé il y a " + runtimeText(ago) + " · replay disponible").font(P.font(21)).foregroundStyle(P.dim)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16)).frame(height: 8)
                            Capsule().fill(Color.white).frame(width: g.size.width * pct, height: 8)
                            Circle().fill(Color.white).frame(width: 18, height: 18).offset(x: g.size.width * pct - 9)
                        }
                    }.frame(height: 18)
                    HStack {
                        Text("↺ " + Fmt.hm(a.p.startDate) + " début"); Spacer()
                        Text("maintenant " + Fmt.hm(Date())).foregroundStyle(.white); Spacer()
                        Text("fin " + Fmt.hm(a.p.stopDate))
                    }.font(P.font(18)).foregroundStyle(P.dim)
                }
                HStack(spacing: 18) {
                    Button(action: begin) { Text("↺ Depuis le début").font(P.font(25, .semibold)).padding(.horizontal, 30).frame(height: 72) }
                        .buttonStyle(PrefRowStyle()).focused($f, equals: "beg").accessibilityIdentifier("st-beg")
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.25), lineWidth: 1.5).allowsHitTesting(false))
                    Button(action: live) { Text("● Rejoindre le direct").font(P.font(25, .semibold)).padding(.horizontal, 30).frame(height: 72) }
                        .buttonStyle(PrefRowStyle()).focused($f, equals: "live").accessibilityIdentifier("st-live")
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.25), lineWidth: 1.5).allowsHitTesting(false))
                }
                Button(action: never) { Text("Ne plus demander · toujours le direct").font(P.font(20)).padding(.horizontal, 14).frame(height: 50) }
                    .buttonStyle(PrefRowStyle()).focused($f, equals: "never").accessibilityIdentifier("st-never").opacity(0.8)
            }
            .padding(42).frame(width: 980)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(red: 20 / 255, green: 22 / 255, blue: 30 / 255).opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5)))
            .environment(\.colorScheme, .dark)
            .focusSection()
            .accessibilityIdentifier("lstart")
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { f = begFirst ? "beg" : "live" } }
        .onExitCommand(perform: live)
    }
}

/// Choix de la source d'une chaîne (simulateur : fenêtre des sources quand « Toujours ouvrir la meilleure source » est désactivé).
struct LiveSourceModal: View {
    let e: LiveIndex.Entry
    let pick: (Channel) -> Void
    let close: () -> Void
    @FocusState private var f: Int?
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(e.name.uppercased() + " · \(e.sources) SOURCES").font(P.font(18, .heavy)).tracking(1.8).opacity(0.7)
                Text("Quelle source ?").font(P.font(33, .bold))
                ForEach(Array(e.copies.enumerated()), id: \.element.id) { i, c in
                    Button { pick(c) } label: {
                        HStack(spacing: 16) {
                            Text(LiveSourceLabel.text(c)).font(P.font(24, .semibold))
                            if i == 0 { RecBadge() }
                            Spacer()
                            if LiveMemory.shared.direct[e.key] == c.id { Image(systemName: "checkmark") }
                        }
                        .padding(.horizontal, 24).frame(height: 76)
                    }
                    .buttonStyle(PrefRowStyle()).focused($f, equals: i).accessibilityIdentifier("src-\(i)")
                }
                Text("prisme te proposera de retenir une source après 3 choix identiques · Retour pour fermer").font(P.font(18)).foregroundStyle(P.faint)
            }
            .padding(40).frame(width: 860)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(red: 20 / 255, green: 22 / 255, blue: 30 / 255).opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5)))
            .environment(\.colorScheme, .dark)
            .focusSection()
            .accessibilityIdentifier("lsrc")
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { f = 0 } }
        .onExitCommand(perform: close)
    }
}

/// Aperçu vidéo en fond (muet) d'une chaîne : lecteur VLC sans son, coupé dès qu'une lecture démarre.
struct LivePreviewVideo: UIViewRepresentable {
    let url: URL
    final class V: UIView {
        let player = VLCMediaPlayer()
        var current: URL?
        func load(_ u: URL) {
            guard u != current else { return }
            current = u
            player.stop()
            let m = VLCMedia(url: u)
            m.addOption(":no-audio")
            m.addOption(":network-caching=1200")
            player.media = m
            player.play()
            DataCount.write("aperçu vidéo : " + u.lastPathComponent)
        }
        deinit { player.stop() }
    }
    func makeUIView(context: Context) -> V {
        let v = V(); v.backgroundColor = .clear; v.player.drawable = v; v.isUserInteractionEnabled = false
        v.load(url); return v
    }
    func updateUIView(_ v: V, context: Context) { v.load(url) }
    static func dismantleUIView(_ v: V, coordinator: ()) { v.player.stop(); v.player.drawable = nil }
}
