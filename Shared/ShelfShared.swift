import Foundation

/// Top Shelf (lot 6) : ce que PRISME prépare pour le haut de l'écran d'accueil de l'Apple TV.
/// Fichier commun à l'appli et à son module Top Shelf : PRISME écrit la liste des cartes et leurs images dans une
/// « boîte partagée » (groupe d'applis) ; le module ne fait que la relire. Aucune donnée personnelle n'y est copiée
/// en dehors de ces cartes.
enum ShelfShared {
    /// nom demandé à la compilation ; Apparition peut le modifier en signant (suffixe d'équipe) : on lit alors le vrai
    /// nom dans le profil d'installation embarqué
    static let requestedGroup = "group.com.steven.iptvperso"

    struct Feed: Codable, Equatable {
        /// titre de la rangée (« Steven · ce que prisme te propose »)
        var title: String
        var items: [Item]
        var at: Date
    }
    struct Item: Codable, Equatable {
        var id: String
        /// nom du fichier image dans le dossier partagé (carte déjà dessinée, comme le simulateur)
        var image: String
        /// prisme://play?… (lecture) et prisme://open?… (fiche)
        var play: String
        var open: String
        /// OK sur la carte : lecture directe (reprises) ou fiche (propositions), comme le simulateur
        var okPlays: Bool
        /// pour l'accessibilité et le journal de test
        var label: String
    }

    /// groupes d'applis autorisés par la signature (profil d'installation embarqué dans ce paquet)
    static func signedGroups(bundle: Bundle = .main) -> [String] {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return [] }
        // le profil est un message signé : le plist est lisible en clair entre <?xml … et </plist>
        guard let s = String(data: data, encoding: .isoLatin1),
              let a = s.range(of: "<?xml"), let b = s.range(of: "</plist>", range: a.upperBound..<s.endIndex),
              let pd = String(s[a.lowerBound..<b.upperBound]).data(using: .isoLatin1),
              let pl = try? PropertyListSerialization.propertyList(from: pd, format: nil) as? [String: Any],
              let ent = pl["Entitlements"] as? [String: Any] else { return [] }
        return ent["com.apple.security.application-groups"] as? [String] ?? []
    }

    /// la boîte partagée réellement disponible (nil si la signature ne l'a pas accordée)
    static var groupID: String? {
        var names = signedGroups().filter { $0.contains("iptvperso") }
        if names.isEmpty, let host = hostBundle() { names = signedGroups(bundle: host).filter { $0.contains("iptvperso") } }
        names.append(requestedGroup)
        return names.first { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    }

    /// le module Top Shelf est rangé dans PRISME.app/PlugIns/ : son profil peut manquer, celui de l'appli sert alors
    private static func hostBundle() -> Bundle? {
        let u = Bundle.main.bundleURL
        guard u.pathExtension == "appex" else { return nil }
        return Bundle(url: u.deletingLastPathComponent().deletingLastPathComponent())
    }

    static var folder: URL? {
        guard let g = groupID, let c = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) else { return nil }
        let d = c.appendingPathComponent("TopShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func read(from dir: URL? = folder) -> Feed? {
        guard let dir, let d = try? Data(contentsOf: dir.appendingPathComponent("feed.json")) else { return nil }
        return try? JSONDecoder().decode(Feed.self, from: d)
    }

    static func write(_ f: Feed, to dir: URL) {
        guard let d = try? JSONEncoder().encode(f) else { return }
        try? d.write(to: dir.appendingPathComponent("feed.json"), options: .atomic)
    }
}
