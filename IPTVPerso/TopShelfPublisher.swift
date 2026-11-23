import SwiftUI
import TVServices

// MARK: - Lot 6 : Top Shelf (simulateur shelfItems / fxShelf)
// PRISME prépare la rangée du haut de l'écran d'accueil de l'Apple TV pour le dernier profil utilisé :
// 1. REPRENDRE (ou PARTIE 2 pour un film en deux soirées) : films et épisodes en cours, encore chez un fournisseur ;
// 2. POUR STEVEN / POUR VOUS DEUX : « Le meilleur mix » à partir du dernier film vu en entier (score et raison) ;
// 3. NOUVEAUTÉ s'il y a moins de 4 cartes. 7 cartes au plus.
// Chaque carte est dessinée ici comme dans le simulateur (image, dégradé, étiquette, titre, ligne d'info, progression),
// puis rangée dans la boîte partagée où le module Top Shelf la relit.

struct ShelfCardData: Equatable {
    var id: String
    var kicker: String
    var title: String
    var line: String
    var progress: Double?
    var art: String
    var blur: Bool
    var play: String
    var open: String
    var okPlays: Bool
}

@MainActor
enum TopShelfPublisher {
    /// dernière rangée calculée (aperçu de test, et rien n'est réécrit si elle n'a pas changé)
    static var last: [ShelfCardData] = []
    static var lastTitle = ""
    /// journal de la visite de test
    static var note = ""
    private static var pending: Task<Void, Never>?

    /// mise à jour un peu après l'événement (fin de lecture, changement de profil, import), sans gêner l'écran en cours
    static func schedule(after s: Double = 4) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await publish()
        }
    }

    static func publish() async {
        let ps = ProfileStore.shared
        let cards = await build()
        let title = ps.isGuest ? "Ce que prisme te propose, sans ouvrir l'appli"
            : (ps.isDuo ? "À deux" : ps.me.name) + " · ce que prisme te propose, sans ouvrir l'appli"
        last = cards; lastTitle = title
        guard let dir = ShelfShared.folder else {
            note = "boîte partagée indisponible (signature) : \(cards.count) cartes calculées, rien d'écrit"
            PerfLog.ev("Top Shelf : " + note)
            return
        }
        var items: [ShelfShared.Item] = []
        var keep = Set(["feed.json"])
        for c in cards {
            guard let img = await render(c), let jpg = img.jpegData(compressionQuality: 0.86) else { continue }
            let name = "c-" + stableHash(c.id + c.kicker + c.title + c.line + c.art + String(format: "%.3f", c.progress ?? -1)) + ".jpg"
            if !FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) { try? jpg.write(to: dir.appendingPathComponent(name), options: .atomic) }
            keep.insert(name)
            items.append(.init(id: c.id, image: name, play: c.play, open: c.open, okPlays: c.okPlays, label: c.kicker + " · " + c.title + " · " + c.line))
        }
        let feed = ShelfShared.Feed(title: title, items: items, at: Date())
        ShelfShared.write(feed, to: dir)
        // anciennes cartes : effacées (seulement dans le dossier du Top Shelf)
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where !keep.contains(f) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        TVTopShelfContentProvider.topShelfContentDidChange()
        note = "\(items.count) cartes écrites dans la boîte partagée"
        PerfLog.ev("Top Shelf : " + note + " · " + items.map(\.label).joined(separator: " | "))
    }

    /// nom de fichier stable d'un lancement à l'autre (FNV-1a)
    private static func stableHash(_ s: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return String(h, radix: 36)
    }

    // MARK: contenu (simulateur shelfItems)

    static func build() async -> [ShelfCardData] {
        let ps = ProfileStore.shared, watch = WatchStore.shared
        let pids = ProviderStore.shared.active.map(\.id)
        guard !pids.isEmpty else { return [] }
        // l'écran d'accueil se voit sans code : avec un code parental, la limite d'âge la plus stricte des profils s'applique
        let strict: Int? = AppPrefs.parentalCode != nil ? ps.profiles.compactMap(\.limit).min() : nil
        let limits = (ps.isGuest ? [] : ps.watchers.compactMap(\.limit)) + (strict.map { [$0] } ?? [])
        let limit = limits.min()
        let kids = !ps.isGuest && (ps.watchers.contains { $0.kids } || (strict == 0 && ps.profiles.contains { $0.kids }))
        func ok(_ x: MediaItem) -> Bool {
            guard pids.contains(x.pid) else { return false }
            if let lim = limit, let c = x.fiche?.cert, let a = Int(c), a > lim { return false }
            if kids { guard let g = x.fiche?.genres, g.contains("Animation") || g.contains("Familial") || g.contains("Kids") else { return false } }
            return true
        }
        var L: [ShelfCardData] = []
        let who = ps.isDuo ? "duo" : ps.current
        let personal = !ps.isGuest && (strict == nil || ps.watchers.allSatisfy { $0.limit != nil })

        // 1. reprises
        if personal {
            let list = Array(watch.inProgress.prefix(20))
            let items = await MediaStore.items(ids: list.map(\.item))
            let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for e in list {
                guard let x = byID[e.item], ok(x), !L.contains(where: { $0.id == x.id }) else { continue }
                let left = EveningPlan.dur(max(1, Int(((e.dur - e.pos) / 60).rounded())))
                var kick = "REPRENDRE", line = "reste " + left
                if x.kind == .series, let tag = ResumeEntry.episodeTag(e.ep) { line = tag + " · reste " + left }
                if x.kind == .film, SplitStore.get(x.id) != nil { kick = "PARTIE 2"; line = left + " · avec résumé" }
                L.append(card(x, kick, line, progress: e.pos / e.dur, play: true, who: who))
            }
        }
        // 2. propositions (« Le meilleur mix » à partir du dernier film vu en entier, sinon de la première nouveauté)
        let newest = await MediaStore.list(.film, pids: pids, order: "added DESC", limit: 30).filter(ok)
        if personal {
            let done = watch.entries.values.filter { $0.item.hasPrefix("film:") && $0.dur > 0 && $0.pos / $0.dur >= 0.85 }.sorted { $0.at > $1.at }
            var base: MediaItem? = nil
            if let d = done.first { base = await MediaStore.items(ids: [d.item]).first }
            if base?.fiche == nil { base = newest.first { $0.fiche != nil } }
            if let b = base, let f = b.fiche {
                let genres = f.genres.components(separatedBy: CharacterSet(charactersIn: ",/")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let sim = await MediaStore.similar(of: b, genres: genres, pids: pids, limit: 60).map(\.0)
                var models: [TasteModel] = []
                for w in ps.watchers { models.append(await TasteStore.shared.model(w.id)) }
                let no = NotInterested.list(ps.me.id)
                let pool = sim.filter { $0.id != b.id && $0.workKey != b.workKey && ok($0) && !no.contains($0.workKey) && (watch.fraction($0.id) ?? 0) < 0.85 }
                let title = f.title.isEmpty ? b.clean.title : f.title
                let res = await Task.detached(priority: .utility) { CrossPick.pick(base: f, title: title, cands: pool, recs: [], models: models, mode: .mix) }.value
                let kick = "POUR " + (ps.isDuo ? "VOUS DEUX" : ps.me.name.uppercased())
                for r in res.prefix(5) where !L.contains(where: { $0.id == r.item.id }) {
                    L.append(card(r.item, kick, "\(r.pct) %" + (r.why.isEmpty ? "" : " · " + r.why), progress: nil, play: false, who: who))
                }
            }
        }
        // 3. nouveautés (année de sortie TMDB et durée, jamais la date d'ajout chez le fournisseur)
        if L.count < 4 {
            for x in newest.prefix(6) where !L.contains(where: { $0.id == x.id }) {
                let y = (x.fiche?.year ?? 0) > 0 ? x.fiche!.year : x.clean.year
                let rt = x.fiche?.runtime ?? 0
                let line = [y > 0 ? "\(y)" : nil, rt > 0 ? EveningPlan.dur(rt) : nil].compactMap { $0 }.joined(separator: " · ")
                L.append(card(x, "NOUVEAUTÉ", line, progress: nil, play: false, who: who))
            }
        }
        return Array(L.prefix(7))
    }

    private static func card(_ x: MediaItem, _ kick: String, _ line: String, progress: Double?, play: Bool, who: String) -> ShelfCardData {
        let q = "id=" + (x.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? x.id) + "&p=" + who
        let bd = x.fiche.map { $0.backdrop.isEmpty ? "" : Fiche.img($0.backdrop, "w1280") } ?? ""
        return ShelfCardData(id: x.id, kicker: kick, title: x.displayTitle, line: line, progress: progress,
                             art: bd.isEmpty ? x.posterURL : bd, blur: bd.isEmpty, play: "prisme://play?" + q, open: "prisme://open?" + q, okPlays: play)
    }

    // MARK: dessin de la carte (simulateur .shi : 470 × 264, ici × 2,72 = 1280 × 720)

    static func render(_ c: ShelfCardData) async -> UIImage? {
        var art: UIImage? = nil
        if let u = URL(string: c.art), !c.art.isEmpty, let (d, _) = try? await URLSession.shared.data(from: u) { art = UIImage(data: d) }
        let r = ImageRenderer(content: ShelfCardView(c: c, art: art))
        r.scale = 1
        return r.uiImage
    }
}

/// Carte du Top Shelf, dessinée comme le simulateur (.shi, .sh-sh, .sh-t, em, b, span, .sh-p).
struct ShelfCardView: View {
    let c: ShelfCardData
    let art: UIImage?
    static let size = CGSize(width: 1280, height: 720)
    private let k = 1280.0 / 470.0
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    Image(uiImage: art).resizable().aspectRatio(contentMode: .fill).blur(radius: c.blur ? 18 * k : 0)
                } else {
                    LinearGradient(colors: [Color(hex: "#2b3245"), Color(hex: "#0a0b10")], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: Self.size.width, height: Self.size.height).clipped()
            // .sh-sh : linear-gradient(0deg, rgba(0,0,0,.8), transparent 60%)
            LinearGradient(stops: [.init(color: .black.opacity(0.8), location: 0), .init(color: .clear, location: 0.6)], startPoint: .bottom, endPoint: .top)
            VStack(alignment: .leading, spacing: 0) {
                Text(c.kicker).font(.system(size: 11.5 * k, weight: .heavy)).tracking(1.15 * k).foregroundStyle(P.gold)
                Text(c.title).font(.system(size: 24 * k, weight: .bold)).lineLimit(1).padding(.top, 4 * k).padding(.bottom, 2 * k)
                if !c.line.isEmpty { Text(c.line).font(.system(size: 13.5 * k)).opacity(0.8).lineLimit(1) }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20 * k).padding(.bottom, 18 * k)
            if let p = c.progress {
                // .sh-p : barre de 4 px à 8 px du bas, 20 px des bords
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white).frame(width: (Self.size.width - 40 * k) * min(1, max(0, p)))
                }
                .frame(width: Self.size.width - 40 * k, height: 4 * k)
                .padding(.leading, 20 * k).padding(.bottom, 8 * k)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.black)
    }
}

/// Simulateur de test seulement : la rangée telle que le module Top Shelf la relit (fichiers de la boîte partagée),
/// posée sur le fond de l'écran d'accueil du simulateur (.hwall, .shelf, .sh-lab) pour la comparaison côte à côte.
struct ShelfPreviewScreen: View {
    let close: () -> Void
    @State private var imgs: [UIImage] = []
    @State private var title = ""
    @State private var source = ""
    @FocusState private var f: Int?
    var body: some View {
        ZStack(alignment: .topLeading) {
            // .hwall : halo bleu en haut à gauche, violet en bas à droite, sur #05060a
            Color(hex: "#05060a")
            RadialGradient(colors: [Color(hex: "#1e3a5f"), .clear], center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color(hex: "#3b1d4f"), .clear], center: UnitPoint(x: 0.8, y: 0.7), startRadius: 0, endRadius: 700)
            VStack(alignment: .leading, spacing: 3) {
                ScrollView(.horizontal) {
                    HStack(spacing: 39) {
                        ForEach(imgs.indices, id: \.self) { i in
                            Button(action: close) {
                                Image(uiImage: imgs[i]).resizable().frame(width: 705, height: 396)
                                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            }
                            .buttonStyle(.card).focused($f, equals: i)
                        }
                    }
                    .padding(.vertical, 24).padding(.trailing, 120)
                }
                .scrollClipDisabled()
                Text(title).font(.system(size: 19.5)).opacity(0.55)
            }
            .padding(.leading, 120).padding(.top, 90)
            Text(source).font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("prisme.shelf").accessibilityLabel(source)
        }
        .ignoresSafeArea()
        .task {
            if let dir = ShelfShared.folder, let feed = ShelfShared.read(from: dir) {
                imgs = feed.items.compactMap { UIImage(contentsOfFile: dir.appendingPathComponent($0.image).path) }
                title = feed.title
                source = "boîte partagée : " + feed.items.map(\.label).joined(separator: " | ")
            } else {
                for c in TopShelfPublisher.last { if let i = await TopShelfPublisher.render(c) { imgs.append(i) } }
                title = TopShelfPublisher.lastTitle
                source = "calcul seul (" + TopShelfPublisher.note + ") : " + TopShelfPublisher.last.map { $0.kicker + " · " + $0.title + " · " + $0.line }.joined(separator: " | ")
            }
            f = 0
        }
    }
}
