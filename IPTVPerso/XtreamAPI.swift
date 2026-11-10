import Foundation

// MARK: - Compte

struct XtreamAccount: Codable, Equatable {
    var server: String
    var username: String
    var password: String

    /// Adresse du serveur nettoyée (ajoute http:// si absent, retire le / final).
    var baseURL: String {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/player_api.php") { s = String(s.dropLast("/player_api.php".count)) }
        return s
    }
}

enum XtreamError: LocalizedError {
    case badURL, badStatus(Int), authFailed

    var errorDescription: String? {
        switch self {
        case .badURL: return "Adresse du serveur invalide."
        case .badStatus(let code): return "Le serveur a répondu avec le code \(code)."
        case .authFailed: return "Identifiants refusés par le serveur."
        }
    }
}

// MARK: - Décodage tolérant (les serveurs Xtream mélangent texte et nombres)

struct FlexString: Codable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else if let b = try? c.decode(Bool.self) { value = b ? "1" : "0" }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

// MARK: - Modèles

struct AuthResponse: Decodable {
    struct UserInfo: Decodable {
        let auth: FlexString?
        let status: String?
        let exp_date: FlexString?
    }
    let user_info: UserInfo?
}

struct XCategory: Decodable, Identifiable {
    let category_id: FlexString
    let category_name: String?
    var id: String { category_id.value }
    var name: String { category_name ?? "Sans nom" }
}

struct LiveStream: Decodable, Identifiable {
    let stream_id: FlexString
    let name: String?
    let stream_icon: String?
    var id: String { stream_id.value }
    var displayName: String { name ?? "Chaîne \(id)" }
}

struct VodStream: Decodable, Identifiable {
    let stream_id: FlexString
    let name: String?
    let stream_icon: String?
    let container_extension: String?
    let rating: FlexString?
    var id: String { stream_id.value }
    var displayName: String { name ?? "Film \(id)" }
}

struct SeriesItem: Decodable, Identifiable {
    let series_id: FlexString
    let name: String?
    let cover: String?
    let plot: String?
    var id: String { series_id.value }
    var displayName: String { name ?? "Série \(id)" }
}

struct Episode: Decodable, Identifiable {
    let id: String
    let title: String?
    let container_extension: String?
    let episode_num: String?
    let image: String?

    private enum CodingKeys: String, CodingKey { case id, title, container_extension, episode_num, info }
    private struct Info: Decodable { let movie_image: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(FlexString.self, forKey: .id).value
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        container_extension = try? c.decodeIfPresent(String.self, forKey: .container_extension)
        episode_num = (try? c.decodeIfPresent(FlexString.self, forKey: .episode_num))?.value
        // "info" est parfois un tableau vide : on l'ignore dans ce cas
        image = (try? c.decodeIfPresent(Info.self, forKey: .info))?.movie_image
    }
}

struct SeasonGroup: Identifiable {
    let id: String
    let episodes: [Episode]
}

struct SeriesInfo: Decodable {
    let seasons: [SeasonGroup]

    private enum CodingKeys: String, CodingKey { case episodes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let dict = try? c.decode([String: [Episode]].self, forKey: .episodes) {
            seasons = dict.map { SeasonGroup(id: $0.key, episodes: $0.value) }
                .sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
        } else if let arr = try? c.decode([[Episode]].self, forKey: .episodes) {
            seasons = arr.enumerated().map { SeasonGroup(id: String($0.offset + 1), episodes: $0.element) }
        } else {
            seasons = []
        }
    }
}

// MARK: - API Xtream

struct XtreamAPI {
    let account: XtreamAccount

    private func apiURL(_ action: String?, _ params: [String: String] = [:]) -> URL? {
        guard var comps = URLComponents(string: account.baseURL + "/player_api.php") else { return nil }
        var items = [
            URLQueryItem(name: "username", value: account.username),
            URLQueryItem(name: "password", value: account.password)
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        for (k, v) in params { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        // Un "+" dans le mot de passe serait lu comme un espace par le serveur
        comps.percentEncodedQuery = comps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return comps.url
    }

    private func get<T: Decodable>(_ type: T.Type, _ action: String?, _ params: [String: String] = [:]) async throws -> T {
        guard let url = apiURL(action, params) else { throw XtreamError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw XtreamError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func authenticate() async throws {
        let response: AuthResponse
        do { response = try await get(AuthResponse.self, nil) }
        catch is DecodingError { throw XtreamError.authFailed }
        guard response.user_info?.auth?.value == "1" else { throw XtreamError.authFailed }
    }

    private func categoryParam(_ id: String?) -> [String: String] {
        id.map { ["category_id": $0] } ?? [:]
    }

    func liveCategories() async throws -> [XCategory] { try await get([XCategory].self, "get_live_categories") }
    func liveStreams(categoryID: String?) async throws -> [LiveStream] {
        try await get([LiveStream].self, "get_live_streams", categoryParam(categoryID))
    }

    func vodCategories() async throws -> [XCategory] { try await get([XCategory].self, "get_vod_categories") }
    func vodStreams(categoryID: String?) async throws -> [VodStream] {
        try await get([VodStream].self, "get_vod_streams", categoryParam(categoryID))
    }

    func seriesCategories() async throws -> [XCategory] { try await get([XCategory].self, "get_series_categories") }
    func series(categoryID: String?) async throws -> [SeriesItem] {
        try await get([SeriesItem].self, "get_series", categoryParam(categoryID))
    }
    func seriesInfo(id: String) async throws -> SeriesInfo {
        try await get(SeriesInfo.self, "get_series_info", ["series_id": id])
    }

    // MARK: URLs de lecture

    private func streamURL(_ kind: String, _ id: String, _ ext: String) -> URL? {
        let u = account.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? account.username
        let p = account.password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? account.password
        return URL(string: "\(account.baseURL)/\(kind)/\(u)/\(p)/\(id).\(ext)")
    }

    func liveURL(_ s: LiveStream, format: String) -> URL? { streamURL("live", s.id, format) }
    func movieURL(_ m: VodStream) -> URL? { streamURL("movie", m.id, m.container_extension ?? "mp4") }
    func episodeURL(_ e: Episode) -> URL? { streamURL("series", e.id, e.container_extension ?? "mp4") }
}
