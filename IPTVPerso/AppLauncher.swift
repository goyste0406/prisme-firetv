import UIKit

/// Ouvrir un film ou une série dans une autre app (Netflix, Disney+…).
/// Du meilleur au plus simple : lien direct vers le titre (identifiant trouvé sur Wikidata à partir de l'id TMDB),
/// puis l'app Apple TV sur le titre (elle propose « Ouvrir dans … »), puis l'app du service sur son accueil.
enum AppLauncher {
    struct App { let key: String; let match: String; let name: String; let home: String; let direct: ((String, Bool) -> String)? }
    static let apps: [App] = [
        App(key: "nf", match: "netflix", name: "Netflix", home: "nflx://", direct: { id, _ in "nflx://www.netflix.com/title/\(id)" }),
        App(key: "dp", match: "disney", name: "Disney+", home: "disneyplus://", direct: { id, tv in "https://www.disneyplus.com/\(tv ? "series" : "movies")/\(id)" }),
        App(key: "pv", match: "amazon|prime video", name: "Prime Video", home: "aiv://", direct: { id, _ in "https://app.primevideo.com/detail?gti=\(id)" }),
        App(key: "atv", match: "^apple tv", name: "Apple TV", home: "videos://", direct: { id, tv in "https://tv.apple.com/fr/\(tv ? "show" : "movie")/\(id)" }),
        App(key: "cp", match: "canal", name: "Canal+", home: "mycanal://", direct: nil),
        App(key: "mx", match: "^max|hbo", name: "Max", home: "hbomax://", direct: nil),
        App(key: "pp", match: "paramount", name: "Paramount+", home: "paramountplus://", direct: nil),
        App(key: "yt", match: "youtube", name: "YouTube", home: "youtube://", direct: nil),
        App(key: "ar", match: "arte", name: "ARTE", home: "arte://", direct: nil),
        App(key: "ft", match: "france ?tv|france\\.tv", name: "france.tv", home: "francetv://", direct: nil),
        App(key: "m6", match: "m6|6play", name: "M6+", home: "m6plus://", direct: nil),
        App(key: "tf", match: "tf1", name: "TF1+", home: "tf1plus://", direct: nil),
        App(key: "rk", match: "rakuten", name: "Rakuten TV", home: "rakutentv://", direct: nil),
    ]
    static func app(for providerName: String) -> App? {
        apps.first { providerName.range(of: $0.match, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private static var wdCache: [String: [String: String]] = [:]

    /// Identifiants du titre chez les services (Wikidata, gratuit, sans clé).
    static func ids(tmdb: Int, tv: Bool) async -> [String: String] {
        let k = (tv ? "t" : "m") + String(tmdb)
        if let c = wdCache[k] { return c }
        let q = """
        SELECT ?nf ?dp ?pv ?atv WHERE { ?i wdt:\(tv ? "P4983" : "P4947") "\(tmdb)" . OPTIONAL{?i wdt:P1874 ?nf} OPTIONAL{?i wdt:\(tv ? "P7596" : "P7595") ?dp} OPTIONAL{?i wdt:P8055 ?pv} OPTIONAL{?i wdt:\(tv ? "P9751" : "P9586") ?atv} } LIMIT 1
        """
        var c = URLComponents(string: "https://query.wikidata.org/sparql")
        c?.queryItems = [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "query", value: q)]
        var out: [String: String] = [:]
        if let url = c?.url {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            req.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
            if let res = try? await URLSession.shared.data(for: req),
               let j = try? JSONSerialization.jsonObject(with: res.0) as? [String: Any],
               let b = ((j["results"] as? [String: Any])?["bindings"] as? [[String: Any]])?.first {
                for key in ["nf", "dp", "pv", "atv"] { if let v = (b[key] as? [String: Any])?["value"] as? String { out[key] = v } }
            }
        }
        wdCache[k] = out
        return out
    }

    /// Ouvre le titre ; renvoie ce qui s'est passé, pour l'afficher.
    @MainActor
    static func open(providerName: String, tmdb: Int, tv: Bool) async -> String {
        let a = app(for: providerName)
        let ids = await ids(tmdb: tmdb, tv: tv)
        var tries: [(String, String)] = []
        if let a, let d = a.direct, let id = ids[a.key] { tries.append((d(id, tv), "\(a.name) s'ouvre sur le titre")) }
        if a?.key != "atv", let id = ids["atv"] { tries.append(("https://tv.apple.com/fr/\(tv ? "show" : "movie")/\(id)", "L'app Apple TV s'ouvre sur le titre et propose \(a?.name ?? providerName)")) }
        if let a { tries.append((a.home, "\(a.name) s'ouvre : cherche le titre dans l'app")) }
        for (u, msg) in tries {
            guard let url = URL(string: u) else { continue }
            if await UIApplication.shared.open(url) { return msg }
        }
        return "\(providerName) n'est pas installée sur cette Apple TV"
    }
}
