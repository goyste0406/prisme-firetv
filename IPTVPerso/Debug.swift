import Foundation

/// Réglages de test, lus UNIQUEMENT dans les arguments de lancement (jamais enregistrés sur l'appareil).
/// Ils servent au simulateur Apple TV de la compilation en ligne : un faux fournisseur et une fausse TMDB locales
/// permettent de lancer la vraie app, de la piloter à la télécommande et d'en faire des captures d'écran.
/// Installée avec Apparition, l'app n'a jamais ces arguments : rien ne change pour toi.
enum Debug {
    private static func arg(_ k: String) -> String? {
        guard let v = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[k] as? String, !v.isEmpty else { return nil }
        return v
    }
    static var demoServer: String? { arg("prisme.debug.demoServer") }
    static var tmdbKey: String? { arg("prisme.debug.tmdbKey") }
    static var tmdbBase: String { arg("prisme.debug.tmdbBase") ?? "https://api.themoviedb.org/3" }
    static var itunesBase: String { arg("prisme.debug.itunesBase") ?? "https://itunes.apple.com" }
    /// ouvrir directement une fiche (« film:demo:1030 ») au lancement
    static var open: String? { arg("prisme.debug.open") }
    /// rubrique de la TV en direct au lancement (« replay »)
    static var liveSection: String? { arg("prisme.debug.live") }
    /// onglet au lancement (« live », « series »…)
    static var tab: String? { arg("prisme.debug.tab") }
    /// historique de visionnage factice (pour voir « Reprendre », « Résumé 60 s »)
    static var seed: Bool { arg("prisme.debug.seed") == "1" }
    static var imgBase: String { arg("prisme.debug.imgBase") ?? "https://image.tmdb.org" }
}

extension Debug {
    /// nombre de profils de test (« 2 » : ajoute Léa, 12 ans max)
    static var profiles: String? { arg("prisme.debug.profiles") }
    /// « Qui regarde ? » : pas de choix automatique au bout de 5 s (la visite de test met plus de 5 s à prendre sa capture)
    static var whoHold: Bool { arg("prisme.debug.whoHold") == "1" }

    /// Simule une installation 1.5.3 (avant les profils) : historique et Ma liste écrits dans les clés d'origine,
    /// AVANT le chargement des profils. Sert à vérifier que la migration les rattache bien au profil de Steven.
    static func legacySeedBeforeStores() {
        guard seed, demoServer != nil, UserDefaults.standard.object(forKey: "prisme.profiles") == nil else { return }
        let now = Date()
        var e: [String: WatchStore.Entry] = [:]
        var t = now.addingTimeInterval(-3 * 86400)
        let lupin = "series:demo:2001", d = 45.0 * 60
        for (s, n, f) in [(1, 1, 1.0), (1, 2, 1), (1, 3, 1), (1, 4, 1), (1, 5, 1), (2, 1, 1), (2, 2, 1), (2, 3, 0.4)] {
            t = t.addingTimeInterval(3600)
            e[lupin + ":e" + String(format: "2001%02d%02d", s, n)] = .init(pos: d * f, dur: d, at: t, title: "Lupin", icon: "", item: lupin, ep: "Saison \(s) · Épisode \(n)")
        }
        e["film:demo:1006"] = .init(pos: 148 * 60 * 0.3, dur: 148 * 60, at: now.addingTimeInterval(-7200), title: "Inception", icon: "", item: "film:demo:1006", ep: nil)
        e["film:demo:1001"] = .init(pos: 155 * 60, dur: 155 * 60, at: now.addingTimeInterval(-86400), title: "Dune", icon: "", item: "film:demo:1001", ep: nil)
        if let data = try? JSONEncoder().encode(e) { UserDefaults.standard.set(data, forKey: "prisme.watch") }
        UserDefaults.standard.set(["film:demo:1016", "series:demo:2004", "film:demo:1030"], forKey: "prisme.media.favs")
    }

    @MainActor static func seedIfNeeded() {
        guard seed, demoServer != nil else { return }
        if profiles == "2", ProfileStore.shared.profiles.count == 1, let p = ProfileStore.shared.add() {
            var x = p; x.name = "Léa"; x.color = 1; x.maxAge = 12; x.bed = 22 * 60 + 30; x.lang = "VOSTFR"
            ProfileStore.shared.update(x)
        }
    }
}
