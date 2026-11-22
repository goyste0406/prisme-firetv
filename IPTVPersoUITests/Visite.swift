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
                "-prisme.debug.itunesBase", "http://127.0.0.1:8099/itunes", "-prisme.debug.xfrURL", "http://127.0.0.1:8099/xfr/xmltv_tnt.xml.gz",
                "-prisme.debug.seed", "1", "-prisme.debug.bgTrailer", "off"]

    /// Relance l'app directement sur un écran (fiche, rubrique) : le catalogue est déjà dans la base.
    func relaunch(_ extra: [String], wait: Double = 14, trailer: Bool = false) {
        app.terminate()
        app.launchArguments = (trailer ? Array(base.dropLast(2)) : base) + extra
        app.launch()
        Thread.sleep(forTimeInterval: wait)
    }

    func focused() -> String {
        let e = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        guard e.exists else { return "(rien)" }
        let f = e.frame
        return "\(e.elementType.rawValue) « \(e.label) » x=\(Int(f.minX)) y=\(Int(f.minY)) w=\(Int(f.width)) h=\(Int(f.height))"
    }

    /// `focus: false` pendant une lecture vidéo : lire l'arbre des éléments peut alors dépasser le délai du test.
    func shot(_ name: String, focus: Bool = true) {
        Thread.sleep(forTimeInterval: 1.6)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways; add(a)
        log += name + " → " + (focus ? focused() : "(lecture en cours, non lu)") + "\n"
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
        // visite partielle (lancement manuel avec « seulement = lecteur ») : uniquement le lecteur
        if ProcessInfo.processInfo.environment["ONLY"] == "lecteur" { lecteur(); lecteurTV(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "serie" { ficheSerie(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "tv" { tvUnivers(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "nav" { navigation(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "multi" { multi(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "perf" { perf(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "fournisseurs" { fournisseurs(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "fiches" { fiches(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "geant" { geant(port: "8096", tag: "G"); geant(port: "8095", tag: "K"); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "tvlecteur" { lecteurTV(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "tvcrash" { tvCrash(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "gouts" { gouts(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "langue" { langue(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "reglages" { reglages(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "dit" { quATilDit(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "sauvegarde" { sauvegarde(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "accueil" { accueils(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "duo" { duo(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "sources" { sources(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "envoi" { envoi(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "finserie" { finSerie(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "finfilm" { finFilm(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot1" { lot1(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot2" { lot2(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot3" { lot3(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot4" { lot4(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot4n" { lot4n(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "lot3g" { lot3g(); return }
        if ProcessInfo.processInfo.environment["ONLY"] == "tvidle" {
            // TV en direct au lancement avec deux fournisseurs, 150 s sans aucune interaction, puis une capture
            relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.tab", "live"], wait: 150)
            shot("I1-apres-150s"); press(.down); Thread.sleep(forTimeInterval: 2); shot("I2-bas"); return
        }
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
        press(.up, 12); press(.down, 3); press(.select); Thread.sleep(forTimeInterval: 3); shot("12-fiche-serie")
        press(.right, 2); shot("13-fiche-serie-panneau")
        press(.down, 3); shot("14-fiche-serie-episodes")
        press(.right, 2); shot("15-fiche-serie-episodes-droite")
        back()

        tab(2); shot("20-tv-ouverture")
        for i in 1...6 { press(.down); shot(String(format: "21-tv-bas-%02d", i)) }
        press(.right, 6); shot("22-tv-droite")
        press(.left, 12); shot("23-tv-gauche")
        press(.up, 10); shot("24-tv-retour-barre")

        tvUnivers()
        // colonne d'icônes : chaque catégorie ouvre sa grille
        press(.left, 12); shot("28-colonne")
        for i in 1...12 { press(.down); Thread.sleep(forTimeInterval: 0.6); shot(String(format: "28b-colonne-%02d", i)) }
        // OK sur une icône de la colonne : la grille de la catégorie s'affiche (Catégories du fournisseur)
        press(.select); Thread.sleep(forTimeInterval: 1.5); press(.right); Thread.sleep(forTimeInterval: 1); shot("29-grille-categorie")
        // Retour depuis une catégorie : accueil de la TV en direct ; Retour depuis l'accueil : barre du haut (sans quitter prisme)
        back(); Thread.sleep(forTimeInterval: 1); shot("29a-retour-accueil-tv")
        press(.down, 2); back(); Thread.sleep(forTimeInterval: 1); shot("29a1-retour-barre")
        // « Autres » dans la colonne
        press(.down); press(.left, 12); press(.down, 9); press(.select); Thread.sleep(forTimeInterval: 1.5); press(.right); Thread.sleep(forTimeInterval: 1); shot("29a2-grille-categorie")
        for i in 1...4 { press(.down); shot(String(format: "29b-grille-bas-%02d", i)) }
        press(.up, 8); shot("29c-grille-haut")
        back(); Thread.sleep(forTimeInterval: 1); shot("29d-retour")

        tab(3); shot("30-maliste")
        press(.down, 2); press(.up, 4); shot("31-maliste-retour-barre")

        tab(5); shot("40-reglages")
        press(.right, 4); press(.up, 6); shot("41-reglages-droite-haut")
        press(.down, 2); press(.left, 4); press(.up, 6); shot("42-reglages-gauche-haut")

        // fiche « Projet dernière chance » : focus d'ouverture, bande-annonce en fond, effet de transparence, plein écran
        relaunch(["-prisme.debug.open", "film:demo:1030"], trailer: true)
        shot("50-fiche-projet", focus: false)
        Thread.sleep(forTimeInterval: 5); shot("50b-fiche-projet-bande-annonce-fond", focus: false)
        press(.right, 3); Thread.sleep(forTimeInterval: 1.5); shot("51-fiche-projet-bouton-bande-annonce", focus: false)
        press(.select); Thread.sleep(forTimeInterval: 5); shot("52-bande-annonce-plein-ecran", focus: false)
        back(); shot("53-retour-fiche", focus: false)
        press(.left, 3)
        for i in 1...5 { press(.down); shot(String(format: "54-fiche-projet-bas-%02d", i), focus: false) }

        // fenêtre des versions (Interstellar : 4 versions sous des noms différents chez le fournisseur)
        relaunch(["-prisme.debug.open", "film:demo:1016"])
        shot("55-fiche-interstellar")
        press(.right, 2); shot("56-bouton-version")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("57-fenetre-versions")
        press(.down); shot("58-fenetre-versions-bas")
        back(); shot("59-fenetre-versions-fermee")

        // fiche « Ce soir ? » (Dune : Deuxième partie, 2 h 46) : coucher simulé dans 60 min → fin après le coucher,
        // raison « Suite de Dune » (Dune vu en entier dans l'historique de test), bouton « En 2 soirées » et sa fenêtre
        relaunch(["-prisme.debug.open", "film:demo:1000", "-prisme.debug.bedIn", "60"])
        shot("60a-ce-soir-apres-coucher")
        for _ in 0..<4 where !focused().contains("En 2 soirées") { press(.right) }
        shot("60b-bouton-en-2-soirees")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("60c-fenetre-en-2-soirees")
        press(.down); shot("60d-fenetre-en-2-soirees-bas")
        back(); shot("60e-fenetre-fermee")
        // même film avec l'heure du coucher normale du profil (23:00) : message « il te restera … » ou « après ton coucher »
        relaunch(["-prisme.debug.open", "film:demo:1000"])
        shot("60f-ce-soir-coucher-profil")
        // film court sans saga (pour voir le cas sans bouton « En 2 soirées ») : coucher dans 4 h
        relaunch(["-prisme.debug.open", "film:demo:1016", "-prisme.debug.bedIn", "240"])
        shot("60g-ce-soir-il-te-restera")

        // SAGAS / UNIVERS : Wonder Woman (saga + même univers DC confirmé par TMDB : Aquaman), Wonder (aucun lien malgré le titre),
        // Dune 1984 (remake homonyme : ni la saga Dune, ni « même univers »)
        for (id, name) in [("1031", "wonder-woman"), ("1032", "wonder"), ("1035", "dune-1984"), ("1012", "spider-man")] {
            relaunch(["-prisme.debug.open", "film:demo:" + id])
            shot("B0-saga-\(name)")
            for i in 1...4 { press(.down); shot(String(format: "B0-saga-\(name)-bas-%02d", i)) }
        }

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
        press(.select); Thread.sleep(forTimeInterval: 3); shot("72-replay-lecture", focus: false)
        back()

        // PROFILS — « Qui regarde ? » à l'ouverture (2 profils : Steven, Léa 12 ans max)
        // (l'écran choisit tout seul le profil probable au bout de 5 s : capture avant)
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.whoHold", "1"], wait: 2)
        diag(); shot("80-qui-regarde")
        press(.right); shot("81-qui-regarde-lea")
        press(.left); Thread.sleep(forTimeInterval: 1); shot("81b-qui-regarde-steven")
        press(.select); Thread.sleep(forTimeInterval: 3); shot("82-accueil-steven")
        // Réglages › Profils
        relaunch(["-prisme.debug.tab", "settings"])
        shot("83-reglages-profils")
        press(.down); Thread.sleep(forTimeInterval: 1); shot("83b-panneau-profils")
        press(.up); Thread.sleep(forTimeInterval: 0.5)
        for _ in 0..<3 where !focused().contains("Steven") { press(.left) }
        Thread.sleep(forTimeInterval: 1); shot("84-profils-focus")
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

        // VOUS DEUX : fenêtre « Choisis un profil » → « Steven + Léa, à deux », accueil, fiche (score pour vous deux,
        // coucher le plus tôt = celui de Léa, 22:30), retour à Steven seul
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.tab", "films"])
        press(.up, 8); press(.right, 8); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("C0-fenetre")
        for i in 1...2 { press(.down); shot(String(format: "C0b-fenetre-bas-%02d", i)) }
        press(.select); Thread.sleep(forTimeInterval: 4); shot("C1-a-deux-films")
        press(.down, 2); shot("C1b-a-deux-films-bas")
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.duo", "1", "-prisme.debug.open", "film:demo:1000"])
        shot("C2-a-deux-fiche")
        press(.up, 4); Thread.sleep(forTimeInterval: 1); shot("C3-a-deux-pastille")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("C3b-a-deux-fenetre")
        press(.up, 2); shot("C3c-vers-steven")
        press(.select); Thread.sleep(forTimeInterval: 3); shot("C4-steven-seul")

        gouts()

        // 6 PROFILS (le maximum) : « Qui regarde ? », fenêtre « Choisis un profil », Réglages › Profils (défilement dans le cadre)
        relaunch(["-prisme.debug.profiles", "6", "-prisme.debug.whoHold", "1"], wait: 2)
        shot("A0-six-qui-regarde")
        for i in 1...7 { press(.right); shot(String(format: "A0b-six-qui-regarde-%02d", i)) }
        // « À deux » avec 6 profils : choisir les deux
        press(.left, 8); press(.right, 6); shot("A0c-six-a-deux"); press(.select); Thread.sleep(forTimeInterval: 1); shot("A0d-six-qui-es-tu")
        press(.left, 6); press(.select); Thread.sleep(forTimeInterval: 1); shot("A0e-six-avec-qui")
        back(); Thread.sleep(forTimeInterval: 1); shot("A0f-six-annule")
        press(.left, 8); press(.select); Thread.sleep(forTimeInterval: 3)
        press(.up, 8); press(.right, 8); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("A1-six-fenetre")
        for i in 1...7 { press(.down); shot(String(format: "A1b-six-fenetre-bas-%02d", i)) }
        back(); Thread.sleep(forTimeInterval: 1)
        relaunch(["-prisme.debug.tab", "settings"])
        press(.down); Thread.sleep(forTimeInterval: 1); shot("A2-six-reglages")
        press(.up); Thread.sleep(forTimeInterval: 0.5)
        for _ in 0..<3 where !focused().contains("Steven") { press(.left) }
        for i in 1...7 { press(.right); shot(String(format: "A2b-six-reglages-droite-%02d", i)) }
        press(.left, 8); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("A3-six-fiche-profil")
        for i in 1...14 { press(.down); shot(String(format: "A3b-six-fiche-bas-%02d", i)) }
        press(.up, 16); shot("A3c-six-fiche-haut")

        ficheSerie()
        lecteur()

        // MESURES : accueil Films avec, en plus, le coût de l'ancienne méthode (comparaison avant / après dans mesures.txt)
        relaunch(["-prisme.debug.tab", "films", "-prisme.debug.perfOld", "1"], wait: 20)
        shot("Z-mesures")
    }

    /// Fiche série : états du simulateur (complété depuis une autre version, manquant, à venir annoncé par TMDB)
    /// Navigation depuis la barre du haut et Retour, sur les trois accueils (parcours que la visite complète ne faisait pas)
    func navigation() {
        for (i, n) in [(0, "films"), (1, "series"), (2, "tv")] {
            tab(i); shot("N\(i)a-\(n)-ouverture")
            press(.up, 8); shot("N\(i)b-\(n)-barre")
            press(.down); shot("N\(i)c-\(n)-bas-depuis-barre")
            press(.down); shot("N\(i)d-\(n)-bas-2")
            back(); shot("N\(i)e-\(n)-retour-1")
            press(.down, 5); shot("N\(i)f-\(n)-bas-5")
            press(.right, 25); shot("N\(i)g-\(n)-bout-de-rangee")
            back(); shot("N\(i)h-\(n)-retour-depuis-rangee")
            press(.down, 30); shot("N\(i)i-\(n)-tout-en-bas")
            if i < 2 {
                // « Parcourir » › Licences et sagas (Films) / Chaînes (Séries) : logos en couleurs d'origine
                press(.up); press(.right); press(.select); Thread.sleep(forTimeInterval: 1.5); press(.down); Thread.sleep(forTimeInterval: 2)
                shot("N\(i)k-\(n)-logos"); press(.right); shot("N\(i)l-\(n)-logo-selectionne")
            }
            back(); Thread.sleep(forTimeInterval: 2); shot("N\(i)j-\(n)-retour-depuis-le-bas")
        }
        // fiches : position à l'ouverture (profil visible ?) et Retour
        relaunch(["-prisme.debug.open", "film:demo:1006"])
        shot("N3a-fiche-film-ouverture")
        press(.down, 4); back(); shot("N3b-fiche-film-retour-1")
        back(); shot("N3c-fiche-film-retour-2")
        relaunch(["-prisme.debug.open", "series:demo:2001"])
        shot("N4a-fiche-serie-ouverture")
        press(.right, 2); press(.down, 3); back(); shot("N4b-fiche-serie-retour-1")
        back(); shot("N4c-fiche-serie-retour-2")
    }

    /// Deux fournisseurs (Lune + Soleil) et un fournisseur injoignable (Étoile)
    func multi() {
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.demoDown", "http://127.0.0.1:8090"], wait: 60)
        shot("M1-films-deux-fournisseurs")
        tab(5); press(.down); press(.left, 2); press(.up, 6); press(.down); shot("M2-reglages-fournisseurs")
        press(.right); shot("M2a-fournisseurs-panneau")
        for k in 1...6 { press(.down); shot(String(format: "M2b-fournisseurs-bas-%02d", k)) }
        tab(2); shot("M3-tv-deux-fournisseurs")
        // TF1 : une seule vignette, ses sources dans le menu « OK maintenu »
        // « Explorer par univers » › Généraliste (éventail), puis OK maintenu sur TF1 : ses sources (qualité · fournisseur)
        press(.down, 2); shot("M3b-tv-univers")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("M3b2-generaliste-eventail")
        remote.press(.select, forDuration: 1.2); Thread.sleep(forTimeInterval: 1.5); shot("M3c-tv-sources")
        back(); back()
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.demoDown", "http://127.0.0.1:8090", "-prisme.debug.open", "film:demo:1016"])
        shot("M4-fiche-interstellar")
    }

    /// Réglages › Fournisseurs (simulateur) : liste, « Gérer », parcours d'ajout en 4 étapes (iPhone par code QR, lien, identifiants)
    func fournisseurs() {
        let two = ["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.demoDown", "http://127.0.0.1:8090", "-prisme.debug.tab", "settings"]
        relaunch(two + ["-prisme.debug.settings", "prov"], wait: 60)
        shot("F1-fournisseurs")
        press(.right); shot("F1a-fournisseurs-panneau")
        for k in 1...9 { press(.down); shot(String(format: "F1b-fournisseurs-bas-%02d", k)) }
        press(.up, 12); press(.left); press(.up, 3); shot("F1c-retour-categories")
        // « Gérer » : actif, serveur, catégories à masquer, actualiser, supprimer
        relaunch(two + ["-prisme.debug.settings", "prov", "-prisme.debug.manage", "Soleil"], wait: 45)
        shot("F2-gerer-soleil")
        for k in 1...10 { press(.down); shot(String(format: "F2b-gerer-bas-%02d", k)) }
        back(); Thread.sleep(forTimeInterval: 1.5); shot("F2c-gerer-retour")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("F2d-gerer-rouvert")
        back(); Thread.sleep(forTimeInterval: 1.5); press(.down); shot("F2e-retour-puis-bas")
        // ajout : 1. connexion (trois façons)
        relaunch(two + ["-prisme.debug.settings", "prov", "-prisme.debug.addProvider", "1"], wait: 40)
        shot("F3-ajout-connexion")
        press(.right); shot("F3a-ajout-lien")
        press(.right); shot("F3b-ajout-identifiants")
        press(.select); Thread.sleep(forTimeInterval: 1); shot("F3c-ajout-identifiants-formulaire")
        back(); Thread.sleep(forTimeInterval: 1); press(.left, 2); press(.select); Thread.sleep(forTimeInterval: 3)
        shot("F4-ajout-iphone-code")
        // l'iPhone envoie le formulaire de la page ouverte par le code QR
        let addr = app.staticTexts.allElementsBoundByIndex.map(\.label).first { $0.hasPrefix("http://") } ?? ""
        attach("adresse-iphone", addr)
        if !addr.isEmpty { post(addr, "server=http%3A%2F%2F127.0.0.1%3A8098&user=demo&pass=demo&name=Test") }
        Thread.sleep(forTimeInterval: 6); shot("F5-ajout-verification")
        Thread.sleep(forTimeInterval: 6); shot("F5b-ajout-verification-finie")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("F6-ajout-contenu")
        for k in 1...5 { press(.down); shot(String(format: "F6b-contenu-bas-%02d", k)) }
        press(.up, 8); press(.select); Thread.sleep(forTimeInterval: 1); shot("F6c-tv-decochee")
        press(.select); Thread.sleep(forTimeInterval: 1)
        press(.down, 3); press(.select); Thread.sleep(forTimeInterval: 2); shot("F6d-categories-francaises")
        for k in 1...4 { press(.down); shot(String(format: "F6e-categories-bas-%02d", k)) }
        back(); Thread.sleep(forTimeInterval: 1); shot("F6f-categories-retour")
        press(.right); press(.down, 2); shot("F6g-importer"); press(.select); Thread.sleep(forTimeInterval: 2); shot("F6h-importation-lancee")
        Thread.sleep(forTimeInterval: 20); shot("F7-ajout-importation")
        Thread.sleep(forTimeInterval: 30); shot("F7b-ajout-importation-finie")
        press(.select); Thread.sleep(forTimeInterval: 3); shot("F8-apres-ajout")
        // Classement des chaînes TV (diagnostic) : catégories, raison, sources ; Retour le referme sur sa ligne
        relaunch(two + ["-prisme.debug.settings", "prov", "-prisme.debug.classify", "1"], wait: 40)
        shot("F9-classement")
        press(.right, 2); press(.select); Thread.sleep(forTimeInterval: 1); shot("F9b-classement-sport")
        for k in 1...4 { press(.down); shot(String(format: "F9c-classement-bas-%02d", k)) }
        press(.up, 8); press(.left, 2); press(.select); Thread.sleep(forTimeInterval: 1); shot("F9d-classement-generaliste")
        press(.down); shot("F9e-generaliste-tf1")
        back(); Thread.sleep(forTimeInterval: 1.5); shot("F9f-classement-ferme")
    }

    /// Fiches : position à l'ouverture, « Si tu hésites encore » (modes, pourcentages, options, « Comment on choisit »),
    /// selon le profil (Steven aime la science-fiction, Léa la comédie et l'animation), puis à deux ; séries proches.
    func fiches() {
        let t = ["-prisme.debug.profiles", "2", "-prisme.debug.tastes", "1"]
        relaunch(t + ["-prisme.debug.open", "film:demo:1006"], wait: 18)
        shot("X0-fiche-ouverture")
        press(.down, 4); Thread.sleep(forTimeInterval: 1.5); shot("X1-steven-mix")
        for k in 1...4 { press(.down); Thread.sleep(forTimeInterval: 1); shot(String(format: "X1b-descente-%02d", k)) }
        relaunch(t + ["-prisme.debug.open", "film:demo:1006"], wait: 18)
        // jusqu'aux pastilles de mode
        for _ in 0..<12 { press(.down); Thread.sleep(forTimeInterval: 0.6); if focused().contains("Le meilleur mix") { break } }
        shot("X2-pastilles")
        press(.right, 2); press(.select); Thread.sleep(forTimeInterval: 2); shot("X3-steven-selon-tes-gouts")
        press(.right); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("X4-comment-on-choisit")
        back(); Thread.sleep(forTimeInterval: 1); press(.down); Thread.sleep(forTimeInterval: 1); shot("X5-affiche")
        remote.press(.select, forDuration: 1.2); Thread.sleep(forTimeInterval: 1.5); shot("X6-options"); back()
        // même fiche, profil de Léa, puis « Vous deux »
        relaunch(t + ["-prisme.debug.second", "1", "-prisme.debug.open", "film:demo:1006"], wait: 18)
        for _ in 0..<12 { press(.down); Thread.sleep(forTimeInterval: 0.6); if focused().contains("Le meilleur mix") { break } }
        press(.right, 2); press(.select); Thread.sleep(forTimeInterval: 2); shot("X7-lea-selon-tes-gouts")
        relaunch(t + ["-prisme.debug.duo", "1", "-prisme.debug.open", "film:demo:1006"], wait: 18)
        for _ in 0..<12 { press(.down); Thread.sleep(forTimeInterval: 0.6); if focused().contains("Le meilleur mix") { break } }
        shot("X8-vous-deux")
        // fiche série : onglet « Séries proches »
        relaunch(t + ["-prisme.debug.open", "series:demo:2001"], wait: 18)
        press(.right, 2); press(.up); Thread.sleep(forTimeInterval: 1); shot("X9-serie-onglets")
        for _ in 0..<5 { if focused().contains("Séries proches") { break }; press(.right); Thread.sleep(forTimeInterval: 0.6) }
        press(.select); Thread.sleep(forTimeInterval: 2); press(.down); Thread.sleep(forTimeInterval: 1); shot("X9b-series-proches")
        press(.down); Thread.sleep(forTimeInterval: 1); shot("X9c-series-proches-affiche")
        back(); Thread.sleep(forTimeInterval: 1); shot("X9d-serie-retour")
    }

    /// Envoi du formulaire de la page iPhone (POST), comme le ferait Safari sur l'iPhone
    func post(_ url: String, _ body: String) {
        guard let u = URL(string: url) else { return }
        var r = URLRequest(url: u); r.httpMethod = "POST"; r.httpBody = Data(body.utf8)
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: r) { _, resp, err in
            self.attach("envoi-iphone", "\((resp as? HTTPURLResponse)?.statusCode ?? 0) \(err?.localizedDescription ?? "")"); sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 10)
    }

    func attach(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text); a.name = name; a.lifetime = .keepAlways; add(a)
        // dans le même journal que les captures (shot() réécrit focus.txt en entier à partir de « log »)
        log += "\(name) → \(text)\n"
        try? log.write(to: URL(fileURLWithPath: dir).appendingPathComponent("focus.txt"), atomically: true, encoding: .utf8)
    }

    /// Ajout d'un fournisseur géant (8096 : 1 500 catégories, 150 000 films, 40 000 séries, 30 000 chaînes)
    /// ou aux réponses incomplètes (8095 : films coupés, séries en erreur), par la page iPhone, jusqu'au bout :
    /// l'appli ne doit pas se fermer ; elle note sa mémoire à chaque étape dans mesures.txt.
    func geant(port: String, tag: String) {
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "prov", "-prisme.debug.addProvider", "1"], wait: 30)
        press(.select); Thread.sleep(forTimeInterval: 3); shot("\(tag)0-iphone")
        let addr = app.staticTexts.allElementsBoundByIndex.map(\.label).first { $0.hasPrefix("http://") } ?? ""
        attach("\(tag)-adresse-iphone", addr)
        guard !addr.isEmpty else { return }
        post(addr, "server=http%3A%2F%2F127.0.0.1%3A\(port)&user=demo&pass=demo&name=Geant\(tag)")
        var t = 0
        while t < 600 {
            Thread.sleep(forTimeInterval: 10); t += 10
            attach("\(tag)-verification-\(t)s", app.state == .runningForeground ? "appli ouverte" : "APPLI FERMÉE")
            if app.state != .runningForeground { shot("\(tag)1-appli-fermee-verification"); return }
            if t % 30 == 0 { shot(String(format: "\(tag)1-verification-%03ds", t)) }
            if app.buttons["Continuer"].exists || app.buttons["Recommencer"].exists { break }
        }
        shot("\(tag)2-verification-finie")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("\(tag)3-contenu")
        press(.right); press(.down, 2); shot("\(tag)3b-importer"); press(.select)
        t = 0
        while t < 900 {
            Thread.sleep(forTimeInterval: 10); t += 10
            attach("\(tag)-import-\(t)s", app.state == .runningForeground ? "appli ouverte" : "APPLI FERMÉE")
            if app.state != .runningForeground { shot("\(tag)4-appli-fermee-import"); return }
            if t % 30 == 0 { shot(String(format: "\(tag)4-import-%03ds", t)) }
            if app.buttons["Terminer"].exists || app.buttons["Revenir au contenu"].exists { break }
        }
        shot("\(tag)5-import-fini")
        // redémarrage : le catalogue et les données sont toujours là
        relaunch(["-prisme.debug.tab", "films"], wait: 40); shot("\(tag)6-films-apres-redemarrage")
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "prov"], wait: 30); press(.right); shot("\(tag)7-fournisseurs-apres-redemarrage")
    }

    /// Gros catalogue (≈ 20 000 chaînes, 40 000 films, 20 000 séries) : mesures écrites par l'app dans mesures.txt
    func perf() {
        app.terminate()
        app.launchArguments = ["-prisme.debug.demoServer", "http://127.0.0.1:8097", "-prisme.debug.tmdbKey", "demo",
                               "-prisme.debug.tmdbBase", "http://127.0.0.1:8099/tmdb/3", "-prisme.debug.imgBase", "http://127.0.0.1:8099/img",
                               "-prisme.debug.itunesBase", "http://127.0.0.1:8099/itunes", "-prisme.debug.bgTrailer", "off"]
        app.launch(); Thread.sleep(forTimeInterval: 150)
        shot("P1-films-gros-catalogue")
        tab(1); shot("P2-series-gros-catalogue")
        tab(2); shot("P3-tv-gros-catalogue")
        press(.down, 3); press(.right, 10); shot("P4-tv-gros-catalogue-bas")
        tab(0); shot("P5-films-retour")
        // deux fournisseurs (gros catalogue + Lune) : dédoublonnage de ≈ 20 000 chaînes, TV en direct, éventail
        app.terminate()
        app.launchArguments += ["-prisme.debug.demoServer2", "http://127.0.0.1:8099", "-prisme.debug.tab", "live"]
        app.launch(); Thread.sleep(forTimeInterval: 120)
        shot("P6-tv-deux-fournisseurs")
        press(.down, 2); press(.select); Thread.sleep(forTimeInterval: 2); shot("P7-tv-deux-eventail")
        back(); Thread.sleep(forTimeInterval: 1)
        tab(0); shot("P8-films-deux-fournisseurs")
        tab(1); shot("P9-series-deux-fournisseurs")
    }

    /// TV en direct : paquets « univers » et leur éventail, « En ce moment à la télé »
    func tvUnivers() {
        // TV en direct : catégories fixes (Explorer par univers), « En ce moment à la télé », colonne d'icônes
        relaunch(["-prisme.debug.tab", "live"])
        shot("25-tv-accueil")
        // en-tête, puis « Explorer par univers » (catégories fixes), puis « En ce moment à la télé »
        press(.down, 2); shot("25b-tv-univers")
        for i in 1...10 { press(.right); shot(String(format: "26-univers-%02d", i)) }
        press(.left, 9); shot("26b-univers-debut")
        // OK : le paquet s'ouvre en éventail par-dessus la page (simulateur), Retour le referme
        press(.select); Thread.sleep(forTimeInterval: 2); shot("26c-univers-eventail")
        press(.right, 3); shot("26d-eventail-droite")
        press(.down); shot("26e-eventail-refermer")
        press(.up); back(); Thread.sleep(forTimeInterval: 1); shot("26f-eventail-ferme")
        press(.down); shot("27-en-ce-moment")
        for i in 1...4 { press(.right); shot(String(format: "27b-en-ce-moment-%02d", i)) }
        press(.select); Thread.sleep(forTimeInterval: 2); shot("27c-en-ce-moment-chaines")
        press(.down); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("27d-retour")
        press(.down, 3); shot("27e-tv-bas")
        // 1.8 : « Pour toi, maintenant » après avoir regardé une chaîne (raisons tirées de l'historique)
        relaunch(["-prisme.debug.tab", "live", "-prisme.debug.playLive", "TF1"], wait: 20)
        Thread.sleep(forTimeInterval: 40); back(); Thread.sleep(forTimeInterval: 1); back(); Thread.sleep(forTimeInterval: 3)
        shot("28-pour-toi-maintenant")
        relaunch(["-prisme.debug.tab", "live"]); shot("28b-pour-toi-maintenant-relance")
        press(.down); shot("28c-pour-toi-maintenant-rangee")
    }

    func ficheSerie() {
        relaunch(["-prisme.debug.open", "series:demo:2001", "-prisme.debug.season", "3"])
        Thread.sleep(forTimeInterval: 3); shot("16-fiche-serie-saison3")
        press(.right, 2); press(.down, 3); Thread.sleep(forTimeInterval: 1); shot("16b-saison3-episodes")
        press(.down, 3); Thread.sleep(forTimeInterval: 1); shot("16c-saison3-fin")
        press(.select); Thread.sleep(forTimeInterval: 1); shot("16d-saison3-a-venir-message")
        press(.select); Thread.sleep(forTimeInterval: 1)
        relaunch(["-prisme.debug.open", "series:demo:2001", "-prisme.debug.season", "2"])
        Thread.sleep(forTimeInterval: 3)
        press(.right, 2); press(.down, 6); Thread.sleep(forTimeInterval: 1); shot("16e-saison2-complete")
        // 1.7.1 : rangée « selon les goûts » sous la fiche série (comme la fiche film)
        relaunch(["-prisme.debug.open", "series:demo:2001"])
        Thread.sleep(forTimeInterval: 3)
        for i in 1...4 { press(.down, 3); shot(String(format: "16f-sous-la-fiche-%02d", i)) }
        press(.right, 2); shot("16g-sous-la-fiche-droite")
        // 1.7.1 : après la fermeture d'une fiche, Retour sur l'accueil Séries remonte à la barre du haut
        relaunch(["-prisme.debug.tab", "series"])
        for (n, depth) in [("17", 2), ("18", 5)] {
            press(.up, 8); press(.down, depth); shot(n + "a-series-tuile")
            press(.select); Thread.sleep(forTimeInterval: 3); shot(n + "b-fiche-ouverte")
            press(.down, 2); back(); Thread.sleep(forTimeInterval: 1); shot(n + "c-fiche-fermee")
            back(); Thread.sleep(forTimeInterval: 2); shot(n + "d-retour-barre")
        }
    }

    /// Observation : TV en direct ouverte au lancement avec deux fournisseurs, sans toucher à la télécommande,
    /// une capture toutes les 15 s (l'heure de chaque capture dans focus.txt), puis une seule flèche bas.
    func tvCrash() {
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.tab", "live"], wait: 5)
        for k in 0..<8 { shot(String(format: "C%02d-attente", k), focus: false); attach("heure", "\(Date())"); Thread.sleep(forTimeInterval: 15) }
        press(.down); Thread.sleep(forTimeInterval: 2); shot("C9-bas")
        Thread.sleep(forTimeInterval: 20); shot("C10-apres")
    }

    /// Lecteur de la TV en direct (1.7 : lecteur commun, variante TV) : bandeau, raccourcis, liste des chaînes,
    /// zapping en descendant la liste, sources de la chaîne, Retour couche par couche.
    func lecteurTV() {
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.tab", "live"], wait: 120)
        // depuis l'en-tête de la TV en direct (programme mis en avant)
        press(.down); Thread.sleep(forTimeInterval: 1); shot("T-entete")
        press(.select); Thread.sleep(forTimeInterval: 9); shot("T0-direct-bandeau", focus: false)
        Thread.sleep(forTimeInterval: 6); shot("T0b-direct-sans-aide", focus: false)
        press(.up); Thread.sleep(forTimeInterval: 1); shot("T1-direct-raccourcis", focus: false)
        back(); Thread.sleep(forTimeInterval: 1)
        press(.down); Thread.sleep(forTimeInterval: 1.5); shot("T2-direct-chaines", focus: false)
        press(.down); Thread.sleep(forTimeInterval: 0.5); shot("T3-direct-chaine-suivante", focus: false)
        // 1.7.1 : passer sur une chaîne ne lance rien (seul OK change de chaîne)
        Thread.sleep(forTimeInterval: 4); shot("T3b-direct-pas-de-zap", focus: false)
        press(.up); Thread.sleep(forTimeInterval: 4); shot("T3c-direct-haut-pas-de-zap", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); shot("T4-direct-retour-1-panneau-ferme", focus: false)
        press(.down); Thread.sleep(forTimeInterval: 1.5); press(.down); Thread.sleep(forTimeInterval: 0.5)
        press(.select); Thread.sleep(forTimeInterval: 6); shot("T4b-direct-ok-zappe", focus: false)
        // réglages du panneau (sous la liste des chaînes) : tout en bas (Son de nuit) puis remonter jusqu'à Source
        press(.down); Thread.sleep(forTimeInterval: 1); press(.down, 70); press(.up, 4); Thread.sleep(forTimeInterval: 1.5)
        shot("T5a-direct-panneau-reglages", focus: false)
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("T5-direct-sources", focus: false)
        // autre qualité : la source change, la chaîne et le panneau restent
        press(.down); press(.select); Thread.sleep(forTimeInterval: 6); shot("T5b-direct-autre-source-panneau-ouvert", focus: false)
        press(.up); press(.select); Thread.sleep(forTimeInterval: 6); shot("T5c-direct-source-d-origine", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); shot("T6-direct-sources-retour-liste", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); shot("T7b-direct-retour-1-panneau-ferme", focus: false)
        back(); Thread.sleep(forTimeInterval: 2); shot("T8-direct-retour-2-quitte")
        // TF1 : trois sources (720p, 1080p, 4K, deux fournisseurs) — changer de qualité sans changer de chaîne ni fermer le panneau
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.tab", "live", "-prisme.debug.playLive", "TF1"], wait: 90)
        Thread.sleep(forTimeInterval: 8); shot("TQ0-tf1", focus: false)
        press(.down); Thread.sleep(forTimeInterval: 1.5); press(.down, 70); press(.up, 4); Thread.sleep(forTimeInterval: 1.5)
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("TQ1-tf1-sources", focus: false)
        for k in 1...2 { press(.down); press(.select); Thread.sleep(forTimeInterval: 8); shot("TQ2-tf1-qualite-\(k)", focus: false) }
        press(.up, 2); press(.up); Thread.sleep(forTimeInterval: 1); shot("TQ3-tf1-haut", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); shot("TQ4-retour-liste", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); back(); Thread.sleep(forTimeInterval: 2); shot("TQ5-quitte")
        // depuis l'éventail d'un paquet « univers »
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.tab", "live"], wait: 60)
        // (la rangée « Pour toi, maintenant » existe maintenant : l'univers est une rangée plus bas)
        downUntil(["Généraliste"], max: 5, prefix: "T9-bas"); press(.select); Thread.sleep(forTimeInterval: 2); shot("T9-eventail")
        press(.select); Thread.sleep(forTimeInterval: 9); shot("T9b-direct-depuis-eventail", focus: false)
        back(); Thread.sleep(forTimeInterval: 2); shot("T9c-retour-eventail")
    }

    /// 1.7.1 — « Qu'a-t-il dit ? » trois fois de suite sur un film sous-titré (sous-titres français pendant le passage revu,
    /// puis retour aux sous-titres d'avant), puis sur un film sans sous-titres français (message clair).
    func quATilDit() {
        relaunch(["-prisme.debug.open", "film:demo:1000"])
        press(.select); Thread.sleep(forTimeInterval: 25); shot("Q0-lecture", focus: false)
        for k in 1...3 {
            press(.down); Thread.sleep(forTimeInterval: 1); shot("Q\(k)a-options", focus: false)
            press(.select)
            for t in [1.0, 3.0, 5.0] { Thread.sleep(forTimeInterval: t == 1 ? 1 : 2); shot("Q\(k)b-apres-\(Int(t))s", focus: false) }
            Thread.sleep(forTimeInterval: 9); shot("Q\(k)c-apres-14s-retour", focus: false)
        }
        back(); Thread.sleep(forTimeInterval: 1); back(); Thread.sleep(forTimeInterval: 2)
        relaunch(["-prisme.debug.open", "film:demo:1011"])
        press(.select); Thread.sleep(forTimeInterval: 20)
        press(.down); Thread.sleep(forTimeInterval: 1); press(.select); Thread.sleep(forTimeInterval: 1.5); shot("Q9-sans-sous-titres-fr", focus: false)
    }

    /// 1.7.1 — les 9 rubriques des Réglages, puis la sauvegarde par l'iPhone (télécharger, renvoyer, confirmer sur la TV).
    func reglages() {
        for sec in ["prof", "prov", "lang", "play", "live", "epg", "homes", "par", "data"] {
            relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", sec], wait: 14)
            shot("R-\(sec)")
            press(.right); shot("R-\(sec)-panneau")
            for k in 1...7 { press(.down); shot("R-\(sec)-bas-\(k)") }
        }
        // réglage changé (Lecture › saut) puis relu après relance
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "play"], wait: 14)
        press(.right); press(.down, 3); press(.select); Thread.sleep(forTimeInterval: 1); shot("R2-saut-change")
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "play"], wait: 14)
        press(.right); shot("R2b-saut-relu")
        sauvegarde()
    }

    /// Sauvegarde sur l'iPhone : code, téléchargement, renvoi, confirmation sur la TV.
    /// Adresse affichée sous le code de la sauvegarde (élément « backup-address »), ou à défaut tout texte en http://
    func backupAddress() -> String {
        let e = app.descendants(matching: .any)["backup-address"]
        if e.waitForExistence(timeout: 6), e.label.hasPrefix("http") { return e.label }
        return app.descendants(matching: .any).allElementsBoundByIndex.map(\.label).first { $0.hasPrefix("http://") } ?? ""
    }

    func sauvegarde() {
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "data"], wait: 14)
        press(.right); press(.up, 14); press(.down); Thread.sleep(forTimeInterval: 1); shot("R3a-sauvegarde-ligne"); press(.select); Thread.sleep(forTimeInterval: 3); shot("R3-sauvegarde-code")
        let addr = backupAddress()
        attach("adresse-sauvegarde", addr.isEmpty ? "introuvable · textes : " + app.staticTexts.allElementsBoundByIndex.prefix(40).map(\.label).joined(separator: " | ") : addr)
        guard !addr.isEmpty, let u = URL(string: addr + "/prisme-sauvegarde.json") else { return }
        let sem = DispatchSemaphore(value: 0)
        var backup = Data()
        URLSession.shared.dataTask(with: u) { d, r, e in backup = d ?? Data(); self.attach("sauvegarde-recue", "\((r as? HTTPURLResponse)?.statusCode ?? 0) · \(backup.count) octets \(e?.localizedDescription ?? "")"); sem.signal() }.resume()
        _ = sem.wait(timeout: .now() + 15)
        if let o = try? JSONSerialization.jsonObject(with: backup) as? [String: Any] { attach("sauvegarde-contenu", "profils \(o["profiles"] ?? "?") · appareil \(o["device"] ?? "?") · date \(o["date"] ?? "?")") }
        Thread.sleep(forTimeInterval: 2); shot("R3b-sauvegarde-telechargee")
        // Ma liste vidée (donnees.txt le montre), puis la sauvegarde est renvoyée et doit la rétablir
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "data", "-prisme.debug.wipeFavs", "1"], wait: 14)
        press(.right); press(.up, 14); press(.down); press(.select); Thread.sleep(forTimeInterval: 3); shot("R3c-code-apres-vidage")
        let a2 = backupAddress(); let addr2 = a2.isEmpty ? addr : a2
        attach("adresse-apres-vidage", addr2)
        var r = URLRequest(url: URL(string: addr2)!); r.httpMethod = "POST"; r.httpBody = backup
        let sem2 = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: r) { d, resp, err in
            var page = ""
            if let html = String(data: d ?? Data(), encoding: .utf8), let h = html.range(of: "<h3>") { page = String(html[h.upperBound...].prefix(40)) }
            self.attach("renvoi-sauvegarde", "\((resp as? HTTPURLResponse)?.statusCode ?? 0) · \(backup.count) octets envoyés · réponse « \(page) » \(err?.localizedDescription ?? "")"); sem2.signal() }.resume()
        _ = sem2.wait(timeout: .now() + 15)
        Thread.sleep(forTimeInterval: 3); shot("R4-restaurer-confirmation")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("R4b-restauree")
        relaunch(["-prisme.debug.tab", "mine"], wait: 20); shot("R5-ma-liste-apres-restauration")
        // annuler la dernière restauration (remet Ma liste vidée)
        relaunch(["-prisme.debug.tab", "settings", "-prisme.debug.settings", "data"], wait: 14)
        press(.right); press(.up, 14); press(.down, 4); shot("R6-annuler-ligne"); press(.select); press(.select); Thread.sleep(forTimeInterval: 2); shot("R6b-annulee")
        relaunch(["-prisme.debug.tab", "mine"], wait: 20); shot("R7-ma-liste-apres-annulation")
    }

    /// 1.8 phase 0 — accueils Films et Séries de haut en bas (Ce soir ?, Top 10, Explorer, Parcourir et ses onglets).
    func accueils() {
        for (k, tab) in [("F", "films"), ("S", "series")] {
            relaunch(["-prisme.debug.tab", tab, "-prisme.debug.demoServer2", "http://127.0.0.1:8098"], wait: 40)
            shot("A\(k)00-ouverture")
            for i in 1...12 { press(.down); shot(String(format: "A\(k)%02d-bas", i)) }
            // Parcourir : chaque onglet, puis ses tuiles vers la droite
            downUntil(["Catégories", "Licences et sagas", "Collections", "Chaînes"], max: 6, prefix: "A\(k)P-cherche")
            // le focus peut être sur les tuiles : remonter jusqu'aux onglets
            let tabs = ["Catégories", "Licences", "Collections", "Chaînes"]
            for _ in 0..<3 where !tabs.contains(where: { focused().contains($0) }) { press(.up) }
            press(.left, 4)
            for t in 0..<3 {
                press(.select); Thread.sleep(forTimeInterval: 1.5); shot("A\(k)P\(t)-onglet")
                press(.down); Thread.sleep(forTimeInterval: 2); shot("A\(k)P\(t)-tuiles")
                press(.right, 3); Thread.sleep(forTimeInterval: 1.5); shot("A\(k)P\(t)-tuiles-droite")
                press(.left, 3); press(.up)
                for _ in 0..<2 where !tabs.contains(where: { focused().contains($0) }) { press(.up) }
                press(.left, 4); press(.right, t + 1)
            }
        }
    }

    /// 1.8 phase 0 — « Selon vos goûts » / « Pour vous deux » : fiches film et série en mode à deux, puis seul.
    func duo() {
        for (k, extra) in [("D", ["-prisme.debug.duo", "1"]), ("S", [])] {
            for (n, id) in [("film", "film:demo:1000"), ("serie", "series:demo:2001")] {
                relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.tastes", "1", "-prisme.debug.open", id] + extra, wait: 16)
                for i in 1...10 { press(.down); shot(String(format: "\(k)-\(n)-%02d", i)) }
                if n == "film" { press(.right, 2); shot("\(k)-\(n)-pastilles") }
            }
        }
    }

    /// 1.8 phase 0 — fenêtre de choix des sources avec 25 sources (Mission: Impossible).
    func sources() {
        relaunch(["-prisme.debug.demoServer2", "http://127.0.0.1:8098", "-prisme.debug.open", "film:demo:1027"], wait: 30)
        shot("V0-fiche")
        for i in 1...4 { press(.right); shot("V0-droite-\(i)"); if focused().lowercased().contains("version") { break } }
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("V1-ouverte")
        for i in 1...26 { press(.down); if i % 5 == 0 || i > 22 { shot(String(format: "V2-bas-%02d", i)) } }
        for i in 1...26 { press(.up); if i % 8 == 0 || i > 23 { shot(String(format: "V3-haut-%02d", i)) } }
        back(); Thread.sleep(forTimeInterval: 1); shot("V4-retour")
    }

    /// 1.8 phase 0 — envoi vers une autre Apple TV : un 2e simulateur (lancé par le workflow) est en réception.
    func envoi() {
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.tab", "settings", "-prisme.debug.settings", "data"], wait: 20)
        press(.right); press(.up, 14); press(.down, 3); shot("E1-ligne-envoyer"); press(.select)
        Thread.sleep(forTimeInterval: 12); shot("E2-apple-tv-trouvees")
        press(.down); shot("E3-pret"); press(.select)
        Thread.sleep(forTimeInterval: 8); shot("E4-envoye")
        Thread.sleep(forTimeInterval: 40); shot("E5-fin")
    }

    /// 1.7.1 — langue du contenu de Soleil : Français uniquement, Privilégier, puis retour à Tout garder.
    /// À chaque fois : Gérer (nombres), l'écran « Catégories françaises », et les films de Soleil.
    func langue() {
        let two = ["-prisme.debug.demoServer2", "http://127.0.0.1:8098"]
        for (n, m) in [("1", "fr"), ("2", "prefer"), ("3", "all")] {
            relaunch(two + ["-prisme.debug.lang", m, "-prisme.debug.tab", "settings", "-prisme.debug.settings", "prov", "-prisme.debug.manage", "Soleil"], wait: 50)
            shot("L\(n)a-gerer-\(m)")
            press(.down, 4); shot("L\(n)b-gerer-langue-\(m)")
            relaunch(two + ["-prisme.debug.tab", "settings", "-prisme.debug.settings", "prov", "-prisme.debug.manage", "Soleil", "-prisme.debug.frcats", "1"], wait: 25)
            shot("L\(n)c-categories-francaises-\(m)")
            for k in 1...6 { press(.down); shot("L\(n)d-categories-bas-\(m)-\(k)") }
        }
    }

    /// Test des goûts (grands classiques), puis ses effets sur la fiche, l'accueil et les réglages.
    func gouts() {
        // MES GOÛTS : le test en entier (8 titres, 5 duels, ambiances, « jamais de… »), puis ses effets
        relaunch(["-prisme.debug.taste", "1", "-prisme.debug.tab", "films"], wait: 12)
        shot("D0-gouts-intro")
        press(.select); Thread.sleep(forTimeInterval: 1.5); shot("D1-gouts-carte-01")
        let verdicts = [0, 0, 2, 1, 0, 2, 0, 0]   // 0 j'aime, 1 pas vu, 2 pas pour moi
        for (i, v) in verdicts.enumerated() {
            if v > 0 { press(.left, v) }
            press(.select); Thread.sleep(forTimeInterval: 1.2)
            shot(String(format: "D1-gouts-carte-%02d", i + 2))
        }
        for i in 1...5 { if i % 2 == 0 { press(.right) }; press(.select); Thread.sleep(forTimeInterval: 1.2); shot(String(format: "D2-gouts-duel-%02d", i)) }
        press(.select); press(.right); press(.select); shot("D3-gouts-ambiances")
        press(.down, 3); press(.select); Thread.sleep(forTimeInterval: 1); shot("D4-gouts-jamais")
        press(.up, 4); press(.select); shot("D4b-gouts-jamais-horreur")
        press(.down, 5); press(.select); Thread.sleep(forTimeInterval: 3); shot("D5-gouts-resultat")
        press(.select); Thread.sleep(forTimeInterval: 2); shot("D6-gouts-fini")
        relaunch(["-prisme.debug.open", "film:demo:1000"])
        shot("D7-gouts-fiche-score")
        relaunch(["-prisme.debug.tab", "films"])
        for i in 1...4 { press(.down); shot(String(format: "D8-gouts-pour-toi-%02d", i)) }
        relaunch(["-prisme.debug.tab", "settings"])
        press(.down); Thread.sleep(forTimeInterval: 1); press(.up); Thread.sleep(forTimeInterval: 0.5)
        for _ in 0..<3 where !focused().contains("Steven") { press(.left) }
        press(.select); Thread.sleep(forTimeInterval: 1.5)
        for i in 1...9 { press(.down); shot(String(format: "D9-gouts-reglages-%02d", i)) }
    }

    func lecteur() {
        // LECTEUR (vraie vidéo de test) : bandeau, Raccourcis (↑), Lecture (↑ encore), sous-listes, son de nuit,
        // « Qu'a-t-il dit ? » (↓), puis « Tu regardes toujours ? » et l'arrêt au coucher (délais raccourcis pour le test).
        // Captures sans lecture du focus : pendant une vidéo, lire l'écran peut dépasser le délai du test.
        relaunch(["-prisme.debug.open", "film:demo:1000"])
        press(.select); Thread.sleep(forTimeInterval: 8); shot("E0-lecteur", focus: false)
        press(.up); Thread.sleep(forTimeInterval: 1); shot("E1-raccourcis", focus: false)
        press(.up); Thread.sleep(forTimeInterval: 1); shot("E2-lecture", focus: false)
        press(.select); Thread.sleep(forTimeInterval: 1); shot("E3-audio", focus: false)
        back(); Thread.sleep(forTimeInterval: 1)
        press(.down, 4); press(.select); Thread.sleep(forTimeInterval: 1); shot("E4-son-de-nuit", focus: false)
        press(.down); press(.select); Thread.sleep(forTimeInterval: 6); shot("E5-son-de-nuit-toujours", focus: false)
        press(.down, 3); Thread.sleep(forTimeInterval: 1); shot("E5b-lecture-bas", focus: false)
        back(); shot("E6a-retour-1-sous-liste", focus: false); back(); Thread.sleep(forTimeInterval: 1); shot("E6b-retour-2-panneau-ferme", focus: false)
        press(.down); Thread.sleep(forTimeInterval: 1); shot("E7-options", focus: false)
        press(.select); Thread.sleep(forTimeInterval: 1); shot("E7b-qu-a-t-il-dit", focus: false)
        press(.up); Thread.sleep(forTimeInterval: 1); shot("E7c-raccourcis-appris", focus: false)
        back(); Thread.sleep(forTimeInterval: 1); shot("E7d-retour-1-panneau-ferme", focus: false)
        back(); Thread.sleep(forTimeInterval: 1.5); shot("E7e-retour-2-quitte", focus: false)
        relaunch(["-prisme.debug.open", "film:demo:1016", "-prisme.debug.sleepAfter", "25"])
        press(.select); Thread.sleep(forTimeInterval: 34); shot("E8-tu-regardes-toujours", focus: false)
        Thread.sleep(forTimeInterval: 17); shot("E9-pause-place-gardee", focus: false)
        relaunch(["-prisme.debug.open", "film:demo:1000", "-prisme.debug.bedIn", "1"])
        press(.select); Thread.sleep(forTimeInterval: 6)
        press(.up); press(.up); Thread.sleep(forTimeInterval: 1); press(.down, 5); press(.left); Thread.sleep(forTimeInterval: 1); shot("E10-arret-coucher-choix", focus: false)
        press(.select); Thread.sleep(forTimeInterval: 1); shot("E10b-arret-coucher-active", focus: false)
        back(); Thread.sleep(forTimeInterval: 75); shot("E11-arret-coucher", focus: false)
    }

    // MARK: 1.8 phase 1 — fin d'épisode, intro, « Encore un ? », panneau Épisodes, langue retenue, zéro spoiler

    /// HPI (faux fournisseur) : saison 1 avec chapitres « Intro » (30 → 75 s ; 38 → 83 s sur l'épisode 2) et « Générique » (260 s),
    /// français + anglais ; saison 2 sans chapitres, français seul. Captures sans lecture du focus (vidéo en cours).
    /// Attend qu'un repère de l'appli apparaisse (carte de fin, message) ; faux après `t` secondes.
    @discardableResult
    func waitFor(_ id: String, _ t: Double) -> Bool {
        let ok = app.descendants(matching: .any)[id].waitForExistence(timeout: t)
        log += "attente \(id) → \(ok ? "vu" : "pas vu")\n"
        return ok
    }

    func finSerie() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        let hpi = ["-prisme.debug.open", "series:demo:2002"]
        func play(_ ep: String, from: Int, _ extra: [String] = []) { relaunch(hpi + ["-prisme.debug.playEp", ep, "-prisme.debug.playFrom", String(from)] + extra, wait: 8) }
        // intro : bouton (É1) confirmé par OK ; É2 (intro décalée de 8 s) confirmé aussi ; É3 : passage automatique, puis annulé
        play("1-1", from: 26); waitFor("carte-intro", 60); w(1); shot("S01-intro-bouton", focus: false)
        press(.select); w(2); shot("S02-intro-passee", focus: false)
        play("1-2", from: 34); waitFor("carte-intro", 60); w(1); shot("S05-intro-e2", focus: false)
        press(.select); w(2)
        play("1-3", from: 26); waitFor("toast", 60); w(0.5); shot("S09-intro-auto-e3", focus: false)
        press(.left, 3); w(1); shot("S10-retour-annule", focus: false)
        // générique (chapitre à 260 s) : carte, « prêt », enchaînement automatique
        play("1-1", from: 254, ["-prisme.debug.playFromEach", "1"]); waitFor("carte-episode", 60); w(1); shot("S03-carte-episode-suivant", focus: false)
        w(4); shot("S03b-carte-prete", focus: false)
        waitFor("toast", 20); shot("S04-enchaine-e2", focus: false)
        // « Voir le générique » puis « Fin de l'épisode »
        play("1-2", from: 254); waitFor("carte-episode", 60); press(.right); press(.select); w(1); shot("S07-generique", focus: false)
        waitFor("carte-episode", 70); w(1); shot("S08-fin-episode", focus: false)
        // « Encore un ? » (réglé sur 1 épisode pour le test), « Un dernier », puis « Dernier épisode de la soirée »
        play("1-3", from: 254, ["-prisme.debug.playFromEach", "1", "-prisme.play.binge", "1"]); waitFor("carte-episode", 60); w(1)
        press(.select); waitFor("carte-encore", 10); w(1); shot("S12-encore-un", focus: false)
        press(.down); w(1); shot("S12b-un-dernier-choisi", focus: false)
        press(.select); w(3); shot("S13-un-dernier", focus: false)
        waitFor("carte-episode", 60); w(1); shot("S14-dernier-de-la-soiree", focus: false)
        press(.select); w(1); shot("S15-bonne-nuit", focus: false)
        w(5); shot("S16-fiche-zero-spoiler", focus: false)
        press(.right, 2); press(.down, 6); w(1); shot("S16b-fiche-episodes-floutes")
        // panneau : Épisodes et réglages de cette série ; audio anglais retenu pour la série
        play("1-6", from: 100); w(12); press(.up); w(1); shot("S20-raccourcis", focus: false)
        press(.up); w(2); shot("S21-panneau-episodes", focus: false)
        press(.down, 3); w(1); shot("S22-reglages-serie")
        if focused().contains("Sous-titres") { press(.left) }
        press(.select); w(1); shot("S23-audio")
        press(.down); press(.select); w(2); shot("S24-audio-anglais")
        back(); w(1)
        press(.down); press(.right); press(.select); w(10); shot("S25-e7-langue-retenue", focus: false)
        press(.up); press(.up); w(2); press(.down, 3); w(1); shot("S26-e7-panneau")
        back(); w(1)
        // saison 2 sans piste anglaise : message, la langue n'est pas imposée
        relaunch(hpi + ["-prisme.debug.playEp", "2-1"], wait: 8)
        waitFor("toast", 60); w(0.5); for i in 1...3 { shot("S27-\(i)-pas-de-piste-anglaise", focus: false); w(1) }
        // épisode manquant chez le fournisseur (Lupin S2·É4)
        relaunch(["-prisme.debug.open", "series:demo:2001", "-prisme.debug.playEp", "2-3", "-prisme.debug.playFrom", "73"], wait: 8)
        waitFor("carte-episode", 60); w(1); shot("S28-episode-absent", focus: false)
    }

    /// Lot 1 : cas restants des lecteurs (fin de saison, épisode absent, « Encore un ? » après le coucher, oublier l'intro,
    /// film sans proposition, mode à deux, journal par profil).
    func lot1() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        let hpi = ["-prisme.debug.open", "series:demo:2002"]
        func play(_ ep: String, from: Int, _ extra: [String] = []) { relaunch(hpi + ["-prisme.debug.playEp", ep, "-prisme.debug.playFrom", String(from)] + extra, wait: 8) }
        // 1. épisode absent (Lupin S2·É4) : carte, « M'avertir et fermer », fenêtre « Saison terminée », navigation, saison 3
        relaunch(["-prisme.debug.open", "series:demo:2001", "-prisme.debug.playEp", "2-3", "-prisme.debug.playFrom", "73"], wait: 8)
        waitFor("carte-episode", 60); w(1); shot("L01-fin-episode-absent", focus: false)
        press(.select); waitFor("carte-season", 10); w(1); shot("L02-saison-terminee-absent", focus: false)
        press(.select); w(1); shot("L03-alerte-activee", focus: false)
        press(.down); w(0.5); shot("L04-saison-suivante", focus: false)
        press(.down); w(0.5); shot("L05-revoir", focus: false)
        press(.right); w(0.5); shot("L06-fermer", focus: false)
        press(.up); w(0.5); shot("L07-retour-ligne", focus: false)
        press(.select); w(10); shot("L08-saison-3-lancee", focus: false)
        // 2. dernier épisode de la série (HPI S4·É8) : « Tu as tout vu ! », puis la fenêtre, puis Fermer
        play("4-8", from: 250); waitFor("carte-episode", 60); w(1); shot("L10-tu-as-tout-vu", focus: false)
        press(.select); waitFor("carte-season", 10); w(1); shot("L11-saison-terminee-fin", focus: false)
        press(.down); press(.right); press(.select); w(3); shot("L12-ferme-fiche", focus: false)
        // 3. intro apprise (É1 puis É2), passée seule sur É3, puis « Oublier le moment de l'intro » : É4 revient au bouton
        play("1-1", from: 26); waitFor("carte-intro", 60); press(.select); w(2)
        play("1-2", from: 34); waitFor("carte-intro", 60); press(.select); w(2)
        play("1-3", from: 26); waitFor("toast", 60); w(0.5); shot("L20-intro-auto", focus: false)
        press(.up); w(1); press(.up); w(2)
        for _ in 0..<16 where !focused().contains("Oublier") { press(.down) }
        shot("L21-oublier-intro")
        press(.select); w(2); shot("L22-intro-oubliee", focus: false)
        play("1-4", from: 26); waitFor("carte-intro", 60); w(1); shot("L23-e4-bouton-sans-auto", focus: false)
        // 4. « Encore un ? » quand l'épisode suivant finirait après le coucher : « Un dernier » choisi d'office
        play("1-3", from: 254, ["-prisme.debug.playFromEach", "1", "-prisme.play.binge", "1", "-prisme.debug.bedIn", "5"])
        waitFor("carte-episode", 60); w(1); press(.select); waitFor("carte-encore", 10); w(1); shot("L30-encore-un-apres-coucher", focus: false)
        back(); w(3)
        // 5. journal : 40 s de lecture, 15 s de pause, 10 s, retour de 10 s, 10 s → environ 60 s comptées
        play("1-5", from: 80); w(40); press(.playPause); w(15); press(.playPause); w(10); press(.left); w(10)
        back(); w(2); back(); w(3); shot("L40-journal-steven", focus: false)
        // 6. mode à deux (Steven + Léa) : zéro spoiler selon la progression de chacun, note pour le profil actif seulement,
        //    film sans proposition (aucune carte « À suivre » vide), journal pour les deux profils
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.open", "series:demo:2001", "-prisme.debug.season", "2"], wait: 14)
        press(.down, 3); w(1); shot("L50-lupin-s2-steven")
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.duo", "1", "-prisme.debug.open", "series:demo:2001", "-prisme.debug.season", "2"], wait: 14)
        press(.down, 3); w(1); shot("L51-lupin-s2-a-deux")
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.duo", "1", "-prisme.debug.noPick", "1", "-prisme.debug.open", "film:demo:1020", "-prisme.debug.playFrom", "500"], wait: 16)
        press(.select); w(30); shot("L52-film-sans-proposition", focus: false)
        waitFor("carte-rate", 60); w(1); shot("L53-tu-as-aime-a-deux", focus: false)
        press(.select); w(3); shot("L54-note-profil-actif", focus: false)
        // 7. profil de Léa seule : son propre journal
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.second", "1", "-prisme.debug.open", "series:demo:2002", "-prisme.debug.playEp", "1-6", "-prisme.debug.playFrom", "100"], wait: 10)
        w(35); back(); w(2); back(); w(3); shot("L60-journal-lea", focus: false)
    }

    /// Lot 2 : Ma liste (envies, propositions, « Tu l'avais oublié ? », Duel, options, rangées) et Ma semaine.
    func lot2() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        func until(_ s: String, _ b: XCUIRemote.Button, _ n: Int = 10) { for _ in 0..<n where !focused().contains(s) { press(b) } }
        func hold() { remote.press(.select, forDuration: 1.2); Thread.sleep(forTimeInterval: 0.8) }
        let base2 = ["-prisme.debug.mylist", "1", "-prisme.debug.profiles", "2", "-prisme.debug.tab", "mine"]
        relaunch(base2, wait: 16)
        w(20)   // fiches TMDB du faux serveur : genres et durées (envies, heures de fin)
        shot("M01-ma-liste-haut")
        until("Sous-onglet Ma liste", .down, 3); shot("M02-sous-onglet")
        press(.down); w(1); shot("M03-envie-rire")
        press(.right, 2); w(1); shot("M04-envie-emotion")
        press(.down); w(1); shot("M05-oublie")
        press(.down); w(1); shot("M06-proposition")
        hold(); shot("M07-options-proposition")
        press(.down); w(0.5); shot("M07b-options-bas")
        back(); w(1); shot("M08-options-fermees")
        until("Duel", .down, 4); shot("M09-bouton-duel")
        press(.select); w(1.5); shot("M10-duel-1")
        let duel = app.descendants(matching: .any)["mnd-0"].exists
        press(.right); w(0.5); shot("M11-duel-droite")
        press(.select); w(1.5); shot("M12-duel-2")
        for _ in 0..<4 where app.descendants(matching: .any)["mnd-0"].exists { press(.select); w(1.5) }
        if duel {
            w(8); shot("M13-gagnant-lance", focus: false)
            back(); w(3); back(); w(3)
        }
        shot("M14-retour-ma-liste")
        for _ in 0..<6 { press(.down) }
        w(1); shot("M15-rangees")
        for _ in 0..<4 { press(.down) }
        w(1); shot("M16-plus-disponible")
        // « Le garder » puis « Tu l'avais oublié ? » disparaît
        for _ in 0..<14 where !focused().contains("Le garder") { press(.up) }
        press(.select); w(2); shot("M17-garde")
        // Ma semaine : chiffres, colonnes, options, retirer de l'historique
        for _ in 0..<12 where !focused().contains("Sous-onglet") { press(.up) }
        until("Sous-onglet Ma semaine", .right, 3); w(1.5); shot("M20-ma-semaine")
        press(.down); w(1); shot("M21-semaine-titre")
        hold(); shot("M22-options-historique")
        press(.down, 2); press(.select); w(2); shot("M23-retire-historique")
        // profil de Léa : sa liste et sa semaine (vide)
        relaunch(base2 + ["-prisme.debug.second", "1"], wait: 16)
        shot("M30-ma-liste-lea")
        until("Sous-onglet Ma liste", .down, 3); until("Sous-onglet Ma semaine", .right, 3); w(1.5); shot("M31-semaine-lea-vide")
    }

    /// Lot 3 : recherche (clavier PRISME, fautes, phrases, filtres, aperçu, récentes, Siri / clavier d'Apple, gros catalogue)
    /// Lot 4 : grande affiche en diapositives (films et séries), « Le moment » selon le jour, télé du soir, bientôt chez toi.
    func lot4() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        func hold() { remote.press(.select, forDuration: 1.2); Thread.sleep(forTimeInterval: 1) }
        let base4 = ["-prisme.debug.profiles", "2", "-prisme.debug.tab", "films"]
        // dimanche après-midi : arrivée, le moment (dimanche en famille), à l'honneur, télé, bientôt
        relaunch(base4 + ["-prisme.debug.day", "sun", "-prisme.debug.hour", "14"], wait: 16)
        w(25)   // fiches TMDB du faux serveur, puis diapositives
        relaunch(base4 + ["-prisme.debug.day", "sun", "-prisme.debug.hour", "14"], wait: 20)
        shot("H01-films-1")
        for i in 2...6 { press(.right); w(1.5); shot("H0\(i)-films-\(i)") }
        // le moment : OK maintenu, puis « Voir la collection »
        relaunch(base4 + ["-prisme.debug.day", "sun", "-prisme.debug.hour", "14"], wait: 20)
        press(.right); w(1.5); hold(); shot("H10-moment-ok-maintenu"); back(); w(1)
        press(.select); w(3); shot("H11-moment-collection"); back(); w(1.5); shot("H12-retour-accueil")
        press(.down); w(1); shot("H13-descente-ce-soir"); press(.up); w(1); shot("H14-remonte-affiche")
        press(.up); w(1); shot("H15-barre")
        // autres jours : semaine, vendredi (à deux), décembre
        for (d, n) in [("mon", "H20-moment-semaine"), ("fri", "H21-moment-vendredi"), ("dec", "H22-moment-decembre")] {
            relaunch(base4 + ["-prisme.debug.day", d, "-prisme.debug.hour", "14"], wait: 20)
            press(.right); w(1.5); shot(n)
        }
        // vendredi : « Passer en mode à deux » (OK maintenu, 2e choix)
        relaunch(base4 + ["-prisme.debug.day", "fri", "-prisme.debug.hour", "14"], wait: 20)
        press(.right); w(1.5); hold(); press(.down); w(0.5); shot("H23-vendredi-menu"); press(.select); w(2); shot("H24-mode-a-deux")
        // le soir : la télé d'abord ; rappel
        relaunch(base4 + ["-prisme.debug.day", "mon", "-prisme.debug.hour", "20", "-prisme.debug.remindNow", "1"], wait: 20)
        shot("H30-soir-tele")
        hold(); shot("H31-tele-ok-maintenu"); press(.select); w(2); shot("H32-rappel-programme")
        w(40); shot("H33-rappel-arrive")
        press(.select); w(8); shot("H34-chaine-lancee", focus: false); back(); w(2)
        // bientôt chez toi : Préviens-moi
        relaunch(base4 + ["-prisme.debug.day", "sun", "-prisme.debug.hour", "14"], wait: 20)
        press(.left); w(1.5); shot("H40-bientot"); press(.select); w(1.5); shot("H41-alerte-activee")
        // séries
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.tab", "series", "-prisme.debug.day", "sat", "-prisme.debug.hour", "14"], wait: 20)
        shot("S01-series-1")
        for i in 2...5 { press(.right); w(1.5); shot("S0\(i)-series-\(i)") }
        relaunch(["-prisme.debug.profiles", "2", "-prisme.debug.tab", "series", "-prisme.debug.day", "tue", "-prisme.debug.hour", "14"], wait: 20)
        press(.right); w(1.5); shot("S10-series-semaine")
    }

    /// Lot 4 : bandeau « Cette nuit » (dernière visite il y a 3 jours, alertes), puis une 2e ouverture (rien), puis le dimanche soir.
    func lot4n() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        let b = ["-prisme.debug.profiles", "2", "-prisme.debug.tab", "films", "-prisme.debug.mylist", "1"]
        relaunch(b, wait: 30)   // catalogue et fiches (Dune doit avoir sa fiche TMDB)
        relaunch(b + ["-prisme.debug.lastVisit", "3", "-prisme.debug.filmAlert", "1000:Dune", "-prisme.debug.seriesAlert", "series:demo:2001", "-prisme.debug.day", "mon", "-prisme.debug.hour", "10"], wait: 2.5)
        shot("N01-cette-nuit")
        w(8); shot("N02-efface")
        relaunch(b + ["-prisme.debug.day", "mon", "-prisme.debug.hour", "10"], wait: 3)
        shot("N03-deuxieme-ouverture")
        relaunch(b + ["-prisme.debug.day", "sun", "-prisme.debug.hour", "19"], wait: 3)
        shot("N04-dimanche-soir")
    }

    func lot3() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        let grid = ["abcdef", "ghijkl", "mnopqr", "stuvwx", "yz1234", "567890"].map { Array($0) }
        var at = (0, 0)
        func pos(_ c: Character) -> (Int, Int) { for (r, row) in grid.enumerated() { if let i = row.firstIndex(of: c) { return (r, i) } }; return (0, 0) }
        func typeWord(_ s: String) {
            for c in s {
                let t = pos(c)
                if t.0 > at.0 { press(.down, t.0 - at.0) } else if t.0 < at.0 { press(.up, at.0 - t.0) }
                if t.1 > at.1 { press(.right, t.1 - at.1) } else if t.1 < at.1 { press(.left, at.1 - t.1) }
                at = t; press(.select); w(0.3)
            }
        }
        let q = { (s: String) -> [String] in ["-prisme.debug.tab", "search", "-prisme.debug.q", s] }
        relaunch(["-prisme.debug.tab", "search"], wait: 16)
        w(15)
        shot("R01-vide")
        press(.down); w(0.5); at = (0, 0); shot("R02-clavier")
        typeWord("nolan"); w(2); shot("R03-nolan-tape")
        press(.right, 6); w(1.5); shot("R04-nolan-apercu")
        press(.down); w(1); shot("R05-nolan-2e")
        press(.playPause); w(10); shot("R06-lecture-directe", focus: false)
        back(); w(3); back(); w(3); shot("R07-retour-recherche")
        relaunch(q("inceptoin"), wait: 16); w(10); press(.down); press(.right, 7); w(1.5); shot("R10-faute")
        relaunch(q("inceptin"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R10b-lettre-oubliee")
        relaunch(q("comedie"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R11-phrase-genre")
        relaunch(q("science fiction annees 2010"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R11b-phrase-decennie")
        relaunch(q("series avec omar sy"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R12-phrase-acteur")
        relaunch(q("le match en ce moment"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R13-match")
        relaunch(q("omar") + ["-prisme.debug.filt", "actor"], wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R14-filtre-acteurs")
        press(.select); w(4); shot("R16-acteur-fiche")
        back(); w(2)
        relaunch(q("tf1"), wait: 16); w(8); press(.down); press(.right, 7); w(1.5); shot("R17-chaine-apercu")
        press(.select); w(8); shot("R17b-chaine-lancee", focus: false); back(); w(3)
        // récentes : les recherches ouvertes plus haut
        relaunch(["-prisme.debug.tab", "search"], wait: 16); w(4); press(.down); press(.right, 7); w(1); shot("R18-recentes")
        // Siri / clavier d'Apple : la touche ouvre le clavier du système, le texte revient dans la recherche
        press(.left, 8); w(0.5); at = (0, 0)
        for _ in 0..<12 where !focused().contains("« a »") { press(.up) }
        press(.down, 6); press(.right, 2); w(0.5); shot("R19-touche-siri")
        press(.select); w(3); shot("R20-clavier-apple", focus: false)
        if app.keyboards.count > 0 { app.typeText("lupin"); w(2); shot("R21-texte-tape", focus: false) }
        else { attach("R21-clavier", "clavier d'Apple non détecté") }
        back(); w(3); shot("R22-texte-revenu")
    }

    /// Lot 3 : recherche sur le gros catalogue (40 000 films, 20 000 séries, 20 000 chaînes) — temps de réponse dans donnees.txt
    func lot3g() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        app.terminate()
        app.launchArguments = ["-prisme.debug.demoServer", "http://127.0.0.1:8097", "-prisme.debug.tmdbKey", "demo",
                               "-prisme.debug.tmdbBase", "http://127.0.0.1:8099/tmdb/3", "-prisme.debug.imgBase", "http://127.0.0.1:8099/img",
                               "-prisme.debug.itunesBase", "http://127.0.0.1:8099/itunes", "-prisme.debug.bgTrailer", "off", "-prisme.debug.tab", "search"]
        app.launch(); w(330)   // import complet du gros catalogue
        shot("G01-gros-catalogue")
        press(.down); w(0.5)
        // « fil » : f, i, l (depuis « a » : f = rangée 0 col 5 ; i = rangée 1 col 2 ; l = rangée 1 col 5) → 40 000 « Film de test … »
        press(.right, 5); press(.select); w(4); shot("G02-f")
        press(.down); press(.left, 3); press(.select); w(4); shot("G03-fi")
        press(.right, 3); press(.select); w(4); shot("G04-fil")
        press(.right, 6); w(2); shot("G05-apercu")
    }

    func finFilm() {
        let w = { (t: Double) in Thread.sleep(forTimeInterval: t) }
        func film(_ id: String, from: Int, _ extra: [String] = []) {
            relaunch(["-prisme.debug.open", "film:demo:" + id, "-prisme.debug.playFrom", String(from)] + extra, wait: 16)
            press(.select)
        }
        // À suivre : suite de la saga (Spider-Man Homecoming → Far From Home), pause pendant le compte à rebours
        film("1014", from: 116); waitFor("carte-film", 60); w(2); shot("F01-a-suivre-saga", focus: false)
        press(.playPause); w(1); shot("F02-pause-compte-arrete", focus: false)
        w(4); shot("F02b-pause-toujours", focus: false)
        press(.playPause); waitFor("toast", 30); shot("F03-film-suivant-lance", focus: false)
        // scène après le générique (No Way Home) : carte, 👍 depuis la carte
        film("1012", from: 116); waitFor("carte-post", 60); w(1); shot("F04-scene-apres-generique", focus: false)
        press(.right, 2); press(.select); w(2); shot("F05-note-pouce", focus: false)
        press(.left, 2); press(.select); w(1); shot("F06-carte-fermee", focus: false)
        // fin réelle du film : À suivre revient ; Rester ferme (déjà noté : pas de question)
        film("1012", from: 533); waitFor("carte-film", 60); w(1); shot("F07-fin-a-suivre", focus: false)
        press(.right); press(.select); w(3); shot("F08-rester-quitte", focus: false)
        // recommandation (Le Parrain), Rester, puis fin : « Tu as aimé … ? »
        film("1020", from: 116); waitFor("carte-film", 60); w(1); shot("F09-a-suivre-reco", focus: false)
        back(); w(1); shot("F10-rester", focus: false)
        film("1020", from: 533); waitFor("carte-film", 60); w(1); shot("F10b-fin-du-film", focus: false)
        back(); waitFor("carte-rate", 10); w(1); shot("F11-tu-as-aime", focus: false)
        press(.select); w(3); shot("F12-note-fermee", focus: false)
        film("1020", from: 500); waitFor("carte-film", 60); back(); w(1); back(); w(3); shot("F13-pas-de-seconde-demande", focus: false)
        // fin après l'heure du coucher : pas de lancement automatique
        film("1014", from: 116, ["-prisme.debug.bedIn", "1"]); waitFor("carte-film", 60); w(1); shot("F14-apres-coucher-sans-compte", focus: false)
    }
}
