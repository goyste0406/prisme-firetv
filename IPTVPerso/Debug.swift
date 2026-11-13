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
    /// Historique factice du faux fournisseur « demo » : Lupin vue jusqu'à S2 · É3 (en cours), Inception à 30 %.
    @MainActor static func seedIfNeeded() {
        guard seed, demoServer != nil else { return }
        let now = Date()
        var list: [(String, WatchStore.Entry)] = []
        var t = now.addingTimeInterval(-3 * 86400)
        let lupin = "series:demo:2001", d = 45.0 * 60
        for (s, e, f) in [(1, 1, 1.0), (1, 2, 1), (1, 3, 1), (1, 4, 1), (1, 5, 1), (2, 1, 1), (2, 2, 1), (2, 3, 0.4)] {
            t = t.addingTimeInterval(3600)
            list.append((lupin + ":e" + String(format: "2001%02d%02d", s, e),
                         .init(pos: d * f, dur: d, at: t, title: "Lupin", icon: "", item: lupin, ep: "Saison \(s) · Épisode \(e)")))
        }
        list.append(("film:demo:1006", .init(pos: 148 * 60 * 0.3, dur: 148 * 60, at: now.addingTimeInterval(-7200), title: "Inception", icon: "", item: "film:demo:1006", ep: nil)))
        WatchStore.shared.debugSeed(list)
    }
}
