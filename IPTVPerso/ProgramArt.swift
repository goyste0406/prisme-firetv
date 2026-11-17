import Foundation
import SwiftUI
import Compression

// MARK: - Images des programmes TV (1.7.1)
//
// Ordre de recherche, du plus sûr au moins sûr :
//  1. l'image donnée par le guide du fournisseur pour ce programme (<icon> ou <image> du XMLTV, lue à l'import) ;
//  2. l'image du même programme dans le guide public xmltvfr.fr (chaînes françaises), si son guide en donne ;
//  3. TMDB, seulement pour un film ou une série, et seulement si le titre correspond nettement.
// Rien d'inventé : sans image sûre, la vignette garde son fond aux couleurs de la chaîne.

enum ProgramArt {
    /// adresse du guide xmltvfr.fr (chaînes de la TNT), remplaçable par le banc d'essai
    static var xfrURL: String { Debug.arg("prisme.debug.xfrURL") ?? "https://xmltvfr.fr/xmltv/xmltv_tnt.xml.gz" }

    private static let memo = NSCache<NSString, NSString>()

    /// Image d'un programme (URL), ou nil. Rapide quand déjà connue ; sinon xmltvfr puis TMDB, en arrière-plan.
    static func url(ch: Channel, p: Program) async -> String? {
        if !p.img.isEmpty { return p.img }
        let mk = "\(ch.epg)|\(ch.name)|\(p.start)|\(p.title)" as NSString
        if let m = memo.object(forKey: mk) { return m.length == 0 ? nil : m as String }
        var found = await XmltvFr.shared.image(ch: ch, p: p)
        if found == nil { found = await TmdbProgram.shared.image(p) }
        memo.setObject((found ?? "") as NSString, forKey: mk)
        return found
    }
}

/// Fond d'une vignette TV : l'image du programme en plein cadre quand on en a une, assombrie pour garder le texte lisible.
struct ProgramImage: View {
    let ch: Channel
    let p: Program?
    @State private var url: String?
    var body: some View {
        ZStack {
            if let url {
                SharpImage(url: url, maxPixel: 640)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(Color.black.opacity(0.28))
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .task(id: (p?.id ?? "") + ch.id) {
            guard let p else { url = nil; return }
            let u = await ProgramArt.url(ch: ch, p: p)
            withAnimation(.easeOut(duration: 0.3)) { url = u }
        }
    }
}

// MARK: - xmltvfr.fr

/// Guide public xmltvfr.fr : téléchargé au plus toutes les 12 h, gardé dans la base pour les 30 prochaines heures.
/// Sert uniquement à trouver l'image d'un programme que le guide du fournisseur ne donne pas.
actor XmltvFr {
    static let shared = XmltvFr()
    private let lastKey = "prisme.xfr.last"
    private var refreshing: Task<Void, Never>?
    /// nom de chaîne simplifié → identifiant xmltvfr (« tf1 » → « TF1.fr »)
    private var byName: [String: String] = [:]
    private var ids: Set<String> = []
    private var loadedMap = false

    func image(ch: Channel, p: Program) async -> String? {
        await refreshIfNeeded()
        if !loadedMap { await loadMap() }
        guard let id = match(ch) else { return nil }
        let mid = (p.start + p.stop) / 2
        let rows: [(String, String)] = await Database.shared.read { db in
            var out: [(String, String)] = []
            db.query("SELECT title, img FROM xfr WHERE ch=? AND start<=? AND stop>? AND img<>''", [id, mid, mid]) { r in out.append((r.str(0), r.str(1))) }
            return out
        }
        // même créneau ET même titre (à peu près) : sinon on ne prend pas l'image
        return rows.first { TmdbAPI.similarity(TmdbProgram.core($0.0), TmdbProgram.core(p.title)) >= 0.7 }?.1
    }

    private func match(_ ch: Channel) -> String? {
        if !ch.epg.isEmpty, let hit = ids.first(where: { $0.caseInsensitiveCompare(ch.epg) == .orderedSame }) { return hit }
        return byName[Self.simple(ChannelTools.clean(ch.name))]
    }

    static func simple(_ s: String) -> String {
        TitleTools.fold(s).replacingOccurrences(of: #"\b(hd|fhd|uhd|4k|sd|hevc|h265|fr|france)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "")
    }

    private func loadMap() async {
        let L: [(String, String)] = await Database.shared.read { db in
            var out: [(String, String)] = []
            db.query("SELECT id, n FROM xfrch") { r in out.append((r.str(0), r.str(1))) }
            return out
        }
        ids = Set(L.map(\.0))
        byName = [:]
        for (id, n) in L {
            byName[Self.simple(n)] = byName[Self.simple(n)] ?? id
            // « TF1.fr » → « tf1 »
            let base = Self.simple(String(id.split(separator: ".").first ?? ""))
            if !base.isEmpty { byName[base] = byName[base] ?? id }
        }
        loadedMap = true
    }

    private func refreshIfNeeded() async {
        let last = UserDefaults.standard.double(forKey: lastKey)
        guard Date().timeIntervalSince1970 - last > 12 * 3600 else { return }
        if let r = refreshing { await r.value; return }
        let t = Task { await self.download() }
        refreshing = t
        await t.value
        refreshing = nil
    }

    private func download() async {
        // une seule tentative par période, même en cas d'échec (pas de nouvelles demandes en boucle)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastKey)
        guard let u = URL(string: ProgramArt.xfrURL) else { return }
        let dir = ListFiles.dir
        let gz = dir.appendingPathComponent("xmltvfr.download"), xml = dir.appendingPathComponent("xmltvfr.xml")
        defer { try? FileManager.default.removeItem(at: gz); try? FileManager.default.removeItem(at: xml) }
        do { try await ListFiles.download(u, to: gz, timeout: 90) } catch { PerfLog.ev("xmltvfr : téléchargement impossible (\(error))"); return }
        guard Gunzip.file(gz, to: xml) else { PerfLog.ev("xmltvfr : fichier illisible"); return }
        let parser = XfrParser(file: xml)
        let (chans, progs) = parser.run()
        await Database.shared.read { db in
            db.exec("BEGIN IMMEDIATE")
            db.run("DELETE FROM xfr"); db.run("DELETE FROM xfrch")
            db.exec("COMMIT")
            db.insertMany("INSERT OR REPLACE INTO xfrch VALUES(?,?)", chans)
            db.insertMany("INSERT INTO xfr VALUES(?,?,?,?,?)", progs)
        }
        loadedMap = false
        PerfLog.ev("xmltvfr : \(chans.count) chaînes, \(progs.count) programmes, \(progs.filter { !(($0[4] as? String) ?? "").isEmpty }.count) avec image")
    }
}

/// Lecture du guide xmltvfr : les chaînes, et les programmes des 30 prochaines heures (titre, image).
final class XfrParser: NSObject, XMLParserDelegate {
    private let file: URL
    private var chans: [[Any?]] = [], progs: [[Any?]] = []
    private var chID: String?, chName = ""
    private var cur: (ch: String, start: Int, stop: Int)?
    private var title = "", img = "", text = ""
    private var inName = false, inTitle = false
    private let from = Int(Date().timeIntervalSince1970) - 3 * 3600, to = Int(Date().timeIntervalSince1970) + 30 * 3600
    init(file: URL) { self.file = file }

    func run() -> ([[Any?]], [[Any?]]) {
        guard let s = InputStream(url: file) else { return ([], []) }
        let p = XMLParser(stream: s); p.delegate = self; p.parse()
        return (chans, progs)
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        switch name {
        case "channel": chID = a["id"]; chName = ""
        case "display-name": if chID != nil, chName.isEmpty { inName = true; text = "" }
        case "programme":
            let st = EPGParser.time(a["start"] ?? ""), sp = EPGParser.time(a["stop"] ?? "")
            cur = (sp > from && st < to && sp > st) ? (a["channel"] ?? "", st, sp) : nil
            title = ""; img = ""
        case "title": if cur != nil, title.isEmpty { inTitle = true; text = "" }
        case "icon": if cur != nil, img.isEmpty, let u = a["src"], u.hasPrefix("http") { img = u }
        default: break
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inName || inTitle { text += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "display-name": if inName { chName = text.trimmingCharacters(in: .whitespacesAndNewlines); inName = false }
        case "channel": if let id = chID { chans.append([id, chName]) }; chID = nil
        case "title": if inTitle { title = text; inTitle = false }
        case "programme": if let c = cur { progs.append([c.ch, c.start, c.stop, title, img]) }; cur = nil
        default: break
        }
    }
}

/// Décompression d'un fichier .gz (format gzip) vers un fichier, par morceaux. Un fichier déjà en clair est copié.
enum Gunzip {
    static func file(_ src: URL, to dst: URL) -> Bool {
        guard let data = try? Data(contentsOf: src, options: .alwaysMapped), data.count > 18 else { return false }
        try? FileManager.default.removeItem(at: dst)
        if !(data[0] == 0x1f && data[1] == 0x8b) {
            return (try? FileManager.default.copyItem(at: src, to: dst)) != nil
        }
        // en-tête gzip (RFC 1952) : 10 octets, puis champs facultatifs selon les drapeaux
        let flg = data[3]
        var i = 10
        if flg & 4 != 0 { guard data.count > i + 2 else { return false }; i += 2 + Int(data[i]) + Int(data[i + 1]) << 8 }
        if flg & 8 != 0 { while i < data.count, data[i] != 0 { i += 1 }; i += 1 }
        if flg & 16 != 0 { while i < data.count, data[i] != 0 { i += 1 }; i += 1 }
        if flg & 2 != 0 { i += 2 }
        guard i < data.count - 8 else { return false }
        FileManager.default.createFile(atPath: dst.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: dst) else { return false }
        defer { try? out.close() }
        // le reste est un flux DEFLATE brut : c'est ce que lit COMPRESSION_ZLIB
        let bufSize = 1 << 16
        let dstBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { dstBuf.deallocate() }
        var stream = compression_stream(dst_ptr: dstBuf, dst_size: 0, src_ptr: UnsafePointer(dstBuf), src_size: 0, state: nil)
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { return false }
        defer { compression_stream_destroy(&stream) }
        let ok: Bool = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            stream.src_ptr = base + i
            stream.src_size = data.count - i - 8
            while true {
                stream.dst_ptr = dstBuf; stream.dst_size = bufSize
                let st = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let n = bufSize - stream.dst_size
                if n > 0 { out.write(Data(bytesNoCopy: dstBuf, count: n, deallocator: .none)) }
                switch st {
                case COMPRESSION_STATUS_OK: continue
                case COMPRESSION_STATUS_END: return true
                default: return false
                }
            }
        }
        return ok
    }
}

// MARK: - TMDB pour un film ou une série diffusé à la TV

actor TmdbProgram {
    static let shared = TmdbProgram()
    private var running = 0

    /// titre sans « (S2, Ep. 3) », « - Épisode 4 », « (VM) »… pour comparer et chercher
    nonisolated static func core(_ t: String) -> String {
        var s = t
        for rx in [#"\s*\((?:S|Saison)\s*\d+.*?\)"#, #"\s*[-:–]\s*(?:S\d+\s*E\d+|Saison\s*\d+|Épisode\s*\d+|Ep\.?\s*\d+).*$"#, #"\s*\((?:VM|VF|VOST|VOSTFR|Rediffusion|Inédit)\)"#] {
            s = s.replacingOccurrences(of: rx, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// seuls les films et les séries passent par TMDB (le journal, la météo, le sport en direct n'y sont pas)
    nonisolated static func eligible(_ p: Program) -> Bool {
        let c = TitleTools.fold(p.cat)
        guard c.range(of: #"film|serie|feuilleton|telefilm|movie|series|sitcom|animation|dessin anime"#, options: .regularExpression) != nil else { return false }
        return c.range(of: #"journal|info|meteo|sport|magazine|jeu|debat|talk"#, options: .regularExpression) == nil
    }

    func image(_ p: Program) async -> String? {
        guard TmdbProgram.eligible(p), let key = TmdbKey.value else { return nil }
        let title = TmdbProgram.core(p.title)
        guard title.count >= 2 else { return nil }
        let k = "t:" + TitleTools.fold(title)
        // mémorisé : trouvé (30 jours) ou introuvable (7 jours)
        let cached: (String, Int)? = await Database.shared.read { db in
            var out: (String, Int)?
            db.query("SELECT url, at FROM progimg WHERE k=?", [k]) { r in out = (r.str(0), r.int(1)) }
            return out
        }
        let now = Int(Date().timeIntervalSince1970)
        if let c = cached, now - c.1 < (c.0.isEmpty ? 7 : 30) * 86400 { return c.0.isEmpty ? nil : c.0 }
        while running >= 3 { try? await Task.sleep(nanoseconds: 150_000_000) }
        running += 1
        defer { running -= 1 }
        let tv = TitleTools.fold(p.cat).range(of: #"serie|feuilleton|sitcom|series"#, options: .regularExpression) != nil
        let api = TmdbAPI(key: key)
        var url = ""
        if let d = await api.get(tv ? "/search/tv" : "/search/movie", [("query", title), ("language", "fr-FR")]),
           let L = d["results"] as? [[String: Any]] {
            // le meilleur résultat doit avoir presque exactement le même titre, sinon rien (pas de fausse affiche)
            let best = L.prefix(5).map { r -> ([String: Any], Double) in
                let names = [r["title"], r["name"], r["original_title"], r["original_name"]].compactMap { $0 as? String }
                return (r, names.map { TmdbAPI.similarity($0, title) }.max() ?? 0)
            }.max { $0.1 < $1.1 }
            if let b = best, b.1 >= 0.86 {
                let path = (b.0["backdrop_path"] as? String) ?? (b.0["poster_path"] as? String) ?? ""
                if !path.isEmpty { url = Fiche.img(path, "w780") }
            }
        }
        await Database.shared.read { db in db.run("INSERT OR REPLACE INTO progimg VALUES(?,?,?)", [k, url, now]) }
        return url.isEmpty ? nil : url
    }
}
