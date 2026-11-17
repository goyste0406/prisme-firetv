import Foundation

/// Réglages généraux de PRISME (1.7.1, Réglages du simulateur). Gardés sur l'Apple TV (UserDefaults, clés « prisme.pref.* »).
/// Chaque réglage a une valeur par défaut qui reproduit le comportement d'avant : rien ne change tant qu'on n'y touche pas.
enum AppPrefs {
    private static var d: UserDefaults { .standard }
    private static func int(_ k: String, _ def: Int) -> Int { d.object(forKey: "prisme.pref." + k) as? Int ?? def }
    private static func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: "prisme.pref." + k) as? Bool ?? def }
    static func set(_ k: String, _ v: Any?) { d.set(v, forKey: "prisme.pref." + k); NotificationCenter.default.post(name: .prismePrefs, object: nil) }

    // MARK: Langues et sous-titres
    /// sous-titres français activés d'office (profil réglé sur « Comme le réglage général »)
    static var subsFR: Bool { bool("subsFR", false) }
    /// sous-titres français activés d'office quand le film n'a pas de piste audio française
    static var subsIfVO: Bool { bool("subsVO", false) }
    /// taille : 0 petite, 1 moyenne, 2 grande, 3 très grande
    static var subSize: Int { int("subSize", 1) }
    /// fond : 0 ombre, 1 bandeau sombre, 2 aucun
    static var subBack: Int { int("subBack", 0) }
    /// couleur : 0 blanc, 1 jaune
    static var subColor: Int { int("subColor", 0) }
    static let subSizes = ["Petite", "Moyenne", "Grande", "Très grande"]
    static let subBacks = ["Ombre", "Bandeau sombre", "Aucun"]
    static let subColors = ["Blanc", "Jaune"]
    /// options du moteur VLC pour l'apparence des sous-titres
    static var subOptions: [String] {
        var o = [":freetype-rel-fontsize=\([20, 16, 13, 10][max(0, min(3, subSize))])",
                 ":freetype-color=\(subColor == 1 ? 16_776_960 : 16_777_215)"]
        switch subBack {
        case 1: o += [":freetype-background-opacity=170", ":freetype-background-color=0", ":freetype-outline-thickness=0"]
        case 2: o += [":freetype-shadow-opacity=0", ":freetype-outline-thickness=0"]
        default: o += [":freetype-shadow-opacity=160", ":freetype-outline-thickness=4"]
        }
        return o
    }

    // MARK: Lecture et image
    /// qualité maximale choisie d'office : 0 la meilleure, 1 jusqu'en 1080p, 2 jusqu'en 720p
    static var maxQuality: Int { int("maxQ", 0) }
    static let qualities = ["La meilleure (4K HDR)", "Jusqu'en 1080p", "Jusqu'en 720p"]
    /// rang de qualité maximal accepté (4 = 4K, 3 = 1080p, 2 = 720p)
    static var maxRank: Int { [4, 3, 2][max(0, min(2, maxQuality))] }
    static var hwDecode: Bool { bool("hw", true) }
    /// saut des flèches gauche / droite pendant un film, en secondes
    static var skip: Int { int("skip", 10) }
    static let skips = [5, 10, 15, 30]

    // MARK: TV en direct
    static var openOnLive: Bool { bool("openLive", false) }
    /// délai avant de passer à la source suivante quand la chaîne ne démarre pas (0 = jamais)
    static var failover: Int { int("failover", 25) }
    static let failovers = [0, 5, 10, 20, 25]

    // MARK: Guide TV
    static var epgAuto: Bool { bool("epgAuto", true) }
    /// décalage horaire appliqué au guide, en heures (−3 … +3)
    static var epgShift: Int { int("epgShift", 0) }

    // MARK: Fiches
    /// fiches TMDB : 0 automatique, 1 jamais (une fiche arrive quand on l'ouvre)
    static var ficheMode: Int { int("ficheMode", 0) }

    // MARK: Contrôle parental
    static var parentalCode: String? { d.string(forKey: "prisme.pref.code") }
    static var lockSettings: Bool { bool("lock", false) && parentalCode != nil }
}

extension Notification.Name { static let prismePrefs = Notification.Name("prisme.prefs") }
