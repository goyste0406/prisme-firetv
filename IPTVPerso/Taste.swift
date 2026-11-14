import SwiftUI

// MARK: - « Mes goûts » : ce que prisme sait des goûts de chaque profil
//
// Deux sources, propres à chaque profil :
//  1. le test « Mes goûts » (titres connus, duels, ambiances, « jamais de… », contexte) ;
//  2. ce que le profil regarde vraiment (fini ≥ 85 % : aimé ; abandonné < 35 % : pas aimé), qui compte de plus en plus
//     à mesure que l'historique grandit : le test n'est qu'un point de départ, jamais une vérité définitive.
// Rien n'est inventé : sans réponse ni historique, le goût reste « à découvrir ».

/// Genres TMDB ramenés à une même liste pour les films et les séries (« Action & Adventure » → Action, Aventure).
enum Genres {
    static func canon(_ list: String) -> [String] {
        var out: [String] = []
        for g0 in list.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !g0.isEmpty {
            switch g0 {
            case "Action & Adventure": out += ["Action", "Aventure"]
            case "Science-Fiction & Fantastique": out += ["Science-Fiction", "Fantastique"]
            case "War & Politics": out += ["Guerre"]
            case "Kids": out += ["Familial"]
            case "Reality", "Soap", "Talk", "News": out += [g0 == "News" ? "Documentaire" : "Divertissement"]
            default: out.append(g0)
            }
        }
        return Array(NSOrderedSet(array: out)) as? [String] ?? out
    }
}

/// Réponses au test, enregistrées pour un profil (clé « prisme.taste », propre à chaque profil).
struct TasteAnswers: Codable {
    /// titres jugés : clé de l'œuvre (« t12345 ») → +1 j'aime, -1 pas pour moi
    var judged: [String: Int] = [:]
    /// genres (canoniques), mots-clés TMDB, réalisateurs et acteurs des titres jugés (pour ne pas dépendre du catalogue)
    var judgedInfo: [String: JudgedInfo] = [:]
    /// duels : axe → préférence de -1 à 1
    var axes: [String: Double] = [:]
    /// ambiances choisies
    var moods: [String] = []
    /// « Jamais de… » : genres canoniques, ou « __long » (films de plus de 2 h 30)
    var never: [String] = []
    /// « Plutôt » : films / series / both ; « Un soir de semaine » : court / episode / any
    var kindPref = "both"
    var weeknight = "any"
    var at = Date()
    var count = 0

    struct JudgedInfo: Codable { var genres: [String]; var kw: [Int]; var dir: String; var cast: [String]; var title: String }
}

/// Axes des duels : chaque titre a une valeur -1 / +1 (ou 0 si ça ne dit rien).
enum TasteAxis: String, CaseIterable {
    case tone, scale, era, length, origin
    var label: (String, String) {
        switch self {
        case .tone: return ("léger", "intense")
        case .scale: return ("intimiste", "grand spectacle")
        case .era: return ("classique", "récent")
        case .length: return ("court", "long")
        case .origin: return ("français", "international")
        }
    }
    func value(genres g: [String], year: Int, runtime: Int, country: String) -> Double {
        let has = { (x: [String]) in g.contains { x.contains($0) } }
        switch self {
        case .tone:
            let light = has(["Comédie", "Familial", "Animation", "Romance"]), heavy = has(["Thriller", "Horreur", "Crime", "Guerre"])
            return light == heavy ? 0 : (heavy ? 1 : -1)
        case .scale:
            let big = has(["Action", "Aventure", "Science-Fiction", "Fantastique"]), small = has(["Drame", "Romance"]) && !big
            return big ? 1 : (small ? -1 : 0)
        case .era: return year <= 0 ? 0 : (year < 2000 ? -1 : (year >= 2015 ? 1 : 0))
        case .length: return runtime <= 0 ? 0 : (runtime < 110 ? -1 : (runtime > 140 ? 1 : 0))
        case .origin: return country.isEmpty ? 0 : (country.split(separator: ",").contains("FR") ? -1 : 1)
        }
    }
}

/// Ambiances (méthode des « groupes » de MovieLens : 3 affiches + 3 mots).
struct TasteMood: Identifiable {
    let id: String
    let words: String
    let genres: [String]
    static let all: [TasteMood] = [
        TasteMood(id: "haletant", words: "Haletant · complots · twist", genres: ["Thriller", "Crime", "Mystère"]),
        TasteMood(id: "feelgood", words: "Doux · drôle · feel-good", genres: ["Comédie", "Familial", "Romance"]),
        TasteMood(id: "epique", words: "Épique · grand spectacle", genres: ["Action", "Aventure", "Science-Fiction"]),
        TasteMood(id: "frisson", words: "Frissons · tension · peur", genres: ["Horreur", "Thriller"]),
        TasteMood(id: "emouvant", words: "Émouvant · vrai · humain", genres: ["Drame", "Histoire"]),
        TasteMood(id: "imaginaire", words: "Imaginaire · magie · autres mondes", genres: ["Fantastique", "Science-Fiction", "Animation"]),
    ]
}

/// Modèle de goûts calculé pour un profil (test + historique), utilisé pour les scores et les suggestions.
struct TasteModel {
    var genre: [String: Double] = [:]
    var kw: [Int: Double] = [:]
    var dir: [String: Double] = [:]
    var cast: [String: Double] = [:]
    var axes: [String: Double] = [:]
    var never: Set<String> = []
    var kindPref = "both"
    var liked: [(key: String, title: String, genres: [String])] = []
    var historyCount = 0
    var hasTest = false
    var isEmpty: Bool { genre.isEmpty && kw.isEmpty && axes.isEmpty }

    /// Le titre tombe dans « Jamais de… »
    func neverHit(genres g: [String], runtime: Int, kind: MediaKind) -> Bool {
        if never.contains("__long"), kind == .film, runtime > 150 { return true }
        return g.contains { never.contains($0) }
    }

    /// Correspondance avec les goûts, de 1 à 99 % ; nil si rien n'est connu (« à découvrir »).
    func fit(_ f: Fiche, kind: MediaKind) -> Int? {
        guard !isEmpty else { return nil }
        let g = Genres.canon(f.genres)
        if neverHit(genres: g, runtime: f.runtime, kind: kind) { return 3 }
        let gmax = max(1, genre.values.map(abs).max() ?? 1)
        let gs = g.isEmpty ? 0 : g.map { (genre[$0] ?? 0) / gmax }.reduce(0, +) / Double(g.count)
        let kmax = max(1, kw.values.map(abs).max() ?? 1)
        let ks = max(-1, min(1, f.keywordIDs.map { (kw[$0] ?? 0) / kmax }.reduce(0, +) / 2))
        var cs = 0.0
        for d in f.director.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) { cs += min(1, (dir[d] ?? 0) / 2) }
        for a in f.cast.prefix(6) { cs += min(0.5, (cast[a.n] ?? 0) / 3) }
        cs = min(1, cs)
        var asum = 0.0, an = 0.0
        for ax in TasteAxis.allCases {
            let v = ax.value(genres: g, year: f.year, runtime: f.runtime, country: f.country)
            if v != 0, let p = axes[ax.rawValue] { asum += v * p; an += 1 }
        }
        let aS = an > 0 ? asum / an : 0
        var p = 0.45 * gs + 0.2 * ks + 0.15 * cs + 0.2 * aS
        if kindPref == "films" && kind == .series { p -= 0.15 }
        if kindPref == "series" && kind == .film { p -= 0.15 }
        p = max(-1, min(1, p * 1.6))
        return Int((50 + 49 * p).rounded())
    }

    /// Le titre aimé qui ressemble le plus (« parce que tu aimes Titanic »).
    func because(_ f: Fiche) -> String? {
        let g = Set(Genres.canon(f.genres))
        let best = liked.map { ($0.title, Set($0.genres).intersection(g).count) }.filter { $0.1 > 0 }.max { $0.1 < $1.1 }
        return best.map { "parce que tu aimes " + $0.0 }
    }

    /// Les genres préférés, pour « Steven aime… » (part de 0 à 1).
    var topGenres: [(String, Double)] {
        let pos = genre.filter { $0.value > 0 }
        let m = pos.values.max() ?? 1
        return pos.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value / m) }
    }
}

@MainActor
final class TasteStore: ObservableObject {
    static let shared = TasteStore()
    @Published private(set) var version = 0
    private var models: [String: TasteModel] = [:]

    static func key(_ pid: String) -> String { ProfileStore.storageKey("prisme.taste", for: pid) }

    func answers(_ pid: String) -> TasteAnswers? {
        guard let d = UserDefaults.standard.data(forKey: TasteStore.key(pid)) else { return nil }
        return try? JSONDecoder().decode(TasteAnswers.self, from: d)
    }

    func save(_ a: TasteAnswers, for pid: String) {
        if let d = try? JSONEncoder().encode(a) { UserDefaults.standard.set(d, forKey: TasteStore.key(pid)) }
        models[pid] = nil; HomeCacheReset.run(); version += 1
    }

    /// « Oublier mes réponses » : le test est effacé, l'historique (ce qui a été regardé) reste.
    func forget(_ pid: String) {
        UserDefaults.standard.removeObject(forKey: TasteStore.key(pid))
        models[pid] = nil; HomeCacheReset.run(); version += 1
    }

    /// Le modèle d'un profil (calculé une fois, recalculé quand ses réponses ou son historique changent).
    func model(_ pid: String) async -> TasteModel {
        let hist = WatchStore.entries(for: pid)
        let sig = "\(hist.count)|\(hist.values.map(\.at).max()?.timeIntervalSince1970 ?? 0)"
        if let m = models[pid], cachedSig[pid] == sig { return m }
        let m = await build(pid, hist: hist)
        models[pid] = m; cachedSig[pid] = sig
        return m
    }
    private var cachedSig: [String: String] = [:]

    /// Synchrone, si déjà calculé (fiches, chips).
    func cached(_ pid: String) -> TasteModel? { models[pid] }

    private func build(_ pid: String, hist: [String: WatchStore.Entry]) async -> TasteModel {
        var m = TasteModel()
        let a = answers(pid)
        // ce que le profil a regardé (films et séries) : son vrai goût
        let films = hist.values.filter { $0.dur > 0 && ($0.item.hasPrefix("film:") || $0.item.hasPrefix("series:")) }
        let byItem = Dictionary(films.map { ($0.item, $0) }, uniquingKeysWith: { $0.at > $1.at ? $0 : $1 })
        let items = await MediaStore.items(ids: Array(byItem.keys))
        m.historyCount = items.count
        // le test compte moins à mesure que l'historique grandit (jamais moins d'un tiers)
        let testW = max(0.33, 1 - Double(items.count) / 30)
        func add(_ genres: [String], _ kws: [Int], _ dir: String, _ cast: [String], _ w: Double) {
            for g in genres { m.genre[g, default: 0] += w }
            for k in kws { m.kw[k, default: 0] += w * 0.6 }
            if w > 0 {
                for d in dir.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !d.isEmpty { m.dir[d, default: 0] += w }
                for c in cast.prefix(4) { m.cast[c, default: 0] += w * 0.5 }
            }
        }
        for it in items {
            guard let f = it.fiche, let e = byItem[it.id] else { continue }
            let done = e.pos / e.dur
            var w = done >= 0.85 ? 1.0 : (done >= 0.35 ? 0.5 : -0.6)
            if Date().timeIntervalSince(e.at) < 14 * 86400 { w *= 1.2 }
            add(Genres.canon(f.genres), Array(f.keywordIDs), f.director, f.cast.map(\.n), w)
            if w >= 1 { m.liked.append((it.workKey, it.displayTitle, Genres.canon(f.genres))) }
        }
        if let a {
            m.hasTest = true
            for (k, v) in a.judged {
                guard let info = a.judgedInfo[k] else { continue }
                add(info.genres, info.kw, info.dir, info.cast, (v > 0 ? 1.6 : -1.2) * testW)
                if v > 0 { m.liked.append((k, info.title, info.genres)) }
            }
            for mood in TasteMood.all where a.moods.contains(mood.id) { for g in mood.genres { m.genre[g, default: 0] += 1.0 * testW } }
            for (k, v) in a.axes { m.axes[k] = v }
            m.never = Set(a.never)
            m.kindPref = a.kindPref
        }
        return m
    }

    /// Recalcul (après une lecture, un changement de réponses…)
    func invalidate(_ pid: String) { models[pid] = nil; version += 1 }
}
