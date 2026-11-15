import SwiftUI
import UIKit

// Chaînes telles que le simulateur les présente : vrai nom (sans « FR| » ni « FHD »), une seule fois chacune
// (les copies HD / SD / secours deviennent des sources de la même chaîne), et rangées par univers.

/// Catégorie FIXE d'une chaîne (TF1 = Généraliste, quel que soit le programme du moment).
/// Ordre de décision, du plus fiable au moins fiable — jamais de « ressemblance » de nom :
///  1. liste explicite des chaînes connues (nom exact, ou famille explicite : « beIN Sports 1, 2, 3 »…) ;
///  2. groupe de la chaîne chez le fournisseur, s'il désigne UNE seule catégorie (« FR | SPORTS », « FR | ENFANTS ») ;
///  3. un mot entier sans ambiguïté dans le nom (« … Sport », « … Kids », « … News ») ;
///  4. sinon « Autres » (plutôt qu'une catégorie fausse).
/// (Le regroupement selon le programme EN CE MOMENT, celui du simulateur, est une rangée à part : « En ce moment ».)
enum Univers: String, CaseIterable, Identifiable {
    case generaliste, info, sport, cinema, series, divert, jeunesse, decouverte, musique, autres
    var id: String { rawValue }
    var label: String {
        switch self {
        case .generaliste: return "Généraliste"
        case .info: return "Info"
        case .sport: return "Sport"
        case .cinema: return "Cinéma"
        case .series: return "Séries"
        case .divert: return "Divertissement"
        case .jeunesse: return "Jeunesse"
        case .decouverte: return "Découverte"
        case .musique: return "Musique"
        case .autres: return "Autres"
        }
    }
    var icon: String {
        switch self {
        case .generaliste: return "tv"
        case .cinema: return "film"
        case .series: return "play.tv"
        case .sport: return "sportscourt"
        case .info: return "newspaper"
        case .divert: return "star"
        case .jeunesse: return "face.smiling"
        case .decouverte: return "globe.europe.africa"
        case .musique: return "music.note"
        case .autres: return "ellipsis.circle"
        }
    }

    static func of(name: String, category: String) -> Univers {
        let k = ChannelTools.nkey(ChannelTools.clean(name))
        if let u = known(k) { return u }
        let g = fromWords(ChannelTools.fold(category), group: true)
        if let u = g, u != .generaliste { return u }
        if let u = fromWords(ChannelTools.fold(ChannelTools.clean(name)), group: false) { return u }
        // groupe « Régions » / « Généralistes » du fournisseur : seulement si le nom ne dit rien d'autre
        if let u = g { return u }
        return .autres
    }

    // MARK: 1. Chaînes connues (clé normalisée : minuscules, sans accents ni espaces, « + » → « plus »)

    /// Familles : la clé commence par ce préfixe (le plus long d'abord). Un préfixe qui finit par un chiffre
    /// n'accepte pas un chiffre juste après (« france2 » ne prend pas « france24 »).
    private static let families: [(String, Univers)] = {
        let g: [(Univers, [String])] = [
            (.generaliste, ["tf1", "france2", "france3", "m6", "canalplus", "tmc", "w9", "tfx", "6ter", "rmcstory", "cherie25", "nrj12", "c8", "cstar", "t18", "novo19",
                            "tv5monde", "tv5", "rtltvi", "latrois", "laune", "rtbf", "rts1", "rtsun", "rts2", "rtsdeux", "tvaplus", "tva", "noovo", "icitele", "radiocanada", "paris premiere", "parispremiere",
                            "france o", "franceo", "la1ere", "guadeloupe1ere", "martinique1ere", "reunion1ere", "guyane1ere", "mayotte1ere", "polynesie1ere", "nouvellecaledonie1ere",
                            "bbcone", "bbctwo", "bbcthree", "bbcfour", "itv1", "itv", "channel4", "channel5", "clubrtl", "tipik", "plugrtl", "tebeo", "tvrennes", "tl7", "8montblanc", "tlm", "vialocale", "canal32", "ktotv", "kto"]),
            (.info, ["bfmparis", "bfmlyon", "bfmmarseille", "bfmgrandlille", "bfmnice", "bfmalsace", "bfmtoulon", "bfmgrandlittoral", "bfmdici", "tv5mondeinfo", "ln24", "bfmtv", "bfmbusiness", "bfm2", "cnews", "lci", "franceinfo", "franceinformation", "france24", "euronews", "i24news", "lcp", "publicsenat", "lcppublicsenat", "tf1info",
                     "bloomberg", "cnn", "bbcworldnews", "bbcnews", "skynews", "aljazeera", "cnbc", "lcn", "rdi", "rtsinfo", "lequipeinfo", "africa24", "trtfrancais"]),
            (.sport, ["lequipe", "beinsports", "bein", "rmcsport", "eurosport", "canalplussport", "canalplusfoot", "canalplussport360", "canalplussportmax", "canalplusmotors", "canalplusmotogp", "canalplusformula1",
                      "infosportplus", "infosport", "equidia", "automotolachaine", "automoto", "golfplus", "golfchannel", "sportenfrance", "multisports", "dazn", "ligue1plus", "olplay", "omtv", "pstv", "tvsport",
                      "skysport", "tsn", "rds", "polsat sport", "extremesports", "fightnetwork", "trace sport", "tracesportstars", "eleven", "elevensports", "motorsporttv", "motorvision", "ufcfightpass", "nbatv", "nfl", "mlbnetwork"]),
            (.cinema, ["tf1seriesfilms", "canalpluscinema", "canalpluscinemas", "canalplusgrandecran", "canalpluspremier", "canalplusbox", "cineplus", "ocs", "tcmcinema", "tcm", "paramountchannel", "paramountnetwork",
                       "warnertv", "actionmax", "action", "polarplus", "polar", "rtl9", "cinefx", "cinema", "studiocanal", "sundancetv", "amc", "mgm", "hbo", "showtime", "starz", "cinemax", "filmo", "sonymovies", "goldmovie"]),
            (.series, ["canalplusseries", "serieclub", "13emerue", "13erue", "treizemerue", "syfy", "teva", "ab1", "abxplore", "novelas", "novelastv", "seriesplus", "serieplus", "foxlife", "universal", "tf1series",
                       "crimedistrict", "investigationdiscovery", "polarseries"]),
            (.divert, ["comedieplus", "gameone", "j one", "jone", "mcm", "rmc life", "rmclife", "m6boutique", "tfouboutique", "gongtv", "gong", "e!", "eentertainment", "tlc", "fashiontv", "ftv", "luxetv",
                       "elleplus", "bblack", "rtl2", "comedycentral", "canalplusdivertissement", "slip", "melodytv", "museum"]),
            (.jeunesse, ["gulli", "canalj", "tiji", "disneychannel", "disneyjunior", "disneyxd", "nickelodeon", "nickjr", "nickjunior", "nickteen", "cartoonnetwork", "cartoonito", "boomerang", "piwiplus", "piwi",
                         "teletoonplus", "teletoon", "boing", "mangas", "okoo", "babytv", "babyfirst", "canalpluskids", "france4", "ludikids", "toonami", "duckTV", "ducktv", "tfou", "lucky jack", "luckyjack", "mangasplus", "ginx", "kidsandme", "discoverykids"]),
            (.decouverte, ["france5", "arte", "rmcdecouverte", "planeteplus", "planete", "ushuaiatv", "ushuaia", "nationalgeographic", "natgeo", "natgeowild", "discovery", "discoveryscience", "histoiretv", "histoire",
                           "toutelhistoire", "animaux", "scienceetvie", "scienceetvietv", "voyage", "trek", "seasons", "chasseetpeche", "chasseetpechetv", "museumtv", "canalplusdocs", "canalplusdocumentaires",
                           "mytf1xtra", "lcpdocs", "warnerbrostv", "explore", "travelchannel", "historychannel", "history", "animalplanet", "zone3", "uptv"]),
            (.musique, ["mtv", "mtvhits", "mtvlive", "mcmtop", "nrjhits", "m6music", "tracelatina", "traceurban", "tracetropical", "traceafrica", "tracetv", "trace", "mezzo", "mezzolive", "melody", "rfmtv", "clubbingtv",
                        "stingray", "muzzik", "virgintv", "funradio", "nostalgie", "cherieFM", "cheriefm", "skyrock", "radio", "djazz", "bestof80", "vh1", "deluxemusic", "qmusic", "cstarhits", "rtl2musique"]),
        ]
        var out: [(String, Univers)] = []
        for (u, L) in g { for x in L { let k = ChannelTools.nkey(x); if !k.isEmpty { out.append((k, u)) } } }
        // le plus long d'abord : « tf1seriesfilms » avant « tf1 », « canalplussport » avant « canalplus »
        return out.sorted { $0.0.count > $1.0.count }
    }()

    static func known(_ k: String) -> Univers? {
        guard !k.isEmpty else { return nil }
        for (p, u) in families where k.hasPrefix(p) {
            if k.count > p.count, p.last?.isNumber == true, k[k.index(k.startIndex, offsetBy: p.count)].isNumber { continue }
            // un préfixe très court (« m6 », « w9 », « tcm ») ne vaut que suivi d'un chiffre, de « plus » ou d'une variante courante
            if p.count <= 3 && k.count > p.count {
                let rest = String(k.dropFirst(p.count))
                let family = ["ocs", "mtv"].contains(p)   // familles connues : OCS Max, OCS City…, MTV Dance…
                if !(family || rest.first?.isNumber == true || rest.hasPrefix("plus") || ["hd", "fhd", "uhd", "4k", "sd", "music", "boutique", "cinema"].contains(where: { rest.hasPrefix($0) })) { continue }
            }
            return u
        }
        return nil
    }

    // MARK: 2–3. Mots entiers (groupe du fournisseur, puis nom) — seulement si UNE catégorie ressort

    private static let words: [(Univers, String)] = [
        (.sport, #"\b(sports?|foot|football|soccer|rugby|tennis|golf|basket|nba|nfl|ufc|boxe|boxing|cyclisme|motorsport)\b"#),
        (.info, #"\b(info|infos|news|actualites?|journal)\b"#),
        (.cinema, #"\b(cinema|cine|films?|movies?)\b"#),
        (.series, #"\b(series?|feuilletons?|novelas?)\b"#),
        (.jeunesse, #"\b(enfants?|kids|jeunesse|junior|cartoons?|dessins? animes?|anime)\b"#),
        (.decouverte, #"\b(docu|docus|documentaires?|documentary|documentaries|decouvertes?|discovery|nature|histoire|history)\b"#),
        (.musique, #"\b(musiques?|music|musik|clips?|radios?|hits)\b"#),
        (.divert, #"\b(divertissements?|entertainment|varietes?|humour|comedy)\b"#),
        (.generaliste, #"\b(generalistes?|regionales?|regions|locales?)\b"#),
    ]

    static func fromWords(_ s: String, group: Bool) -> Univers? {
        guard !s.isEmpty else { return nil }
        let hits = Set(words.filter { s.range(of: $0.1, options: .regularExpression) != nil }.map(\.0))
        // « Films & Séries » : deux catégories → on ne décide pas d'après ce groupe
        if hits.count == 1 { return hits.first }
        if group, hits == [.cinema, .series] { return nil }
        return nil
    }
}

enum ChannelTools {
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }
    /// Clé de comparaison : minuscules, sans accents, « + » → « plus », « & » → « et », rien que lettres et chiffres.
    static func nkey(_ s: String) -> String {
        fold(s).replacingOccurrences(of: "+", with: "plus").replacingOccurrences(of: "&", with: "et")
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
    private static let lead = try! NSRegularExpression(pattern: #"^\s*(?:[\[(|]?\s*(?:fr|fra|france|be|ch|ca|qc|uk|us|vip|4k|hd|fhd|uhd)\s*[\])|:\-–—•·▎┃│★✦◉●_/]+\s*)+"#, options: [.caseInsensitive])
    /// « FR TF1 » : pays en majuscules suivi d'un simple espace (jamais « BE IN SPORTS »)
    private static let leadSpace = try! NSRegularExpression(pattern: #"^\s*(?:VIP\s+)?(?:FR|FRA|BE|CH|CA|QC|UK|US)\s+(?!IN\b)(?=\S)"#)
    private static let tail = try! NSRegularExpression(pattern: #"(?:\s*[\[(|\-–—]?\s*(?:fhd|uhd|ultra ?hd|hdr10?\+?|hdr|dolby(?: vision| atmos)?|hd\+?|sd|hq|lq|4k|8k|hevc|h\.?26[45]|1080[pi]?|720p?|2160p?|576p?|\d{2} ?fps|raw|backup(?: ?\d)?|secours(?: ?\d)?|alt|vip|low|multi(?:[ -]?audio)?|\(fr\)|\[fr\])\s*[\])]?)+\s*$"#, options: [.caseInsensitive])
    /// symboles décoratifs en fin de nom (« ◉ », « ★ », « Ⓢ »)
    private static let tailSymbols = try! NSRegularExpression(pattern: #"[\s◉●★☆✦✪⚡Ⓢ⓪-⓿•·|▎┃│*]+$"#)
    /// lettres en exposant (« ᴴᴰ », « ᶠᴴᴰ », « ᵁᴴᴰ », « ⁴ᴷ », « ᴿᴬᵂ ») : traduites en texte normal
    private static let superMap: [(String, String)] = [("ᵁᴴᴰ", " UHD"), ("ᶠᴴᴰ", " FHD"), ("ᴴᴰᴿ", " HDR"), ("ᴴᴰ", " HD"), ("⁴ᴷ", " 4K"), ("ᴿᴬᵂ", " RAW"), ("ˢᴰ", " SD"), ("ᴴᴱⱽᶜ", " HEVC")]
    private static let supers = try! NSRegularExpression(pattern: #"[\u1D2C-\u1D6A\u02B0-\u02FF\u2070-\u209F\u2C7D]+"#)

    static func plain(_ raw: String) -> String {
        var s = raw
        for (a, b) in superMap { s = s.replacingOccurrences(of: a, with: b) }
        return supers.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
    }

    /// Vrai nom de la chaîne : « FR| TF1 FHD » → « TF1 ».
    static func clean(_ raw: String) -> String {
        var s = plain(raw)
        s = lead.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        s = leadSpace.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        var prev = ""
        while prev != s {
            prev = s
            s = tailSymbols.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
            s = tail.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: " -–|:"))
        return s.count >= 1 ? s : raw
    }

    /// Qualité, pour garder la meilleure copie comme chaîne principale.
    static func quality(_ raw: String) -> Int {
        let r = fold(plain(raw))
        if r.range(of: #"\b(4k|8k|uhd|ultra ?hd|2160)"#, options: .regularExpression) != nil { return 4 }
        if r.range(of: #"\b(fhd|1080)"#, options: .regularExpression) != nil { return 3 }
        if r.range(of: #"\b(hd|720p?)\b"#, options: .regularExpression) != nil { return 2 }
        if r.range(of: #"\b(sd|low|576p?|480p?)\b"#, options: .regularExpression) != nil { return 0 }
        if r.range(of: #"secours|backup|alt\b"#, options: .regularExpression) != nil { return -1 }
        return 1
    }

    /// Pays indiqué devant le nom (« BE| », « CH: », « UK - ») ; rien (ou FR) = France.
    private static let leadCountry = try! NSRegularExpression(pattern: #"^\s*[\[(|]?\s*(?:vip\s*)?(fr|fra|france|be|ch|ca|qc|uk|us)\s*[\])|:\-–—•·▎┃│★✦◉●_/]"#, options: [.caseInsensitive])
    private static let leadCountrySpace = try! NSRegularExpression(pattern: #"^\s*(?:VIP\s+)?(FR|FRA|BE|CH|CA|QC|UK|US)\s+(?!IN\b)(?=\S)"#)
    static func country(_ raw: String) -> String {
        let m = leadCountry.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) ?? leadCountrySpace.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw))
        guard let m, let r = Range(m.range(at: 1), in: raw) else { return "fr" }
        let c = raw[r].lowercased()
        return c == "fra" || c == "france" ? "fr" : (c == "qc" ? "ca" : c)
    }

    /// Identité d'une chaîne : pays + vrai nom (« FR| TF1 FHD », « TF1 HEVC » et « TF1 (secours) » = la même chaîne,
    /// même si l'une n'a pas d'identifiant de guide). Restent distinctes : les régions (France 3 Alsace / Paris),
    /// les « +1 », les autres pays (BE| TF1), les chaînes aux noms différents (TF1 / TF1 Séries Films).
    static func key(_ ch: Channel) -> String {
        country(ch.name) + "|" + nkey(clean(ch.name))
    }

    /// Une chaîne par identité, la meilleure qualité d'abord ; l'ordre d'arrivée est conservé.
    /// Si la meilleure copie n'a pas d'identifiant de guide, elle reprend celui d'une autre copie de la même chaîne.
    static func dedupe(_ list: [Channel]) -> [Channel] {
        var best: [String: Channel] = [:], guide: [String: String] = [:], order: [String] = []
        for c in list {
            let k = key(c)
            if guide[k] == nil, !c.epg.isEmpty { guide[k] = c.epg }
            if let b = best[k] { if quality(c.name) > quality(b.name) { best[k] = c } } else { best[k] = c; order.append(k) }
        }
        return order.compactMap { k in
            guard let c = best[k] else { return nil }
            if c.epg.isEmpty, let g = guide[k] { return Channel(pid: c.pid, sid: c.sid, name: c.name, num: c.num, icon: c.icon, cid: c.cid, epg: g, archive: c.archive) }
            return c
        }
    }

    /// Nombre de sources (copies) d'une chaîne dans une liste.
    static func sources(_ ch: Channel, in list: [Channel]) -> Int {
        let k = key(ch); return list.filter { key($0) == k }.count
    }
}

/// Toutes les chaînes des fournisseurs actifs, sans doublon, avec leur univers (gardé en mémoire par version du catalogue).
/// Une chaîne = une identité (pays + vrai nom) avec TOUTES ses copies chez TOUS les fournisseurs actifs (« sources ») :
/// différentes qualités (720p, 1080p, 4K…), différents fournisseurs. La meilleure est jouée d'abord, les autres restent
/// accessibles (choix de la source, bascule automatique si la première ne répond pas).
enum LiveIndex {
    struct Entry: Identifiable, Hashable {
        /// copie jouée par défaut (meilleure qualité, avec un identifiant de guide)
        let ch: Channel
        let name: String
        let univers: Univers
        /// toutes les copies, la meilleure d'abord
        let copies: [Channel]
        let key: String
        var sources: Int { copies.count }
        var id: String { ch.id }
    }
    private static var memo: (String, [Entry])?
    /// dernière liste construite, par identité (lecture depuis le fil principal seulement)
    nonisolated(unsafe) private(set) static var byKey: [String: Entry] = [:]

    /// Ordre des sources : qualité (secours en dernier), puis l'ordre des fournisseurs dans les réglages.
    static func ordered(_ L: [Channel], providerOrder: [String]) -> [Channel] {
        func rank(_ c: Channel) -> Int { providerOrder.firstIndex(of: c.pid) ?? 99 }
        return L.sorted { a, b in
            let qa = ChannelTools.quality(a.name), qb = ChannelTools.quality(b.name)
            return qa != qb ? qa > qb : (rank(a) != rank(b) ? rank(a) < rank(b) : a.num < b.num)
        }
    }

    @MainActor static func all(pids: [String], version: Int) async -> [Entry] {
        let mk = pids.joined(separator: ",") + "|\(version)"
        if let m = memo, m.0 == mk { return m.1 }
        guard !pids.isEmpty else { return [] }
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        let t0 = Date()
        let res = await Database.shared.read { db -> [Entry] in
            var cats: [String: String] = [:]
            db.query("SELECT pid,cid,name FROM category WHERE type='live' AND pid IN (\(ph))", pids.map { $0 as Any? }) { r in cats[r.str(0) + ":" + r.str(1)] = r.str(2) }
            var groups: [String: [Channel]] = [:], order: [String] = []
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive FROM live WHERE pid IN (\(ph)) ORDER BY num, name", pids.map { $0 as Any? }) { r in
                let c = Channel(pid: r.str(0), sid: r.str(1), name: r.str(2), num: r.int(3), icon: r.str(4), cid: r.str(5), epg: r.str(6), archive: r.int(7))
                let k = ChannelTools.key(c)
                if groups[k] == nil { order.append(k) }
                groups[k, default: []].append(c)
            }
            return order.compactMap { k -> Entry? in
                guard let L0 = groups[k] else { return nil }
                let L = ordered(L0, providerOrder: pids)
                var best = L[0]
                // la copie jouée reprend le guide, le logo et le replay d'une autre copie s'il lui en manque
                if best.epg.isEmpty || best.icon.isEmpty || best.archive == 0 {
                    let g = L.first { !$0.epg.isEmpty }?.epg ?? best.epg, ic = L.first { !$0.icon.isEmpty }?.icon ?? best.icon
                    best = Channel(pid: best.pid, sid: best.sid, name: best.name, num: best.num, icon: best.icon.isEmpty ? ic : best.icon, cid: best.cid, epg: best.epg.isEmpty ? g : best.epg, archive: best.archive)
                }
                let n = ChannelTools.clean(best.name)
                // univers : décidé sur le nom ; à défaut, le groupe le plus précis parmi les copies
                var u = Univers.of(name: n, category: cats[best.pid + ":" + best.cid] ?? "")
                if u == .autres || u == .generaliste {
                    for c in L.dropFirst() {
                        let v = Univers.of(name: n, category: cats[c.pid + ":" + c.cid] ?? "")
                        if v != .autres && v != u { if u == .autres { u = v }; break }
                    }
                }
                return Entry(ch: best, name: n, univers: u, copies: L, key: k)
            }
        }
        memo = (mk, res)
        byKey = Dictionary(res.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        PerfLog.note("Index des chaînes : \(res.count) chaînes (\(res.reduce(0) { $0 + $1.sources }) sources) en \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        if Debug.demoServer != nil { dump(res) }
        return res
    }

    /// Chaînes enregistrées (favoris, récentes) retrouvées par leur IDENTITÉ chez les fournisseurs actifs :
    /// un favori enregistré chez un fournisseur désactivé ou supprimé reste affiché s'il existe chez un autre.
    @MainActor static func resolve(ids: [String]) async -> [Channel] {
        guard !ids.isEmpty else { return [] }
        let st = ProviderStore.shared
        if byKey.isEmpty { _ = await all(pids: st.active.map(\.id), version: st.catalogVersion) }
        let rows = await LiveStore.channels(ids: ids)
        var keys: [String: String] = [:]
        for c in rows { keys[c.id] = ChannelTools.key(c) }
        LivePrefs.shared.remember(keys)
        var out: [Channel] = [], seen = Set<String>()
        for id in ids {
            guard let k = keys[id] ?? LivePrefs.shared.knownKey(id), seen.insert(k).inserted, let e = byKey[k] else { continue }
            out.append(e.ch)
        }
        return out
    }

    @MainActor static func entry(_ ch: Channel) -> Entry? { byKey[ChannelTools.key(ch)] }
}

extension ChannelTools {
    /// Étiquette de qualité lue dans le nom chez le fournisseur ; nil si le nom n'en dit rien.
    static func qualityLabel(_ raw: String) -> String? {
        switch quality(raw) { case 4: return "4K"; case 3: return "1080p"; case 2: return "720p"; case 0: return "SD"; case -1: return "secours"; default: return nil }
    }
}

extension LiveIndex {
    /// Simulateur de test seulement : écrit le classement obtenu (catégorie, copies, identité, nom chez le fournisseur)
    /// dans Documents/classement-tv.txt, récupéré par la visite automatique pour vérification ligne par ligne.
    static func dump(_ L: [Entry]) {
        let lines = L.sorted { ($0.univers.label, $0.name) < ($1.univers.label, $1.name) }
            .map { e in "\(e.univers.label)\t\(e.sources) copie(s)\t\(e.key)\t\(e.ch.name)\tguide=\(e.ch.epg)\tsources: " + e.copies.map { "\($0.pid)/\($0.name)" }.joined(separator: " | ") }
        let txt = "\(L.count) chaînes après dédoublonnage\n" + lines.joined(separator: "\n") + "\n"
        if let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? txt.write(to: d.appendingPathComponent("classement-tv.txt"), atomically: true, encoding: .utf8)
        }
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
