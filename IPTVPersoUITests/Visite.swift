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
        app.launchArguments = ["-prisme.debug.demoServer", "http://127.0.0.1:8099",
                               "-prisme.debug.tmdbKey", "demo",
                               "-prisme.debug.tmdbBase", "http://127.0.0.1:8099/tmdb/3",
                               "-prisme.debug.imgBase", "http://127.0.0.1:8099/img"]
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

    func press(_ b: XCUIRemote.Button, _ n: Int = 1) { for _ in 0..<n { remote.press(b); Thread.sleep(forTimeInterval: 0.45) } }

    /// Va sur un onglet de la barre du haut (Films = 0, Séries = 1, TV = 2, Ma liste = 3, Recherche = 4, Réglages = 5).
    func tab(_ i: Int) {
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
        for i in 1...7 { press(.down); shot(String(format: "02-films-bas-%02d", i)) }
        press(.right, 6); shot("03-films-droite-bas")
        press(.up, 12); shot("04-films-retour-haut")

        // fiche film (bouton de la grande affiche : appui long → Voir la fiche)
        press(.up, 8); press(.down); shot("05-films-bas-depuis-barre")
        press(.down); press(.select); Thread.sleep(forTimeInterval: 3); shot("06-fiche-film")
        for i in 1...6 { press(.down); shot(String(format: "07-fiche-film-bas-%02d", i)) }
        press(.right, 3); shot("08-fiche-film-droite")
        press(.menu); Thread.sleep(forTimeInterval: 2)

        tab(1); shot("10-series-ouverture")
        for i in 1...6 { press(.down); shot(String(format: "11-series-bas-%02d", i)) }
        press(.up, 12); press(.down, 2); press(.select); Thread.sleep(forTimeInterval: 3); shot("12-fiche-serie")
        press(.right, 2); shot("13-fiche-serie-panneau")
        press(.down, 3); shot("14-fiche-serie-episodes")
        press(.right, 2); shot("15-fiche-serie-episodes-droite")
        press(.menu); Thread.sleep(forTimeInterval: 2)

        tab(2); shot("20-tv-ouverture")
        for i in 1...4 { press(.down); shot(String(format: "21-tv-bas-%02d", i)) }
        press(.right, 6); shot("22-tv-droite")
        press(.left, 12); shot("23-tv-gauche")
        press(.up, 10); shot("24-tv-retour-barre")

        tab(3); shot("30-maliste")
        press(.down, 2); press(.up, 4); shot("31-maliste-retour-barre")

        tab(5); shot("40-reglages")
        press(.right, 4); press(.up, 6); shot("41-reglages-droite-haut")
        press(.down, 2); press(.left, 4); press(.up, 6); shot("42-reglages-gauche-haut")
    }
}
