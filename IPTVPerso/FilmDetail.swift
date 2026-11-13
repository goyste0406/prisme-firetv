import SwiftUI

// MARK: - Fiche d'un film (structure du simulateur : haut de fiche + panneau « Score prisme / Ta soirée / Aussi »,
// puis saga, même univers, distribution, « Si tu hésites encore », « Où le regarder »).

struct FilmDetailView: View {
    let item: MediaItem
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var fiche: Fiche?
    @State private var info = MediaInfo()
    @State private var versions: [MediaItem] = []
    @State private var chosen: MediaItem?
    @State private var playing: VodRequest?
    @State private var pickVersion = false
    @State private var sagaName = ""
    @State private var saga: [SagaPart] = []
    @State private var sagaAvail: [Int: MediaItem] = [:]
    @State private var universe: [MediaItem] = []
    @State private var similar: [SimilarItem] = []
    @State private var airings: [LiveStore.Airing] = []
    @State private var openOther: MediaItem?
    @State private var launchMsg: String?
    @State private var showSyn = false
    @State private var actor: CastMember?
    @State private var live: LiveLaunch?
    @State private var loaded = false
    @FocusState private var playFocused: Bool

    private var cur: MediaItem { chosen ?? item }
    private var title: String { (fiche?.title.isEmpty == false) ? fiche!.title : item.clean.title }
    /// Durée en minutes : TMDB, sinon le fournisseur. 0 = inconnue (l'heure de fin n'est alors pas affichée).
    private var minutes: Int { (fiche?.runtime ?? 0) > 0 ? fiche!.runtime : info.minutes }
    private var resumeAt: Double? { watch.resume(cur.id) ?? watch.resume(item.id) }
    private var providerRating: Double { item.rating > 0 ? item.rating : info.rating }
    private var tmdbVote: Double { fiche?.vote ?? 0 }
    private var shownRating: Double { tmdbVote > 0 ? tmdbVote : providerRating }
    private var plot: String { (fiche?.overview.isEmpty == false) ? fiche!.overview : (info.plot.isEmpty ? item.plot : info.plot) }
    private var genres: [String] {
        let g = (fiche?.genres.isEmpty == false) ? fiche!.genres : info.genre
        return g.components(separatedBy: CharacterSet(charactersIn: ",/")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var year: Int { (fiche?.year ?? 0) > 0 ? fiche!.year : (item.clean.year > 0 ? item.clean.year : info.year) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    top(proxy).id("top")
                    if saga.count > 1 { sagaRow }
                    if !universe.isEmpty {
                        MediaRow(title: saga.count > 1 ? "Dans le même univers" : "De la même saga",
                                 sub: "\(universe.count) film\(universe.count > 1 ? "s" : "") chez tes fournisseurs · reconnus par le titre",
                                 items: universe, open: { openOther = $0 })
                    }
                    castSection
                    if !similar.isEmpty { similarRow }
                    WhereSection(kind: .film, fiche: fiche, airings: airings, versions: versions,
                                 onTV: { live = LiveLaunch(ch: $0.ch) },
                                 onApp: { name in if let f = fiche { Task { launchMsg = await AppLauncher.open(providerName: name, tmdb: f.tmdb, tv: false) } } })
                        .padding(.horizontal, 120).id("where")
                }
                .padding(.bottom, 120)
            }
            .scrollClipDisabled()
        }
        .background(alignment: .top) {
            let hasBd = fiche?.backdrop.isEmpty == false
            DetailBackdrop(url: hasBd ? Fiche.img(fiche!.backdrop, "w1280") : (info.backdrop.isEmpty ? item.posterURL : info.backdrop),
                           sharp: hasBd || !info.backdrop.isEmpty)
        }
        .background(P.room)
        .ignoresSafeArea()
        .navigationDestination(item: $openOther) { it in DetailView(item: it) }
        .task(id: item.id) { await load() }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .fullScreenCover(item: $live) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .sheet(isPresented: $showSyn) { SynopsisSheet(kicker: "RÉSUMÉ", title: title, text: plot) }
        .sheet(item: $actor) { a in ActorSheet(actor: a, kind: .film, excluding: item.clean.key) }
        .confirmationDialog("Choisir la version", isPresented: $pickVersion) {
            ForEach(versions) { v in Button(versionLabel(v)) { chosen = v } }
        }
        .alert(launchMsg ?? "", isPresented: Binding(get: { launchMsg != nil }, set: { if !$0 { launchMsg = nil } })) { Button("OK") {} }
    }

    // MARK: haut de fiche (premier écran)

    private func top(_ proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .bottom, spacing: 50) {
            VStack(alignment: .leading, spacing: 18) {
                Text("FILM" + (info.country.isEmpty ? "" : " · " + info.country.uppercased())).font(P.font(21, .bold)).tracking(2.5).foregroundStyle(P.dim).lineLimit(1)
                Text(title).font(P.serif(titleSize)).lineLimit(2).minimumScaleFactor(0.6).frame(maxWidth: 1080, alignment: .leading)
                meta
                if shownRating >= 7.5 {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill").font(P.font(18)).padding(8).background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "star.fill").font(P.font(18))
                        Text(String(format: "%.1f", shownRating) + " · " + ratingWord(shownRating)).font(P.font(22, .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8).glass(14)
                }
                if !plot.isEmpty {
                    Button { showSyn = true } label: {
                        Text(plot).font(P.font(27)).lineLimit(2).multilineTextAlignment(.leading).frame(maxWidth: 1040, alignment: .leading).padding(.vertical, 8)
                    }.buttonStyle(TextBlockStyle())
                }
                actions.focusSection()
            }
            Spacer(minLength: 0)
            panel(proxy)
        }
        .padding(.horizontal, 120)
        .frame(width: 1920, height: 1010, alignment: .bottom)
        .focusSection()
    }

    private var titleSize: CGFloat {
        let n = title.count
        return n <= 10 ? 120 : n <= 16 ? 106 : n <= 24 ? 88 : n <= 34 ? 72 : 60
    }

    private var meta: some View {
        HStack(spacing: 20) {
            if year > 0 { Text(String(year)) }
            if minutes > 0 { Text(runtimeText(minutes)) }
            if !genres.isEmpty { Text(genres.prefix(2).joined(separator: ", ")).lineLimit(1) }
            if !info.age.isEmpty { Text(info.age) }
            if shownRating > 0 { Stars(value: shownRating) }
            let t = cur.clean.tags
            if !t.isEmpty { Pill(text: t.joined(separator: " · "), bg: .clear) }
        }
        .font(P.font(26, .medium)).foregroundStyle(P.dim)
    }

    private var actions: some View {
        HStack(spacing: 20) {
            Button { play(from: resumeAt ?? 0) } label: {
                if let r = resumeAt {
                    PlayLabel(title: "Reprendre", sub: minutes > 0 ? "RESTE " + runtimeText(max(1, (minutes * 60 - Int(r)) / 60)).uppercased() : nil)
                } else {
                    PlayLabel(title: "Lecture", sub: minutes > 0 ? "FINIT À " + Fmt.hm(Date().addingTimeInterval(Double(minutes * 60))) : nil)
                }
            }
            .buttonStyle(PrimaryStyle())
            .focused($playFocused)
            if resumeAt != nil {
                Button { play(from: 0) } label: { Label("Début", systemImage: "gobackward").font(P.font(27, .semibold)) }.buttonStyle(GlassStyle())
            }
            Button { watch.toggleFavorite(item.id) } label: {
                Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus").font(P.font(30, .bold)).frame(width: 34)
            }.buttonStyle(GlassStyle(radius: 42, minH: 84))
            Button { if versions.count > 1 { pickVersion = true } } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(versionShort(cur)).font(P.font(26, .bold))
                    Text("\(max(1, versions.count)) VERSION\(versions.count > 1 ? "S" : "")" + (versions.count > 1 ? " ▾" : "")).font(P.font(15, .bold)).tracking(0.8).opacity(0.6)
                }
            }.buttonStyle(GlassStyle())
            if !info.trailer.isEmpty {
                Button { Task { launchMsg = await openTrailer(info.trailer) } } label: { Image(systemName: "film").font(P.font(28, .semibold)).frame(width: 34) }
                    .buttonStyle(GlassStyle(radius: 22, minH: 84))
            }
        }
        .defaultFocus($playFocused, true)
    }

    // MARK: panneau de droite : Score prisme · Ta soirée · Aussi

    @ViewBuilder private func panel(_ proxy: ScrollViewProxy) -> some View {
        let hasScore = providerRating > 0 || tmdbVote > 0
        if hasScore || minutes > 0 || !alsoParts.isEmpty {
            VStack(alignment: .leading, spacing: 22) {
                if hasScore { scoreBox }
                if minutes > 0 { evening }
                if !alsoParts.isEmpty {
                    Button { withAnimation { proxy.scrollTo("where", anchor: .top) } } label: {
                        HStack(spacing: 14) {
                            Text("AUSSI").font(P.font(17, .bold)).tracking(2).opacity(0.5)
                            Text(alsoParts.joined(separator: " · ")).font(P.font(20, .semibold)).lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(P.font(18, .bold))
                        }.padding(.horizontal, 18).frame(height: 62)
                    }.buttonStyle(WhereCardStyle())
                }
            }
            .padding(28).frame(width: 600).glass(30)
            .focusSection()
        }
    }

    private var scoreLine: String {
        var l: [String] = []
        if providerRating > 0 { l.append("Note " + String(format: "%.1f", providerRating)) }
        if tmdbVote > 0 { l.append("TMDB \(Int((tmdbVote * 10).rounded())) %") }
        return l.joined(separator: " · ")
    }

    /// Score prisme (sans goûts enregistrés, comme le simulateur : la moyenne des notes disponibles).
    private var scoreBox: some View {
        var parts: [Double] = []
        if providerRating > 0 { parts.append(providerRating * 10) }
        if tmdbVote > 0 { parts.append(tmdbVote * 10) }
        let sc = min(99, Int((parts.reduce(0, +) / Double(max(1, parts.count))).rounded()))
        return HStack(spacing: 20) {
            ZStack {
                Ring(value: Double(sc) / 100, width: 9).frame(width: 92, height: 92)
                Circle().fill(Color.black.opacity(0.55)).frame(width: 74, height: 74)
                Text("\(sc)").font(P.font(32, .heavy))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Score prisme").font(P.font(21, .bold)).foregroundStyle(P.gold)
                Text(scoreLine).font(P.font(19)).foregroundStyle(P.dim)
                Text("Tes goûts : à découvrir").font(P.font(19)).foregroundStyle(P.dim)
            }
        }
    }

    private var evening: some View {
        let now = Date()
        let left = max(60, Double(minutes * 60) - (resumeAt ?? 0))
        let end = now.addingTimeInterval(left)
        let span = max(left + 1800, 3 * 3600)
        let a = 0.08, b = min(0.94, a + left / span)
        return VStack(alignment: .leading, spacing: 16) {
            Text("TA SOIRÉE").font(P.font(17, .bold)).tracking(2).foregroundStyle(P.faint)
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14)).frame(height: 8)
                    Capsule().fill(LinearGradient(colors: [P.gold, Color(red: 1, green: 0.55, blue: 0.22)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(16, w * (b - a)), height: 14).offset(x: w * a)
                    Rectangle().fill(Color(red: 0.4, green: 0.75, blue: 1)).frame(width: 3, height: 34).offset(x: w * a - 1.5)
                }.frame(height: 34)
            }.frame(height: 34)
            HStack { Text("maintenant"); Spacer(); Text("fin " + Fmt.hm(end)) }.font(P.font(17)).foregroundStyle(P.faint)
            (Text("Fin à " + Fmt.hm(end)).foregroundColor(P.gold).bold() + Text(" · dans " + runtimeText(Int(left / 60))).foregroundColor(P.dim)).font(P.font(23))
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1.5))
    }

    private var alsoParts: [String] {
        var p: [String] = []
        if let a = airings.first { p.append(a.ch.name + (a.p.startDate <= Date() ? " en direct" : " " + Fmt.hm(a.p.startDate))) }
        if let f = fiche {
            p += Array(Array(Set((f.wp.f + f.wp.g).map(\.n))).sorted().prefix(2))
            if !f.wp.r.isEmpty { p.append("location") }
        }
        return p
    }

    // MARK: sections du bas

    private var sagaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            let n = saga.filter { sagaAvail[$0.tmdb] != nil }.count
            SectionTitle(title: sagaName.isEmpty ? "La saga" : sagaName, sub: "\(saga.count) films" + (n < saga.count ? " · \(n) chez tes fournisseurs" : " · tous chez tes fournisseurs")).padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 34) {
                    ForEach(Array(saga.enumerated()), id: \.element.tmdb) { i, p in
                        let here = sagaAvail[p.tmdb]
                        let isThis = fiche?.tmdb == p.tmdb
                        Button {
                            if let m = here { if !isThis { openOther = m } }
                            else { launchMsg = "« \(p.title) » n'est chez aucun de tes fournisseurs pour le moment." }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                Poster(url: Fiche.img(p.poster), title: p.title).frame(width: 210, height: 315)
                                    .saturation(here == nil ? 0 : 1).opacity(here == nil ? 0.45 : 1)
                                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title).font(P.font(21, .bold)).lineLimit(2)
                                    Text(p.year > 0 ? String(p.year) : "à venir").font(P.font(17)).opacity(0.7)
                                }.foregroundStyle(.white).padding(14)
                                VStack {
                                    Pill(text: sagaTag(i, isThis: isThis, here: here), bg: .black.opacity(0.65), stroke: nil).padding(10)
                                    Spacer()
                                }
                            }.frame(width: 210, height: 315)
                        }.buttonStyle(TileStyle())
                    }
                }.padding(.horizontal, 120).padding(.vertical, 34)
            }.scrollClipDisabled()
        }.focusSection()
    }

    private func sagaTag(_ i: Int, isThis: Bool, here: MediaItem?) -> String {
        if isThis { return "\(i + 1) · cette page" }
        guard let h = here else { return "\(i + 1) · pas chez tes fournisseurs" }
        return watch.watched(h.id) ? "\(i + 1) · ✓ Vu" : "\(i + 1)"
    }

    private var creditLine: String {
        var parts: [String] = []
        if !info.director.isEmpty { parts.append("Réalisé par " + info.director) }
        if year > 0 { parts.append(String(year)) }
        if providerRating > 0 { parts.append("Note " + String(format: "%.1f", providerRating)) }
        if tmdbVote > 0 { parts.append("TMDB \(Int((tmdbVote * 10).rounded())) %") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var castSection: some View {
        let cast = castList(fiche: fiche, info: info)
        let director = info.director
        if !cast.isEmpty || !director.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(title: "Distribution", sub: fiche != nil ? "OK pour ses autres films dans ton abonnement" : nil).padding(.horizontal, 120)
                if !cast.isEmpty {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 26) {
                            ForEach(cast, id: \.self) { a in
                                Button { if fiche != nil { actor = a } } label: { CastCircle(name: a.n, role: a.c, photo: a.p) }.buttonStyle(CircleStyle())
                            }
                        }.padding(.horizontal, 120).padding(.vertical, 22)
                    }.scrollClipDisabled()
                }
                if !creditLine.isEmpty { Text(creditLine).font(P.font(21)).foregroundStyle(P.dim).padding(.horizontal, 120) }
            }.focusSection()
        }
    }

    private var similarRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Si tu hésites encore", sub: fiche != nil ? "selon les genres de ce film · les mieux notés d'abord" : "de la même catégorie chez ton fournisseur").padding(.horizontal, 120)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 34) {
                    ForEach(similar) { pair in
                        VStack(alignment: .leading, spacing: 12) {
                            PosterButton(item: pair.item) { openOther = pair.item }
                            if !pair.common.isEmpty {
                                Text("Thèmes communs : " + pair.common.prefix(2).joined(separator: ", ").lowercased()).font(P.font(17)).foregroundStyle(P.dim).lineLimit(2).frame(width: 210, alignment: .leading)
                            }
                        }
                    }
                }.padding(.horizontal, 120).padding(.vertical, 34)
            }.scrollClipDisabled()
        }.focusSection()
    }

    // MARK: données

    private func load() async {
        let pids = store.active.map(\.id)
        if item.fiche != nil { fiche = item.fiche }
        else { let k = item.kind, key = item.clean.key; fiche = await Database.shared.read { _ in FicheStore.byKeys(k, [key])[key] } }
        async let i = InfoLoader.load(item)
        async let v = MediaStore.versions(of: item, pids: pids)
        let (i1, v1) = await (i, v)
        info = i1; versions = v1
        if chosen == nil { chosen = v1.first }
        // fiche TMDB pas encore téléchargée en arrière-plan : on la cherche tout de suite pour ce film
        if fiche == nil, TmdbKey.value != nil { fiche = await FicheWorker.fetchNow(item, tmdbHint: i1.tmdb) }
        var titles = [title]
        if item.clean.title.lowercased() != title.lowercased() { titles.append(item.clean.title) }
        var air: [LiveStore.Airing] = []
        for t in titles where air.isEmpty { air = await LiveStore.airings(title: t, providers: pids) }
        airings = air
        var exclude = Set<Int>()
        if let f = fiche, f.coll > 0 {
            let (n, parts) = await SagaStore.parts(f.coll)
            sagaName = n; saga = parts
            sagaAvail = await MediaStore.items(kind: .film, tmdb: parts.map(\.tmdb), pids: pids)
            exclude = Set(parts.map(\.tmdb))
        }
        if let f = fiche { exclude.insert(f.tmdb) }
        var it = item; it.fiche = fiche
        universe = await MediaStore.universe(of: it, pids: pids, exclude: exclude)
        let skip = Set(universe.map(\.clean.key)).union(sagaAvail.values.map(\.clean.key))
        similar = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 16).filter { !skip.contains($0.0.clean.key) }.map { SimilarItem(item: $0.0, common: $0.1) }
        loaded = true
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

    private func play(from: Double) {
        guard let p = store.provider(cur.pid), let url = p.movieURL(cur) else { return }
        playing = VodRequest(url: url, key: item.id, item: item.id, title: title, subtitle: "", icon: item.posterURL, startAt: from)
    }
}

/// Bloc de texte sélectionnable (résumé) : léger voile quand il est sélectionné.
struct TextBlockStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(.white.opacity(f ? 1 : 0.85)).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(f ? 0.14 : 0)))
                .scaleEffect(f ? 1.01 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// « OK sur un acteur » : ses autres films dans tes abonnements.
struct ActorSheet: View {
    let actor: CastMember
    let kind: MediaKind
    let excluding: String
    @EnvironmentObject var store: ProviderStore
    @State private var list: [MediaItem] = []
    @State private var done = false
    @State private var open: MediaItem?
    var body: some View {
        NavigationStack {
            ZStack {
                PrismeBackground()
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 26) {
                        CastCircle(name: actor.n, role: "", photo: actor.p).scaleEffect(0.8).frame(width: 180, height: 200)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DANS TON ABONNEMENT").font(P.font(18, .bold)).tracking(2).foregroundStyle(P.faint)
                            Text(actor.n).font(P.font(54, .bold))
                            Text(done ? (list.isEmpty ? "Aucun autre titre avec cet acteur chez tes fournisseurs (d'après les fiches déjà téléchargées)." : "\(list.count) titre\(list.count > 1 ? "s" : "")") : "Recherche…")
                                .font(P.font(23)).foregroundStyle(P.dim)
                        }
                    }.padding(.horizontal, 120)
                    if !list.isEmpty { MediaRow(title: kind == .film ? "Ses films" : "Ses séries", items: list, open: { open = $0 }) }
                    Spacer()
                }.padding(.top, 90)
            }
            .ignoresSafeArea()
            .navigationDestination(item: $open) { it in DetailView(item: it) }
        }
        .task {
            list = await MediaStore.withActor(actor.n, kind: kind, pids: store.active.map(\.id), excluding: excluding)
            done = true
        }
    }
}
