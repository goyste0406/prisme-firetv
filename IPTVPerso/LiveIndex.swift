import SwiftUI
import UIKit

// Chaînes telles que le simulateur les présente : vrai nom (sans « FR| » ni « FHD »), une seule fois chacune
// (les copies HD / SD / secours deviennent des sources de la même chaîne), et rangées par univers.

/// Univers de la TV en direct (colonne d'icônes et « Explorer par univers » du simulateur).
enum Univers: String, CaseIterable, Identifiable {
    case cinema, series, sport, info, divert, jeunesse, decouverte
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cinema: return "Cinéma"
        case .series: return "Séries"
        case .sport: return "Sport"
        case .info: return "Info"
        case .divert: return "Divertissement"
        case .jeunesse: return "Jeunesse"
        case .decouverte: return "Découverte"
        }
    }
    var icon: String {
        switch self {
        case .cinema: return "film"
        case .series: return "play.tv"
        case .sport: return "sportscourt"
        case .info: return "newspaper"
        case .divert: return "star"
        case .jeunesse: return "face.smiling"
        case .decouverte: return "globe.europe.africa"
        }
    }
    /// Mots repérés dans le nom de la chaîne (puis dans celui de sa catégorie chez le fournisseur).
    var pattern: String {
        switch self {
        case .sport: return #"sport|bein|eurosport|equipe|rmc sport|foot|golf|tennis|rugby|f1\b|moto|infosport|automoto|dazn"#
        case .info: return #"info|news|bfm|cnews|lci\b|euronews|lcp|public s|france 24|tv5|i24|bloomberg|cnn"#
        case .jeunesse: return #"jeunesse|enfant|kids|junior|gulli|disney|canal j|tiji|nickelodeon|nick|cartoon|boomerang|piwi|teletoon|baby|boing|mangas"#
        case .decouverte: return #"docu|decouverte|discovery|national geo|nat geo|histoire|planete|ushuaia|science|animaux|voyage|trek|chasse|peche|france 5|arte|toute l.histoire|seasons|museum|explore"#
        case .cinema: return #"cine|cinema|film|ocs|tcm|paramount|action\b|polar|warner|sundance|frisson|emotion|premier|famiz|club"#
        case .series: return #"serie|series|syfy|13e rue|tmc|tfx|w9|6ter|serieclub|novelas|comedie\+|rtl9|ab1|teva|chérie|cherie"#
        case .divert: return #"."#
        }
    }
    /// Ordre de reconnaissance : le plus précis d'abord, « Divertissement » quand rien ne correspond.
    static let detection: [Univers] = [.sport, .info, .jeunesse, .decouverte, .cinema, .series, .divert]
    static func of(name: String, category: String) -> Univers {
        let n = ChannelTools.fold(name), c = ChannelTools.fold(category)
        for u in detection where u != .divert { if n.range(of: u.pattern, options: .regularExpression) != nil { return u } }
        for u in detection where u != .divert { if c.range(of: u.pattern, options: .regularExpression) != nil { return u } }
        return .divert
    }
}

enum ChannelTools {
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }
    private static let lead = try! NSRegularExpression(pattern: #"^\s*(?:[\[(|]?\s*(?:fr|fra|france|be|ch|ca|qc|uk|us|vip|4k|hd|fhd|uhd)\s*[\])|:\-–]+\s*)+"#, options: [.caseInsensitive])
    private static let tail = try! NSRegularExpression(pattern: #"(?:\s*[\[(|\-–]?\s*(?:fhd|uhd|hd|sd|4k|hevc|h\.?26[45]|1080p?|720p?|2160p?|50 ?fps|60 ?fps|raw|backup|secours|alt|vip|low|multi|\+1)\s*[\])]?)+\s*$"#, options: [.caseInsensitive])
    private static let supers = try! NSRegularExpression(pattern: "[ᴴᴰᶠᵁ⁴ᴷˢ³⁴]+")

    /// Vrai nom de la chaîne : « FR| TF1 FHD » → « TF1 ».
    static func clean(_ raw: String) -> String {
        var s = supers.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: " ")
        s = lead.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        var prev = ""
        while prev != s { prev = s; s = tail.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "") }
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: " -–|:"))
        return s.count >= 1 ? s : raw
    }

    /// Qualité, pour garder la meilleure copie comme chaîne principale.
    static func quality(_ raw: String) -> Int {
        let r = fold(raw)
        if r.range(of: #"\b(4k|uhd|2160)"#, options: .regularExpression) != nil { return 4 }
        if r.range(of: #"\b(fhd|1080)"#, options: .regularExpression) != nil { return 3 }
        if r.range(of: #"\b(hd|720)\b"#, options: .regularExpression) != nil { return 2 }
        if r.range(of: #"\b(sd|low)\b"#, options: .regularExpression) != nil { return 0 }
        if r.range(of: #"secours|backup|alt\b"#, options: .regularExpression) != nil { return -1 }
        return 1
    }

    /// Identité fiable d'une chaîne : son vrai nom ET son identifiant de guide.
    /// Deux chaînes aux noms proches mais différents (France 3 Alsace / France 3 Paris) restent séparées.
    static func key(_ ch: Channel) -> String {
        fold(clean(ch.name)).replacingOccurrences(of: #"[^a-z0-9+]+"#, with: "", options: .regularExpression) + "|" + ch.epg.lowercased()
    }

    /// Une chaîne par identité, la meilleure qualité d'abord ; l'ordre d'arrivée est conservé.
    static func dedupe(_ list: [Channel]) -> [Channel] {
        var best: [String: Channel] = [:], order: [String] = []
        for c in list {
            let k = key(c)
            if let b = best[k] { if quality(c.name) > quality(b.name) { best[k] = c } } else { best[k] = c; order.append(k) }
        }
        return order.compactMap { best[$0] }
    }

    /// Nombre de sources (copies) d'une chaîne dans une liste.
    static func sources(_ ch: Channel, in list: [Channel]) -> Int {
        let k = key(ch); return list.filter { key($0) == k }.count
    }
}

/// Toutes les chaînes des fournisseurs actifs, sans doublon, avec leur univers (gardé en mémoire par version du catalogue).
enum LiveIndex {
    struct Entry: Identifiable, Hashable { let ch: Channel; let name: String; let univers: Univers; let sources: Int; var id: String { ch.id } }
    private static var memo: (String, [Entry])?

    static func all(pids: [String], version: Int) async -> [Entry] {
        let mk = pids.joined(separator: ",") + "|\(version)"
        if let m = memo, m.0 == mk { return m.1 }
        guard !pids.isEmpty else { return [] }
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        let res = await Database.shared.read { db -> [Entry] in
            var cats: [String: String] = [:]
            db.query("SELECT pid,cid,name FROM category WHERE type='live' AND pid IN (\(ph))", pids.map { $0 as Any? }) { r in cats[r.str(0) + ":" + r.str(1)] = r.str(2) }
            var chans: [Channel] = []
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE pid IN (\(ph)) ORDER BY num, name", pids.map { $0 as Any? }) { r in
                chans.append(Channel(pid: r.str(0), sid: r.str(1), name: r.str(2), num: r.int(3), icon: r.str(4), cid: r.str(5), epg: r.str(6), archive: r.int(7)))
            }
            var count: [String: Int] = [:]
            for c in chans { count[ChannelTools.key(c), default: 0] += 1 }
            return ChannelTools.dedupe(chans).map { c in
                let n = ChannelTools.clean(c.name)
                return Entry(ch: c, name: n, univers: Univers.of(name: n, category: cats[c.pid + ":" + c.cid] ?? ""), sources: count[ChannelTools.key(c)] ?? 1)
            }
        }
        memo = (mk, res)
        return res
    }
}

/// Pastille de chaîne (simulateur) : le logo de la chaîne s'il se charge, sinon son nom sur sa couleur.
struct ChannelChip: View {
    let name: String
    let icon: String
    var height: CGFloat = 40
    @State private var logo: UIImage?
    var body: some View {
        Group {
            if let logo {
                Image(uiImage: logo).resizable().scaledToFit().padding(5)
                    .frame(width: height * 1.9, height: height)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                Text(name).font(P.font(height * 0.42, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 10).frame(height: height)
                    .background(Color(hue: P.hue(name), saturation: 0.62, brightness: 0.62), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .task(id: icon) {
            guard !icon.isEmpty else { logo = nil; return }
            logo = await ImageLoader.load(icon, maxPixel: 240)
        }
    }
}
