import Foundation
import Security
import SwiftUI

// MARK: - Clé TMDB (tapée sur l'Apple TV, rangée dans le trousseau de l'appareil)

enum TmdbKey {
    private static let service = "prisme.tmdb"
    static var value: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        let s = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }
    static func set(_ v: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let v, !v.isEmpty else { return }
        var add = base; add[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}

// MARK: - Fiche (ce qu'on garde de TMDB pour un titre)

struct CastMember: Codable, Hashable { let n: String; let c: String; let p: String }
struct WatchProviders: Codable, Hashable { var f: [WP] = []; var r: [WP] = []; var b: [WP] = []; var g: [WP] = [] }
struct WP: Codable, Hashable { let n: String; let l: String }

struct Fiche: Hashable {
    let tmdb: Int
    let title: String
    let overview: String
    let poster: String
    let backdrop: String
    let genres: String
    let runtime: Int
    let vote: Double
    let year: Int
    let coll: Int
    let collName: String
    let cast: [CastMember]
    let wp: WatchProviders
    let pid: String
    let sid: String
    static func img(_ path: String, _ size: String = "w342") -> String { path.isEmpty ? "" : "https://image.tmdb.org/t/p/\(size)\(path)" }
}

enum FicheStore {
    static func row(_ r: Database.Statement) -> Fiche {
        let cast = (try? JSONDecoder().decode([CastMember].self, from: Data(r.str(10).utf8))) ?? []
        let wp = (try? JSONDecoder().decode(WatchProviders.self, from: Data(r.str(11).utf8))) ?? WatchProviders()
        return Fiche(tmdb: r.int(0), title: r.str(1), overview: r.str(2), poster: r.str(3), backdrop: r.str(4), genres: r.str(5),
                     runtime: r.int(6), vote: r.double(7), year: r.int(8), coll: r.int(9), collName: r.str(12), cast: cast, wp: wp,
                     pid: r.str(13), sid: r.str(14))
    }
    static let cols = "tmdb,title,overview,poster,backdrop,genres,runtime,vote,year,coll,cast,wp,collname,pid,sid"

    /// Fiches de plusieurs titres d'un coup (clé = titre propre + année).
    static func byKeys(_ kind: MediaKind, _ keys: [String]) -> [String: Fiche] {
        guard !keys.isEmpty else { return [:] }
        var out: [String: Fiche] = [:]
        let db = Database.shared
        for chunk in stride(from: 0, to: keys.count, by: 400) {
            let part = Array(keys[chunk..<min(keys.count, chunk + 400)])
            db.query("SELECT \(cols),ckey FROM fiche WHERE kind=? AND ckey IN (" + part.map { _ in "?" }.joined(separator: ",") + ")",
                     [kind.rawValue] + part) { r in out[r.str(15)] = row(r) }
        }
        return out
    }
}

// MARK: - Téléchargement des fiches en arrière-plan

@MainActor
final class FicheService: ObservableObject {
    static let shared = FicheService()
    @Published var done = 0
    @Published var total = 0
    @Published var running = false
    @Published var version = 0          // change quand de nouvelles fiches arrivent (les écrans se mettent à jour)
    @Published var lastError: String?
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil, TmdbKey.value != nil else { return }
        running = true
        task = Task.detached(priority: .background) { await FicheWorker().run() ; await MainActor.run { FicheService.shared.task = nil; FicheService.shared.running = false } }
    }
    func restart() { task?.cancel(); task = nil; start() }
}

/// Va chercher les fiches manquantes, 4 à la fois, les titres les plus récents d'abord.
struct FicheWorker {
    func run() async {
        guard let key = TmdbKey.value else { return }
        let api = TmdbAPI(key: key)
        // clé valide ?
        if await api.get("/configuration") == nil {
            await MainActor.run { FicheService.shared.lastError = "TMDB refuse cette clé (ou pas de connexion)." }
            return
        }
        await MainActor.run { FicheService.shared.lastError = nil }
        for kind in [MediaKind.film, .series] {
            let todo = await candidates(kind)
            await MainActor.run { FicheService.shared.total += todo.count }
            var i = 0
            while i < todo.count {
                if Task.isCancelled { return }
                let batch = Array(todo[i..<min(todo.count, i + 24)])
                i += batch.count
                var rows: [[Any?]] = [], misses: [[Any?]] = []
                await withTaskGroup(of: (MediaItem, [Any?]?).self) { g in
                    var it = batch.makeIterator()
                    for _ in 0..<4 { if let m = it.next() { g.addTask { (m, await fetch(api, m)) } } }
                    while let done = await g.next() {
                        let (m, r) = done
                        if let r { rows.append(r) } else { misses.append([kind.rawValue, m.clean.key, Int(Date().timeIntervalSince1970)]) }
                        if let n = it.next() { g.addTask { (n, await fetch(api, n)) } }
                    }
                }
                await Database.shared.read { db in
                    db.insertMany("INSERT OR REPLACE INTO fiche(kind,ckey,pid,sid,\(FicheStore.cols.replacingOccurrences(of: ",pid,sid", with: ""))) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
                    db.insertMany("INSERT OR REPLACE INTO fmiss VALUES(?,?,?)", misses)
                }
                let n = batch.count
                await MainActor.run { FicheService.shared.done += n; FicheService.shared.version += 1 }
            }
        }
    }

    /// Titres sans fiche (une seule fois par titre, même s'il existe en plusieurs versions).
    private func candidates(_ kind: MediaKind) async -> [MediaItem] {
        let pids = await MainActor.run { ProviderStore.shared.active.map(\.id) }
        guard !pids.isEmpty else { return [] }
        let table = kind == .film ? "vod" : "series"
        let cols = kind == .film ? "pid,sid,name,year,icon,cid,ext,rating,added,tmdb,''" : "pid,sid,name,year,cover,cid,'',rating,added,tmdb,plot"
        return await Database.shared.read { db in
            var have = Set<String>()
            db.query("SELECT ckey FROM fiche WHERE kind=?", [kind.rawValue]) { r in have.insert(r.str(0)) }
            let weekAgo = Int(Date().timeIntervalSince1970) - 7 * 86400
            db.query("SELECT ckey FROM fmiss WHERE kind=? AND at>?", [kind.rawValue, weekAgo]) { r in have.insert(r.str(0)) }
            var out: [MediaItem] = []
            db.query("SELECT \(cols) FROM \(table) WHERE pid IN (" + pids.map { _ in "?" }.joined(separator: ",") + ") ORDER BY added DESC", pids) { r in
                let m = MediaItem(kind: kind, pid: r.str(0), sid: r.str(1), name: r.str(2), year: r.int(3), icon: r.str(4), cid: r.str(5),
                                  ext: r.str(6), rating: r.double(7), added: r.int(8), tmdb: r.str(9), plot: r.str(10))
                if have.insert(m.clean.key).inserted { out.append(m) }
            }
            return out
        }
    }

    /// Une fiche : l'identifiant TMDB du fournisseur s'il existe, sinon recherche par titre et année.
    private func fetch(_ api: TmdbAPI, _ m: MediaItem) async -> [Any?]? {
        let tv = m.kind == .series
        let c = m.clean
        var id = Int(m.tmdb) ?? 0
        if id == 0 {
            var q = [("query", c.title), ("language", "fr-FR")]
            if c.year > 0 { q.append((tv ? "first_air_date_year" : "year", String(c.year))) }
            guard let res = await api.get(tv ? "/search/tv" : "/search/movie", q)?["results"] as? [[String: Any]] else { return nil }
            var best: (Int, Double) = (0, 0)
            for r in res.prefix(8) {
                let names = [r["title"], r["name"], r["original_title"], r["original_name"]].compactMap { $0 as? String }
                let sim = names.map { TmdbAPI.similarity($0, c.title) }.max() ?? 0
                let date = (r[tv ? "first_air_date" : "release_date"] as? String) ?? ""
                let y = Int(date.prefix(4)) ?? 0
                let score = sim + (c.year > 0 && y > 0 ? (abs(y - c.year) <= 1 ? 0.25 : -0.3) : 0) + min(0.1, (r["popularity"] as? Double ?? 0) / 500)
                if (r["adult"] as? Bool) != true, score > best.1 { best = ((r["id"] as? Int) ?? 0, score) }
            }
            guard best.1 >= 0.62 else { return nil }
            id = best.0
        }
        let append = tv ? "aggregate_credits,watch/providers" : "credits,watch/providers"
        guard let d = await api.get((tv ? "/tv/" : "/movie/") + String(id), [("language", "fr-FR"), ("append_to_response", append)]),
              (d["adult"] as? Bool) != true else { return nil }
        let title = (d[tv ? "name" : "title"] as? String) ?? c.title
        let genres = ((d["genres"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }.joined(separator: ", ")
        let runtime = tv ? (((d["episode_run_time"] as? [Int]) ?? []).first ?? 0) : ((d["runtime"] as? Int) ?? 0)
        let date = (d[tv ? "first_air_date" : "release_date"] as? String) ?? ""
        let coll = d["belongs_to_collection"] as? [String: Any]
        let credits = (d[tv ? "aggregate_credits" : "credits"] as? [String: Any])?["cast"] as? [[String: Any]] ?? []
        let cast: [CastMember] = credits.prefix(12).map { a in
            let ch = tv ? ((((a["roles"] as? [[String: Any]]) ?? []).first?["character"] as? String) ?? "") : ((a["character"] as? String) ?? "")
            return CastMember(n: (a["name"] as? String) ?? "", c: ch, p: (a["profile_path"] as? String) ?? "")
        }
        var wp = WatchProviders()
        if let fr = (((d["watch/providers"] as? [String: Any])?["results"] as? [String: Any])?["FR"] as? [String: Any]) {
            func l(_ k: String) -> [WP] { ((fr[k] as? [[String: Any]]) ?? []).map { WP(n: ($0["provider_name"] as? String) ?? "", l: ($0["logo_path"] as? String) ?? "") } }
            wp.f = l("flatrate"); wp.r = l("rent"); wp.b = l("buy"); wp.g = l("free") + l("ads")
        }
        let castJ = String(data: (try? JSONEncoder().encode(cast)) ?? Data(), encoding: .utf8) ?? "[]"
        let wpJ = String(data: (try? JSONEncoder().encode(wp)) ?? Data(), encoding: .utf8) ?? "{}"
        // kind,ckey,pid,sid,tmdb,title,overview,poster,backdrop,genres,runtime,vote,year,coll,cast,wp,collname
        return [m.kind.rawValue, c.key, m.pid, m.sid, id, title, (d["overview"] as? String) ?? "", (d["poster_path"] as? String) ?? "",
                (d["backdrop_path"] as? String) ?? "", genres, runtime, (d["vote_average"] as? Double) ?? 0, Int(date.prefix(4)) ?? c.year,
                (coll?["id"] as? Int) ?? 0, castJ, wpJ, (coll?["name"] as? String) ?? ""]
    }
}

struct TmdbAPI {
    let key: String
    func get(_ path: String, _ q: [(String, String)] = []) async -> [String: Any]? {
        var c = URLComponents(string: "https://api.themoviedb.org/3" + path)
        c?.queryItems = [URLQueryItem(name: "api_key", value: key)] + q.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = c?.url else { return nil }
        for attempt in 0..<3 {
            var req = URLRequest(url: url); req.timeoutInterval = 20
            guard let res = try? await URLSession.shared.data(for: req) else { return nil }
            let (data, resp) = res
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 429 { try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (attempt + 1))); continue }
            guard code == 200 else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        return nil
    }

    /// Ressemblance de deux titres (0 à 1), sans accents ni ponctuation.
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = TitleTools.fold(a), y = TitleTools.fold(b)
        if x == y { return 1 }
        func pairs(_ s: String) -> [String] { let c = Array(s); return c.count < 2 ? [s] : (0..<(c.count - 1)).map { String(c[$0...$0 + 1]) } }
        var p2 = pairs(y); let p1 = pairs(x)
        var hit = 0
        for p in p1 { if let i = p2.firstIndex(of: p) { hit += 1; p2.remove(at: i) } }
        return Double(2 * hit) / Double(max(1, p1.count + pairs(y).count))
    }
}

// MARK: - Sagas (collection TMDB, gardée sur l'appareil)

struct SagaPart: Hashable { let tmdb: Int; let title: String; let year: Int; let poster: String }

enum SagaStore {
    static func parts(_ coll: Int) async -> (String, [SagaPart]) {
        if let c = await Database.shared.read({ db -> (String, String)? in
            var out: (String, String)?
            db.query("SELECT name, parts FROM coll WHERE id=?", [coll]) { r in out = (r.str(0), r.str(1)) }
            return out
        }), let arr = try? JSONSerialization.jsonObject(with: Data(c.1.utf8)) as? [[String: Any]] {
            return (c.0, arr.map { SagaPart(tmdb: $0["i"] as? Int ?? 0, title: $0["t"] as? String ?? "", year: $0["y"] as? Int ?? 0, poster: $0["p"] as? String ?? "") })
        }
        guard let key = TmdbKey.value, let d = await TmdbAPI(key: key).get("/collection/\(coll)", [("language", "fr-FR")]) else { return ("", []) }
        let name = d["name"] as? String ?? ""
        let parts = ((d["parts"] as? [[String: Any]]) ?? []).filter { ($0["adult"] as? Bool) != true }.map { p -> SagaPart in
            SagaPart(tmdb: p["id"] as? Int ?? 0, title: (p["title"] as? String) ?? "", year: Int(((p["release_date"] as? String) ?? "").prefix(4)) ?? 0, poster: (p["poster_path"] as? String) ?? "")
        }.sorted { ($0.year == 0 ? 9999 : $0.year) < ($1.year == 0 ? 9999 : $1.year) }
        let js = String(data: (try? JSONSerialization.data(withJSONObject: parts.map { ["i": $0.tmdb, "t": $0.title, "y": $0.year, "p": $0.poster] })) ?? Data(), encoding: .utf8) ?? "[]"
        await Database.shared.read { db in db.run("INSERT OR REPLACE INTO coll VALUES(?,?,?)", [coll, name, js]) }
        return (name, parts)
    }
}
