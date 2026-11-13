import Foundation
import SwiftUI

struct Channel: Identifiable, Hashable {
    let pid: String
    let sid: String
    let name: String
    let num: Int
    let icon: String
    let cid: String
    let epg: String
    let archive: Int
    var id: String { pid + ":" + sid }
}

struct LiveCategory: Identifiable, Hashable {
    let pid: String
    let cid: String
    let name: String
    let count: Int
    var id: String { pid + ":" + cid }
}

struct Program: Identifiable, Hashable {
    let start: Int
    let stop: Int
    let title: String
    let descr: String
    var id: String { "\(start)-\(title)" }
    var startDate: Date { Date(timeIntervalSince1970: TimeInterval(start)) }
    var stopDate: Date { Date(timeIntervalSince1970: TimeInterval(stop)) }
    func progress(_ now: Date = Date()) -> Double {
        let t = now.timeIntervalSince1970
        guard stop > start else { return 0 }
        return min(1, max(0, (t - Double(start)) / Double(stop - start)))
    }
}

/// Lectures de la TV en direct dans la base : toujours hors de l'écran, résultats gardés en mémoire (limité).
enum LiveStore {
    static func categories(providers: [String]) async -> [LiveCategory] {
        guard !providers.isEmpty else { return [] }
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await Database.shared.read { db in
            var out: [LiveCategory] = []
            db.query("""
                SELECT c.pid, c.cid, c.name, COUNT(l.sid) FROM category c JOIN live l ON l.pid=c.pid AND l.cid=c.cid
                WHERE c.type='live' AND c.pid IN (\(ph)) GROUP BY c.pid, c.cid ORDER BY c.pid, c.pos
                """, providers) { r in out.append(LiveCategory(pid: r.str(0), cid: r.str(1), name: TitleTools.category(r.str(2)), count: r.int(3))) }
            return out
        }
    }

    static func channels(pid: String, cid: String) async -> [Channel] {
        await Database.shared.read { db in
            var out: [Channel] = []
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE pid=? AND cid=? ORDER BY num, name", [pid, cid]) { r in
                out.append(row(r))
            }
            return out
        }
    }

    static func channels(ids: [String]) async -> [Channel] {
        guard !ids.isEmpty else { return [] }
        return await Database.shared.read { db in
            var byID: [String: Channel] = [:]
            for chunk in stride(from: 0, to: ids.count, by: 400) {
                let part = Array(ids[chunk..<min(ids.count, chunk + 400)])
                let cond = part.map { _ in "(pid=? AND sid=?)" }.joined(separator: " OR ")
                let args: [Any?] = part.flatMap { id -> [Any?] in let p = id.split(separator: ":", maxSplits: 1).map(String.init); return [p.first, p.count > 1 ? p[1] : ""] }
                db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE \(cond)", args) { r in let c = row(r); byID[c.id] = c }
            }
            return ids.compactMap { byID[$0] }
        }
    }

    static func row(_ r: Database.Statement) -> Channel {
        Channel(pid: r.str(0), sid: r.str(1), name: r.str(2), num: r.int(3), icon: r.str(4), cid: r.str(5), epg: r.str(6), archive: r.int(7))
    }

    // MARK: guide

    private static let cache = NSCache<NSString, ProgramsBox>()
    final class ProgramsBox { let list: [Program]; let at: Date; init(_ l: [Program]) { list = l; at = Date() } }

    /// Programmes d'une chaîne autour de maintenant (gardés 5 minutes en mémoire).
    static func programs(_ ch: Channel, from: Date, hours: Double = 6) async -> [Program] {
        guard !ch.epg.isEmpty else { return [] }
        let key = "\(ch.epg)|\(Int(from.timeIntervalSince1970) / 1800)|\(hours)" as NSString
        if let b = cache.object(forKey: key), Date().timeIntervalSince(b.at) < 300 { return b.list }
        let a = Int(from.timeIntervalSince1970), z = a + Int(hours * 3600)
        let list = await Database.shared.read { db -> [Program] in
            var out: [Program] = []
            db.query("SELECT start,stop,title,descr FROM epg WHERE ch=? AND stop>? AND start<? ORDER BY start", [ch.epg, a, z]) { r in
                out.append(Program(start: r.int(0), stop: r.int(1), title: r.str(2), descr: r.str(3)))
            }
            return out
        }
        cache.setObject(ProgramsBox(list), forKey: key)
        return list
    }

    /// Un programme du guide, avec sa chaîne.
    struct Airing: Identifiable, Hashable { let ch: Channel; let p: Program; var id: String { ch.id + "|" + p.id } }

    private static let soonCache = NSCache<NSString, AiringBox>()
    final class AiringBox { let list: [Airing]; let at: Date; init(_ l: [Airing]) { list = l; at = Date() } }

    /// Les diffusions d'un titre au guide (en cours ou dans les 2 jours) : « À la TV » sur la fiche d'un film.
    static func airings(title: String, providers: [String]) async -> [Airing] {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, !providers.isEmpty else { return [] }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await Database.shared.read { db in
            var out: [Airing] = [], seen = Set<String>()
            db.query("""
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.title=? COLLATE NOCASE AND e.stop>? AND l.pid IN (\(ph)) ORDER BY e.start LIMIT 12
                """, ([t, now] as [Any?]) + providers.map { $0 as Any? }) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11)))
                if seen.insert(a.ch.name + "|\(a.p.start)").inserted { out.append(a) }
            }
            return Array(out.prefix(6))
        }
    }

    /// « Commence bientôt » : ce qui démarre dans l'heure (gardé 5 minutes en mémoire).
    static func startingSoon(providers: [String]) async -> [Airing] {
        guard !providers.isEmpty else { return [] }
        let key = providers.joined(separator: ",") as NSString
        if let b = soonCache.object(forKey: key), Date().timeIntervalSince(b.at) < 300 { return b.list }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        let list = await Database.shared.read { db -> [Airing] in
            var out: [Airing] = [], seen = Set<String>()
            db.query("""
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.start>? AND e.start<=? AND l.pid IN (\(ph)) ORDER BY e.start, l.num LIMIT 80
                """, ([now, now + 3600] as [Any?]) + providers.map { $0 as Any? }) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11)))
                if seen.insert(a.ch.epg + "|\(a.p.start)").inserted { out.append(a) }
            }
            return Array(out.prefix(20))
        }
        soonCache.setObject(AiringBox(list), forKey: key)
        return list
    }

    /// Recherche d'une chaîne par son nom.
    static func search(_ q: String, providers: [String]) async -> [Channel] {
        guard !providers.isEmpty else { return [] }
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await Database.shared.read { db in
            var out: [Channel] = []
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE name LIKE ? AND pid IN (\(ph)) ORDER BY num, name LIMIT 120",
                     (["%" + q + "%"] as [Any?]) + providers.map { $0 as Any? }) { r in out.append(row(r)) }
            return out
        }
    }

    /// Première chaîne d'une catégorie (image de la carte « univers »).
    static func firstChannels(pid: String, cid: String, limit: Int) async -> [Channel] {
        await Database.shared.read { db in
            var out: [Channel] = []
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE pid=? AND cid=? ORDER BY num, name LIMIT \(limit)", [pid, cid]) { r in out.append(row(r)) }
            return out
        }
    }

    /// En ce moment + ensuite.
    static func nowNext(_ ch: Channel) async -> (Program?, Program?) {
        let now = Date()
        let l = await programs(ch, from: now.addingTimeInterval(-4 * 3600), hours: 10)
        let t = Int(now.timeIntervalSince1970)
        let i = l.firstIndex { $0.start <= t && $0.stop > t }
        guard let i else { return (nil, l.first { $0.start > t }) }
        return (l[i], i + 1 < l.count ? l[i + 1] : nil)
    }
}

/// Favoris et chaînes récentes (stockés sur l'Apple TV, gardés d'une version à l'autre).
@MainActor
final class LivePrefs: ObservableObject {
    static let shared = LivePrefs()
    @Published var favorites: [String] { didSet { UserDefaults.standard.set(favorites, forKey: "prisme.live.favs") } }
    @Published var recent: [String] { didSet { UserDefaults.standard.set(recent, forKey: "prisme.live.recent") } }
    @Published var lastCategory: String? { didSet { UserDefaults.standard.set(lastCategory, forKey: "prisme.live.lastcat") } }

    private init() {
        favorites = UserDefaults.standard.stringArray(forKey: "prisme.live.favs") ?? []
        recent = UserDefaults.standard.stringArray(forKey: "prisme.live.recent") ?? []
        lastCategory = UserDefaults.standard.string(forKey: "prisme.live.lastcat")
    }

    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.append(id) }
    }
    func played(_ id: String) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > 20 { recent.removeLast(recent.count - 20) }
    }
}

extension Provider {
    func liveURL(_ ch: Channel) -> URL? {
        let u = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let p = password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? password
        return URL(string: "\(account.baseURL)/live/\(u)/\(p)/\(ch.sid).ts")
    }
}
