import SwiftUI

// Éléments des accueils Films et Séries, repris du simulateur :
// bande en verre (« Ce soir ? » / « À suivre · Ce soir ? · Cette semaine »), cartes larges, Top 10, Explorer, Parcourir.

// MARK: - En-tête de section (icône + titre + sous-titre)

struct HomeHeader: View {
    var icon: String? = nil
    let title: String
    var sub: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            if let icon { Image(systemName: icon).font(P.font(28, .semibold)).foregroundStyle(P.ink) }
            Text(title).font(P.font(33, .bold)).foregroundStyle(P.ink)
            if let sub, !sub.isEmpty { Text(sub).font(P.font(20)).foregroundStyle(P.faint).lineLimit(1) }
        }
        .padding(.horizontal, 120)
    }
}

// MARK: - Carte large (Reprendre, À suivre, Nouveau sur prisme)

struct WideCard: View {
    let item: MediaItem
    var backdrop: String? = nil
    var tag: String? = nil          // pastille sombre, texte doré (« NOUVEAU · IL Y A 5 J »)
    var flag: String? = nil         // pastille bleue (« NOUVEAU »)
    var corner: String? = nil       // en haut à droite (« VF · 1080p »)
    var badge: String? = nil        // au-dessus du titre (« S2 · É3 »)
    var title: String
    var sub: String
    var chip: String? = nil         // fournisseur
    var progress: Double? = nil
    var width: CGFloat = 480
    let action: () -> Void

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(TileStyle(radius: 22, zoom: 1.06))
    }

    private var label: some View {
        ZStack(alignment: .bottomLeading) {
            ArtView(backdrop: backdrop ?? item.backdropURL, poster: item.posterURL, maxPixel: 1000, fill: true)
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if let flag { Text(flag).font(P.font(15, .heavy)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5).background(Color(red: 0.04, green: 0.52, blue: 1), in: RoundedRectangle(cornerRadius: 7)) }
                    if let tag { Text(tag).font(P.font(16, .heavy)).tracking(1).foregroundStyle(P.gold).padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10)) }
                    Spacer(minLength: 0)
                    if let corner { Text(corner).font(P.font(15, .heavy)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 7)) }
                }
                Spacer(minLength: 0)
                if let badge { Text(badge).font(P.font(16, .heavy)).foregroundStyle(Color(red: 0.75, green: 0.85, blue: 1)).padding(.horizontal, 9).padding(.vertical, 4).background(Color(red: 0.2, green: 0.3, blue: 0.5).opacity(0.85), in: RoundedRectangle(cornerRadius: 7)).padding(.bottom, 8) }
                Text(title).font(P.font(26, .bold)).lineLimit(1)
                Text(sub).font(P.font(18)).opacity(0.75).lineLimit(1).padding(.top, 3)
                if let chip { Text(chip).font(P.font(15, .bold)).padding(.horizontal, 9).padding(.vertical, 3).background(P.chip.opacity(0.45), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(P.chip, lineWidth: 1)).padding(.top, 8) }
                if let progress {
                    ProgressLine(value: progress, color: .white).frame(height: 5).padding(.top, 10)
                }
            }
            .foregroundStyle(.white).padding(20)
        }
        .frame(width: width, height: width * 0.5625)
    }
}

/// Carte « Tout voir » au bout d'une rangée.
struct AllCard: View {
    let count: Int
    let unit: String
    var height: CGFloat = 270
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "chevron.right").font(P.font(30, .bold))
                Spacer().frame(height: 10)
                Text("Tout voir").font(P.font(26, .bold))
                Text("\(count) \(unit)").font(P.font(18)).opacity(0.6)
            }
            .padding(26).frame(width: 220, height: height, alignment: .leading)
            .background(Color.white.opacity(0.06))
        }
        .buttonStyle(TileStyle(radius: 22, zoom: 1.06))
    }
}

// MARK: - Top 10 (chiffres en contour + affiche + évolution)

struct OutlineNumber: View {
    let n: Int
    private static let offs: [(CGFloat, CGFloat)] = [(-2.5, 0), (2.5, 0), (0, -2.5), (0, 2.5), (-1.8, -1.8), (1.8, 1.8), (-1.8, 1.8), (1.8, -1.8)]
    var body: some View {
        ZStack {
            ForEach(0..<OutlineNumber.offs.count, id: \.self) { i in
                Text("\(n)").foregroundStyle(Color.white.opacity(0.7)).offset(x: OutlineNumber.offs[i].0, y: OutlineNumber.offs[i].1)
            }
            Text("\(n)").foregroundStyle(P.room)
        }
        .font(.system(size: 270, weight: .heavy))
        .fixedSize()
    }
}

struct Top10Row: View {
    let title: String
    let sub: String
    let items: [TrendStore.Ranked]
    let open: (MediaItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(icon: "flame", title: title, sub: sub)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 20) {
                    ForEach(items) { r in
                        HStack(alignment: .bottom, spacing: -46) {
                            OutlineNumber(n: r.rank).offset(y: 40)
                            Button { open(r.item) } label: {
                                ZStack(alignment: .topTrailing) {
                                    PosterTile(item: r.item, showNew: false).frame(width: 220, height: 330)
                                    if let m = r.move { MoveBadge(text: m).padding(10) }
                                }
                            }
                            .buttonStyle(TileStyle())
                        }
                    }
                }
                .padding(.horizontal, 120).padding(.vertical, 34)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

struct MoveBadge: View {
    let text: String
    var body: some View {
        let up = text.hasPrefix("▲"), down = text.hasPrefix("▼"), new = text == "NOUVEAU"
        Text(text).font(P.font(15, .heavy))
            .foregroundStyle(new ? Color.black : up ? Color(red: 0.45, green: 0.9, blue: 0.55) : down ? Color(red: 1, green: 0.5, blue: 0.45) : .white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(new ? P.gold : Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
    }
}

/// Top 10 : titres populaires en France cette semaine (TMDB) qui sont chez tes fournisseurs,
/// avec l'évolution par rapport à la semaine précédente (gardée sur l'Apple TV).
enum TrendStore {
    struct Ranked: Identifiable { let item: MediaItem; let rank: Int; let move: String?; var id: String { item.id } }
    private static var memo: [String: (Date, [Int])] = [:]

    static func top(_ k: MediaKind, pids: [String]) async -> [Ranked] {
        guard let key = TmdbKey.value, !pids.isEmpty else { return [] }
        let ids = await popular(k, key: key)
        guard !ids.isEmpty else { return [] }
        let found = await MediaStore.items(kind: k, tmdb: ids, pids: pids)
        let list = ids.compactMap { id in found[id].map { (id, $0) } }.prefix(10)
        // évolution : classement de la semaine précédente
        let week = Calendar(identifier: .iso8601).component(.weekOfYear, from: Date())
        let dk = "prisme.top.\(k.rawValue)"
        var store = UserDefaults.standard.dictionary(forKey: dk) ?? [:]
        let curWeek = store["week"] as? Int ?? -1
        var prev = store["prev"] as? [String: Int] ?? [:]
        let now = Dictionary(uniqueKeysWithValues: list.enumerated().map { (String($0.element.0), $0.offset + 1) })
        if curWeek != week {
            if let last = store["cur"] as? [String: Int] { prev = last }
            store["week"] = week; store["prev"] = prev
        }
        store["cur"] = now
        UserDefaults.standard.set(store, forKey: dk)
        let hasPrev = !prev.isEmpty
        return list.enumerated().map { i, x in
            var mv: String? = nil
            if hasPrev {
                if let p = prev[String(x.0)] { mv = p == i + 1 ? "=" : p > i + 1 ? "▲\(p - i - 1)" : "▼\(i + 1 - p)" } else { mv = "NOUVEAU" }
            }
            return Ranked(item: x.1, rank: i + 1, move: mv)
        }
    }

    private static func popular(_ k: MediaKind, key: String) async -> [Int] {
        let mk = k.rawValue
        if let m = memo[mk], Date().timeIntervalSince(m.0) < 6 * 3600 { return m.1 }
        let api = TmdbAPI(key: key)
        var ids: [Int] = []
        for page in 1...3 {
            let path = k == .film ? "/movie/popular" : "/trending/tv/week"
            var q: [(String, String)] = [("language", "fr-FR"), ("page", String(page))]
            if k == .film { q.append(("region", "FR")) }
            guard let d = await api.get(path, q), let res = d["results"] as? [[String: Any]] else { break }
            ids += res.filter { ($0["adult"] as? Bool) != true }.compactMap { $0["id"] as? Int }
        }
        if !ids.isEmpty { memo[mk] = (Date(), ids) }
        return ids
    }
}

// MARK: - Bande en verre

struct GlassBand<Head: View, Row: View>: View {
    let head: () -> Head
    let row: () -> Row
    init(@ViewBuilder head: @escaping () -> Head, @ViewBuilder row: @escaping () -> Row) { self.head = head; self.row = row }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            head().padding(.horizontal, 56).padding(.top, 30).focusSection()
            ScrollView(.horizontal) {
                row().padding(.horizontal, 56).padding(.vertical, 28)
            }
            .scrollClipDisabled()
            .focusSection()
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color.white.opacity(0.035)))
        // les affiches défilent à l'intérieur du cadre arrondi, sans jamais en déborder
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1.5))
        .padding(.horizontal, 64)
    }
}

/// Puce de la bande (« Peu importe ▾ », « Surprends-moi »).
struct BandChip: View {
    var icon: String? = nil
    let text: String
    var menu = false
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(text)
                if menu { Image(systemName: "chevron.down").font(P.font(14, .bold)).opacity(0.7) }
            }.font(P.font(21, .semibold))
        }
        .buttonStyle(GlassStyle(radius: 16, minH: 56, on: on))
    }
}

// MARK: - Explorer (collections faites à partir de ton fournisseur)

struct CollInfo: Identifiable {
    let id: String
    let icon: String
    let name: String
    let why: String
    let count: Int
    let preview: [MediaItem]
    let loader: () async -> [MediaItem]
    var kind: String = "Collection"     // « Saga », « Plateforme » dans Licences et sagas
}

struct CollTile: View {
    let c: CollInfo
    let unit: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Color.white.opacity(0.06)
                HStack(spacing: -70) {
                    ForEach(Array(Array(c.preview.prefix(3).enumerated()).reversed()), id: \.element.id) { i, it in
                        Poster(url: it.posterURL, maxPixel: 240).frame(width: 110, height: 165).clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.5), radius: 8, x: -4).opacity(1 - Double(i) * 0.12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 26)
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: c.icon).font(P.font(26, .semibold))
                    Text(c.name).font(P.font(25, .bold)).lineLimit(1)
                    Text("\(c.count) \(unit)").font(P.font(18)).opacity(0.6)
                }
                .padding(24).frame(maxWidth: 300, alignment: .leading)
            }
            .frame(width: 480, height: 232)
            .foregroundStyle(.white)
        }
        .buttonStyle(TileStyle(radius: 22, zoom: 1.05))
    }
}

/// Tuile de « Parcourir » : un mot (catégorie, genre) ou une licence (saga, plateforme).
struct WordTile: View {
    let title: String
    let sub: String
    var rank: Int? = nil
    let action: () -> Void
    var body: some View {
        let hue = P.hue(title)
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.5, brightness: 0.38), Color(hue: hue, saturation: 0.55, brightness: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let rank, rank <= 3 {
                    Text(rank == 1 ? "🔥 N° 1" : "🔥 Top \(rank)").font(P.font(15, .heavy)).padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 7)).padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(P.font(28, .heavy)).lineLimit(2).minimumScaleFactor(0.7)
                    Text(sub).font(P.font(17)).opacity(0.7).lineLimit(1)
                }.padding(20)
            }
            .frame(width: 320, height: 180)
            .foregroundStyle(.white)
        }
        .buttonStyle(TileStyle(radius: 20, zoom: 1.06))
    }
}

// MARK: - Une collection en grille (tri : Pertinence · Note · Durée · Récent)

struct CollectionGridView: View {
    let kicker: String
    let title: String
    let why: String
    let loader: () async -> [MediaItem]
    @State private var items: [MediaItem] = []
    @State private var sort = "pert"
    @State private var loaded = false
    @State private var open: MediaItem?
    private let cols = Array(repeating: GridItem(.fixed(210), spacing: 36), count: 7)
    private static let sorts: [(String, String)] = [("pert", "Pertinence"), ("note", "Note"), ("duree", "Durée"), ("recent", "Récent")]

    private var shown: [MediaItem] {
        switch sort {
        case "note": return items.sorted { rating($0) > rating($1) }
        case "duree": return items.sorted { ($0.fiche?.runtime ?? 9999) < ($1.fiche?.runtime ?? 9999) }
        case "recent": return items.sorted { year($0) > year($1) }
        default: return items
        }
    }
    private func rating(_ m: MediaItem) -> Double { (m.fiche?.vote ?? 0) > 0 ? m.fiche!.vote : m.rating }
    private func year(_ m: MediaItem) -> Int { (m.fiche?.year ?? 0) > 0 ? m.fiche!.year : m.clean.year }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(kicker).font(P.font(20, .bold)).tracking(2).foregroundStyle(P.faint)
                Text(title).font(P.font(56, .bold)).foregroundStyle(P.ink)
                if !why.isEmpty { Text(why).font(P.font(23)).foregroundStyle(P.dim) }
                HStack(spacing: 14) {
                    ForEach(0..<CollectionGridView.sorts.count, id: \.self) { i in
                        let s = CollectionGridView.sorts[i]
                        BandChip(text: s.1, on: sort == s.0) { sort = s.0 }
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
                if loaded { Text("\(items.count) titre\(items.count > 1 ? "s" : "")").font(P.font(20)).foregroundStyle(P.faint).padding(.top, 6) }
            }
            .padding(.horizontal, 120).padding(.top, 80)
            if !loaded { ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 300) }
            LazyVGrid(columns: cols, spacing: 50) {
                ForEach(shown) { it in PosterButton(item: it) { open = it } }
            }
            .padding(.horizontal, 100).padding(.vertical, 40)
        }
        .scrollClipDisabled()
        .background(PrismeBackground())
        .ignoresSafeArea()
        .navigationDestination(item: $open) { it in DetailView(item: it) }
        .task { items = await loader(); loaded = true }
    }
}

/// Services reconnus dans les noms de catégories des fournisseurs (« FR| NETFLIX », « Disney+ »…).
enum Services {
    static let list: [(String, String)] = [
        ("Netflix", "netflix"), ("Disney+", "disney"), ("Prime Video", "amazon|prime"), ("Apple TV+", "apple"),
        ("Canal+", "canal"), ("Max", "\\bmax\\b|hbo"), ("Paramount+", "paramount"), ("OCS", "\\bocs\\b"),
        ("Arte", "\\barte\\b"), ("France TV", "france ?tv|france\\.tv"), ("M6+", "\\bm6\\b|6play"), ("TF1+", "tf1"),
    ]
    static func match(_ name: String) -> String? {
        list.first { name.range(of: $0.1, options: [.regularExpression, .caseInsensitive]) != nil }?.0
    }
}


/// Carte « Nouveau sur prisme » (simulateur) : image sur toute la carte, « NOUVEAU · IL Y A 5 J » en haut,
/// titre, « année · durée · genre », fournisseur. Sans fiche TMDB, l'image de fond et la durée viennent du fournisseur.
struct NewCard: View {
    let item: MediaItem
    let chip: String?
    let action: () -> Void
    @State private var info = MediaInfo()
    @State private var infoFor = ""

    var body: some View {
        WideCard(item: item, backdrop: art, tag: "NOUVEAU · " + (agoText(item.added) ?? "récent").uppercased(), title: item.displayTitle, sub: sub,
                 chip: chip, width: 530, action: action)
            .task(id: item.id) {
                guard item.backdropURL.isEmpty || (item.kind == .film && (item.fiche?.runtime ?? 0) == 0) || item.fiche == nil else { return }
                let id = item.id
                let m = await InfoLoader.load(item)
                if id == item.id { info = m; infoFor = id }
            }
    }

    private var details: MediaInfo { infoFor == item.id ? info : MediaInfo() }
    private var art: String { !item.backdropURL.isEmpty ? item.backdropURL : details.backdrop }

    private var sub: String {
        var p: [String] = []
        let y = (item.fiche?.year ?? 0) > 0 ? item.fiche!.year : (item.clean.year > 0 ? item.clean.year : details.year)
        if y > 0 { p.append(String(y)) }
        if item.kind == .film {
            let rt = (item.fiche?.runtime ?? 0) > 0 ? item.fiche!.runtime : details.minutes
            if rt > 0 { p.append(runtimeText(rt)) }
        } else if !details.seasons.isEmpty {
            p.append("\(details.seasons.count) saison" + (details.seasons.count > 1 ? "s" : ""))
        }
        let g = (item.fiche?.genres.isEmpty == false) ? item.fiche!.genres : details.genre
        if let first = g.components(separatedBy: CharacterSet(charactersIn: ",/")).first?.trimmingCharacters(in: .whitespaces), !first.isEmpty { p.append(first) }
        return p.joined(separator: " · ")
    }
}
