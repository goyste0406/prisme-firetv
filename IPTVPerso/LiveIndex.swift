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
        of(clean: ChannelTools.clean(name), category: category)
    }

    /// Même décision, pour un nom déjà nettoyé (index des chaînes : chaque nom n'est nettoyé qu'une fois)
    static func of(clean c: String, category: String) -> Univers {
        let k = ChannelTools.nkey(c)
        if let u = known(k) { return u }
        let g = groupOf(category)
        if let u = g, u != .generaliste { return u }
        if let u = fromWords(ChannelTools.fold(c), group: false) { return u }
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

    /// Raison du classement (écran de diagnostic) : même ordre de décision que of(clean:category:).
    static func reason(clean c: String, category: String) -> String {
        if known(ChannelTools.nkey(c)) != nil { return "chaîne connue (liste de prisme)" }
        let g = groupOf(category)
        if let u = g, u != .generaliste { return "groupe « \(category) » chez le fournisseur" }
        if fromWords(ChannelTools.fold(c), group: false) != nil { return "un mot du nom" }
        if g != nil { return "groupe « \(category) » (régions, généralistes)" }
        return "aucun indice fiable"
    }

    /// univers d'un groupe du fournisseur (quelques centaines de groupes pour des dizaines de milliers de chaînes)
    private static let groupLock = NSLock()
    nonisolated(unsafe) private static var groupMemo: [String: Univers?] = [:]
    private static func groupOf(_ category: String) -> Univers? {
        groupLock.lock(); if let v = groupMemo[category] { groupLock.unlock(); return v }; groupLock.unlock()
        let v = fromWords(ChannelTools.fold(category), group: true)
        groupLock.lock(); groupMemo[category] = v; groupLock.unlock()
        return v
    }

    // MARK: 2–3. Mots entiers (groupe du fournisseur, puis nom) — seulement si UNE catégorie ressort

    private static let words: [(Univers, NSRegularExpression)] = [
        (.sport, ChannelTools.rx(#"\b(sports?|foot|football|soccer|rugby|tennis|golf|basket|nba|nfl|ufc|boxe|boxing|cyclisme|motorsport)\b"#)),
        (.info, ChannelTools.rx(#"\b(info|infos|news|actualites?|journal)\b"#)),
        (.cinema, ChannelTools.rx(#"\b(cinema|cine|films?|movies?)\b"#)),
        (.series, ChannelTools.rx(#"\b(series?|feuilletons?|novelas?)\b"#)),
        (.jeunesse, ChannelTools.rx(#"\b(enfants?|kids|jeunesse|junior|cartoons?|dessins? animes?|anime)\b"#)),
        (.decouverte, ChannelTools.rx(#"\b(docu|docus|documentaires?|documentary|documentaries|decouvertes?|discovery|nature|histoire|history)\b"#)),
        (.musique, ChannelTools.rx(#"\b(musiques?|music|musik|clips?|radios?|hits)\b"#)),
        (.divert, ChannelTools.rx(#"\b(divertissements?|entertainment|varietes?|humour|comedy)\b"#)),
        (.generaliste, ChannelTools.rx(#"\b(generalistes?|regionales?|regions|locales?)\b"#)),
    ]

    static func fromWords(_ s: String, group: Bool) -> Univers? {
        guard !s.isEmpty else { return nil }
        let hits = Set(words.filter { ChannelTools.has($0.1, s) }.map(\.0))
        // « Films & Séries » : deux catégories → on ne décide pas d'après ce groupe
        if hits.count == 1 { return hits.first }
        if group, hits == [.cinema, .series] { return nil }
        return nil
    }
}

enum ChannelTools {
    /// expression compilée une seule fois (la compiler à chaque appel coûtait plusieurs secondes sur 20 000 chaînes)
    static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    static func has(_ r: NSRegularExpression, _ s: String) -> Bool {
        r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
    private static let spaces = rx(#"\s{2,}"#)
    private static let q4 = rx(#"\b(4k|8k|uhd|ultra ?hd|2160)"#), q3 = rx(#"\b(fhd|1080)"#), q2 = rx(#"\b(hd|720p?)\b"#),
                       q0 = rx(#"\b(sd|low|576p?|480p?)\b"#), qm = rx(#"secours|backup|alt\b"#)

    private static let fr = Locale(identifier: "fr_FR")
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: fr)
    }
    /// Clé de comparaison : minuscules, sans accents, « + » → « plus », « & » → « et », rien que lettres et chiffres.
    static func nkey(_ s: String) -> String {
        let f = fold(s).replacingOccurrences(of: "+", with: "plus").replacingOccurrences(of: "&", with: "et")
        // rien que a–z et 0–9 (comme l'ancienne expression [^a-z0-9]+, sans la compiler à chaque fois)
        var out = String.UnicodeScalarView()
        for u in f.unicodeScalars where (u.value >= 97 && u.value <= 122) || (u.value >= 48 && u.value <= 57) { out.append(u) }
        return String(out)
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
        s = spaces.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ").trimmingCharacters(in: CharacterSet(charactersIn: " -–|:"))
        return s.count >= 1 ? s : raw
    }

    /// Qualité, pour garder la meilleure copie comme chaîne principale.
    static func quality(_ raw: String) -> Int {
        let r = fold(plain(raw))
        if has(q4, r) { return 4 }
        if has(q3, r) { return 3 }
        if has(q2, r) { return 2 }
        if has(q0, r) { return 0 }
        if has(qm, r) { return -1 }
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

    /// calcul en cours : un deuxième demandeur (page TV + favoris au même moment) attend le même résultat
    @MainActor private static var running: (String, Task<[Entry], Never>)?

    @MainActor static func all(pids: [String], version: Int) async -> [Entry] {
        let mk = pids.joined(separator: ",") + "|\(version)"
        if let m = memo, m.0 == mk { return m.1 }
        guard !pids.isEmpty else { return [] }
        if let r = running, r.0 == mk { return await r.1.value }
        let t = Task { @MainActor in await compute(pids: pids, mk: mk) }
        running = (mk, t)
        let res = await t.value
        if running?.0 == mk { running = nil }
        return res
    }

    @MainActor private static func compute(pids: [String], mk: String) async -> [Entry] {
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        let t0 = Date()
        // 1. lecture seule dans la base (rapide) ; 2. calcul HORS de la file de la base : avant, ce calcul la bloquait
        // et retardait toutes les autres pages (accueil Films, en-tête de la TV) pendant des secondes
        let rows = await Database.shared.read { db -> ([String: String], [Channel], [Identity?]) in
            var cats: [String: String] = [:], list: [Channel] = [], ids: [Identity?] = []
            db.query("SELECT pid,cid,name FROM category WHERE type='live' AND pid IN (\(ph))", pids.map { $0 as Any? }) { r in cats[r.str(0) + ":" + r.str(1)] = r.str(2) }
            db.query("SELECT pid,sid,name,num,icon,cid,epg,archive,iname,ikey,iq,iu,iv FROM live WHERE pid IN (\(ph)) ORDER BY num, name", pids.map { $0 as Any? }) { r in
                list.append(Channel(pid: r.str(0), sid: r.str(1), name: r.str(2), num: r.int(3), icon: r.str(4), cid: r.str(5), epg: r.str(6), archive: r.int(7)))
                // identité enregistrée à l'import (règles de cette version) ; sinon calculée comme avant
                if r.int(12) == rulesVersion, !r.str(9).isEmpty, let u = Univers(rawValue: r.str(11)) {
                    ids.append(Identity(name: r.str(8), key: r.str(9), q: r.int(10), u: u))
                } else { ids.append(nil) }
            }
            return (cats, list, ids)
        }
        let tRead = Date().timeIntervalSince(t0)
        let res = await Task.detached(priority: .userInitiated) { build(cats: rows.0, list: rows.1, ids: rows.2, pids: pids) }.value
        PerfLog.note("  lecture de la base : \(Int(tRead * 1000)) ms (\(rows.1.count) lignes, \(rows.2.filter { $0 != nil }.count) identités enregistrées)")
        memo = (mk, res)
        byKey = Dictionary(res.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        PerfLog.note("Index des chaînes : \(res.count) chaînes (\(res.reduce(0) { $0 + $1.sources }) sources) en \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        if Debug.demoServer != nil { dump(res) }
        return res
    }

    /// Regroupement par identité : nom nettoyé, clé et qualité calculés UNE fois par copie (et non à chaque comparaison).
    /// Version des règles (nettoyage du nom, clé, qualité, univers) : une identité enregistrée avec d'autres règles est recalculée.
    static let rulesVersion = 1

    struct Identity { let name: String; let key: String; let q: Int; let u: Univers }

    /// Identité d'une copie de chaîne, d'après son nom et le groupe du fournisseur (calculée à l'import).
    static func identity(name: String, category: String) -> Identity {
        let n = ChannelTools.clean(name)
        return Identity(name: n, key: ChannelTools.country(name) + "|" + ChannelTools.nkey(n), q: ChannelTools.quality(name),
                        u: Univers.of(clean: n, category: category))
    }

    private static func build(cats: [String: String], list: [Channel], ids: [Identity?], pids: [String]) -> [Entry] {
        struct Info { let c: Channel; let clean: String; let q: Int; let rank: Int; let u: Univers? }
        var groups: [String: [Info]] = [:], order: [String] = []
        let measure = Debug.demoServer != nil
        var tc = 0.0, tk = 0.0, tq = 0.0, tu = 0.0
        func clock() -> Double { measure ? CFAbsoluteTimeGetCurrent() : 0 }
        for (i, c) in list.enumerated() {
            let n: String, k: String, q: Int
            if i < ids.count, let id = ids[i] {
                n = id.name; k = id.key; q = id.q
            } else {
                let a = clock()
                n = ChannelTools.clean(c.name)
                let b = clock()
                k = ChannelTools.country(c.name) + "|" + ChannelTools.nkey(n)
                let d = clock()
                q = ChannelTools.quality(c.name)
                tc += b - a; tk += d - b; tq += clock() - d
            }
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(Info(c: c, clean: n, q: q, rank: pids.firstIndex(of: c.pid) ?? 99, u: i < ids.count ? ids[i]?.u : nil))
        }
        defer { if measure { PerfLog.note("  détail index : nettoyage \(Int(tc * 1000)) ms · clé \(Int(tk * 1000)) ms · qualité \(Int(tq * 1000)) ms · univers \(Int(tu * 1000)) ms") } }
        return order.compactMap { k -> Entry? in
            guard let G0 = groups[k] else { return nil }
            // même ordre que ordered(_:providerOrder:) : qualité (secours en dernier), ordre des fournisseurs, numéro
            let G = G0.count == 1 ? G0 : G0.sorted { a, b in a.q != b.q ? a.q > b.q : (a.rank != b.rank ? a.rank < b.rank : a.c.num < b.c.num) }
            let L = G.map(\.c)
            var best = L[0]
            // la copie jouée reprend le guide, le logo et le replay d'une autre copie s'il lui en manque
            if best.epg.isEmpty || best.icon.isEmpty || best.archive == 0 {
                let g = L.first { !$0.epg.isEmpty }?.epg ?? best.epg, ic = L.first { !$0.icon.isEmpty }?.icon ?? best.icon
                best = Channel(pid: best.pid, sid: best.sid, name: best.name, num: best.num, icon: best.icon.isEmpty ? ic : best.icon, cid: best.cid, epg: best.epg.isEmpty ? g : best.epg, archive: best.archive)
            }
            let n = G[0].clean
            // univers : décidé sur le nom ; à défaut, le groupe le plus précis parmi les copies
            let t1 = clock()
            // (univers de chaque copie enregistré à l'import quand il existe)
            var u = G[0].u ?? Univers.of(clean: n, category: cats[best.pid + ":" + best.cid] ?? "")
            if u == .autres || u == .generaliste {
                for x in G.dropFirst() {
                    let v = x.u ?? Univers.of(clean: n, category: cats[x.c.pid + ":" + x.c.cid] ?? "")
                    if v != .autres && v != u { if u == .autres { u = v }; break }
                }
            }
            tu += clock() - t1
            return Entry(ch: best, name: n, univers: u, copies: L, key: k)
        }
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

    /// Chaîne lancée seule (en-tête, « Commence bientôt », choix d'une source) : la liste du lecteur reprend les chaînes
    /// de son univers, pour zapper depuis le panneau Chaînes ; la copie choisie reste celle qui est jouée.
    @MainActor static func withNeighbors(_ ch: Channel) -> ([Channel], Int) {
        let k = ChannelTools.key(ch)
        guard let all = memo?.1, let e = byKey[k] else { return ([ch], 0) }
        var list = all.filter { $0.univers == e.univers }.map(\.ch)
        guard let i = list.firstIndex(where: { ChannelTools.key($0) == k }) else { return ([ch], 0) }
        list[i] = ch
        return (list, i)
    }
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
