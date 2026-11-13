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
    @State private var trailer: Trailer?
    @State private var showTrailer: Trailer?
    @State private var loaded = false
    @State private var why: [WhyReason] = []
    @State private var splitOpen = false
    @State private var clock = Date()
    @ObservedObject private var profiles = ProfileStore.shared
    private let minuteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @FocusState private var playFocused: Bool
    @FocusState private var versionFocused: Bool
    @FocusState private var splitFocused: Bool

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
    /// Pays de production : TMDB (« France »), sinon le fournisseur.
    private var countryText: String { (fiche?.countryName.isEmpty == false) ? fiche!.countryName : info.country }
    private var year: Int { (fiche?.year ?? 0) > 0 ? fiche!.year : (item.clean.year > 0 ? item.clean.year : info.year) }

    /// Police du titre (règle du simulateur, d'après les genres).
    private var face: TitleFace { TitleFace.of(genres: genres) }
    /// Bande-annonce en fond de fiche (2,5 s après l'ouverture, comme le simulateur).
    @StateObject private var bg = TrailerHolder()
    @FocusState private var trailerFocused: Bool
    /// Sélection sur le bouton bande-annonce : le texte s'efface pour laisser voir la vidéo (simulateur « peek »).
    private var peek: Bool { trailerFocused && bg.playing }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 60) {
                        top(proxy).id("top")
                        if saga.count > 1 { sagaRow }
                        if !universe.isEmpty {
                            // (même franchise d'après TMDB, autres sagas : jamais d'après la ressemblance des titres)
                            MediaRow(title: "Dans le même univers", sub: "\(universe.count) film\(universe.count > 1 ? "s" : "") chez tes fournisseurs · même franchise selon TMDB", items: universe, open: { openOther = $0 })
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
            .disabled(pickVersion || splitOpen)
            .defaultFocus($playFocused, true, priority: .userInitiated)
            if splitOpen {
                SplitModal(title: title, minutes: minutes, start: { m in
                    splitOpen = false
                    SplitStore.set(item.id, Double(m * 60))
                    play(from: 0, stopAt: Double(m * 60))
                }, close: { splitOpen = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { splitFocused = true } })
                .transition(.opacity)
            }
            if pickVersion {
                VersionsModal(title: title, versions: versions, current: cur, label: { versionInfo($0) },
                              pick: { v in chosen = v; pickVersion = false; play(from: resumeAt ?? 0, item: v) },
                              close: { pickVersion = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { versionFocused = true } })
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: pickVersion)
        .animation(.easeOut(duration: 0.2), value: splitOpen)
        .onReceive(minuteTimer) { clock = $0 }
        .background(alignment: .top) {
            let hasBd = fiche?.backdrop.isEmpty == false
            ZStack {
                DetailBackdrop(backdrop: hasBd ? Fiche.img(fiche!.backdrop, "original") : info.backdrop, poster: item.posterURL, video: bg.player, playing: bg.playing, peek: peek)
                if bg.playing, let t = trailer {
                    TrailerChip(lang: t.lang, loud: peek).padding(.top, 142).padding(.trailing, 105)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .transition(.opacity)
                }
            }
            .frame(width: 1920, height: 1080)
            .animation(.easeInOut(duration: 0.45), value: bg.playing)
        }
        .background(P.room)
        .ignoresSafeArea()
        .navigationDestination(item: $openOther) { it in DetailView(item: it) }
        .task(id: item.id) { await load() }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if !pickVersion { playFocused = true } } }
        .onDisappear { bg.stop() }
        .onChange(of: peek) { _, p in bg.loud(p) }
        .onChange(of: playing?.id) { _, p in if p != nil { bg.stop() } }
        .onChange(of: showTrailer) { _, t in if t != nil { bg.stop() } }
        .fullScreenCover(item: $playing) { r in VodPlayerView(request: r) }
        .fullScreenCover(item: $live) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .fullScreenCover(item: $showTrailer) { t in TrailerScreen(trailer: t, title: title, playFilm: trailerPlay) }
        .sheet(isPresented: $showSyn) { SynopsisSheet(kicker: "RÉSUMÉ", title: title, text: plot) }
        .sheet(item: $actor) { a in ActorSheet(actor: a, kind: .film, excluding: item.clean.key) }
        .alert(launchMsg ?? "", isPresented: Binding(get: { launchMsg != nil }, set: { if !$0 { launchMsg = nil } })) { Button("OK") {} }
    }

    // MARK: haut de fiche (premier écran) — mesures du simulateur (fiche film « W2 »), converties pour la télé

    private func top(_ proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .bottom, spacing: 78) {
            VStack(alignment: .leading, spacing: 0) {
                Text("FILM" + (countryText.isEmpty ? "" : " · " + countryText.uppercased()))
                    .font(P.font(24, .bold)).tracking(3.4).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    .padding(.bottom, 15).opacity(peek ? 0.14 : 1)
                BigTitle(text: title, face: face).padding(.bottom, 18).opacity(peek ? 0.14 : 1)
                meta.padding(.bottom, 19)
                if let w = why.first { whyChip(w).padding(.bottom, 17) }
                if !plot.isEmpty {
                    Button { showSyn = true } label: {
                        Text(plot).font(P.font(31)).lineSpacing(9).lineLimit(2).multilineTextAlignment(.leading)
                            .foregroundStyle(.white.opacity(0.82)).frame(width: 1050, alignment: .leading).padding(.vertical, 6)
                    }.buttonStyle(TextBlockStyle())
                    .padding(.leading, -14).opacity(peek ? 0.14 : 1)
                }
                actions.focusSection().padding(.top, 28)
            }
            .frame(width: 1050, alignment: .leading)
            panel(proxy).opacity(peek ? 0.14 : 1)
        }
        .animation(.easeInOut(duration: 0.45), value: peek)
        .padding(.leading, 120)
        .padding(.bottom, 18)
        .frame(width: 1920, height: 1002, alignment: .bottomLeading)
        // pastille du profil en haut à gauche (simulateur « who ») : OK pour changer de profil
        .overlay(alignment: .topLeading) { ProfileChip().padding(.leading, 120).padding(.top, 45).opacity(peek ? 0.14 : 1).focusSection() }
        .padding(.bottom, -60)
        .focusSection()
    }

    private var meta: some View {
        HStack(spacing: 26) {
            if year > 0 { Text(String(year)) }
            if minutes > 0 { Text(runtimeText(minutes)) }
            if !genres.isEmpty { Text(genres.prefix(2).joined(separator: ", ")).lineLimit(1) }
            if !info.age.isEmpty { Text(info.age) }
            if shownRating > 0 {
                HStack(spacing: 8) { Image(systemName: "star.fill").font(P.font(25)); Text(String(format: "%.1f", shownRating)).fontWeight(.bold) }
                    .foregroundStyle(Color(red: 1, green: 211 / 255, blue: 107 / 255))
            }
            let t = cur.clean.tags.filter { ["4K", "1080p", "720p", "HDR", "HEVC", "SD"].contains($0) }
            if !t.isEmpty {
                Text(t.joined(separator: " · ")).font(P.font(23, .bold)).tracking(0.4)
                    .padding(.horizontal, 17).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            }
        }
        .font(P.font(30)).foregroundStyle(.white.opacity(0.82)).lineLimit(1)
        .opacity(peek ? 0.14 : 1)
    }

    /// Puce « pourquoi ce film » (simulateur whyc) : la première raison réelle (saga vue, acteur, genre préféré, note).
    private func whyChip(_ w: WhyReason) -> some View {
        HStack(spacing: 15) {
            Image(systemName: w.icon).font(P.font(19)).frame(width: 36, height: 36)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Text(w.text).font(P.font(26))
        }
        .padding(.leading, 14).padding(.trailing, 22).padding(.vertical, 12)
        .background(Color(red: 10 / 255, green: 11 / 255, blue: 15 / 255).opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
        .opacity(peek ? 0.14 : 1)
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
            .buttonStyle(FicheButtonStyle(prim: true))
            .focused($playFocused)
            .opacity(peek ? 0.22 : 1)
            if resumeAt != nil {
                Button { play(from: 0) } label: { Label("Début", systemImage: "gobackward").font(P.font(30, .semibold)) }
                    .buttonStyle(FicheButtonStyle()).opacity(peek ? 0.22 : 1)
            }
            if resumeAt == nil, plan?.needSplit == true {
                // le film finit trop tard pour le profil actif : le couper en deux soirées
                Button { splitOpen = true } label: { Label("En 2 soirées", systemImage: "moon").font(P.font(30, .semibold)) }
                    .buttonStyle(FicheButtonStyle()).opacity(peek ? 0.22 : 1).focused($splitFocused)
            }
            Button { watch.toggleFavorite(item.id) } label: {
                Image(systemName: watch.favorites.contains(item.id) ? "checkmark" : "plus").font(P.font(32, .bold))
            }.buttonStyle(FicheButtonStyle(square: true)).opacity(peek ? 0.22 : 1)
            Button { if versions.count > 1 { pickVersion = true } else { launchMsg = "Une seule version chez ton fournisseur" } } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(versionShort(cur)).font(P.font(32, .bold))
                    Text("\(max(1, versions.count)) VERSION\(versions.count > 1 ? "S" : "") ▾").font(P.font(19, .bold)).tracking(1.2).opacity(0.6)
                }
            }.buttonStyle(FicheButtonStyle()).opacity(peek ? 0.22 : 1)
            .focused($versionFocused)
            if let t = trailer {
                // bouton « bande-annonce » du simulateur : sélectionné, la vidéo de fond passe devant le texte ; OK = plein écran
                Button { showTrailer = t } label: { Image(systemName: "film").font(P.font(30, .semibold)) }
                    .buttonStyle(FicheButtonStyle(square: true, pulse: peek))
                    .focused($trailerFocused)
            }
        }
    }

    // MARK: panneau de droite : Score prisme · Ta soirée · Aussi

    @ViewBuilder private func panel(_ proxy: ScrollViewProxy) -> some View {
        let hasScore = providerRating > 0 || tmdbVote > 0
        if true {
            VStack(alignment: .leading, spacing: 26) {
                if hasScore { scoreBox }
                evening
                if !alsoParts.isEmpty {
                    Button { withAnimation { proxy.scrollTo("where", anchor: .top) } } label: {
                        HStack(spacing: 18) {
                            Text("AUSSI").font(P.font(19, .bold)).tracking(3).opacity(0.5)
                            Text(alsoParts.joined(separator: " · ")).font(P.font(25, .medium)).lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(P.font(20, .heavy)).opacity(0.6)
                        }.padding(.horizontal, 26).frame(height: 64)
                    }.buttonStyle(WhereCardStyle())
                }
            }
            .padding(28).frame(width: 600, alignment: .leading)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 45, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 45, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
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
        return HStack(spacing: 22) {
            ZStack {
                Ring(value: Double(sc) / 100, width: 10).frame(width: 96, height: 96)
                Circle().fill(Color(red: 0.07, green: 0.08, blue: 0.1)).frame(width: 76, height: 76)
                Text("\(sc)").font(P.font(36, .bold))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Score prisme").font(P.font(24, .bold)).foregroundStyle(P.gold)
                Text(scoreLine).font(P.font(23)).foregroundStyle(P.gold.opacity(0.75))
                Text("Tes goûts : à découvrir").font(P.font(23)).foregroundStyle(P.gold.opacity(0.75))
            }
        }
    }

    /// minutes restantes (durée réelle moins la reprise) ; nil si la durée est inconnue
    private var remainingMin: Int? {
        guard minutes > 0 else { return nil }
        return max(1, Int((Double(minutes * 60) - (resumeAt ?? 0)) / 60))
    }
    /// heure du coucher du profil actif (en test seulement : remplacée par « maintenant + N min »)
    private var bedMinutes: Int {
        if let n = Debug.bedInMinutes {
            let c = Calendar.current.dateComponents([.hour, .minute], from: clock.addingTimeInterval(Double(n) * 60))
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        return profiles.me.bed
    }
    private var plan: EveningPlan? { EveningPlan.make(remaining: remainingMin, bed: bedMinutes, at: clock) }

    /// « TA SOIRÉE » (simulateur planHtml) : frise maintenant → fin, trait bleu du coucher du profil actif, message.
    private var evening: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TA SOIRÉE").font(P.font(21, .bold)).tracking(2.6).foregroundStyle(.white.opacity(0.55))
            if let p = plan {
                EveningTimeline(p: p)
                Group {
                    if let cut = SplitStore.get(item.id), resumeAt != nil, minutes > 0 {
                        Text("Partie 1 vue").foregroundColor(.white.opacity(0.86)) + Text(" · ") + Text("partie 2 : " + EveningPlan.dur(max(1, minutes - Int(cut / 60)))).bold().foregroundColor(P.gold)
                    } else {
                        Text(p.message.bold).bold().foregroundColor(P.gold) + Text(p.message.rest).foregroundColor(.white.opacity(0.86))
                    }
                }
                .font(P.font(27)).lineSpacing(4).padding(.top, 16)
            } else {
                Text("Durée inconnue chez ton fournisseur et sur TMDB : l'heure de fin ne peut pas être calculée.").font(P.font(23)).foregroundStyle(.white.opacity(0.7)).padding(.top, 10)
            }
        }
        .padding(26).frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1.5))
    }

    private var alsoParts: [String] {
        var p: [String] = []
        if let a = airings.first { p.append(a.ch.name + (a.p.startDate <= Date() ? " en direct" : " ce soir " + Fmt.hm(a.p.startDate))) }
        if let f = fiche {
            p += Array(Array(Set((f.wp.f + f.wp.g).map(\.n))).sorted().prefix(2))
            if !f.wp.r.isEmpty { p.append("location") }
        }
        return p
    }

    // MARK: sections du bas

    private var sagaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: sagaName.isEmpty ? "La saga" : sagaName).padding(.horizontal, 120)
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
        let dir = (fiche?.director.isEmpty == false) ? fiche!.director : info.director
        if !dir.isEmpty { parts.append("Réalisé par " + dir) }
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
                SectionTitle(title: "Distribution").padding(.horizontal, 120)
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
            SectionTitle(title: "Si tu hésites encore").padding(.horizontal, 120)
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
        trailer = await TrailerStore.find(title: title, year: year, minutes: minutes, tmdb: fiche?.tmdb ?? i1.tmdb, tv: false)
        if let t = trailer { bg.arm(t.url) }
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
        let skip = Set(universe.map(\.workKey)).union(sagaAvail.values.map(\.workKey)).union(exclude.map { "t\($0)" })
        similar = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 16).filter { !skip.contains($0.0.workKey) }.map { SimilarItem(item: $0.0, common: $0.1) }
        why = await WhyBuilder.reasons(fiche: fiche, rating: shownRating, item: item, pids: pids)
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

    private var trailerPlay: (() -> Void)? { { play(from: resumeAt ?? 0) } }

    private func play(from: Double, item v: MediaItem? = nil, stopAt: Double? = nil) {
        let src = v ?? cur
        guard let p = store.provider(src.pid), let url = p.movieURL(src) else { return }
        bg.stop()
        var r = VodRequest(url: url, key: item.id, item: item.id, title: title, subtitle: "", icon: item.posterURL, startAt: from)
        // partie 1 d'un film coupé en deux soirées : arrêt prévu (encore à venir)
        if let s = stopAt ?? SplitStore.get(item.id), from < s - 60 { r.stopAt = s }
        playing = r
    }

    /// Ligne de détail d'une version (fenêtre « Choisis la version ») : uniquement ce que dit le nom chez le fournisseur.
    private func versionInfo(_ v: MediaItem) -> VersionsModal.Row {
        let t = v.clean.tags
        let q = t.first { ["4K", "1080p", "720p", "SD"].contains($0) } ?? (t.contains("HD") ? "HD" : "")
        var lang: [String] = []
        let raw = v.name.uppercased()
        if raw.contains("VFF") || raw.contains("TRUEFRENCH") { lang.append("Français (France) · VFF") }
        else if raw.contains("VFQ") { lang.append("Français (Québec) · VFQ") }
        else if t.contains("VF") { lang.append("Français · VF") }
        if t.contains("MULTI") { lang.append("Plusieurs langues · MULTI") }
        if t.contains("VOSTFR") { lang.append("VO sous-titrée français") }
        if t.contains("VO") { lang.append("Version originale") }
        let extra = t.filter { ["HDR", "HEVC", "DV", "ATMOS", "5.1"].contains($0) }
        return .init(quality: q, provider: store.provider(v.pid)?.name ?? "Fournisseur", raw: v.name + (extra.isEmpty ? "" : ""),
                     audio: lang, isDefault: v.id == (versions.first?.id ?? ""))
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
