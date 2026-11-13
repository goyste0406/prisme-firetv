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
    @FocusState private var tabFocus: String?
    @FocusState private var playFocused: Bool

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
        .fullScreenCover(item: $showTrailer) { t in
            TrailerScreen(trailer: t, title: title, backdrop: (fiche?.backdrop.isEmpty == false) ? Fiche.img(fiche!.backdrop, "original") : info.backdrop,
                          poster: item.posterURL, playFilm: trailerPlay, playTitle: "Regarder la série")
        }
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
                HStack(alignment: .center, spacing: 18) {
                    Text(title).font(P.serif(titleSize)).lineLimit(2).minimumScaleFactor(0.6)
                    Button { showSyn = true } label: { Image(systemName: "info").font(P.font(22, .bold)).frame(width: 26, height: 26) }
                        .buttonStyle(GlassStyle(radius: 30, minH: 54))
                }
                meta
                actions
                if !all.isEmpty { progressCard }
                if info.seasons.count > 0 { seasonRows }
                if !all.isEmpty {
                    HStack(spacing: 22) {
                        Label("vu", systemImage: "checkmark").foregroundStyle(Color(red: 0.45, green: 0.85, blue: 0.5))
                        Text("● à suivre").foregroundStyle(.white.opacity(0.85))
                        Text("○ pas encore vu").foregroundStyle(P.faint)
                    }.font(P.font(17, .medium))
                }
                if loading { ProgressView().tint(.white).padding(.top, 20) }
            }
            .padding(.vertical, 30).padding(.horizontal, 12)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    private var titleSize: CGFloat { let n = title.count; return n <= 10 ? 86 : n <= 16 ? 74 : n <= 24 ? 62 : 52 }

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
        .font(P.font(22, .medium)).foregroundStyle(P.dim)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { mainAction() } label: { PlayLabel(title: mainLabel.0, sub: mainLabel.1) }
                .buttonStyle(PrimaryStyle())
                .focused($playFocused)
                .disabled(all.isEmpty)
            HStack(spacing: 16) {
                Button { watch.toggleFavorite(item.id) } label: {
                    Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus").font(P.font(28, .bold)).frame(width: 30)
                }.buttonStyle(GlassStyle(radius: 40, minH: 76))
                Button { if versions.count > 1 { pickVersion = true } } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(versionShort(cur)).font(P.font(25, .bold))
                        Text("\(max(1, versions.count)) VERSION\(versions.count > 1 ? "S ▾" : "")").font(P.font(15, .bold)).tracking(0.8).opacity(0.6)
                    }
                }.buttonStyle(GlassStyle(radius: 20, minH: 76))
                if let t = trailer {
                    Button { showTrailer = t } label: { Image(systemName: "film").font(P.font(26, .semibold)).frame(width: 30) }
                        .buttonStyle(GlassStyle(radius: 20, minH: 76))
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
        return d.formatted(.dateTime.weekday(.wide))
    }

    // lignes des saisons : une case par épisode (vu, en cours, pas vu)
    private var seasonRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(info.seasons) { s in
                let vu = s.episodes.filter { watch.watched(key($0)) }.count
                Button { season = s.number; tab = "eps" } label: {
                    HStack(spacing: 18) {
                        Text("Saison \(s.number)").font(P.font(22, .bold)).frame(width: 130, alignment: .leading)
                        HStack(spacing: 5) {
                            ForEach(s.episodes.prefix(24)) { e in
                                let st = state(e)
                                RoundedRectangle(cornerRadius: 4).fill(st == 2 ? Color(red: 0.45, green: 0.85, blue: 0.5).opacity(0.85) : st == 1 ? Color.white : Color.white.opacity(0.16))
                                    .frame(width: 18, height: 22)
                            }
                            if s.episodes.count > 24 { Text("+\(s.episodes.count - 24)").font(P.font(15, .bold)).opacity(0.6) }
                        }
                        Spacer(minLength: 0)
                        Text(vu == s.episodes.count ? "✓" : "\(vu)/\(s.episodes.count)").font(P.font(19, .semibold)).opacity(0.7)
                    }
                    .padding(.horizontal, 16).frame(height: 58)
                }
                .buttonStyle(SeasonStyle(selected: s.number == season))
            }
        }
        .focusSection()
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
                    Button { tab = k } label: { Text(SeriesDetailView.tabs[i].1).font(P.font(24, .semibold)) }
                        .buttonStyle(TabPillStyle(selected: tab == k))
                        .focused($tabFocus, equals: k)
                }
            }
            .padding(10)
            .focusSection()
            .onChange(of: tabFocus) { f in if let f { tab = f } }
            Divider().overlay(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { tabBody }
                    .padding(26).frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollClipDisabled(false)
            .focusSection()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saison \(s.number)").font(P.font(32, .bold))
                    Text("\(eps.count) ép." + (d > 0 ? " · " + runtimeText(d) : "") + (avg > 0 ? " · ★ " + String(format: "%.1f", avg).replacingOccurrences(of: ".", with: ",") : ""))
                        .font(P.font(19)).foregroundStyle(P.dim)
                }
                Spacer()
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
                }.focusSection()
            }
            ForEach(shown) { e in episodeRow(e) }
        } else if loading {
            ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 300)
        } else {
            Text("Aucun épisode chez le fournisseur pour cette série.").font(P.font(24)).foregroundStyle(P.dim).padding(.top, 40)
        }
    }

    private func episodeRow(_ e: EpisodeInfo) -> some View {
        let st = state(e)
        let f = watch.fraction(key(e))
        let m = mins(e)
        return Button { playEpisode(e, from: watch.resume(key(e)) ?? 0) } label: {
            HStack(alignment: .top, spacing: 24) {
                ZStack(alignment: .bottom) {
                    Poster(url: e.image.isEmpty ? (info.backdrop.isEmpty ? item.posterURL : info.backdrop) : e.image).frame(width: 288, height: 162)
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
                        if e.rating > 0 { Text("★ " + String(format: "%.1f", e.rating).replacingOccurrences(of: ".", with: ",")).foregroundStyle(e.rating >= 8.6 ? P.gold : .primary) }
                        if m > 0 { Text(runtimeText(m)) }
                        if st == 2 { Pill(text: "✓ VU", bg: Color.white.opacity(0.1), stroke: nil) }
                        else if f != nil { Pill(text: "EN COURS", bg: Color.white.opacity(0.85), fg: .black, stroke: nil) }
                    }.font(P.font(18, .medium)).opacity(0.75)
                    if !e.plot.isEmpty { Text(e.plot).font(P.font(19)).opacity(0.7).lineLimit(2) }
                }
                Spacer(minLength: 0)
            }.padding(12)
        }
        .buttonStyle(EpisodeStyle(current: st == 1))
    }

    /// Titre d'épisode sans le nom de la série répété par certains fournisseurs (« Lupin - S01E02 - … »).
    private func cleanEpTitle(_ t: String) -> String {
        let parts = t.components(separatedBy: " - ")
        if parts.count >= 3, parts[1].range(of: #"^S\d+E\d+$"#, options: [.regularExpression, .caseInsensitive]) != nil { return parts[2...].joined(separator: " - ") }
        return t
    }

    @ViewBuilder private var castTab: some View {
        let cast = castList(fiche: fiche, info: info)
        SectionTitle(title: "Qui est qui ?", sub: "sans spoiler : les personnages principaux")
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
        SectionTitle(title: "Séries proches", sub: fiche != nil ? "mêmes genres, les mieux notées d'abord" : "de la même catégorie chez ton fournisseur")
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
        if season == 0 { season = nextEp?.season ?? info.seasons.first?.number ?? 1 }
        loading = false
        if fiche == nil, TmdbKey.value != nil { fiche = await FicheWorker.fetchNow(item, tmdbHint: info.tmdb) }
        airings = await LiveStore.airings(title: title, providers: pids)
        trailer = await TrailerStore.find(tmdb: fiche?.tmdb ?? info.tmdb, tv: true, providerKey: info.trailer)
        var it = item; it.fiche = fiche
        similar = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 16).map { SimilarItem(item: $0.0, common: $0.1) }
    }

    private var trailerPlay: (() -> Void)? {
        if all.isEmpty { return nil }
        return { mainAction() }
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
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, current: current) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let current: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : .white)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(f ? Color.white : Color.white.opacity(current ? 0.08 : 0)))
                .overlay(alignment: .leading) { if current && !f { Capsule().fill(.white).frame(width: 4).padding(.vertical, 14) } }
                .scaleEffect(f ? 1.02 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 16, y: 8)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}
