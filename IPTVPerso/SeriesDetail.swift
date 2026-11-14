import SwiftUI

// MARK: - Fiche d'une série (structure du simulateur) :
// à gauche titre, infos, Reprendre, ma liste, version, carte d'avancement, saisons ;
// à droite un panneau en verre avec onglets : Épisodes · Qui est qui ? · Séries proches · Où regarder · Détails.

struct SeriesDetailView: View {
    let item: MediaItem
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var fiche: Fiche?
    @State private var info = MediaInfo()
    @State private var versions: [MediaItem] = []
    @State private var chosen: MediaItem?
    @State private var season = 0
    @State private var tab = "eps"
    @State private var essential = false
    @State private var playing: VodRequest?
    @State private var pickVersion = false
    @State private var similar: [SimilarItem] = []
    @State private var airings: [LiveStore.Airing] = []
    @State private var openOther: MediaItem?
    @State private var launchMsg: String?
    @State private var showSyn = false
    @State private var actor: CastMember?
    @State private var live: LiveLaunch?
    @State private var trailer: Trailer?
    @State private var showTrailer: Trailer?
    @State private var loading = true
    @State private var showRecap: RecapPlan?
    /// épisodes absents de la version choisie mais présents dans une autre version (« complété depuis … »)
    @State private var fills: [String: EpisodeFill] = [:]
    /// épisodes annoncés par TMDB dans les 7 prochains jours, pas encore chez le fournisseur (« à venir »)
    @State private var upcoming: [UpcomingEpisode] = []
    @FocusState private var tabFocus: String?
    @FocusState private var playFocused: Bool

    /// 1920 − marges (90 + 64) − colonne de gauche (700) − espace (56)
    static let panelW: CGFloat = 1010
    private static let tabs: [(String, String)] = [("eps", "Épisodes"), ("cast", "Qui est qui ?"), ("sim", "Séries proches"), ("where", "Où regarder"), ("det", "Détails")]

    private var cur: MediaItem { chosen ?? item }
    private var title: String { (fiche?.title.isEmpty == false) ? fiche!.title : item.clean.title }
    private var all: [EpisodeInfo] { info.seasons.flatMap(\.episodes) }
    private var plot: String { (fiche?.overview.isEmpty == false) ? fiche!.overview : (info.plot.isEmpty ? item.plot : info.plot) }
    private var shownRating: Double { (fiche?.vote ?? 0) > 0 ? fiche!.vote : (item.rating > 0 ? item.rating : info.rating) }
    private var genres: [String] {
        let g = (fiche?.genres.isEmpty == false) ? fiche!.genres : info.genre
        return g.components(separatedBy: CharacterSet(charactersIn: ",/")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private func key(_ e: EpisodeInfo) -> String { EpisodeLogic.key(item, e) }
    private func mins(_ e: EpisodeInfo) -> Int { EpisodeLogic.minutes(e, info: info, fiche: fiche) }
    private var nextEp: EpisodeInfo? { EpisodeLogic.next(item, info, watch) }
    private var started: Bool { all.contains { watch.fraction(key($0)) != nil } }
    private var allSeen: Bool { !all.isEmpty && all.allSatisfy { watch.watched(key($0)) } }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 700)
            right
        }
        .padding(.leading, 90).padding(.trailing, 64).padding(.top, 70).padding(.bottom, 50)
        .background {
            let hasBd = fiche?.backdrop.isEmpty == false
            ZStack {
                DetailBackdrop(backdrop: hasBd ? Fiche.img(fiche!.backdrop, "original") : info.backdrop, poster: item.posterURL)
                Color.black.opacity(0.25)
            }
        }
        .background(P.room)
        .ignoresSafeArea()
        .navigationDestination(item: $openOther) { it in DetailView(item: it) }
        .task(id: item.id) { await load() }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .fullScreenCover(item: $live) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .fullScreenCover(item: $showTrailer) { t in TrailerScreen(trailer: t, title: title, playFilm: trailerPlay, playTitle: "Regarder la série") }
        .fullScreenCover(item: $showRecap) { plan in
            RecapScreen(plan: plan, backdrop: (fiche?.backdrop.isEmpty == false) ? Fiche.img(fiche!.backdrop, "original") : info.backdrop, poster: item.posterURL) { mainAction() }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { playFocused = true } }
        .sheet(isPresented: $showSyn) { SynopsisSheet(kicker: "SÉRIE", title: title, text: plot.isEmpty ? "Pas de résumé chez le fournisseur." : plot) }
        .sheet(item: $actor) { a in ActorSheet(actor: a, kind: .series, excluding: item.clean.key) }
        .confirmationDialog("Choisir la version", isPresented: $pickVersion) {
            ForEach(versions) { v in Button(versionLabel(v)) { chosen = v; Task { info = await InfoLoader.load(v) } } }
        }
        .alert(launchMsg ?? "", isPresented: Binding(get: { launchMsg != nil }, set: { if !$0 { launchMsg = nil } })) { Button("OK") {} }
    }

    // MARK: colonne de gauche

    private var left: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 22) {
                    BigTitle(text: title, face: TitleFace.of(genres: genres), scale: 0.55, maxWidth: 600)
                    Button { showSyn = true } label: { Image(systemName: "info").font(P.font(24, .bold)).frame(width: 30, height: 30) }
                        .buttonStyle(GlassStyle(radius: 30, minH: 54))
                }
                meta
                actions
                if !all.isEmpty { progressCard }
                if info.seasons.count > 0 { seasonRows }
                if !all.isEmpty {
                    HStack(spacing: 22) {
                        // légende du simulateur (.f3leg)
                        Text("✓ vu").foregroundStyle(Color(red: 0.62, green: 0.94, blue: 0.69))
                        Text("● à suivre").foregroundStyle(.white)
                        Text("● nouveau").foregroundStyle(Self.newBlue)
                        Text("○ à venir").foregroundStyle(Self.soonTeal)
                        Text("! manquant").foregroundStyle(Self.missOrange)
                        Text("◆ complété").foregroundStyle(Self.fillPurple)
                    }.font(P.font(17, .medium)).opacity(0.85)
                }
                if loading { ProgressView().tint(.white).padding(.top, 20) }
            }
            .padding(.vertical, 30).padding(.horizontal, 12)
        }
        .scrollClipDisabled()
        .focusSection()
    }


    private var meta: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                let y = (fiche?.year ?? 0) > 0 ? fiche!.year : (item.clean.year > 0 ? item.clean.year : info.year)
                if y > 0 { Text(String(y)) }
                if !info.seasons.isEmpty { Text("\(info.seasons.count) saison\(info.seasons.count > 1 ? "s" : "")") }
                if !genres.isEmpty { Text(genres.prefix(2).joined(separator: ", ")).lineLimit(1) }
                if !info.age.isEmpty { Text(info.age) }
                if shownRating > 0 { Stars(value: shownRating) }
            }
            if let p = store.provider(cur.pid)?.name, store.active.count > 1 { Pill(text: p, bg: P.chip.opacity(0.45), stroke: P.chip) }
        }
        .font(P.font(23)).foregroundStyle(.white.opacity(0.82))
    }

    /// Le plan du résumé (épisodes déjà vus seulement) quand la série est commencée et pas finie.
    private var recapPlan: RecapPlan? {
        guard started, !allSeen, let e = nextEp else { return nil }
        return RecapPlan.make(item: item, info: info, next: e, watch: watch, title: title)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button { mainAction() } label: { PlayLabel(title: mainLabel.0, sub: mainLabel.1).lineLimit(1).fixedSize() }
                    .buttonStyle(FicheButtonStyle(prim: true, pad: 28))
                    .focused($playFocused)
                    .disabled(all.isEmpty)
                // « ⏮ Résumé 60 s » du simulateur : ce qu'il faut savoir avant l'épisode, sans rien dévoiler de la suite
                if let plan = recapPlan {
                    Button { showRecap = plan } label: { Label("Résumé 60 s", systemImage: "backward.end.fill").font(P.font(29, .semibold)).lineLimit(1).fixedSize() }
                        .buttonStyle(FicheButtonStyle(pad: 26))
                }
            }.focusSection()
            HStack(spacing: 12) {
                Button { watch.toggleFavorite(item.id) } label: {
                    Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus").font(P.font(32, .bold))
                }.buttonStyle(FicheButtonStyle(square: true))
                Button { if versions.count > 1 { pickVersion = true } else { launchMsg = "Une seule version chez ton fournisseur" } } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(versionShort(cur)).font(P.font(32, .heavy))
                        Text("\(max(1, versions.count)) VERSION\(versions.count > 1 ? "S ▾" : "")").font(P.font(19, .bold)).tracking(1).opacity(0.6)
                    }
                }.buttonStyle(FicheButtonStyle())
                if let t = trailer {
                    Button { showTrailer = t } label: { Image(systemName: "film").font(P.font(30, .semibold)) }
                        .buttonStyle(FicheButtonStyle(square: true))
                }
            }.focusSection()
        }
        .defaultFocus($playFocused, true)
    }

    /// Bouton blanc : « Reprendre S2 · É3 / RESTE 25 MIN · FIN 02:22 », « Commencer S1 · É1 / 52 MIN · FIN 23:40 »…
    private var mainLabel: (String, String?) {
        if all.isEmpty { return (loading ? "Chargement…" : "Aucun épisode", nil) }
        if allSeen { return ("Revoir depuis le début", "\(info.seasons.count) saison\(info.seasons.count > 1 ? "s" : "") · \(all.count) épisodes") }
        guard let e = nextEp else { return ("Lecture", nil) }
        let pos = watch.resume(key(e))
        let verb = pos != nil ? "Reprendre" : started ? "Regarder" : "Commencer"
        let m = mins(e)
        guard m > 0 else { return ("\(verb) S\(e.season) · É\(e.number)", nil) }
        let left = max(60, Double(m * 60) - (pos ?? 0))
        let sub = (pos != nil ? "RESTE " + runtimeText(Int(left / 60)) : runtimeText(m)) + " · FIN " + Fmt.hm(Date().addingTimeInterval(left))
        return ("\(verb) S\(e.season) · É\(e.number)", sub.uppercased())
    }

    private func mainAction() {
        if allSeen, let first = all.first { playEpisode(first, from: 0); return }
        guard let e = nextEp else { return }
        playEpisode(e, from: watch.resume(key(e)) ?? 0)
    }

    // carte d'avancement (anneau + phrases + « Finir la saison ce soir »)
    private var progressCard: some View {
        let seen = all.filter { watch.watched(key($0)) }.count
        let frac = Double(seen) / Double(max(1, all.count))
        let restAll = all.filter { !watch.watched(key($0)) }
        let e = nextEp
        let inSeason = e.map { n in (info.seasons.first { $0.number == n.season }?.episodes ?? []).filter { $0.number >= n.number && !watch.watched(key($0)) } } ?? []
        let dur: ([EpisodeInfo]) -> Int = { $0.reduce(0) { $0 + mins($1) } }
        var lines: [Text] = []
        if allSeen { lines = [Text("Tu as tout vu · ") + Text("\(all.count) épisodes").bold()] }
        else if !started {
            let d = dur(all)
            lines = [Text("\(all.count) épisodes").bold() + Text(d > 0 ? " · " + runtimeText(d) : ""), Text("environ \(Int((Double(all.count) / 2).rounded(.up))) soirées à 2 ép./soir")]
        } else if let e {
            let d = dur(inSeason)
            lines = [Text("Il te reste ") + Text("\(inSeason.count) ép.").bold() + Text(" dans la saison \(e.season)" + (d > 0 ? " · " + runtimeText(d) : "")),
                     Text("saison finie ") + Text(dayWord(inSeason.count)).bold() + Text(" à 1 ép./soir"),
                     Text("\(restAll.count) ép.").bold() + Text(" en tout" + (dur(restAll) > 0 ? " · " + runtimeText(dur(restAll)) : ""))]
        }
        let finTotal = inSeason.isEmpty ? 0 : Double(dur(inSeason) * 60) - (e.flatMap { watch.resume(key($0)) } ?? 0)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 22) {
                ZStack {
                    Ring(value: frac, color: Color(red: 0.45, green: 0.85, blue: 0.5), width: 8).frame(width: 86, height: 86)
                    (Text("\(Int((frac * 100).rounded()))").font(P.font(28, .heavy)) + Text("%").font(P.font(15, .bold)))
                }
                VStack(alignment: .leading, spacing: 5) { ForEach(0..<lines.count, id: \.self) { i in lines[i] } }.font(P.font(20)).foregroundStyle(.white.opacity(0.88))
            }
            if started, !allSeen, inSeason.count > 1, let e {
                Button { playEpisode(e, from: watch.resume(key(e)) ?? 0) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Finir la saison ce soir", systemImage: "play.fill").font(P.font(23, .bold))
                        Text("\(inSeason.count) ép." + (finTotal > 0 ? " · fin " + Fmt.hm(Date().addingTimeInterval(finTotal)) : "")).font(P.font(17, .semibold)).opacity(0.65)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                }.buttonStyle(PrimaryStyle())
            }
        }
        .padding(22).glass(24)
    }

    private func dayWord(_ n: Int) -> String {
        if n <= 1 { return "ce soir" }
        if n == 2 { return "demain" }
        let d = Calendar.current.date(byAdding: .day, value: n - 1, to: Date()) ?? Date()
        return Fmt.day(d)
    }

    // lignes des saisons : une case par épisode (vu, en cours, pas vu)
    private var seasonRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(info.seasons) { s in
                let vu = s.episodes.filter { watch.watched(key($0)) }.count
                Button { season = s.number; tab = "eps" } label: {
                    HStack(spacing: 18) {
                        Text("Saison \(s.number)").font(P.font(22, .bold)).frame(width: 130, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            let sl = slots(s)
                            HStack(spacing: 5) {
                                ForEach(sl.prefix(24)) { x in slotBox(x) }
                                if sl.count > 24 { Text("+\(sl.count - 24)").font(P.font(15, .bold)).opacity(0.6) }
                            }
                            // courbe des notes des épisodes (simulateur : .spk), points sur les deux meilleurs
                            if s.episodes.count > 1, s.episodes.allSatisfy({ $0.rating > 0 }) {
                                RatingSpark(ratings: s.episodes.map(\.rating), tops: topEpisodes(s).compactMap { n in s.episodes.firstIndex { $0.number == n } })
                                    .frame(height: 16)
                            }
                        }
                        Spacer(minLength: 0)
                        Text(vu == s.episodes.count ? "✓" : "\(vu)/\(s.episodes.count)").font(P.font(19, .semibold)).opacity(0.7)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 58).padding(.vertical, 4)
                }
                .buttonStyle(SeasonStyle(selected: s.number == season))
            }
        }
        .focusSection()
    }

    static let newBlue = Color(red: 0.31, green: 0.63, blue: 1)
    // couleurs du simulateur : à venir #5ee0c8, manquant #ffb35c, complété #b48cff
    static let soonTeal = Color(red: 0.37, green: 0.88, blue: 0.78)
    static let missOrange = Color(red: 1, green: 0.70, blue: 0.36)
    static let fillPurple = Color(red: 0.71, green: 0.55, blue: 1)

    /// Une place d'épisode dans une saison : épisode du fournisseur, complété depuis une autre version, manquant, ou à venir.
    struct Slot: Identifiable {
        enum Kind { case ep(EpisodeInfo), filled(EpisodeFill), missing, soon(UpcomingEpisode) }
        let season: Int, number: Int, kind: Kind
        var id: String { "\(season)-\(number)" }
    }

    /// Les épisodes de la saison dans l'ordre, trous compris : un numéro absent de la version choisie est pris dans une
    /// autre version s'il y existe (« complété »), sinon il est « manquant » ; les épisodes annoncés par TMDB suivent.
    private func slots(_ s: Season) -> [Slot] {
        var byN: [Int: EpisodeInfo] = [:]
        for e in s.episodes where byN[e.number] == nil { byN[e.number] = e }
        let filledHere = fills.values.filter { $0.episode.season == s.number }
        let top = max(byN.keys.max() ?? 0, filledHere.map(\.episode.number).max() ?? 0)
        guard top > 0, top <= 60 else { return s.episodes.map { Slot(season: s.number, number: $0.number, kind: .ep($0)) } }
        var out: [Slot] = []
        for n in 1...top {
            if let e = byN[n] { out.append(Slot(season: s.number, number: n, kind: .ep(e))) }
            else if let f = fills["\(s.number)-\(n)"] { out.append(Slot(season: s.number, number: n, kind: .filled(f))) }
            else { out.append(Slot(season: s.number, number: n, kind: .missing)) }
        }
        for u in upcoming where u.season == s.number && u.number > top { out.append(Slot(season: s.number, number: u.number, kind: .soon(u))) }
        return out
    }

    /// Case d'un épisode dans la ligne d'une saison (simulateur : .g3d i)
    @ViewBuilder private func slotBox(_ x: Slot) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        switch x.kind {
        case .ep(let e):
            let st = state(e)
            shape.fill(st == 2 ? Color(red: 0.45, green: 0.85, blue: 0.5).opacity(0.85) : st == 1 ? Color.white : isNew(e) ? Self.newBlue : Color.white.opacity(0.16))
                .frame(width: 18, height: 22)
        case .filled(let f):
            let st = state(f.episode)
            shape.fill(st == 2 ? Color(red: 0.45, green: 0.85, blue: 0.5).opacity(0.85) : st == 1 ? Color.white : Color.white.opacity(0.16))
                .overlay(alignment: .bottom) { Rectangle().fill(Self.fillPurple).frame(height: 4) }
                .clipShape(shape).frame(width: 18, height: 22)
        case .missing:
            shape.fill(Self.missOrange).frame(width: 18, height: 22)
        case .soon:
            shape.strokeBorder(Self.soonTeal.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 18, height: 22)
        }
    }

    /// Ajouté chez le fournisseur depuis moins de 7 jours et pas encore vu (date d'ajout réelle de l'épisode).
    private func isNew(_ e: EpisodeInfo) -> Bool {
        e.added > 0 && Date().timeIntervalSince1970 - Double(e.added) < 7 * 86400 && state(e) == 0
    }

    private var hasNew: Bool { info.seasons.contains { $0.episodes.contains { isNew($0) } } }

    /// Les deux épisodes les mieux notés de la saison (note ≥ 8,6), comme le simulateur.
    private func topEpisodes(_ s: Season) -> [Int] {
        s.episodes.filter { $0.rating >= 8.6 }.sorted { $0.rating > $1.rating }.prefix(2).map(\.number)
    }

    /// 2 = vu, 1 = en cours / à suivre, 0 = pas vu.
    private func state(_ e: EpisodeInfo) -> Int {
        if watch.watched(key(e)) { return 2 }
        if watch.fraction(key(e)) != nil || nextEp?.id == e.id { return started ? 1 : 0 }
        return 0
    }

    // MARK: panneau de droite (onglets)

    private var right: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<SeriesDetailView.tabs.count, id: \.self) { i in
                    let k = SeriesDetailView.tabs[i].0
                    Button { tab = k } label: { Text(SeriesDetailView.tabs[i].1).font(P.font(23, .semibold)).lineLimit(1).fixedSize() }
                        .buttonStyle(PanelTabStyle(selected: tab == k))
                        .focused($tabFocus, equals: k)
                }
            }
            .padding(10)
            .focusSection()
            .onChange(of: tabFocus) { f in if let f { tab = f } }
            Divider().overlay(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { tabBody }
                    .padding(.horizontal, 30).padding(.vertical, 24)
                    .frame(width: SeriesDetailView.panelW, alignment: .leading)
            }
            .clipped()
            .focusSection()
        }
        // largeur fixe : le panneau ne s'élargit jamais au-delà de l'écran, son contenu reste dedans
        .frame(width: SeriesDetailView.panelW, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .glass(34)
    }

    @ViewBuilder private var tabBody: some View {
        switch tab {
        case "cast": castTab
        case "sim": simTab
        case "where":
            WhereSection(kind: .series, fiche: fiche, airings: airings, versions: versions,
                         onTV: { live = LiveLaunch(ch: $0.ch) },
                         onApp: { name in if let f = fiche { Task { launchMsg = await AppLauncher.open(providerName: name, tmdb: f.tmdb, tv: true) } } },
                         showTitle: false, compact: true)
        case "det": detTab
        default: episodesTab
        }
    }

    private var shownSeason: Season? { info.seasons.first { $0.number == season } ?? info.seasons.first }

    @ViewBuilder private var episodesTab: some View {
        if let s = shownSeason {
            let eps = s.episodes
            let rated = eps.filter { $0.rating > 0 }
            let avg = rated.isEmpty ? 0 : rated.reduce(0) { $0 + $1.rating } / Double(rated.count)
            let shown = essential ? eps.filter { $0.rating >= 8.2 || state($0) == 1 } : eps
            let d = eps.reduce(0) { $0 + mins($1) }
            let seasonSeen = !eps.isEmpty && eps.allSatisfy { watch.watched(key($0)) }
            VStack(alignment: .leading, spacing: 4) {
                Text("Saison \(s.number)").font(P.font(32, .bold))
                Text("\(eps.count) ép." + (d > 0 ? " · " + runtimeText(d) : "") + (avg > 0 ? " · ★ " + String(format: "%.1f", avg).replacingOccurrences(of: ".", with: ",") : ""))
                    .font(P.font(19)).foregroundStyle(P.dim)
            }
            // les boutons de la saison sur leur propre ligne : rien ne dépasse du panneau
            HStack(spacing: 12) {
                if let t = trailer {
                    Button { showTrailer = t } label: { Label("Bande-annonce", systemImage: "film").font(P.font(19, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 30, minH: 52))
                }
                Button {
                    watch.setWatched(eps.map { key($0) }, watched: !seasonSeen, title: title, icon: item.posterURL, item: item.id)
                } label: { Label(seasonSeen ? "Saison non vue" : "Saison vue", systemImage: seasonSeen ? "arrow.uturn.backward" : "checkmark").font(P.font(19, .semibold)) }
                    .buttonStyle(GlassStyle(radius: 30, minH: 52))
                if avg > 0 {
                    Button { essential.toggle() } label: { Label(essential ? "L'essentiel · \(shown.count)/\(eps.count)" : "L'essentiel", systemImage: "star.fill").font(P.font(19, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 30, minH: 52, on: essential))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
            ForEach(slots(s).filter { x in
                guard essential else { return true }
                if case .ep(let e) = x.kind { return shown.contains(e) }
                return false
            }) { x in
                switch x.kind {
                case .ep(let e): episodeRow(e)
                case .filled(let f): episodeRow(f.episode, fill: f)
                case .missing: placeholderRow(x)
                case .soon: placeholderRow(x)
                }
            }
        } else if loading {
            ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 300)
        } else {
            Text("Aucun épisode chez le fournisseur pour cette série.").font(P.font(24)).foregroundStyle(P.dim).padding(.top, 40)
        }
    }

    private func episodeRow(_ e: EpisodeInfo, fill: EpisodeFill? = nil) -> some View {
        let st = state(e)
        let f = watch.fraction(key(e))
        let m = mins(e)
        return Button {
            if let fill { playFill(fill, from: watch.resume(key(e)) ?? 0) } else { playEpisode(e, from: watch.resume(key(e)) ?? 0) }
        } label: {
            HStack(alignment: .top, spacing: 24) {
                ZStack(alignment: .bottom) {
                    Poster(url: e.image.isEmpty ? (info.backdrop.isEmpty ? item.posterURL : info.backdrop) : e.image).frame(width: 288, height: 162).clipped()
                    if let f, f > 0.02, f < 0.92 {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.3))
                                Capsule().fill(.white).frame(width: g.size.width * f)
                            }.frame(height: 5).frame(maxHeight: .infinity, alignment: .bottom)
                        }.padding(10)
                    }
                }.frame(width: 288, height: 162).clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(e.number). " + (e.title.isEmpty ? "Épisode \(e.number)" : cleanEpTitle(e.title))).font(P.font(25, .bold)).lineLimit(1)
                    HStack(spacing: 8) {
                        if e.rating > 0 {
                            let top = info.seasons.first { $0.number == e.season }.map { topEpisodes($0).contains(e.number) } ?? false
                            let note = "★ " + String(format: "%.1f", e.rating).replacingOccurrences(of: ".", with: ",")
                            // couleur héritée hors « à ne pas manquer » : lisible aussi sur la ligne sélectionnée (fond clair)
                            if top { Text(note + " · à ne pas manquer").foregroundStyle(P.gold).fontWeight(.heavy) } else { Text(note) }
                        }
                        if m > 0 { Text(runtimeText(m)) }
                        if st == 2 { Pill(text: "✓ VU", bg: Color.white.opacity(0.1), stroke: nil) }
                        else if f != nil { Pill(text: "EN COURS", bg: Color.white.opacity(0.85), fg: .black, stroke: nil) }
                        else if isNew(e) { Pill(text: "NOUVEAU", bg: Self.newBlue.opacity(0.25), fg: Self.newBlue, stroke: nil) }
                        if let fill { Text("◆ complété depuis " + fill.from).foregroundStyle(Self.fillPurple).lineLimit(1) }
                    }.font(P.font(18, .medium)).opacity(0.75)
                    if !e.plot.isEmpty { Text(e.plot).font(P.font(19)).opacity(0.7).lineLimit(2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: SeriesDetailView.panelW - 60, alignment: .leading)
        }
        .buttonStyle(EpisodeStyle(current: st == 1, seen: st == 2))
    }

    /// Épisode manquant chez le fournisseur ou annoncé par TMDB : même ligne que les autres, sans lecture possible.
    private func placeholderRow(_ x: Slot) -> some View {
        var name = "Épisode \(x.number)", pill = ("MANQUANT", Self.missOrange, Color.black), when = "", msg = ""
        if case .soon(let u) = x.kind {
            if !u.name.isEmpty { name = u.name }
            pill = ("À VENIR", Self.soonTeal.opacity(0.25), Self.soonTeal)
            when = u.days == 1 ? "demain" : Fmt.day(u.date)
            msg = "Épisode \(x.number) de la saison \(x.season) : diffusion prévue \(when == "demain" ? "demain" : when + " " + Fmt.date(u.date))."
        } else {
            msg = "L'épisode \(x.number) de la saison \(x.season) n'est pas encore chez ton fournisseur."
        }
        let m = info.seasons.first { $0.number == x.season }?.episodes.first.map { mins($0) } ?? 0
        return Button { launchMsg = msg } label: {
            HStack(alignment: .top, spacing: 24) {
                Poster(url: info.backdrop.isEmpty ? item.posterURL : info.backdrop).frame(width: 288, height: 162).clipped()
                    .overlay(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(x.number). " + name).font(P.font(25, .bold)).lineLimit(1)
                    HStack(spacing: 8) {
                        if m > 0 { Text(runtimeText(m)) }
                        Pill(text: pill.0, bg: pill.1, fg: pill.2, stroke: nil)
                        if !when.isEmpty { Text(when) }
                    }.font(P.font(18, .medium)).opacity(0.75)
                    if case .missing = x.kind { Text("pas encore chez ton fournisseur").font(P.font(19)).opacity(0.7) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: SeriesDetailView.panelW - 60, alignment: .leading)
        }
        .buttonStyle(EpisodeStyle(current: false, seen: false))
    }

    /// Titre d'épisode sans le nom de la série répété par certains fournisseurs (« Lupin - S01E02 - … »).
    private func cleanEpTitle(_ t: String) -> String {
        let parts = t.components(separatedBy: " - ")
        if parts.count >= 3, parts[1].range(of: #"^S\d+E\d+$"#, options: [.regularExpression, .caseInsensitive]) != nil { return parts[2...].joined(separator: " - ") }
        return t
    }

    @ViewBuilder private var castTab: some View {
        let cast = castList(fiche: fiche, info: info)
        SectionTitle(title: "Qui est qui ?")
        if cast.isEmpty {
            Text(TmdbKey.value == nil ? "La distribution arrive avec la clé TMDB (Réglages › Fiches TMDB)." : "Pas de distribution connue pour cette série.").font(P.font(22)).foregroundStyle(P.dim)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(210), spacing: 20), count: 4), alignment: .leading, spacing: 20) {
                ForEach(cast) { a in
                    Button { if fiche != nil { actor = a } } label: { CastCircle(name: a.n, role: a.c, photo: a.p, roleFirst: true) }.buttonStyle(CircleStyle())
                }
            }
        }
    }

    @ViewBuilder private var simTab: some View {
        SectionTitle(title: "Séries proches")
        if similar.isEmpty {
            Text("Pas encore de séries proches.").font(P.font(22)).foregroundStyle(P.dim)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(190), spacing: 28), count: 4), alignment: .leading, spacing: 34) {
                ForEach(similar) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        PosterButton(item: s.item, width: 190) { openOther = s.item }
                        if !s.common.isEmpty { Text(s.common.prefix(2).joined(separator: ", ")).font(P.font(16)).foregroundStyle(P.dim).lineLimit(1).frame(width: 190, alignment: .leading) }
                    }
                }
            }.padding(.vertical, 10)
        }
    }

    /// Lignes de l'onglet « Détails » : seulement ce qui est connu.
    private var detailRows: [(String, String)] {
        var rows: [(String, String)] = []
        let d = all.reduce(0) { $0 + mins($1) }
        if !info.director.isEmpty { rows.append(("Créée par", info.director)) }
        if !genres.isEmpty { rows.append(("Genres", genres.joined(separator: ", "))) }
        if !info.seasons.isEmpty { rows.append(("Saisons", "\(info.seasons.count)")) }
        if !all.isEmpty { rows.append(("Épisodes", "\(all.count)" + (d > 0 ? " · " + runtimeText(d) : ""))) }
        rows.append(("Versions", "\(max(1, versions.count))" + (versionTags.isEmpty ? "" : " · " + versionTags)))
        var notes: [String] = []
        let pr = item.rating > 0 ? item.rating : info.rating
        if pr > 0 { notes.append("fournisseur " + String(format: "%.1f", pr)) }
        let tv = fiche?.vote ?? 0
        if tv > 0 { notes.append("TMDB \(Int((tv * 10).rounded())) %") }
        if !notes.isEmpty { rows.append(("Notes", notes.joined(separator: " · "))) }
        if !info.country.isEmpty { rows.append(("Pays", info.country)) }
        if let p = store.provider(cur.pid)?.name { rows.append(("Fournisseur", p)) }
        return rows
    }

    @ViewBuilder private var detTab: some View {
        let rows = detailRows
        SectionTitle(title: "Détails")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], alignment: .leading, spacing: 22) {
            ForEach(0..<rows.count, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(rows[i].0.uppercased()).font(P.font(16, .bold)).tracking(1.5).foregroundStyle(P.faint)
                    Text(rows[i].1).font(P.font(22, .semibold)).lineLimit(2)
                }
            }
        }
        // zone sélectionnable : pour pouvoir faire défiler et revenir aux onglets avec la télécommande
        Button { showSyn = true } label: { Label("Lire le résumé", systemImage: "text.alignleft").font(P.font(21, .semibold)) }.buttonStyle(GlassStyle(radius: 18, minH: 60))
    }

    private var versionTags: String { Array(Set(versions.flatMap { $0.clean.tags })).sorted().joined(separator: ", ") }

    // MARK: données et lecture

    private func load() async {
        let pids = store.active.map(\.id)
        if item.fiche != nil { fiche = item.fiche }
        else { let k = item.kind, kk = item.clean.key; fiche = await Database.shared.read { _ in FicheStore.byKeys(k, [kk])[kk] } }
        async let i = InfoLoader.load(item)
        async let v = MediaStore.versions(of: item, pids: pids)
        let (i1, v1) = await (i, v)
        if chosen == nil { chosen = v1.first }
        if let c = chosen, c.id != item.id { info = await InfoLoader.load(c) } else { info = i1 }
        versions = v1
        if season == 0 { season = Debug.season ?? nextEp?.season ?? info.seasons.first?.number ?? 1 }
        loading = false
        // le bouton Reprendre/Commencer n'est sélectionnable qu'une fois les épisodes chargés : on y pose le focus à ce moment-là
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { if !all.isEmpty && showRecap == nil && playing == nil { playFocused = true } }
        if fiche == nil, TmdbKey.value != nil { fiche = await FicheWorker.fetchNow(item, tmdbHint: info.tmdb) }
        fills = await EpisodeFill.find(main: chosen ?? item, info: info, versions: v1, providerName: { store.provider($0)?.name ?? "" })
        if let id = fiche?.tmdb ?? (info.tmdb > 0 ? info.tmdb : nil) { upcoming = await UpcomingEpisode.load(tmdb: id, have: Set(all.map { "\($0.season)-\($0.number)" })) }
        airings = await LiveStore.airings(title: title, providers: pids)
        let y = (fiche?.year ?? 0) > 0 ? fiche!.year : (item.clean.year > 0 ? item.clean.year : info.year)
        trailer = await TrailerStore.find(title: title, year: y, minutes: 0, tmdb: fiche?.tmdb ?? info.tmdb, tv: true)
        var it = item; it.fiche = fiche
        similar = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 16).map { SimilarItem(item: $0.0, common: $0.1) }
    }

    private var trailerPlay: (() -> Void)? {
        if all.isEmpty { return nil }
        return { mainAction() }
    }

    private func playFill(_ f: EpisodeFill, from: Double) {
        guard let p = store.provider(f.version.pid) else { return }
        playing = EpisodeLogic.request(item, title: title, info: f.info, provider: p, episode: f.episode, from: from)
    }

    private func playEpisode(_ e: EpisodeInfo, from: Double) {
        guard let p = store.provider(cur.pid) else { return }
        playing = EpisodeLogic.request(item, title: title, info: info, provider: p, episode: e, from: from)
    }

    private func versionShort(_ v: MediaItem) -> String {
        let t = v.clean.tags
        let lang = t.first { ["VF", "MULTI", "VOSTFR"].contains($0) } ?? "VF"
        let q = t.first { ["4K", "1080p"].contains($0) } ?? "HD"
        return lang + " · " + q
    }

    private func versionLabel(_ v: MediaItem) -> String {
        let t = v.clean.tags
        let prov = store.provider(v.pid)?.name ?? ""
        return ([t.isEmpty ? "Version standard" : t.joined(separator: " · ")] + (Set(versions.map(\.pid)).count > 1 ? [prov] : [])).joined(separator: " · ")
    }
}

/// Ligne d'une saison dans la colonne de gauche.
struct SeasonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : .white)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(f ? Color.white : Color.white.opacity(selected ? 0.12 : 0)))
                .scaleEffect(f ? 1.03 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// Ligne d'épisode dans le panneau : verre clair quand sélectionnée, liseré blanc à gauche pour l'épisode à suivre.
struct EpisodeStyle: ButtonStyle {
    let current: Bool
    var seen = false
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, current: current, seen: seen) }
    /// comme le simulateur (.sf2e) : sélection = fond blanc à 12 % et anneau blanc autour de l'image ;
    /// épisode à suivre = fond à 7 % et trait blanc à gauche ; épisode vu = atténué
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let current: Bool
        let seen: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(f ? 0.12 : (current ? 0.07 : 0))))
                .overlay(alignment: .topLeading) {
                    // anneau de la vignette (288 × 162, à 12 pt du bord de la ligne)
                    if f { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white, lineWidth: 3).frame(width: 288, height: 162).padding(12) }
                }
                .overlay(alignment: .leading) { if current { Capsule().fill(.white).frame(width: 4).padding(.vertical, 14) } }
                .opacity(seen && !f ? 0.6 : 1)
                .scaleEffect(f ? 1.01 : 1)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}


/// Onglets du panneau d'une fiche série : plus compacts que la barre du haut, pour tenir sur une ligne.
struct PanelTabStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : (selected ? Color.white : Color.white.opacity(0.7)))
                .padding(.horizontal, 20).frame(height: 58)
                .background(Capsule().fill(f ? Color.white : (selected ? Color.white.opacity(0.18) : .clear)))
                .scaleEffect(f ? 1.06 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// Courbe fine des notes d'une saison (simulateur : .spk, or translucide, points sur les meilleurs épisodes).
struct RatingSpark: View {
    let ratings: [Double]
    let tops: [Int]
    var body: some View {
        GeometryReader { g in
            let n = ratings.count
            let pt = { (i: Int) -> CGPoint in
                let y = 14 - (min(max(ratings[i], 7.2), 9.3) - 7.2) / 2.1 * 12
                return CGPoint(x: n > 1 ? g.size.width * CGFloat(i) / CGFloat(n - 1) : g.size.width / 2, y: g.size.height * CGFloat(y) / 16)
            }
            Path { p in
                for i in 0..<n { i == 0 ? p.move(to: pt(i)) : p.addLine(to: pt(i)) }
            }
            .stroke(Color(red: 1, green: 0.83, blue: 0.42).opacity(0.75), lineWidth: 2)
            ForEach(tops, id: \.self) { i in
                Circle().fill(Color(red: 1, green: 0.83, blue: 0.42)).frame(width: 7, height: 7).position(pt(i))
            }
        }
    }
}


/// Épisode absent de la version choisie, pris dans une autre version de la même série.
struct EpisodeFill {
    let episode: EpisodeInfo
    let version: MediaItem
    let info: MediaInfo
    /// fournisseur de l'autre version, ou ses repères (« VOSTFR ») si c'est le même fournisseur
    let from: String

    static func find(main: MediaItem, info: MediaInfo, versions: [MediaItem], providerName: (String) -> String) async -> [String: EpisodeFill] {
        let others = versions.filter { $0.id != main.id }.prefix(4)
        guard !others.isEmpty else { return [:] }
        let have = Set(info.seasons.flatMap(\.episodes).map { "\($0.season)-\($0.number)" })
        var out: [String: EpisodeFill] = [:]
        for v in others {
            let vi = await InfoLoader.load(v)
            let from = v.pid != main.pid ? providerName(v.pid) : (v.clean.tags.isEmpty ? "une autre version" : "la version " + v.clean.tags.joined(separator: " · "))
            for e in vi.seasons.flatMap(\.episodes) {
                let k = "\(e.season)-\(e.number)"
                if !have.contains(k), out[k] == nil { out[k] = EpisodeFill(episode: e, version: v, info: vi, from: from) }
            }
        }
        return out
    }
}

/// Épisode annoncé par TMDB (prochaine diffusion) dans les 7 jours, pas encore chez le fournisseur.
struct UpcomingEpisode {
    let season: Int, number: Int, name: String, date: Date, days: Int

    static func load(tmdb: Int, have: Set<String>) async -> [UpcomingEpisode] {
        guard let key = TmdbKey.value, tmdb > 0 else { return [] }
        let api = TmdbAPI(key: key)
        guard let d = await api.get("/tv/\(tmdb)", [("language", "fr-FR")]),
              let nx = d["next_episode_to_air"] as? [String: Any], let sn = nx["season_number"] as? Int,
              let sd = await api.get("/tv/\(tmdb)/season/\(sn)", [("language", "fr-FR")]) else { return [] }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        return ((sd["episodes"] as? [[String: Any]]) ?? []).compactMap { e in
            guard let n = e["episode_number"] as? Int, let ds = e["air_date"] as? String, let date = f.date(from: ds),
                  !have.contains("\(sn)-\(n)") else { return nil }
            let j = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
            // comme le simulateur : diffusion dans 1 à 7 jours
            guard (1...7).contains(j) else { return nil }
            return UpcomingEpisode(season: sn, number: n, name: (e["name"] as? String) ?? "", date: date, days: j)
        }.sorted { $0.number < $1.number }
    }
}
