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
    /// image du programme donnée par le guide (<icon>), et son genre (« Film », « Série »…) — 1.7.1
    var img = ""
    var cat = ""
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
            db.query("SELECT start,stop,title,descr,COALESCE(img,''),COALESCE(cat,'') FROM epg WHERE ch=? AND stop>? AND start<? ORDER BY start", [ch.epg, a, z]) { r in
                out.append(Program(start: r.int(0), stop: r.int(1), title: r.str(2), descr: r.str(3), img: r.str(4), cat: r.str(5)))
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
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr,COALESCE(e.img,''),COALESCE(e.cat,'') FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.title=? COLLATE NOCASE AND e.stop>? AND l.pid IN (\(ph)) ORDER BY e.start LIMIT 12
                """, ([t, now] as [Any?]) + providers.map { $0 as Any? }) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11), img: r.str(12), cat: r.str(13)))
                if seen.insert(a.ch.name + "|\(a.p.start)").inserted { out.append(a) }
            }
            return Array(out.prefix(6))
        }
    }

    /// Genre d'un programme d'après la catégorie du guide (règle « pgen » du simulateur ; « dessin animé »
    /// et « animation » vont en Jeunesse, « animaux » reste en Découverte).
    private static let genreRx: [(Univers, NSRegularExpression)] = [
        (.cinema, ChannelTools.rx(#"film|cinema|telefilm|movie"#)),
        (.series, ChannelTools.rx(#"serie|feuilleton|fiction|drama|soap|sitcom"#)),
        (.sport, ChannelTools.rx(#"sport|foot|rugby|tennis|cyclisme|match|basket|golf|moteur|\bf1\b"#)),
        (.info, ChannelTools.rx(#"info|journal|politique|debat|actualite|news|meteo"#)),
        (.jeunesse, ChannelTools.rx(#"dessin|animation|\banime\b|jeunesse|enfant|kids|children|cartoon"#)),
        (.decouverte, ChannelTools.rx(#"docu|decouverte|nature|histoire|science|voyage|animaux"#)),
        (.musique, ChannelTools.rx(#"musique|music|concert|clip"#)),
    ]
    /// une catégorie du guide revient des milliers de fois : décidée une seule fois
    private static let genreLock = NSLock()
    nonisolated(unsafe) private static var genreMemo: [String: Univers?] = [:]

    static func genre(ofGuideCategory g0: String) -> Univers? {
        genreLock.lock(); if let v = genreMemo[g0] { genreLock.unlock(); return v }; genreLock.unlock()
        let v = genre0(g0)
        genreLock.lock(); genreMemo[g0] = v; genreLock.unlock()
        return v
    }

    private static func genre0(_ g0: String) -> Univers? {
        let g = ChannelTools.fold(g0)
        guard !g.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        for (u, r) in genreRx where ChannelTools.has(r, g) { return u }
        return .divert
    }

    /// « En ce moment » : les chaînes dont le programme EN COURS est de ce genre, d'après le guide
    /// (seulement les programmes dont le guide donne un genre ; une chaîne une seule fois par genre).
    static func airingNowByGenre(providers: [String]) async -> [(Univers, [Channel])] {
        guard !providers.isEmpty else { return [] }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        let rows = await Database.shared.read { db -> [(Channel, String)] in
            var out: [(Channel, String)] = []
            db.query("""
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.cat FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.start<=? AND e.stop>? AND e.cat IS NOT NULL AND e.cat!='' AND l.pid IN (\(ph)) ORDER BY l.num
                """, ([now, now] as [Any?]) + providers.map { $0 as Any? }) { r in out.append((row(r), r.str(8))) }
            return out
        }
        var by: [Univers: [Channel]] = [:]
        for (c, g) in rows { if let u = genre(ofGuideCategory: g) { by[u, default: []].append(c) } }
        return Univers.allCases.compactMap { u in by[u].map { (u, ChannelTools.dedupe($0)) } }.filter { !$0.1.isEmpty }
    }

    /// Recherche (lot 3) : tous les programmes en cours, une chaîne une fois (gardé 2 minutes en mémoire).
    static func airingNow(providers: [String]) async -> [Airing] {
        guard !providers.isEmpty else { return [] }
        let key = ("now|" + providers.joined(separator: ",")) as NSString
        if let b = soonCache.object(forKey: key), Date().timeIntervalSince(b.at) < 120 { return b.list }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        let list = await Database.shared.read { db -> [Airing] in
            var out: [Airing] = [], seen = Set<String>()
            db.query("""
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr,COALESCE(e.img,''),COALESCE(e.cat,'') FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.start<=? AND e.stop>? AND l.pid IN (\(ph)) ORDER BY l.num LIMIT 3000
                """, ([now, now] as [Any?]) + providers.map { $0 as Any? }) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11), img: r.str(12), cat: r.str(13)))
                if seen.insert(ChannelTools.key(a.ch)).inserted { out.append(a) }
            }
            return out
        }
        soonCache.setObject(AiringBox(list), forKey: key)
        return list
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
                SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr,COALESCE(e.img,''),COALESCE(e.cat,'') FROM epg e JOIN live l ON l.epg=e.ch
                WHERE e.start>? AND e.start<=? AND l.pid IN (\(ph)) ORDER BY e.start, l.num LIMIT 80
                """, ([now, now + 3600] as [Any?]) + providers.map { $0 as Any? }) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11), img: r.str(12), cat: r.str(13)))
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
    private var loading = false
    private func k(_ b: String) -> String { ProfileStore.shared.key(b) }
    @Published var favorites: [String] = [] { didSet { if !loading { UserDefaults.standard.set(favorites, forKey: k("prisme.live.favs")) } } }
    @Published var recent: [String] = [] { didSet { if !loading { UserDefaults.standard.set(recent, forKey: k("prisme.live.recent")) } } }
    @Published var lastCategory: String? { didSet { if !loading { UserDefaults.standard.set(lastCategory, forKey: k("prisme.live.lastcat")) } } }

    private init() { reload() }

    /// Chaînes favorites et récentes du profil actif (clés d'origine pour le profil de Steven).
    func reload() {
        loading = true
        favorites = UserDefaults.standard.stringArray(forKey: k("prisme.live.favs")) ?? []
        recent = UserDefaults.standard.stringArray(forKey: k("prisme.live.recent")) ?? []
        lastCategory = UserDefaults.standard.string(forKey: k("prisme.live.lastcat"))
        loading = false
    }

    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.append(id) }
    }
    func played(_ id: String) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > 20 { recent.removeLast(recent.count - 20) }
    }

    // MARK: identité des chaînes (1.7)
    // Les favoris et les chaînes récentes restent enregistrés comme avant (fournisseur:flux) — rien n'est réécrit —,
    // mais ils sont reconnus par l'IDENTITÉ de la chaîne : TF1 en favori chez Lune l'est aussi chez Soleil.
    // La table « flux → identité » (commune à tous les profils) permet de retrouver un favori même si son fournisseur
    // a été supprimé.
    private static let keysKey = "prisme.live.idkeys"
    private var idKeys: [String: String] = UserDefaults.standard.dictionary(forKey: LivePrefs.keysKey) as? [String: String] ?? [:]

    func remember(_ keys: [String: String]) {
        var changed = false
        for (id, k) in keys where idKeys[id] != k { idKeys[id] = k; changed = true }
        if changed { UserDefaults.standard.set(idKeys, forKey: LivePrefs.keysKey) }
    }
    func knownKey(_ id: String) -> String? { idKeys[id] }

    func isFavorite(_ ch: Channel) -> Bool {
        if favorites.contains(ch.id) { return true }
        let k = ChannelTools.key(ch)
        return favorites.contains { idKeys[$0] == k }
    }
    /// Ajoute ou retire la CHAÎNE des favoris (toutes ses copies, chez tous les fournisseurs).
    func toggleFavorite(_ ch: Channel) {
        let k = ChannelTools.key(ch)
        remember([ch.id: k])
        if isFavorite(ch) { favorites.removeAll { $0 == ch.id || idKeys[$0] == k } } else { favorites.append(ch.id) }
    }
    func played(_ ch: Channel) {
        let k = ChannelTools.key(ch)
        remember([ch.id: k])
        recent.removeAll { $0 == ch.id || idKeys[$0] == k }
        recent.insert(ch.id, at: 0)
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
