import Foundation
import SwiftUI

// « Si tu hésites encore » (simulateur : scoreOne / scoredAll / crossPick / SW / SMODES).
// Pour chaque titre proche : six parts (recommandé par TMDB, thèmes communs, équipe en commun, goûts du profil,
// qualité, récence), pondérées selon le mode choisi, puis une rangée diversifiée de 10 titres avec un pourcentage
// et la raison principale. Le calcul dépend du profil actif (et des deux profils en mode « Vous deux »).

enum CrossMode: String, CaseIterable, Identifiable {
    case mix, film, toi
    var id: String { rawValue }
    var label: String {
        switch self { case .mix: return "Le meilleur mix"; case .film: return "Proche de ce film"; case .toi: return "Selon tes goûts" }
    }
    /// Pondérations du simulateur (SW)
    var weights: [(String, Double)] {
        switch self {
        case .mix: return [("co", 0.3), ("kw", 0.25), ("crew", 0.15), ("prof", 0.15), ("qual", 0.1), ("fresh", 0.05)]
        case .film: return [("co", 0.35), ("kw", 0.35), ("crew", 0.2), ("prof", 0), ("qual", 0.1), ("fresh", 0)]
        case .toi: return [("co", 0.2), ("kw", 0.1), ("crew", 0.1), ("prof", 0.45), ("qual", 0.15), ("fresh", 0)]
        }
    }
    /// libellés du simulateur (SL)
    static let partLabel: [String: String] = ["co": "Recommandé par TMDB", "kw": "Thèmes communs", "crew": "Équipe en commun",
                                              "prof": "Tes goûts", "qual": "Qualité", "fresh": "Récence"]
    /// à deux : « Vos goûts »
    static func part(_ k: String, duo: Bool) -> String { k == "prof" && duo ? "Vos goûts" : partLabel[k] ?? k }
    static let partColor: [String: Color] = ["co": Color(red: 0.38, green: 0.65, blue: 1), "kw": Color(red: 0.69, green: 0.55, blue: 1),
                                             "crew": Color(red: 0.2, green: 0.83, blue: 0.6), "prof": Color(red: 1, green: 0.8, blue: 0.3),
                                             "qual": Color(red: 1, green: 0.45, blue: 0.7), "fresh": Color(red: 0.6, green: 0.6, blue: 0.65)]
}

struct CrossPickResult: Identifiable {
    let item: MediaItem
    let pct: Int
    /// mode « Vous deux » : le pourcentage de chacun
    let pA: Int?
    let pB: Int?
    let why: String
    let whyAll: [String]
    let parts: [String: Double]
    var id: String { item.id }
}

enum CrossPick {
    struct Reason { let c: String; let w: Double; let t: String }
    struct Scored { let item: MediaItem; var parts: [String: Double]; var pen: Double; var rel: Double; var why: [Reason]; var raw = 0.0 }

    /// Ressemblance des mots-clés TMDB de deux titres (0 à 1)
    static func kwSim(_ a: Set<Int>, _ b: Set<Int>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / (Double(a.count) * Double(b.count)).squareRoot()
    }

    private static func people(_ s: String) -> [String] { s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }

    /// Titre court pour les raisons (« Les fans de Dune l'adorent »)
    static func short(_ t: String) -> String {
        let s = t.split(separator: ":").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? t
        return s.count > 28 ? String(s.prefix(26)) + "…" : s
    }

    static func score(base: Fiche, baseTitle: String, c: MediaItem, recs: Set<Int>, T: TasteModel) -> Scored? {
        guard let cf = c.fiche else { return nil }
        let cg = Genres.canon(cf.genres), bg = Genres.canon(base.genres)
        if !T.isEmpty, T.neverHit(genres: cg, runtime: cf.runtime, kind: c.kind) { return nil }
        var why: [Reason] = []
        // recommandé par TMDB à partir de ce titre
        let inF = recs.contains(cf.tmdb)
        let co = inF ? 0.7 : 0
        if co > 0 { why.append(Reason(c: "co", w: co, t: "Les fans de \(short(baseTitle)) l'adorent")) }
        // thèmes communs (mots-clés TMDB), puis genres
        let ka = base.keywordIDs, kb = cf.keywordIDs
        let kw = kwSim(ka, kb)
        let shared = ka.intersection(kb)
        let names = base.keywords.split(separator: "|").compactMap { e -> (Int, String)? in
            let p = e.split(separator: ":", maxSplits: 1); guard p.count == 2, let i = Int(p[0]) else { return nil }; return (i, String(p[1]))
        }.filter { shared.contains($0.0) }.map { $0.1.lowercased() }
        if !names.isEmpty { why.append(Reason(c: "kw", w: kw * 1.4, t: "Thèmes communs : " + names.prefix(2).joined(separator: ", "))) }
        else {
            let cgs = cg.filter { bg.contains($0) }
            if !cgs.isEmpty { why.append(Reason(c: "kw", w: 0.2, t: "Genre commun : " + cgs.prefix(2).joined(separator: ", ").lowercased())) }
        }
        // équipe en commun
        var crew = 0.0
        var cw: [String] = []
        let bd = Set(people(base.director)), cd = people(cf.director)
        if let d = cd.first(where: { bd.contains($0) }) { crew += 0.5; cw.append("Même réalisateur (\(d))") }
        let bc = Set(base.cast.prefix(10).map(\.n))
        let sc = cf.cast.prefix(10).filter { bc.contains($0.n) }
        crew += 0.1 * Double(sc.count)
        if let a = sc.first { cw.append("Avec \(a.n)") }
        crew = min(1, crew)
        if !cw.isEmpty { why.append(Reason(c: "crew", w: crew, t: cw[0])) }
        // goûts du profil (test + historique) : 0 tant que rien n'est connu
        var prof = 0.0
        if !T.isEmpty, let f = T.fit(cf, kind: c.kind) { prof = max(0, min(1, Double(f - 50) / 49)) }
        if !T.isEmpty {
            if let d = cd.first(where: { (T.dir[$0] ?? 0) > 0.6 }) {
                why.append(Reason(c: "prof", w: prof + 0.1, t: "Un réalisateur que tu aimes (\(d))"))
            } else if let b = T.because(cf) {
                why.append(Reason(c: "prof", w: prof + 0.05, t: b.prefix(1).uppercased() + b.dropFirst()))
            } else if let k = cf.keywords.split(separator: "|").compactMap({ e -> (Int, String)? in
                let p = e.split(separator: ":", maxSplits: 1); guard p.count == 2, let i = Int(p[0]) else { return nil }; return (i, String(p[1]))
            }).filter({ (T.kw[$0.0] ?? 0) > 0 }).max(by: { (T.kw[$0.0] ?? 0) < (T.kw[$1.0] ?? 0) }) {
                why.append(Reason(c: "prof", w: prof, t: "Un thème que tu aimes : " + k.1.lowercased()))
            }
        }
        // qualité (note TMDB) et récence
        let qual = max(0, min(1, (cf.vote - 6) / 3))
        let fresh = max(0, min(1, Double(cf.year - 1990) / 36))
        var pen = 0.0
        if !T.isEmpty, cg.contains(where: { (T.genre[$0] ?? 0) < -0.3 && !((T.genre[$0] ?? 0) > 0.25) }) { pen += 0.06 }
        let union = Set(cg).union(bg)
        let gj = union.isEmpty ? 0 : Double(Set(cg).intersection(bg).count) / Double(union.count)
        let kwp = min(1, 0.7 * min(1, kw * 1.6) + 0.3 * gj)
        let rel = max(inF ? 1 : 0, kwp, crew)
        return Scored(item: c, parts: ["co": co, "kw": kwp, "crew": crew, "prof": prof, "qual": qual, "fresh": fresh],
                      pen: pen, rel: rel, why: why.sorted { $0.w > $1.w })
    }

    /// Raison affichée sous l'affiche (simulateur bestWhy)
    static func bestWhy(_ w: [Reason]) -> String {
        func P(_ t: (Reason) -> Bool) -> Reason? { w.first { $0.c != "neg" && t($0) } }
        return (P { $0.w >= 9 } ?? P { $0.t.hasPrefix("Parce que") || $0.t.hasPrefix("Un réalisateur") } ?? P { $0.c == "crew" }
                ?? P { $0.c == "co" } ?? P { $0.c == "kw" } ?? P { $0.c == "prof" } ?? P { _ in true })?.t ?? ""
    }

    private static func scoredAll(base: Fiche, title: String, cands: [MediaItem], recs: Set<Int>, T: TasteModel, mode: CrossMode) -> [Scored] {
        let W = mode.weights
        return cands.compactMap { c in
            guard var o = score(base: base, baseTitle: title, c: c, recs: recs, T: T) else { return nil }
            let gate = mode == .toi ? 0.6 + 0.4 * o.rel : 0.35 + 0.65 * o.rel
            o.raw = W.reduce(0) { $0 + $1.1 * (o.parts[$1.0] ?? 0) } * gate - o.pen
            return o
        }
    }

    /// La rangée : jusqu'à 10 titres, diversifiés (pas trois films du même réalisateur ou des mêmes thèmes à la suite).
    /// `models` : le profil actif, ou les deux profils en mode « Vous deux ».
    static func pick(base: Fiche, title: String, cands: [MediaItem], recs: Set<Int>, models: [TasteModel], mode: CrossMode) -> [CrossPickResult] {
        guard let A = models.first else { return [] }
        var all: [Scored]
        var duo: [String: (Int, Int)] = [:]
        if models.count == 2 {
            let a = scoredAll(base: base, title: title, cands: cands, recs: recs, T: A, mode: mode)
            let bmap = Dictionary(scoredAll(base: base, title: title, cands: cands, recs: recs, T: models[1], mode: mode).map { ($0.item.id, $0) }, uniquingKeysWith: { x, _ in x })
            all = a.compactMap { o in
                guard let q = bmap[o.item.id] else { return nil }
                var m = o
                m.raw = (o.raw + q.raw) / 2 - abs(o.raw - q.raw) * 0.35
                let pa = o.parts["prof"] ?? 0, pb = q.parts["prof"] ?? 0
                duo[o.item.id] = (Int((50 + pa * 49).rounded()), Int((50 + pb * 49).rounded()))
                if pa > 0.3 && pb > 0.3 { m.why.insert(Reason(c: "prof", w: 2, t: "Vous aimez tous les deux"), at: 0) }
                return m
            }
        } else {
            all = scoredAll(base: base, title: title, cands: cands, recs: recs, T: A, mode: mode)
        }
        var pool = Array(all.sorted { $0.raw > $1.raw }.prefix(80))
        var out: [Scored] = []
        while !pool.isEmpty && out.count < 10 {
            var bi = 0, bv = -1e9
            for (i, o) in pool.enumerated() {
                let of = o.item.fiche
                let red = out.isEmpty ? 0 : out.map { x -> Double in
                    let xf = x.item.fiche
                    let same = !(xf?.director ?? "").isEmpty && xf?.director == of?.director
                    return kwSim(xf?.keywordIDs ?? [], of?.keywordIDs ?? []) + (same ? 0.3 : 0)
                }.max() ?? 0
                let v = o.raw - 0.18 * red
                if v > bv { bv = v; bi = i }
            }
            out.append(pool.remove(at: bi))
        }
        return out.sorted { $0.raw > $1.raw }.map { o in
            let d = duo[o.item.id]
            return CrossPickResult(item: o.item, pct: max(35, min(99, Int((40 + o.raw * 95).rounded()))), pA: d?.0, pB: d?.1,
                                   why: bestWhy(o.why), whyAll: o.why.filter { $0.c != "neg" }.map(\.t), parts: o.parts)
        }
    }
}

/// Recommandations TMDB d'un titre (« Les fans de … l'adorent »), gardées en mémoire pendant la session.
enum TmdbRecs {
    @MainActor private static var memo: [String: [Int]] = [:]
    @MainActor static func load(kind: MediaKind, tmdb: Int) async -> [Int] {
        guard tmdb > 0, let key = TmdbKey.value else { return [] }
        let k = "\(kind.rawValue):\(tmdb)"
        if let m = memo[k] { return m }
        let path = (kind == .film ? "/movie/" : "/tv/") + "\(tmdb)/recommendations"
        let d = await TmdbAPI(key: key).get(path, [("language", "fr-FR")])
        let ids = ((d?["results"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? Int }
        memo[k] = ids
        return ids
    }
}

/// « Pas intéressé » (options d'une affiche de la rangée) : retiré des propositions de ce profil.
enum NotInterested {
    private static func key(_ pid: String) -> String { ProfileStore.storageKey("prisme.notint", for: pid) }
    static func list(_ pid: String) -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key(pid)) ?? []) }
    static func add(_ workKey: String, pid: String) {
        var s = list(pid); s.insert(workKey)
        UserDefaults.standard.set(Array(s).sorted(), forKey: key(pid))
    }
}
