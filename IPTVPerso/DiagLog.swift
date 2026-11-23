import Foundation
import UIKit

/// 253 : journal de diagnostic (sur l'Apple TV de Steven) — écran affiché, blocages de l'interface de plus de 2 s,
/// fermeture inattendue au lancement précédent. Aucun mot de passe, aucune adresse de flux : seulement des noms
/// d'écrans et des durées. Téléchargeable depuis la page « Sauvegarde sur l'iPhone » (prisme-journal.txt).
enum DiagLog {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var lines: [String] = []
    nonisolated(unsafe) private static var loaded = false
    nonisolated(unsafe) private static var screenName = "lancement"
    nonisolated(unsafe) private static var lastPong = Date()
    nonisolated(unsafe) private static var hangStart: Date?
    /// état de l'appli, tenu à jour sur le fil principal (UIApplication ne se lit pas depuis le fil de surveillance)
    nonisolated(unsafe) private static var active = true
    private static let runningKey = "prisme.diag.running"
    private static let lastScreenKey = "prisme.diag.screen"

    private static var file: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("prisme-journal.txt")
    }

    nonisolated static func add(_ s: String) {
        lock.lock(); defer { lock.unlock() }
        if !loaded {
            loaded = true
            if let f = file, let t = try? String(contentsOf: f, encoding: .utf8) { lines = t.split(separator: "\n").map(String.init) }
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "dd/MM HH:mm:ss"
        lines.append(f.string(from: Date()) + "  " + s)
        if lines.count > 400 { lines.removeFirst(lines.count - 400) }
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    static var text: String {
        _ = { add("journal téléchargé") }()
        lock.lock(); defer { lock.unlock() }
        return "Journal de prisme " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
            + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")\n\n" + lines.joined(separator: "\n") + "\n"
    }

    /// écran affiché (onglet, rubrique, fiche…)
    static func screen(_ s: String) {
        guard s != screenName else { return }
        screenName = s
        UserDefaults.standard.set(s, forKey: lastScreenKey)
        add("écran : " + s)
    }

    /// au lancement : fermeture inattendue la fois précédente ? puis surveillance des blocages
    static func start() {
        let d = UserDefaults.standard
        if d.bool(forKey: runningKey) {
            add("⚠︎ le lancement précédent s'est fermé sans passer par l'arrière-plan (plantage ou arrêt forcé) · dernier écran : " + (d.string(forKey: lastScreenKey) ?? "?"))
        }
        d.set(true, forKey: runningKey)
        add("lancement · tvOS " + UIDevice.current.systemVersion)
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            UserDefaults.standard.set(false, forKey: runningKey)
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in active = true; lastPong = Date() }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in active = false }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            UserDefaults.standard.set(true, forKey: runningKey); lastPong = Date()
        }
        watchdog()
    }

    /// fil de surveillance : le fil principal répond-il toutes les 0,5 s ? Un blocage de plus de 2 s est noté
    /// avec sa durée et l'écran affiché (c'est ce qui figeait la page Replay sur l'Apple TV).
    private static func watchdog() {
        let q = DispatchQueue(label: "prisme.watchdog", qos: .utility)
        func tick() {
            DispatchQueue.main.async { lastPong = Date() }
            q.asyncAfter(deadline: .now() + 0.5) {
                let late = Date().timeIntervalSince(lastPong)
                if late > 2 {
                    if hangStart == nil { hangStart = lastPong }
                } else if let h = hangStart {
                    let dur = Date().timeIntervalSince(h)
                    hangStart = nil
                    if active || dur < 60 {
                        add(String(format: "blocage de l'interface : %.1f s · écran : %@", dur, screenName))
                    }
                }
                tick()
            }
        }
        tick()
    }
}
