import XCTest

/// Visite automatique de prisme dans le simulateur Apple TV (compilation en ligne uniquement) :
/// la vraie app, un faux fournisseur local, la télécommande virtuelle, une capture d'écran à chaque étape
/// et le nom de l'élément sélectionné (pour vérifier la navigation).
final class Visite: XCTestCase {
    var app: XCUIApplication!
    let remote = XCUIRemote.shared
    var log = ""
    var dir: String { ProcessInfo.processInfo.environment["SHOTS"] ?? NSTemporaryDirectory() }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = base
    }

    let base = ["-prisme.debug.demoServer", "http://127.0.0.1:8099",
                "-prisme.debug.tmdbKey", "demo",
                "-prisme.debug.tmdbBase", "http://127.0.0.1:8099/tmdb/3",
                "-prisme.debug.imgBase", "http://127.0.0.1:8099/img",
                "-prisme.debug.itunesBase", "http://127.0.0.1:8099/itunes",
                "-prisme.debug.seed", "1"]

    /// Relance l'app directement sur un écran (fiche, rubrique) : le catalogue est déjà dans la base.
    func relaunch(_ extra: [String], wait: Double = 14) {
        app.terminate()
        app.launchArguments = base + extra
        app.launch()
        Thread.sleep(forTimeInterval: wait)
    }

    func focused() -> String {
        let e = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        guard e.exists else { return "(rien)" }
        let f = e.frame
        return "\(e.elementType.rawValue) « \(e.label) » x=\(Int(f.minX)) y=\(Int(f.minY)) w=\(Int(f.width)) h=\(Int(f.height))"
    }

    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.6)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways; add(a)
        log += name + " → " + focused() + "\n"
        try? log.write(to: URL(fileURLWithPath: dir).appendingPathComponent("focus.txt"), atomically: true, encoding: .utf8)
    }

    /// Descend jusqu'à un élément dont le nom contient l'un des textes (les rangées bougent selon l'historique de test).
    func downUntil(_ texts: [String], max: Int = 14, prefix: String) {
        for i in 1...max {
            press(.down); shot(String(format: "\(prefix)-%02d", i))
            if texts.contains(where: { focused().contains($0) }) { return }
        }
    }

    /// Diagnostic de l'écran « Qui regarde ? » (texte invisible affiché seulement dans le simulateur de test).
    func diag() { let e = app.staticTexts["prisme.diag"]; log += "   diag : " + (e.exists ? e.label : "(absent)") + "\n" }

    func press(_ b: XCUIRemote.Button, _ n: Int = 1) { for _ in 0..<n { remote.press(b); Thread.sleep(forTimeInterval: 0.45) } }

    /// Si un « Menu » de trop a renvoyé à l'écran d'accueil de l'Apple TV, on revient dans prisme.
    func back() {
        press(.menu); Thread.sleep(forTimeInterval: 2)
        if app.state != .runningForeground { log += "(retour à l'accueil tvOS : prisme relancée)\n"; app.activate(); Thread.sleep(forTimeInterval: 3) }
    }

    /// Va sur un onglet de la barre du haut (Films = 0, Séries = 1, TV = 2, Ma liste = 3, Recherche = 4, Réglages = 5).
    func tab(_ i: Int) {
        if app.state != .runningForeground { app.activate(); Thread.sleep(forTimeInterval: 3) }
        press(.up, 8)
        press(.left, 7)
        press(.right, i)
        press(.select)
        Thread.sleep(forTimeInterval: 2.5)
    }

    func testVisite() {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        app.launch()
        // import du catalogue et des fiches du faux fournisseur
        Thread.sleep(forTimeInterval: 45)
        shot("01-films-ouverture")
        downUntil(["Catégories", "Licences et sagas"], prefix: "02-films-bas")
        if focused().contains("Catégories") { press(.right) }
        // onglet « Licences et sagas » (sélectionné par OK), puis ses tuiles avec logos
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("02b-licences-onglet")
        press(.down); Thread.sleep(forTimeInterval: 1.5); shot("02c-licences-tuiles")
        press(.right, 2); Thread.sleep(forTimeInterval: 1.5); shot("02d-licences-tuiles-droite")
        press(.right, 6); shot("03-films-droite-bas")
        press(.up, 12); shot("04-films-retour-haut")

        // fiche film (bouton de la grande affiche : appui long → Voir la fiche)
        press(.up, 8); press(.down); shot("05-films-bas-depuis-barre")
        press(.down); press(.select); Thread.sleep(forTimeInterval: 3); shot("06-fiche-film")
        for i in 1...6 { press(.down); shot(String(format: "07-fiche-film-bas-%02d", i)) }
        press(.right, 3); shot("08-fiche-film-droite")
        back(); shot("09-retour-accueil-films")

        tab(1); shot("10-series-ouverture")
        for i in 1...6 { press(.down); shot(String(format: "11-series-bas-%02d", i)) }
        press(.up, 12); press(.down, 2); press(.select); Thread.sleep(forTimeInterval: 3); shot("12-fiche-serie")
        press(.right, 2); shot("13-fiche-serie-panneau")
        press(.down, 3); shot("14-fiche-serie-episodes")
        press(.right, 2); shot("15-fiche-serie-episodes-droite")
        back()

        tab(2); shot("20-tv-ouverture")
        for i in 1...6 { press(.down); shot(String(format: "21-tv-bas-%02d", i)) }
        press(.right, 6); shot("22-tv-droite")
        press(.left, 12); shot("23-tv-gauche")
        press(.up, 10); shot("24-tv-retour-barre")

        tab(3); shot("30-maliste")
        press(.down, 2); press(.up, 4); shot("31-maliste-retour-barre")

        tab(5); shot("40-reglages")
        press(.right, 4); press(.up, 6); shot("41-reglages-droite-haut")
        press(.down, 2); press(.left, 4); press(.up, 6); shot("42-reglages-gauche-haut")

        // fiche « Projet dernière chance » : focus d'ouverture, bande-annonce en fond, effet de transparence, plein écran
        relaunch(["-prisme.debug.open", "film:demo:1030"])
        shot("50-fiche-projet")
        Thread.sleep(forTimeInterval: 5); shot("50b-fiche-projet-bande-annonce-fond")
        press(.right, 3); Thread.sleep(forTimeInterval: 1.5); shot("51-fiche-projet-bouton-bande-annonce")
        press(.select); Thread.sleep(forTimeInterval: 5); shot("52-bande-annonce-plein-ecran")
        back(); shot("53-retour-fiche")
        press(.left, 3)
        for i in 1...5 { press(.down); shot(String(format: "54-fiche-projet-bas-%02d", i)) }

        // fenêtre des versions (Interstellar : 4 versions sous des noms différents chez le fournisseur)
        relaunch(["-prisme.debug.open", "film:demo:1016"])
        shot("55-fiche-interstellar")
        press(.right, 2); shot("56-bouton-version")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("57-fenetre-versions")
        press(.down); shot("58-fenetre-versions-bas")
        back(); shot("59-fenetre-versions-fermee")

        // fiche série commencée : Reprendre S2 · É3 + Résumé 60 s (sans spoiler)
        relaunch(["-prisme.debug.open", "series:demo:2001"])
        shot("60-fiche-lupin")
        press(.right); shot("61-bouton-resume")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("62-resume-60s")
        back(); shot("63-retour-fiche-lupin")

        // accueil Séries avec une série en cours (rangée Reprendre)
        relaunch(["-prisme.debug.tab", "series"])
        shot("64-series-ouverture-historique")
        for i in 1...3 { press(.down); shot(String(format: "65-series-reprendre-%02d", i)) }

        // Replay de la TV en direct
        relaunch(["-prisme.debug.tab", "live", "-prisme.debug.live", "replay"])
        shot("70-replay")
        for i in 1...3 { press(.down); shot(String(format: "71-replay-bas-%02d", i)) }
        press(.select); Thread.sleep(forTimeInterval: 3); shot("72-replay-lecture")
        back()

        // PROFILS — « Qui regarde ? » à l'ouverture (2 profils : Steven, Léa 12 ans max)
        // (l'écran choisit tout seul le profil probable au bout de 5 s : capture avant)
        relaunch(["-prisme.debug.profiles", "2"], wait: 2.6)
        diag(); shot("80-qui-regarde")
        press(.right); shot("81-qui-regarde-lea")
        press(.left); Thread.sleep(forTimeInterval: 1); shot("81b-qui-regarde-steven")
        press(.select); Thread.sleep(forTimeInterval: 3); shot("82-accueil-steven")
        // Réglages › Profils
        relaunch(["-prisme.debug.tab", "settings"])
        shot("83-reglages-profils")
        press(.down); Thread.sleep(forTimeInterval: 1); shot("83b-panneau-profils")
        press(.up); press(.left, 3); Thread.sleep(forTimeInterval: 1); shot("84-profils-focus")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("85-fiche-profil")
        for i in 1...4 { press(.down); shot(String(format: "86-fiche-profil-bas-%02d", i)) }
        press(.select); Thread.sleep(forTimeInterval: 1); shot("87-limite-age-choix")
        back(); Thread.sleep(forTimeInterval: 1); shot("88-limite-age-ferme")
        press(.down, 6); shot("89-fiche-profil-fin")
        back(); Thread.sleep(forTimeInterval: 1); shot("90-retour-liste-profils")
        // pastille du profil dans la barre du haut → fenêtre « Choisis un profil » → Léa
        press(.up, 6); press(.right, 8); Thread.sleep(forTimeInterval: 1); shot("91-pastille-barre")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("92-fenetre-profils")
        press(.down); shot("93-fenetre-lea")
        press(.select); Thread.sleep(forTimeInterval: 3); shot("94-profil-lea-actif")
        tab(3); shot("95-ma-liste-lea")
        tab(0); Thread.sleep(forTimeInterval: 3); shot("96-films-lea")
        // retour à Steven : son historique et Ma liste d'avant les profils doivent être là
        press(.up, 8); press(.right, 8); press(.select); Thread.sleep(forTimeInterval: 1.5)
        shot("96b-fenetre-depuis-lea")
        press(.up); shot("96c-fenetre-steven")
        press(.select); Thread.sleep(forTimeInterval: 3)
        shot("97-retour-steven")
        tab(3); shot("98-ma-liste-steven")
        tab(5); press(.down, 9); Thread.sleep(forTimeInterval: 1); shot("99-a-propos")
        // fiche film : pastille du profil en haut à gauche
        relaunch(["-prisme.debug.open", "film:demo:1006"])
        press(.up, 4); Thread.sleep(forTimeInterval: 1); shot("99b-fiche-pastille-profil")
    }
}
