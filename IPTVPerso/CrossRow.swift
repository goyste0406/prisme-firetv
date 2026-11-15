import SwiftUI

/// « Si tu hésites encore » / « Pour vous deux » (simulateur xSimHtml) : pastilles de mode, affiches avec leur
/// pourcentage et la raison principale, options en maintenant le clic, fenêtre « Comment on choisit ».
struct CrossRow: View {
    let kind: MediaKind
    let base: Fiche?
    let title: String
    /// titres proches déjà trouvés par la fiche (genres et mots-clés TMDB), avec leur fiche
    let cands: [MediaItem]
    /// titres à ne pas proposer ici (saga, même univers : déjà montrés plus haut sur la fiche)
    let skip: Set<String>
    var posterWidth: CGFloat = 255
    var columns: Int? = nil
    let open: (MediaItem) -> Void

    @EnvironmentObject var store: ProviderStore
    @ObservedObject var ps = ProfileStore.shared
    @ObservedObject var tasteStore = TasteStore.shared
    @State private var mode: CrossMode = .mix
    @State private var res: [CrossPickResult] = []
    @State private var recs: Set<Int> = []
    @State private var extra: [MediaItem] = []
    @State private var models: [TasteModel] = []
    @State private var info = false
    @State private var whyOf: CrossPickResult?
    @State private var hidden = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !res.isEmpty {
                SectionTitle(title: ps.isDuo ? "Pour vous deux" : (kind == .film ? "Si tu hésites encore" : "Séries proches"),
                             sub: (ps.isDuo ? "selon ce titre et vos goûts" : "selon ce titre et ce que tu regardes") + " · maintiens le clic pour les options")
                    .padding(.bottom, 14)
                chips.padding(.bottom, 6)
                if let n = columns {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(posterWidth), spacing: 28), count: n), alignment: .leading, spacing: 30) {
                        ForEach(res) { r in card(r) }
                    }.padding(.vertical, 24)
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 33) { ForEach(res) { r in card(r) } }
                            .padding(.horizontal, 120).padding(.vertical, 24)
                    }
                    .scrollClipDisabled()
                    .padding(.horizontal, -120)
                }
            }
        }
        .focusSection()
        .task(id: "\(base?.tmdb ?? 0)|\(cands.count)") {
            guard let b = base else { return }
            let r = await TmdbRecs.load(kind: kind, tmdb: b.tmdb)
            recs = Set(r)
            // recommandations TMDB présentes chez tes fournisseurs, en plus des titres proches
            let have = Set(cands.compactMap { $0.fiche?.tmdb })
            let want = r.filter { !have.contains($0) && $0 != b.tmdb }.prefix(40)
            extra = Array(await MediaStore.items(kind: kind, tmdb: Array(want), pids: store.active.map(\.id)).values).filter { $0.fiche != nil && $0.allowedForProfile }
            await compute()
        }
        .task(id: "\(ps.version)|\(tasteStore.version)|\(mode.rawValue)") { await compute() }
        .fullScreenCover(isPresented: $info) { CrossInfo(mode: mode, models: models, names: ps.watchers.map(\.name), close: { info = false }) }
        .alert(item: $whyOf) { r in
            Alert(title: Text("Pourquoi " + r.item.displayTitle + " ?"),
                  message: Text((r.whyAll.isEmpty ? ["Proche de ce titre"] : r.whyAll).joined(separator: "\n") + "\n\n" + partsLine(r)),
                  dismissButton: .cancel(Text("Fermer")))
        }
    }

    private var chips: some View {
        HStack(spacing: 12) {
            ForEach(CrossMode.allCases) { m in
                Button { mode = m } label: { Text(m.label) }.buttonStyle(XModeStyle(selected: mode == m))
            }
            Button { info = true } label: { Text("ⓘ Comment on choisit") }.buttonStyle(XModeStyle(selected: false)).padding(.leading, 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private func card(_ r: CrossPickResult) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            PosterButton(item: r.item, width: posterWidth, bare: true) { open(r.item) }
                .overlay(alignment: .topLeading) { pctBadge(r).padding(12).allowsHitTesting(false) }
                .contextMenu {
                    Button("Pourquoi ce titre ?") { whyOf = r }
                    Button("Pas intéressé") {
                        NotInterested.add(r.item.workKey, pid: ps.me.id)
                        hidden.insert(r.item.workKey); res.removeAll { $0.item.workKey == r.item.workKey }
                    }
                    Button("Ouvrir la fiche") { open(r.item) }
                }
            Text(r.why).font(P.font(19.5)).lineSpacing(3).foregroundStyle(.white.opacity(0.78)).lineLimit(2)
                .frame(width: posterWidth, height: 52, alignment: .topLeading)
        }
    }

    @ViewBuilder private func pctBadge(_ r: CrossPickResult) -> some View {
        Group {
            if let a = r.pA, let b = r.pB, ps.watchers.count == 2 {
                HStack(spacing: 6) {
                    ProfileDot(p: ps.watchers[0], size: 22); Text("\(a)")
                    ProfileDot(p: ps.watchers[1], size: 22); Text("\(b)")
                }
            } else {
                Text("\(r.pct) %")
            }
        }
        .font(P.font(18, .heavy)).foregroundStyle(P.gold)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func partsLine(_ r: CrossPickResult) -> String {
        mode.weights.filter { $0.1 > 0 }.map { k, w in
            "\(CrossMode.partLabel[k] ?? k) \(Int(((r.parts[k] ?? 0) * 100).rounded())) % × \(Int((w * 100).rounded())) %"
        }.joined(separator: " · ")
    }

    private func compute() async {
        guard let b = base else { res = []; return }
        var ms: [TasteModel] = []
        for w in ps.watchers { ms.append(await tasteStore.model(w.id)) }
        models = ms
        // déjà vus en entier, « pas intéressé », le titre lui-même, la saga et l'univers (déjà sur la fiche)
        let seen = Set(WatchStore.entries(for: ps.me.id).values.filter { $0.dur > 0 && $0.pos / $0.dur >= 0.85 }.map(\.item))
        let no = NotInterested.list(ps.me.id).union(hidden)
        var keys = Set<String>()
        let pool = (cands + extra).filter { it in
            it.fiche?.tmdb != b.tmdb && !skip.contains(it.workKey) && !no.contains(it.workKey) && !seen.contains(it.id) && keys.insert(it.workKey).inserted
        }
        let m = mode, r = recs, t = title
        res = await Task.detached(priority: .userInitiated) { CrossPick.pick(base: b, title: t, cands: pool, recs: r, models: ms, mode: m) }.value
    }
}

/// Pastille de mode (simulateur .xm) : verre léger, choisie plus claire, sélectionnée blanche.
struct XModeStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyle.Configuration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.font(P.font(21, .semibold)).foregroundStyle(f ? Color.black : .white)
                .padding(.horizontal, 24).frame(height: 57)
                .background(Capsule().fill(f ? Color.white : Color.white.opacity(selected ? 0.2 : 0.07)))
                .overlay(Capsule().stroke(Color.white.opacity(f ? 0 : (selected ? 0.35 : 0.12)), lineWidth: 1.5))
                .scaleEffect(f ? 1.05 : (c.isPressed ? 0.97 : 1))
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// Petite pastille ronde aux couleurs d'un profil (initiale).
struct ProfileDot: View {
    let p: Profile
    var size: CGFloat = 22
    var body: some View {
        Text(String(p.name.prefix(1)).uppercased()).font(P.font(size * 0.55, .heavy)).foregroundStyle(.white)
            .frame(width: size, height: size).background(Circle().fill(Profile.colors[p.color % Profile.colors.count]))
    }
}

/// « Comment prisme choisit » (simulateur fxxinfo) : ton profil à gauche, le calcul du mode à droite.
struct CrossInfo: View {
    let mode: CrossMode
    let models: [TasteModel]
    let names: [String]
    let close: () -> Void
    @FocusState private var f: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("TMDB × " + names.joined(separator: " + ").uppercased()).font(P.font(19, .bold)).tracking(2.4).foregroundStyle(.white.opacity(0.6))
                Text("Comment prisme choisit").font(P.font(42, .bold))
                HStack(alignment: .top, spacing: 60) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TON PROFIL").font(P.font(17, .bold)).tracking(2).foregroundStyle(.white.opacity(0.55))
                        if let m = models.first, !m.isEmpty, !m.topGenres.isEmpty {
                            ForEach(Array(m.topGenres.prefix(4).enumerated()), id: \.offset) { _, g in bar(g.0, g.1, P.gold) }
                        } else {
                            Text("Rien de connu pour l'instant : les recommandations s'appuient sur ce titre. Elles deviennent personnelles avec le test des goûts et au fil de ce que tu finis.")
                                .font(P.font(21)).foregroundStyle(.white.opacity(0.75)).lineSpacing(4)
                        }
                    }.frame(width: 640, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LE CALCUL").font(P.font(17, .bold)).tracking(2).foregroundStyle(.white.opacity(0.55))
                        ForEach(mode.weights.filter { $0.1 > 0 }, id: \.0) { k, w in
                            bar(CrossMode.partLabel[k] ?? k, min(1, w * 2), CrossMode.partColor[k] ?? .white, value: "\(Int((w * 100).rounded())) %")
                        }
                        Text("Retirés : titres vus, « pas intéressé », absents de tes fournisseurs. La rangée est ensuite diversifiée.")
                            .font(P.font(19)).foregroundStyle(.white.opacity(0.65)).padding(.top, 6)
                    }.frame(width: 640, alignment: .topLeading)
                }
                Button(action: close) { Text("Fermer").font(P.font(25, .bold)).frame(maxWidth: .infinity).frame(height: 72) }
                    .buttonStyle(GlassStyle(radius: 20, minH: 72)).focused($f).padding(.top, 10)
            }
            .padding(46).frame(width: 1440).glass(36)
        }
        .onExitCommand(perform: close)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { f = true } }
    }

    private func bar(_ label: String, _ v: Double, _ c: Color, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            Circle().fill(c).frame(width: 10, height: 10)
            Text(label).font(P.font(21)).frame(width: 250, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                GeometryReader { g in Capsule().fill(c).frame(width: g.size.width * max(0.02, v)) }
            }.frame(width: 210, height: 9)
            Text(value ?? "\(Int((v * 100).rounded())) %").font(P.font(19)).foregroundStyle(.white.opacity(0.7))
        }
    }
}
