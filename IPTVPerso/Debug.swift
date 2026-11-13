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
    static var imgBase: String { arg("prisme.debug.imgBase") ?? "https://image.tmdb.org" }
}
