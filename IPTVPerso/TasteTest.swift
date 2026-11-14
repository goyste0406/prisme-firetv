import SwiftUI

// MARK: - Test « Mes goûts » (présentation du simulateur : en-tête avatar + progression, cartes, duels, « Jamais de… »,
// résultat « Voici ce que prisme a compris »). Deux étapes ajoutées d'après les recherches (validées par Steven) :
// les ambiances (groupes de 3 affiches + 3 mots, méthode MovieLens) et le contexte (films / séries, soir de semaine).

struct TasteTestView: View {
    let pid: String
    let close: () -> Void
    @ObservedObject var ps = ProfileStore.shared
    @EnvironmentObject var store: ProviderStore

    enum Step: Equatable { case intro, card, duel, mood, never, result }
    enum Verdict { case like, no, unseen }
    enum Answer {
        case card(MediaItem, Verdict)
        case duel(TasteAxis, MediaItem, MediaItem, Int)   // 0 = le premier, 1 = le second, -1 = aucun
        case mood([String])
        case never
    }

    static let cardsTotal = 8, duelsTotal = 5
    private var total: Int { TasteTestView.cardsTotal + TasteTestView.duelsTotal + 2 }

    @State private var step: Step = .intro
    @State private var pool: [MediaItem] = []
    @State private var log: [Answer] = []
    @State private var current: MediaItem?
    @State private var duel: (TasteAxis, MediaItem, MediaItem)?
    @State private var moods: Set<String> = []
    @State private var never: Set<String> = []
    @State private var kindPref = "both"
    @State private var weeknight = "any"
    @State private var lang = "auto"
    @State private var recs: [(MediaItem, Int, String)] = []
    @State private var model = TasteModel()
    @State private var loading = true
    @FocusState private var focus: String?

    private var me: Profile { ps.profile(pid) ?? ps.me }
    private var cardsDone: Int { log.filter { if case .card = $0 { return true }; return false }.count }
    private var duelsDone: Int { log.filter { if case .duel = $0 { return true }; return false }.count }
    private var answered: Int { log.count }

    var body: some View {
        ZStack {
            Color(red: 11 / 255, green: 13 / 255, blue: 19 / 255)
            RadialGradient(colors: [me.tint.opacity(0.28), .clear], center: UnitPoint(x: 0.35, y: 0.25), startRadius: 0, endRadius: 1000)
            switch step {
            case .intro: intro
            default:
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Group {
                        switch step {
                        case .card: cardStep
                        case .duel: duelStep
                        case .mood: moodStep
                        case .never: neverStep
                        default: resultStep
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 84).padding(.top, 46).padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
        .task { await loadPool() }
        .onExitCommand { back() }
    }

    // MARK: en-tête (avatar, prénom, consigne, « 3 / 15 » et barre)

    private var header: some View {
        HStack(spacing: 22) {
            ProfileAvatar(p: me, size: 66)
            VStack(alignment: .leading, spacing: 2) {
                Text(me.name).font(P.font(30, .bold))
                Text(subtitle).font(P.font(22)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("\(min(total, answered + (step == .result ? 0 : 1))) / \(total)").font(P.font(23, .semibold)).foregroundStyle(.white.opacity(0.7))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(Color.white).frame(width: 390 * CGFloat(step == .result ? 1 : Double(answered) / Double(total)))
            }
            .frame(width: 390, height: 8)
            .animation(.easeOut(duration: 0.3), value: answered)
        }
        .frame(height: 70)
    }

    private var subtitle: String {
        switch step {
        case .card: return "Tu connais ? Dis-moi si tu aimes"
        case .duel: return "Ce soir, lequel te tente le plus ?"
        case .mood: return "Quelles ambiances te ressemblent ?"
        case .never: return "Dernière question"
        default: return "C'est prêt"
        }
    }

    // MARK: introduction

    private var intro: some View {
        VStack(spacing: 0) {
            ProfileAvatar(p: me, size: 144).padding(.top, 150)
            Text("Apprenons tes goûts, \(me.name)").font(P.font(64, .bold)).padding(.top, 40)
            Text("Quelques minutes, des titres de ton catalogue que beaucoup ont vus : prisme saura quoi te proposer dès ce soir. Ce que tu regardes ensuite comptera de plus en plus. Tu pourras le refaire dans Réglages › Profils.")
                .font(P.font(28)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).frame(width: 1140).padding(.top, 22)
            HStack(spacing: 24) {
                introCard("rectangle.on.rectangle", "\(TasteTestView.cardsTotal) titres", "J'aime, pas pour moi, pas vu : la suite s'adapte à tes réponses")
                introCard("scalemass", "\(TasteTestView.duelsTotal) duels", "Celui-ci ou celui-là ? Pour l'ambiance et le rythme")
                introCard("sparkles", "Ambiances", "Trois affiches, trois mots : ce qui te ressemble")
                introCard("nosign", "Jamais de…", "Ce que tu ne veux jamais voir proposé")
            }
            .padding(.top, 50)
            HStack(spacing: 16) {
                Button { start() } label: { Text(loading ? "Préparation…" : "Commencer").font(P.font(30, .bold)).padding(.horizontal, 38).frame(height: 76) }
                    .buttonStyle(TastePrimaryStyle()).focused($focus, equals: "start").disabled(loading || pool.count < 4)
                Button(action: close) { Text("Plus tard").font(P.font(28, .semibold)).padding(.horizontal, 34).frame(height: 72) }
                    .buttonStyle(ChipGlassStyle())
            }
            .padding(.top, 38)
            if !loading && pool.count < 4 {
                Text("Pas encore assez de fiches (TMDB) dans ton catalogue pour le test : reviens quand le téléchargement des fiches aura avancé.")
                    .font(P.font(23)).foregroundStyle(P.gold).padding(.top, 18)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "start" } }
    }

    private func introCard(_ icon: String, _ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .regular))
            Text(t).font(P.font(27, .bold))
            Text(s).font(P.font(21)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(26).frame(width: 330, height: 210, alignment: .topLeading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
    }

    // MARK: 1. titres (une carte à la fois)

    private var cardStep: some View {
        ZStack(alignment: .topLeading) {
            learnBox.padding(.top, 110)
            VStack(spacing: 0) {
                if let it = current {
                    tasteCard(it, w: 470, h: 650).padding(.top, 30)
                    Text(it.fiche?.overview ?? "").font(P.font(23)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                        .multilineTextAlignment(.center).frame(width: 960).padding(.top, 18)
                    Spacer(minLength: 10)
                    HStack(spacing: 24) {
                        Button { answerCard(.no) } label: { Label("Pas pour moi", systemImage: "hand.thumbsdown").font(P.font(28, .semibold)).frame(width: 330, height: 72) }
                            .buttonStyle(ChipGlassStyle()).focused($focus, equals: "no")
                        Button { answerCard(.unseen) } label: { Label("Pas vu", systemImage: "eye.slash").font(P.font(28, .semibold)).frame(width: 330, height: 72) }
                            .buttonStyle(ChipGlassStyle()).focused($focus, equals: "unseen")
                        Button { answerCard(.like) } label: { Label("J'aime", systemImage: "heart").font(P.font(30, .bold)).frame(width: 360, height: 76) }
                            .buttonStyle(TastePrimaryStyle()).focused($focus, equals: "like")
                    }
                    .focusSection()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// « Ce que prisme apprend » (simulateur) : ce qui ressort déjà des réponses.
    private var learnBox: some View {
        let likes = log.compactMap { a -> String? in if case let .card(it, .like) = a { return Genres.canon(it.fiche?.genres ?? "").first }; return nil }
        let txt = likes.isEmpty ? "Rien encore : chaque réponse ajuste ce que prisme te proposera."
            : "Tu sembles aimer : " + Array(NSOrderedSet(array: likes)).compactMap { $0 as? String }.prefix(3).map { $0.lowercased() }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 10) {
            Text("CE QUE PRISME APPREND").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
            Text(txt).font(P.font(22)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24).frame(width: 425, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
    }

    private func tasteCard(_ it: MediaItem, w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: it.posterURL, title: it.displayTitle, maxPixel: 700).frame(width: w, height: h)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text(it.displayTitle).font(P.font(36, .bold)).lineLimit(2)
                Text(Genres.canon(it.fiche?.genres ?? "").prefix(2).joined(separator: " · ") + ((it.fiche?.runtime ?? 0) > 0 && it.kind == .film ? " · " + runtimeText(it.fiche!.runtime) : ""))
                    .font(P.font(22)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(26)
        }
        .frame(width: w, height: h)
        .overlay(alignment: .topLeading) {
            Text((it.kind == .film ? "FILM" : "SÉRIE") + " · \(it.fiche?.year ?? it.year)").font(P.font(19, .bold)).tracking(1)
                .padding(.horizontal, 12).padding(.vertical, 7).background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 9)).padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
    }

    // MARK: 2. duels

    private var duelStep: some View {
        VStack(spacing: 0) {
            Text("Celui-ci ou celui-là ?").font(P.font(40, .bold)).padding(.top, 24)
            if let d = duel {
                HStack(alignment: .center, spacing: 40) {
                    Button { answerDuel(0) } label: { tasteCard(d.1, w: 440, h: 600) }.buttonStyle(DuelStyle()).focused($focus, equals: "d0")
                    Text("ou").font(P.font(40, .bold)).foregroundStyle(.white.opacity(0.5))
                    Button { answerDuel(1) } label: { tasteCard(d.2, w: 440, h: 600) }.buttonStyle(DuelStyle()).focused($focus, equals: "d1")
                }
                .padding(.top, 30)
                .focusSection()
                Text("plutôt " + d.0.label.0 + " ou " + d.0.label.1 + " ?").font(P.font(22)).foregroundStyle(.white.opacity(0.55)).padding(.top, 10)
                Spacer(minLength: 10)
                Button { answerDuel(-1) } label: { Text("Aucun des deux").font(P.font(28, .semibold)).frame(width: 368, height: 72) }
                    .buttonStyle(ChipGlassStyle()).focused($focus, equals: "none")
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 3. ambiances

    private var moodStep: some View {
        VStack(spacing: 0) {
            Text("Quelles ambiances te ressemblent ?").font(P.font(46, .bold)).padding(.top, 20)
            Text("Choisis-en jusqu'à trois (OK pour cocher)").font(P.font(25)).foregroundStyle(.white.opacity(0.7)).padding(.top, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(500), spacing: 30), count: 3), spacing: 30) {
                ForEach(TasteMood.all) { m in
                    Button {
                        if moods.contains(m.id) { moods.remove(m.id) } else if moods.count < 3 { moods.insert(m.id) }
                    } label: { moodTile(m) }
                    .buttonStyle(MoodStyle(on: moods.contains(m.id))).focused($focus, equals: "m:" + m.id)
                }
            }
            .padding(.top, 34)
            .focusSection()
            Button { answerMoods() } label: { Text("Continuer →").font(P.font(28, .bold)).padding(.horizontal, 40).frame(height: 72) }
                .buttonStyle(TastePrimaryStyle()).focused($focus, equals: "mgo").padding(.top, 34)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func moodTile(_ m: TasteMood) -> some View {
        let L = Array(pool.filter { it in let g = Genres.canon(it.fiche?.genres ?? ""); return g.first.map { m.genres.contains($0) } ?? false && !it.posterURL.isEmpty }.prefix(3))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(L) { it in Poster(url: it.posterURL, title: it.displayTitle, maxPixel: 300).frame(width: 140, height: 200).clipShape(RoundedRectangle(cornerRadius: 14)) }
                if L.isEmpty { Image(systemName: "sparkles").font(.system(size: 60)).frame(height: 200).frame(maxWidth: .infinity) }
            }
            Text(m.words).font(P.font(25, .bold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(18)
    }

    // MARK: 4. « Jamais de… » et contexte

    private static let neverChoices: [(String, String)] = [("Horreur", "Horreur"), ("Animation", "Animation"), ("Romance", "Romance"), ("Guerre", "Guerre"),
                                                          ("Western", "Western"), ("Musique", "Musical"), ("Documentaire", "Documentaire"), ("__long", "Films de plus de 2 h 30")]

    private var neverStep: some View {
        VStack(spacing: 0) {
            Text("Jamais de… ?").font(P.font(60, .bold)).padding(.top, 10)
            Text("Coche ce que prisme ne doit jamais te proposer (OK pour cocher)").font(P.font(25)).foregroundStyle(.white.opacity(0.7)).padding(.top, 8)
            chipRow(TasteTestView.neverChoices, sel: { never.contains($0) }, tap: { if never.contains($0) { never.remove($0) } else { never.insert($0) } }, key: "n")
                .padding(.top, 26)
            kicker("PLUTÔT")
            chipRow([("both", "Films et séries"), ("films", "Surtout des films"), ("series", "Surtout des séries")], sel: { kindPref == $0 }, tap: { kindPref = $0 }, key: "k")
            kicker("UN SOIR DE SEMAINE")
            chipRow([("any", "Peu importe"), ("court", "Un film court"), ("episode", "Un épisode")], sel: { weeknight == $0 }, tap: { weeknight = $0 }, key: "w")
            kicker("ET LA VERSION ?")
            chipRow([("auto", "Automatique"), ("VFF", "VFF d'abord"), ("VF", "VF, peu importe l'accent"), ("VOSTFR", "VOSTFR d'abord")], sel: { lang == $0 }, tap: { lang = $0 }, key: "v")
            Button { Task { await finish() } } label: { Text("Voir ce que prisme a compris →").font(P.font(28, .bold)).padding(.horizontal, 36).frame(height: 72) }
                .buttonStyle(TastePrimaryStyle()).focused($focus, equals: "go").padding(.top, 34)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func kicker(_ t: String) -> some View {
        Text(t).font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.6)).padding(.top, 30).padding(.bottom, 14)
    }

    private func chipRow(_ L: [(String, String)], sel: @escaping (String) -> Bool, tap: @escaping (String) -> Void, key: String) -> some View {
        HStack(spacing: 18) {
            ForEach(L, id: \.0) { c in
                Button { tap(c.0) } label: {
                    HStack(spacing: 10) {
                        if sel(c.0) { Image(systemName: "checkmark").font(.system(size: 22, weight: .bold)) }
                        Text(c.1).font(P.font(27, .semibold))
                    }
                    .padding(.horizontal, 30).frame(height: 66)
                }
                .buttonStyle(TasteChipStyle(on: sel(c.0))).focused($focus, equals: key + ":" + c.0)
            }
        }
        .focusSection()
    }

    // MARK: 5. résultat

    private var resultStep: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 16) {
                Text("VOICI CE QUE PRISME A COMPRIS").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
                Text("\(me.name) aime…").font(P.font(46, .bold)).padding(.bottom, 6)
                ForEach(model.topGenres, id: \.0) { g in
                    HStack(spacing: 20) {
                        Text(g.0).font(P.font(25)).frame(width: 220, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color(red: 0.13, green: 0.77, blue: 0.37)).frame(width: 400 * CGFloat(max(0.05, g.1)))
                        }.frame(width: 400, height: 12)
                    }
                }
                if model.topGenres.isEmpty { Text("Pas encore assez de réponses pour dégager des préférences.").font(P.font(24)).foregroundStyle(.white.opacity(0.7)) }
                FlowChips(items: traits).padding(.top, 10)
                Spacer(minLength: 10)
                Text("Ce n'est qu'un départ : ce que tu regardes vraiment compte de plus en plus. Refaire le test ou tout oublier : Réglages › Profils › \(me.name) › Mes goûts.")
                    .font(P.font(21)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(36).frame(width: 720, alignment: .topLeading).frame(maxHeight: .infinity, alignment: .top)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 18) {
                Text("POUR TOI, DÈS CE SOIR · \(recs.count) TITRES DE TON CATALOGUE").font(P.font(20, .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(250), spacing: 34), count: 3), alignment: .leading, spacing: 26) {
                    ForEach(recs, id: \.0.id) { r in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Poster(url: r.0.posterURL, title: r.0.displayTitle, maxPixel: 400).frame(width: 250, height: 300).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                Text("\(r.1) %").font(P.font(20, .bold)).padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color(red: 0.13, green: 0.77, blue: 0.37), in: RoundedRectangle(cornerRadius: 9)).padding(12)
                            }
                            Text(r.0.displayTitle).font(P.font(22, .bold)).lineLimit(1)
                            Text(r.2).font(P.font(18)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 18) {
                    Button(action: close) { Text("Terminer").font(P.font(28, .bold)).padding(.horizontal, 40).frame(height: 72) }
                        .buttonStyle(TastePrimaryStyle()).focused($focus, equals: "done")
                    Button { restart() } label: { Text("Refaire le test").font(P.font(26, .semibold)).padding(.horizontal, 30).frame(height: 68) }
                        .buttonStyle(ChipGlassStyle())
                }
                .focusSection()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 40)
    }

    /// Les traits lisibles : axes nets, version, « jamais ».
    private var traits: [String] {
        var t: [String] = []
        for ax in TasteAxis.allCases { if let v = model.axes[ax.rawValue], abs(v) >= 0.4 { t.append("plutôt " + (v < 0 ? ax.label.0 : ax.label.1)) } }
        if kindPref != "both" { t.append(kindPref == "films" ? "surtout des films" : "surtout des séries") }
        if lang != "auto" { t.append((Profile.langNames[lang] ?? lang)) }
        let nv = never.map { $0 == "__long" ? "films de plus de 2 h 30" : $0.lowercased() }
        if !nv.isEmpty { t.append("jamais : " + nv.sorted().prefix(3).joined(separator: ", ")) }
        return t
    }

    // MARK: déroulé

    private func loadPool() async {
        let pids = store.active.map(\.id)
        let f = await MediaStore.ficheList(.film, pids: pids, cond: "f.vote>=6.3 AND f.poster!=''", order: "f.vote DESC", limit: 400)
        let s = await MediaStore.ficheList(.series, pids: pids, cond: "f.vote>=6.8 AND f.poster!=''", order: "f.vote DESC", limit: 120)
        pool = f + s
        if let a = TasteStore.shared.answers(pid) { never = Set(a.never); kindPref = a.kindPref; weeknight = a.weeknight; moods = Set(a.moods) }
        lang = me.lang
        loading = false
        // « Commencer » était désactivé pendant la préparation : la sélection y revient quand il devient utilisable
        if step == .intro { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "start" } }
    }

    private func start() {
        log = []
        step = .card
        nextCard()
    }

    private func restart() { moods = []; never = []; step = .intro; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "start" } }

    private var shownKeys: Set<String> {
        var s = Set<String>()
        for a in log {
            switch a {
            case let .card(it, _): s.insert(it.workKey)
            case let .duel(_, x, y, _): s.insert(x.workKey); s.insert(y.workKey)
            default: break
            }
        }
        if let c = current { s.insert(c.workKey) }
        return s
    }

    /// Carte suivante : le genre le moins exploré d'abord (les « pas vu » ne comptent pas), le titre le mieux noté de ce genre ;
    /// une série de temps en temps ; après deux « pas vu » de suite, un titre parmi les plus connus.
    private func nextCard() {
        let shown = shownKeys.subtracting(current.map { [$0.workKey] } ?? [])
        var counted: [String: Int] = [:]
        for a in log { if case let .card(it, v) = a, v != .unseen, let g = Genres.canon(it.fiche?.genres ?? "").first { counted[g, default: 0] += 1 } }
        let lastTwoUnseen = log.suffix(2).allSatisfy { if case .card(_, .unseen) = $0 { return true }; return false } && log.count >= 2
        let wantSeries = cardsDone == 3 || cardsDone == 6
        let cands = pool.filter { !shown.contains($0.workKey) && ($0.kind == .series) == wantSeries }
        let base = cands.isEmpty ? pool.filter { !shown.contains($0.workKey) } : cands
        let order = ["Comédie", "Drame", "Action", "Science-Fiction", "Thriller", "Animation", "Romance", "Horreur", "Crime", "Aventure", "Fantastique", "Familial", "Histoire", "Mystère"]
        var pick: MediaItem?
        if lastTwoUnseen { pick = base.max { ($0.fiche?.vote ?? 0) < ($1.fiche?.vote ?? 0) } }
        if pick == nil {
            let genres = order.filter { g in base.contains { Genres.canon($0.fiche?.genres ?? "").first == g } }
            if let g = genres.min(by: { (counted[$0] ?? 0) < (counted[$1] ?? 0) }) {
                pick = base.filter { Genres.canon($0.fiche?.genres ?? "").first == g }.max { ($0.fiche?.vote ?? 0) < ($1.fiche?.vote ?? 0) }
            }
        }
        current = pick ?? base.first
        if current == nil { startDuels(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "like" }
    }

    private func answerCard(_ v: Verdict) {
        guard let it = current else { return }
        log.append(.card(it, v))
        current = nil
        if cardsDone >= TasteTestView.cardsTotal { startDuels() } else { nextCard() }
    }

    private func startDuels() { step = .duel; nextDuel() }

    /// Duel suivant : l'axe le moins connu, un titre de chaque côté (les mieux notés, d'un même genre si possible).
    private func nextDuel() {
        let shown = shownKeys
        let done = Set(log.compactMap { a -> String? in if case let .duel(ax, _, _, _) = a { return ax.rawValue }; return nil })
        for ax in TasteAxis.allCases where !done.contains(ax.rawValue) {
            func val(_ it: MediaItem) -> Double {
                ax.value(genres: Genres.canon(it.fiche?.genres ?? ""), year: it.fiche?.year ?? it.year, runtime: it.fiche?.runtime ?? 0, country: it.fiche?.country ?? "")
            }
            let A = pool.filter { !shown.contains($0.workKey) && val($0) < 0 }.sorted { ($0.fiche?.vote ?? 0) > ($1.fiche?.vote ?? 0) }
            let B = pool.filter { !shown.contains($0.workKey) && val($0) > 0 }.sorted { ($0.fiche?.vote ?? 0) > ($1.fiche?.vote ?? 0) }
            guard let a = A.first, !B.isEmpty else { continue }
            let ga = Set(Genres.canon(a.fiche?.genres ?? ""))
            let b = B.first { !ga.isDisjoint(with: Genres.canon($0.fiche?.genres ?? "")) } ?? B[0]
            // côté au hasard : le premier n'est pas toujours le même pôle
            duel = Bool.random() ? (ax, a, b) : (ax, b, a)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "d0" }
            return
        }
        duel = nil
        step = .mood
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "m:" + TasteMood.all[0].id }
    }

    private func answerDuel(_ c: Int) {
        guard let d = duel else { return }
        log.append(.duel(d.0, d.1, d.2, c))
        if duelsDone >= TasteTestView.duelsTotal { duel = nil; step = .mood; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "m:" + TasteMood.all[0].id } }
        else { nextDuel() }
    }

    private func answerMoods() {
        log.append(.mood(Array(moods)))
        step = .never
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "go" }
    }

    /// Retour : revient à la question précédente (sa réponse est oubliée) ; depuis la première, à l'introduction.
    private func back() {
        switch step {
        case .intro: close()
        case .result: step = .never; log.removeAll { if case .never = $0 { return true }; return false }
        default:
            guard let last = log.popLast() else { step = .intro; current = nil; return }
            switch last {
            case let .card(it, _): step = .card; current = it; duel = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "like" }
            case let .duel(ax, a, b, _): step = .duel; duel = (ax, a, b); DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "d0" }
            case .mood: step = .mood
            case .never: step = .never
            }
        }
    }

    /// Fin : enregistre les réponses du profil, applique la version préférée, calcule les 6 titres pour ce soir.
    private func finish() async {
        log.append(.never)
        var a = TasteAnswers()
        for x in log {
            switch x {
            case let .card(it, v) where v != .unseen:
                a.judged[it.workKey] = v == .like ? 1 : -1
                if let f = it.fiche { a.judgedInfo[it.workKey] = .init(genres: Genres.canon(f.genres), kw: Array(f.keywordIDs), dir: f.director, cast: f.cast.prefix(4).map(\.n), title: it.displayTitle) }
            case let .duel(ax, p, q, c) where c >= 0:
                let w = c == 0 ? p : q
                let v = ax.value(genres: Genres.canon(w.fiche?.genres ?? ""), year: w.fiche?.year ?? w.year, runtime: w.fiche?.runtime ?? 0, country: w.fiche?.country ?? "")
                a.axes[ax.rawValue] = max(-1, min(1, (a.axes[ax.rawValue] ?? 0) + v * 0.8))
                // le titre choisi compte comme un « j'aime » léger (simulateur)
                if a.judged[w.workKey] == nil, let f = w.fiche {
                    a.judged[w.workKey] = 1
                    a.judgedInfo[w.workKey] = .init(genres: Genres.canon(f.genres), kw: Array(f.keywordIDs), dir: f.director, cast: f.cast.prefix(4).map(\.n), title: w.displayTitle)
                }
            case let .mood(m): a.moods = m
            default: break
            }
        }
        a.never = Array(never); a.kindPref = kindPref; a.weeknight = weeknight; a.at = Date(); a.count = log.count
        TasteStore.shared.save(a, for: pid)
        if var p = ps.profile(pid), p.lang != lang { p.lang = lang; ps.update(p) }
        model = await TasteStore.shared.model(pid)
        // 6 titres : jamais vus, pas jugés, hors « jamais », les plus proches, deux au plus par genre principal
        let seen = Set(WatchStore.entries(for: pid).values.map(\.item))
        var perGenre: [String: Int] = [:], out: [(MediaItem, Int, String)] = []
        let scored = pool.filter { !seen.contains($0.id) && a.judged[$0.workKey] == nil }
            .compactMap { it -> (MediaItem, Int)? in guard let f = it.fiche, let s = model.fit(f, kind: it.kind), s > 50 else { return nil }; return (it, s) }
            .sorted { $0.1 > $1.1 }
        for (it, s) in scored where out.count < 6 {
            let g = Genres.canon(it.fiche?.genres ?? "").first ?? ""
            guard perGenre[g, default: 0] < 2 else { continue }
            perGenre[g, default: 0] += 1
            out.append((it, s, it.fiche.flatMap { model.because($0) } ?? "selon tes ambiances"))
        }
        recs = out
        step = .result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "done" }
    }
}

/// Puces « traits » du résultat (retour à la ligne).
private struct FlowChips: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { i in
                HStack(spacing: 12) {
                    ForEach(items[i..<min(items.count, i + 2)], id: \.self) { t in
                        Text(t).font(P.font(22, .semibold)).lineLimit(1).padding(.horizontal, 18).frame(height: 48)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

struct TastePrimaryStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(Color.black)
                .background(Color.white.opacity(f ? 1 : 0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(f ? 1.06 : 1).shadow(color: .black.opacity(f ? 0.45 : 0), radius: 20, y: 10)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

struct TasteChipStyle: ButtonStyle {
    let on: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, on: on) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let on: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color.white.opacity(on ? 0.26 : 0.09), in: Capsule())
                .scaleEffect(f ? 1.06 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

private struct DuelStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white, lineWidth: f ? 8 : 0))
                .scaleEffect(f ? 1.06 : 0.9).opacity(f ? 1 : 0.6)
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

private struct MoodStyle: ButtonStyle {
    let on: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, on: on) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let on: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color.white.opacity(on ? 0.2 : 0.05), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(on ? P.gold : Color.white.opacity(0.14), lineWidth: on ? 4 : 1.5))
                .overlay(alignment: .topTrailing) { if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(P.gold).padding(12) } }
                .scaleEffect(f ? 1.04 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}
