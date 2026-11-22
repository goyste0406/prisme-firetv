import SwiftUI

// MARK: - Lot 3 : page Recherche du simulateur (srHtml) — 3 colonnes
// Écran logique du simulateur 1280 × 720, × 1,5 : clavier à gauche (56 → 84, largeur 340 → 510), filtres et liste au
// milieu (420 → 630, largeur 430 → 645), aperçu à droite (872 → 1308, jusqu'à 40 → 60 du bord), sous la barre (110 → 165).

struct SearchView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @ObservedObject var profiles = ProfileStore.shared
    @ObservedObject var fiches = FicheService.shared
    @State private var q = Debug.arg("prisme.debug.q") ?? ""
    @State private var native = ""
    @State private var filt = Debug.arg("prisme.debug.filt") ?? "all"
    @State private var res = SearchIndex.Result()
    @State private var items: [String: MediaItem] = [:]
    @State private var live: [LiveStore.Airing] = []
    @State private var liveHits: [LiveStore.Airing] = []
    @State private var trend: [MediaItem] = []
    @State private var recent: [String] = []
    @State private var sel: Sel?
    @State private var open: MediaItem?
    @State private var openPlay: MediaItem?
    @State private var actor: CastMember?
    @State private var watchLive: LiveLaunch?
    @State private var ready = false
    @FocusState private var focus: String?

    enum Sel: Equatable { case item(String), ch(LiveStore.Airing), actor(String) }

    private static let rows: [[String]] = ["abcdef", "ghijkl", "mnopqr", "stuvwx", "yz1234", "567890"].map { $0.map(String.init) }
    private static let filters: [(String, String)] = [("all", "Tout"), ("f", "Films"), ("s", "Séries"), ("tv", "TV en direct"), ("actor", "Acteurs")]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TopBar(claimFocus: q.isEmpty)
            HStack(alignment: .top, spacing: 0) {
                leftColumn.frame(width: 510)
                Spacer().frame(width: 36)
                midColumn.frame(width: 645)
                Spacer().frame(width: 33)
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.leading, 84).padding(.trailing, 60).padding(.bottom, 36)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .navigationDestination(item: $openPlay) { it in DetailView(item: it, autoPlay: true) }
        .sheet(item: $actor) { a in ActorSheet(actor: a, kind: .film, excluding: "", both: true) }
        .fullScreenCover(item: $watchLive) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .task(id: "\(q)|\(store.catalogVersion)|\(fiches.version / 10)|\(profiles.version)") { await run() }
        .onAppear { recent = SearchRecent.list }
        .onChange(of: native) { _, t in if !t.isEmpty { q = t } }
        .onChange(of: focus) { old, f in
            if let f, f.hasPrefix("k-") || f.hasPrefix("srf-") { if f != "k-siri" { native = "" } }
            // en descendant de la barre du haut : le clavier, sur « a » (simulateur data-default)
            if old == nil, let f, f.hasPrefix("srf-") { focus = "k-a" }
        }
    }

    // MARK: gauche : saisie, clavier, note (simulateur .sr-left)

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                if q.isEmpty { Text("Rechercher").foregroundStyle(.white.opacity(0.45)).font(P.font(33, .medium)) }
                else { Text(q).font(P.font(33, .semibold)).lineLimit(1).truncationMode(.head) }
                Rectangle().fill(Color.white).frame(width: 3, height: 36).opacity(0.85)
            }
            .padding(.vertical, 18).padding(.horizontal, 27).frame(maxWidth: .infinity, minHeight: 81, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.08)))
            .accessibilityIdentifier("sr-q").accessibilityLabel(q)
            VStack(spacing: 7.5) {
                ForEach(Self.rows, id: \.self) { r in
                    HStack(spacing: 7.5) { ForEach(r, id: \.self) { k in key("k-" + k, k, wide: false) { type(k) } } }
                }
                HStack(spacing: 7.5) {
                    key("k-sp", "espace", wide: true) { type(" ") }
                    key("k-del", "⌫", wide: true) { if !q.isEmpty { q.removeLast() } }
                    siriKey
                }
            }
            .focusSection()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "iphone").font(.system(size: 20)).opacity(0.6)
                Text("Clavier de l'iPhone ou dictée : touche Siri · fautes de frappe pardonnées · « films avec Omar Sy », « comédie années 90 », « le match en ce moment »")
                    .font(P.font(19.5)).foregroundStyle(.white.opacity(0.6)).lineSpacing(3)
            }
        }
    }

    private func key(_ id: String, _ t: String, wide: Bool, _ a: @escaping () -> Void) -> some View {
        FocusTile(id: id, focus: $focus, label: t, tap: a) { f in
            Text(t).font(P.font(wide ? 22.5 : 28.5, .medium))
                .foregroundStyle(f ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white)
                .frame(width: wide ? 165 : 78.75, height: 69)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.07)))
                .scaleEffect(f ? 1.12 : 1)
                .zIndex(f ? 1 : 0)
        }
    }

    /// Siri et clavier de l'iPhone : seulement dans le clavier d'Apple (tvOS). OK ouvre ce clavier, le texte revient ici.
    private var siriKey: some View {
        TextField("", text: $native)
            .textFieldStyle(.plain)
            .foregroundStyle(.clear)
            .frame(width: 165, height: 69)
            .overlay(
                HStack(spacing: 9) { Image(systemName: "mic.fill"); Text("Siri") }
                    .font(P.font(22.5, .medium))
                    .foregroundStyle(focus == "k-siri" ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white)
                    .allowsHitTesting(false)
            )
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(focus == "k-siri" ? Color.white : Color.white.opacity(0.07)))
            .scaleEffect(focus == "k-siri" ? 1.12 : 1)
            .focused($focus, equals: "k-siri")
            .autocorrectionDisabled()
            .onSubmit { if !native.isEmpty { q = native } }
            .accessibilityIdentifier("k-siri")
    }

    private func type(_ c: String) { if q.count < 60 { q += c } }

    // MARK: milieu : filtres et liste (simulateur .sr-mid)

    private var midColumn: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                ForEach(Self.filters, id: \.0) { k, n in
                    FocusTile(id: "srf-" + k, focus: $focus, label: n, tap: { filt = k }) { f in
                        Text(n).font(P.font(21, .semibold)).lineLimit(1)
                            .foregroundStyle(f ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white)
                            .padding(.vertical, 12).padding(.horizontal, 19.5)
                            .background(Capsule().fill(f ? Color.white : Color.white.opacity(filt == k ? 0.28 : 0.1)))
                            .scaleEffect(f ? 1.07 : 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).focusSection()
            ScrollViewReader { sv in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        Color.clear.frame(height: 1).id("top")
                        listContent
                    }
                    .padding(6)
                }
                .scrollClipDisabled(false)
                .onChange(of: q) { _, _ in sv.scrollTo("top", anchor: .top) }
                .onChange(of: filt) { _, _ in sv.scrollTo("top", anchor: .top) }
            }
            .focusSection()
        }
    }

    private func group(_ t: String, _ icon: String? = nil) -> some View {
        HStack(spacing: 10) {
            if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }
            Text(t.uppercased()).font(P.font(18, .bold)).tracking(2.5)
        }
        .foregroundStyle(.white.opacity(0.6)).padding(.top, 18).padding(.bottom, 6).padding(.horizontal, 15)
    }

    @ViewBuilder private var listContent: some View {
        if q.trimmingCharacters(in: .whitespaces).isEmpty {
            if !recent.isEmpty {
                group("Recherches récentes", "clock")
                ForEach(Array(recent.enumerated()), id: \.offset) { i, r in
                    rowShell(id: "sr-rc-\(i)", label: r, tap: { q = r; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = firstRow } }) { f in
                        thumbWide(Image(systemName: "clock").font(.system(size: 27)).foregroundStyle(f ? .black : .white), colors: [Color(red: 0.2, green: 0.22, blue: 0.29), Color(red: 0.1, green: 0.11, blue: 0.15)])
                        texts(r, ["recherché récemment"], f)
                    }
                }
            }
            if !trend.isEmpty {
                group("Tendances cette semaine", "chart.line.uptrend.xyaxis")
                ForEach(trend) { it in itemRow(it, "tr") }
            }
            if !live.isEmpty {
                group("En ce moment à la TV")
                ForEach(Array(live.prefix(6))) { a in tvRow(a, "lv") }
            }
        } else if ready {
            if res.fuzzy {
                HStack(spacing: 12) { Image(systemName: "sparkles"); Text("Résultats pour une orthographe proche de « \(q) »") }
                    .font(P.font(21)).foregroundStyle(Color(red: 207 / 255, green: 224 / 255, blue: 1)).padding(.vertical, 9).padding(.horizontal, 15)
            }
            // une seule ligne par œuvre (plusieurs fournisseurs ou qualités : les versions sont dans l'aperçu)
            let F = Self.unique(res.films.compactMap { items[$0] }), S = Self.unique(res.series.compactMap { items[$0] }), NL = Self.unique(res.asked.compactMap { items[$0] })
            let askTV = res.ask?.live == true
            if filt == "all", let _ = res.ask, !res.why.isEmpty, !NL.isEmpty || (askTV && !liveHits.isEmpty) {
                group("Ce que tu demandes : " + res.why.joined(separator: ", "), "sparkles")
                if askTV { ForEach(liveHits.prefix(12)) { a in tvRow(a, "nl") } } else { ForEach(NL) { it in itemRow(it, "nl") } }
            }
            if (filt == "all" || filt == "tv"), !liveHits.isEmpty, !(askTV && filt == "all") {
                group("À la TV maintenant")
                ForEach(liveHits.prefix(12)) { a in tvRow(a, "lv") }
            }
            if (filt == "all" || filt == "f"), !F.isEmpty { group("Films"); ForEach(F) { it in itemRow(it, "f") } }
            if (filt == "all" || filt == "s"), !S.isEmpty { group("Séries"); ForEach(S) { it in itemRow(it, "s") } }
            if (filt == "all" || filt == "actor"), !res.actors.isEmpty {
                group("Acteurs")
                ForEach(res.actors, id: \.name) { a in actorRow(a) }
            }
            if nothing(F, S, NL) {
                Text("Rien pour « \(q) »\(filt != "all" ? " dans ce filtre" : ""). Essaie un acteur, une chaîne ou une phrase : « comédie des années 90 », « le match en ce moment ».")
                    .font(P.font(24)).foregroundStyle(.white.opacity(0.7)).lineSpacing(6).padding(.vertical, 24).padding(.horizontal, 15)
            }
        }
    }

    private static func unique(_ L: [MediaItem]) -> [MediaItem] {
        var seen = Set<String>()
        return L.filter { seen.insert($0.workKey).inserted }
    }

    private func nothing(_ F: [MediaItem], _ S: [MediaItem], _ NL: [MediaItem]) -> Bool {
        switch filt {
        case "f": return F.isEmpty
        case "s": return S.isEmpty
        case "tv": return liveHits.isEmpty
        case "actor": return res.actors.isEmpty
        default: return F.isEmpty && S.isEmpty && liveHits.isEmpty && res.actors.isEmpty && NL.isEmpty
        }
    }

    private var firstRow: String? {
        if q.isEmpty { return trend.first.map { "sr-tr-" + $0.id } }
        if let x = res.films.first { return "sr-f-" + x }
        return res.series.first.map { "sr-s-" + $0 }
    }

    // une ligne (simulateur .sr-lst) : fond blanc et texte sombre à la sélection
    private func rowShell<C: View>(id: String, label: String, tap: @escaping () -> Void, play: (() -> Void)? = nil, sel s: Sel? = nil,
                                   @ViewBuilder _ c: @escaping (Bool) -> C) -> some View {
        FocusTile(id: id, focus: $focus, label: label, tap: tap, play: play) { f in
            HStack(spacing: 21) { c(f) }
                .padding(.vertical, 12).padding(.horizontal, 15).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(f ? Color.white : .clear))
                .foregroundStyle(f ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white)
        }
        .onChange(of: focus) { _, n in if n == id, let s { sel = s } }
    }

    private func texts(_ t: String, _ lines: [String], _ f: Bool, bar: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4.5) {
            Text(t).font(P.font(24, .bold)).lineLimit(1)
            ForEach(lines.filter { !$0.isEmpty }, id: \.self) { l in
                Text(l).font(P.font(19.5)).lineLimit(1).foregroundStyle(f ? Color(red: 75 / 255, green: 80 / 255, blue: 92 / 255) : .white.opacity(0.66))
            }
            if let bar {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(f ? Color(red: 212 / 255, green: 215 / 255, blue: 222 / 255) : Color.white.opacity(0.25))
                        Capsule().fill(f ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white).frame(width: g.size.width * bar)
                    }
                }.frame(height: 4.5).padding(.top, 4.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func thumbWide<V: View>(_ v: V, colors: [Color]) -> some View {
        ZStack { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing); v }
            .frame(width: 156, height: 87).clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
    }

    private func tag(_ t: String, live: Bool, _ f: Bool) -> some View {
        Text(t).font(P.font(16.5, .heavy)).padding(.vertical, 4.5).padding(.horizontal, 10.5)
            .foregroundStyle(live ? .white : (f ? Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255) : .white))
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(live ? Color(red: 229 / 255, green: 72 / 255, blue: 77 / 255) : (f ? Color(red: 232 / 255, green: 233 / 255, blue: 236 / 255) : Color.white.opacity(0.14))))
    }

    private func sub(_ it: MediaItem) -> String {
        if it.kind == .film {
            let y = it.fiche?.year ?? it.year, rt = it.fiche?.runtime ?? 0
            let g = (it.fiche?.genres ?? "").components(separatedBy: CharacterSet(charactersIn: ",/")).first?.trimmingCharacters(in: .whitespaces) ?? ""
            return [y > 0 ? "\(y)" : "", rt > 0 ? MineLogic.dur(rt) : "", g].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let n = it.fiche?.seasons ?? 0
        return (["Série"] + (n > 0 ? ["\(n) saison\(n > 1 ? "s" : "")"] : []) + ((it.fiche?.year ?? it.year) > 0 ? ["\(it.fiche?.year ?? it.year)"] : [])).joined(separator: " · ")
    }

    private func srcLine(_ it: MediaItem) -> String {
        let tags = it.clean.tags.filter { ["VF", "VFF", "VFQ", "VOSTFR", "MULTI", "4K"].contains($0) }
        var l = [tags.isEmpty ? "VF" : tags.joined(separator: " · "), store.provider(it.pid)?.name ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        if it.kind == .film, let f = watch.fraction(it.id), f > 0.02, f < 0.92 { l += " · reprendre à \(Int((f * 100).rounded())) %" }
        return l
    }

    private func itemRow(_ it: MediaItem, _ g: String) -> some View {
        rowShell(id: "sr-\(g)-\(it.id)", label: it.displayTitle, tap: { remember(); open = it }, play: { remember(); openPlay = it }, sel: .item(it.id)) { f in
            ArtView(backdrop: "", poster: it.posterURL, maxPixel: 200, fill: true)
                .frame(width: 87, height: 123).background(Color(red: 0.2, green: 0.2, blue: 0.27))
                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
            texts(it.displayTitle, [sub(it), srcLine(it)], f)
            if it.kind == .series { tag("SÉRIE", live: false, f) }
        }
    }

    private func tvRow(_ a: LiveStore.Airing, _ g: String) -> some View {
        let now = Int(Date().timeIntervalSince1970)
        let pct = a.p.stop > a.p.start ? min(1, max(0, Double(now - a.p.start) / Double(a.p.stop - a.p.start))) : 0
        let name = ChannelTools.clean(a.ch.name)
        return rowShell(id: "sr-\(g)-ch\(a.ch.id)", label: a.p.title, tap: { remember(); watchLive = LiveLaunch(ch: a.ch) }, sel: .ch(a)) { f in
            thumbWide(ChannelChip(name: name, icon: a.ch.icon, height: 48), colors: [Color(hue: P.hue(name), saturation: 0.45, brightness: 0.4), Color(red: 0.07, green: 0.07, blue: 0.07)])
            texts(a.p.title, [name + " · " + hm(a.p.start) + " – " + hm(a.p.stop)], f, bar: pct)
            tag("DIRECT", live: true, f)
        }
    }

    private func actorRow(_ a: SearchIndex.Actor) -> some View {
        rowShell(id: "sr-a-\(a.name)", label: a.name, tap: { remember(); actor = CastMember(n: a.name, c: "", p: a.photo) }, sel: .actor(a.name)) { f in
            ZStack {
                LinearGradient(colors: [Color(red: 91 / 255, green: 111 / 255, blue: 153 / 255), Color(red: 26 / 255, green: 29 / 255, blue: 38 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(a.name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()).font(P.font(27, .heavy)).foregroundStyle(.white)
                if !a.photo.isEmpty { AsyncImage(url: URL(string: Fiche.img(a.photo, "w185"))) { ph in if let img = ph.image { img.resizable().scaledToFill() } } }
            }
            .frame(width: 87, height: 87).clipShape(Circle())
            texts(a.name, [a.titles.prefix(3).map(\.title).joined(separator: " · ")], f)
        }
    }

    private func hm(_ t: Int) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(t)), c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func remember() { if !q.trimmingCharacters(in: .whitespaces).isEmpty { SearchRecent.remember(q); recent = SearchRecent.list } }

    // MARK: droite : aperçu (simulateur .sr-right, prevH)

    @ViewBuilder private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch sel {
            case .none:
                VStack(alignment: .leading, spacing: 12) {
                    Text("APERÇU").font(P.font(18, .bold)).tracking(2.5).foregroundStyle(.white.opacity(0.66))
                    Text("Le titre sélectionné s'affiche ici : où le regarder, dans quelle version, et s'il passe à la TV en ce moment.")
                        .font(P.font(19.5)).foregroundStyle(.white.opacity(0.7)).lineSpacing(5)
                }.padding(36)
            case .item(let id):
                if let it = items[id] ?? trend.first(where: { $0.id == id }) { SearchItemPreview(item: it) }
            case .ch(let a):
                SearchChannelPreview(a: a)
            case .actor(let n):
                if let a = res.actors.first(where: { $0.name == n }) { actorPreview(a) }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Color(red: 30 / 255, green: 33 / 255, blue: 44 / 255).opacity(0.42))))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .animation(nil, value: sel)
    }

    private func actorPreview(_ a: SearchIndex.Actor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchArt(title: a.name, backdrop: "", poster: "", colors: [Color(red: 91 / 255, green: 111 / 255, blue: 153 / 255), Color(red: 26 / 255, green: 29 / 255, blue: 38 / 255)])
            VStack(alignment: .leading, spacing: 10) {
                Text("\(a.titles.count) titre\(a.titles.count > 1 ? "s" : "") chez tes fournisseurs").font(P.font(19.5)).foregroundStyle(.white.opacity(0.7))
                ForEach(Array(a.titles.prefix(8).enumerated()), id: \.offset) { _, t in
                    (Text("• " + t.title + " ") + Text(t.year > 0 ? "(\(t.year))" : "").foregroundColor(.white.opacity(0.7))).font(P.font(21))
                }
                Text("OK : voir tous ses films et séries").font(P.font(18.75)).foregroundStyle(.white.opacity(0.55)).padding(.top, 6)
            }.padding(.vertical, 21).padding(.horizontal, 27)
        }
    }

    // MARK: chargement

    private func run() async {
        let pids = store.active.map(\.id)
        if q.trimmingCharacters(in: .whitespaces).isEmpty {
            ready = false
            res = SearchIndex.Result()
            if trend.isEmpty {
                // l'une après l'autre : TrendStore garde un cache partagé qui ne supporte pas deux appels simultanés
                let a = await TrendStore.top(.film, pids: pids)
                let b = await TrendStore.top(.series, pids: pids)
                var t: [MediaItem] = []
                for i in 0..<6 { if i < a.count { t.append(a[i].item) }; if i < b.count { t.append(b[i].item) } }
                trend = Array(t.prefix(6))
            }
            live = await LiveStore.airingNow(providers: pids)
            return
        }
        try? await Task.sleep(nanoseconds: 120_000_000)   // une lettre après l'autre : on attend la fin de la frappe
        if Task.isCancelled { return }
        let t0 = Date()
        await SearchIndex.shared.ensure(pids: pids, catalog: store.catalogVersion, fiches: fiches.version)
        let now = MineLogic.eveningNow()
        let r = await SearchIndex.shared.search(q, bed: profiles.bedMinutes, now: now)
        if Task.isCancelled { return }
        let ids = Array(Set(r.films + r.series + r.asked))
        let got = await MediaStore.items(ids: ids)
        // chaînes et programmes en cours : nom de la chaîne ou titre du programme ; les films trouvés qui passent maintenant
        let all = await LiveStore.airingNow(providers: pids)
        var hits: [LiveStore.Airing] = []
        if let a = r.ask, a.live {
            hits = all.filter { x in
                !a.match || ["sport", "foot", "match", "ligue", "rugby", "tennis"].contains { SearchText.norm(x.p.cat + " " + x.p.title).contains($0) }
            }
        } else {
            let Q = SearchText.words(q).map(Array.init)
            hits = all.filter { x in SearchText.score(Q, SearchText.words(ChannelTools.clean(x.ch.name)).map(Array.init)) != nil
                || SearchText.score(Q, SearchText.words(x.p.title).map(Array.init)) != nil }
            let titles = Set(r.films.prefix(20).compactMap { id in got.first { $0.id == id }.map { SearchText.norm($0.displayTitle) } })
            for x in all where titles.contains(SearchText.norm(x.p.title)) && !hits.contains(x) { hits.insert(x, at: 0) }
        }
        if Task.isCancelled { return }
        items = Dictionary(got.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        res = r; liveHits = hits; ready = true
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        PerfLog.ev("Recherche « \(q) » : \(ms) ms · \(r.films.count) films, \(r.series.count) séries, \(hits.count) TV")
        DataCount.write("recherche « \(q) » : \(r.films.count) films, \(r.series.count) séries, \(hits.count) TV, \(r.actors.count) acteurs"
                        + (r.fuzzy ? ", orthographe proche" : "") + (r.why.isEmpty ? "" : ", phrase : " + r.why.joined(separator: ", ") + " (\(r.asked.count))") + " · \(ms) ms")
    }
}

// MARK: - Aperçu d'un titre : où le regarder (fournisseurs, versions), TV en ce moment, reprise

private struct SearchArt: View {
    let title: String, backdrop: String, poster: String
    var colors: [Color] = [Color(red: 0.2, green: 0.2, blue: 0.27), Color(red: 0.07, green: 0.07, blue: 0.07)]
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if !backdrop.isEmpty || !poster.isEmpty { ArtView(backdrop: backdrop, poster: poster, maxPixel: 900, fill: true) }
            LinearGradient(colors: [Color(red: 11 / 255, green: 13 / 255, blue: 19 / 255).opacity(0.92), .clear], startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.3))
            Text(title).font(P.font(34.5, .heavy)).lineLimit(2).padding(24)
        }
        .frame(height: 285).frame(maxWidth: .infinity).clipped()
    }
}

private struct SearchItemPreview: View {
    let item: MediaItem
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var watch = WatchStore.shared
    @State private var where_: [(String, Color, String)] = []
    @State private var tv: LiveStore.Airing?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchArt(title: item.displayTitle, backdrop: item.backdropURL, poster: item.posterURL)
            VStack(alignment: .leading, spacing: 13.5) {
                Text(line).font(P.font(19.5)).foregroundStyle(.white.opacity(0.7)).lineSpacing(4)
                Text("OÙ LE REGARDER").font(P.font(18, .bold)).tracking(2.5).foregroundStyle(.white.opacity(0.66)).padding(.top, 6)
                VStack(alignment: .leading, spacing: 7.5) {
                    ForEach(Array(where_.enumerated()), id: \.offset) { _, w in
                        HStack(spacing: 12) { Circle().fill(w.1).frame(width: 12, height: 12); Text(w.0 + " · " + w.2).font(P.font(19.5)).lineLimit(1) }
                    }
                    if let tv {
                        HStack(spacing: 12) {
                            Circle().fill(Color(red: 229 / 255, green: 72 / 255, blue: 77 / 255)).frame(width: 12, height: 12)
                            Text(ChannelTools.clean(tv.ch.name) + " · passe maintenant, jusqu'à " + hm(tv.p.stop)).font(P.font(19.5)).lineLimit(1)
                        }
                    }
                }
                if item.kind == .film, let f = watch.fraction(item.id), f > 0.02, f < 0.92 {
                    (Text("Tu l'as regardé à \(Int((f * 100).rounded())) % · ") + Text("reprendre").bold()).font(P.font(21))
                }
                Text("OK : ouvrir la fiche · ▶︎ : lire tout de suite").font(P.font(18.75)).foregroundStyle(.white.opacity(0.55)).padding(.top, 6)
            }
            .padding(.vertical, 21).padding(.horizontal, 27)
        }
        .task(id: item.id) { await load() }
    }

    private var line: String {
        var a: [String] = []
        if item.kind == .film {
            let y = item.fiche?.year ?? item.year, rt = item.fiche?.runtime ?? 0
            if y > 0 { a.append("\(y)") }
            if rt > 0 { a.append(MineLogic.dur(rt)) }
        } else {
            a.append("Série")
            if let n = item.fiche?.seasons, n > 0 { a.append("\(n) saison\(n > 1 ? "s" : "")") }
        }
        if let g = item.fiche?.genres.components(separatedBy: CharacterSet(charactersIn: ",/")).first?.trimmingCharacters(in: .whitespaces), !g.isEmpty { a.append(g) }
        let cast = (item.fiche?.cast ?? []).prefix(3).map(\.n)
        return a.joined(separator: " · ") + (cast.isEmpty ? "" : " · avec " + cast.joined(separator: ", "))
    }

    private func hm(_ t: Int) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: TimeInterval(t)))
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func load() async {
        let pids = store.active.map(\.id)
        let vs = await MediaStore.versions(of: item, pids: pids)
        var by: [String: [String]] = [:], order: [String] = []
        for v in vs {
            if by[v.pid] == nil { order.append(v.pid) }
            let t = v.clean.tags
            let lang = t.first { ["VFF", "VFQ", "VOSTFR", "MULTI", "VF"].contains($0) } ?? "VF"
            let ql = t.first { ["4K", "1080p", "720p"].contains($0) } ?? "HD"
            let s = lang + " " + ql
            if !(by[v.pid]?.contains(s) ?? false) { by[v.pid, default: []].append(s) }
        }
        where_ = order.map { pid in (store.provider(pid)?.name ?? pid, store.provider(pid)?.tint ?? .gray, (by[pid] ?? []).prefix(3).joined(separator: ", ")) }
        let all = await LiveStore.airingNow(providers: pids)
        let n = SearchText.norm(item.displayTitle)
        tv = all.first { SearchText.norm($0.p.title) == n }
    }
}

private struct SearchChannelPreview: View {
    let a: LiveStore.Airing
    @EnvironmentObject var store: ProviderStore
    @State private var next: Program?

    var body: some View {
        let name = ChannelTools.clean(a.ch.name)
        let copies = LiveIndex.byKey[ChannelTools.key(a.ch)]?.copies ?? [a.ch]
        VStack(alignment: .leading, spacing: 0) {
            SearchArt(title: a.p.title, backdrop: "", poster: "", colors: [Color(hue: P.hue(name), saturation: 0.45, brightness: 0.45), Color(red: 11 / 255, green: 13 / 255, blue: 19 / 255)])
            VStack(alignment: .leading, spacing: 13.5) {
                Text(name + " · en direct · " + hm(a.p.start) + " – " + hm(a.p.stop)).font(P.font(19.5)).foregroundStyle(.white.opacity(0.7))
                if let next { (Text("Ensuite : ") + Text(next.title).bold() + Text(" à " + hm(next.start))).font(P.font(21)) }
                Text("OÙ LE REGARDER").font(P.font(18, .bold)).tracking(2.5).foregroundStyle(.white.opacity(0.66)).padding(.top, 6)
                VStack(alignment: .leading, spacing: 7.5) {
                    ForEach(Array(Set(copies.map(\.pid))).sorted(), id: \.self) { pid in
                        HStack(spacing: 12) {
                            Circle().fill(store.provider(pid)?.tint ?? .gray).frame(width: 12, height: 12)
                            Text((store.provider(pid)?.name ?? pid) + " · " + (ChannelTools.qualityLabel(copies.first { $0.pid == pid }?.name ?? "") ?? "HD")).font(P.font(19.5)).lineLimit(1)
                        }
                    }
                }
                Text("OK : regarder la chaîne").font(P.font(18.75)).foregroundStyle(.white.opacity(0.55)).padding(.top, 6)
            }
            .padding(.vertical, 21).padding(.horizontal, 27)
        }
        .task(id: a.id) { next = await LiveStore.nowNext(a.ch).1 }
    }

    private func hm(_ t: Int) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: TimeInterval(t)))
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
