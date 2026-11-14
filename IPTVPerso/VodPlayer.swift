import SwiftUI
import UIKit
import TVVLCKit
import Combine

/// Ce qu'on lit : un film ou un épisode (avec l'épisode suivant pour enchaîner).
struct VodRequest: Identifiable {
    let id = UUID()
    let url: URL
    let key: String          // clé de reprise (film ou épisode)
    let item: String         // id du film / de la série
    let title: String
    let subtitle: String
    let icon: String
    let startAt: Double
    var next: (() -> VodRequest?)? = nil
    /// « En 2 soirées » : arrêt prévu (secondes) ; calé sur le début de chapitre le plus proche s'il y en a un à ± 10 min
    var stopAt: Double? = nil
    /// bandeau du lecteur (simulateur) : « FILM · 2024 », « 4K · VF · chez Lune », casting
    var kicker = ""
    var meta = ""
    var cast: [String] = []
    /// autres versions du même film (libellé, adresse) : « Version » du panneau, reprise au même moment
    var versions: [(label: String, url: URL)] = []
}

struct VodPlayerView: View {
    let request: VodRequest
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VodPlayerRepresentable(request: request, onClose: { dismiss() }).ignoresSafeArea()
    }
}

struct VodPlayerRepresentable: UIViewControllerRepresentable {
    let request: VodRequest
    let onClose: () -> Void
    func makeUIViewController(context: Context) -> VodPlayerController { VodPlayerController(request: request, onClose: onClose) }
    func updateUIViewController(_ c: VodPlayerController, context: Context) {}
    static func dismantleUIViewController(_ c: VodPlayerController, coordinator: ()) { c.stop() }
}

/// Lecteur des films et séries : VLC, reprise là où tu t'étais arrêté, ±10 s avec gauche/droite.
/// Interface du simulateur (PlayerOverlay) : ↑ Raccourcis puis Lecture, ↓ « Qu'a-t-il dit ? », son de nuit,
/// marque-page du sommeil (90 min sans touche), arrêt à l'heure du coucher, fin de partie 1 (« En 2 soirées »).
final class VodPlayerController: UIViewController, VLCMediaPlayerDelegate {
    private var req: VodRequest
    private let onClose: () -> Void
    private let player = VLCMediaPlayer()
    private let videoView = UIView()
    private let ui = PlayerUI()
    private var host: UIHostingController<PlayerOverlay>!
    private var watch: AnyCancellable?
    private var hideWork: DispatchWorkItem?
    private var saveTimer: Timer?
    private var minuteTimer: Timer?
    private var seeked = false
    private var retried = false
    private var cutAt: Double?
    private var cutDone = false
    private var bedDone = false
    private var seekWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var menuDown: Date?
    private var menuWork: DispatchWorkItem?
    // marque-page du sommeil
    private var lastInput = Date()
    private var lastInputPos: Double = 0
    private var sleepTimer: Timer?
    // « Qu'a-t-il dit ? »
    private var saidRestore: (until: Double, sub: Int32)?
    // reprise après un changement (version, son de nuit)
    private var restartAt: Double?
    private var versionIndex = 0
    private var shownTracks = false

    private var sleepAfter: TimeInterval { Double(Debug.sleepAfterSeconds ?? 90 * 60) }

    init(request: VodRequest, onClose: @escaping () -> Void) {
        self.req = request; self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        videoView.frame = view.bounds; videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)

        setupUI()
        host = UIHostingController(rootView: PlayerOverlay(m: ui))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds; host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        // quand le panneau s'ouvre ou se ferme, la sélection de l'Apple TV entre dans l'interface ou en sort
        watch = ui.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { guard let self else { return }; self.setNeedsFocusUpdate(); self.updateFocusIfNeeded() }
        }

        player.drawable = videoView
        player.delegate = self
        start()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.savePosition() }
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.minuteCheck() }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { ui.interactive ? [host.view] : [] }

    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }

    func stop() {
        savePosition()
        saveTimer?.invalidate(); saveTimer = nil
        minuteTimer?.invalidate(); minuteTimer = nil
        sleepTimer?.invalidate(); sleepTimer = nil
        if player.isPlaying || player.state != .stopped { player.stop() }
    }

    // MARK: interface

    private func setupUI() {
        ui.title = req.title
        ui.kicker = req.kicker.isEmpty ? req.subtitle : req.kicker
        ui.meta = req.meta
        ui.cast = req.cast
        ui.versions = req.versions.map(\.label)
        ui.versionCur = 0
        ui.bedMinutes = Debug.bedInMinutes.map { Self.eveningNow() + $0 } ?? ProfileStore.shared.bedMinutes
        ui.night = UserDefaults.standard.string(forKey: ProfileStore.shared.key("prisme.player.night")) ?? "auto"
        ui.bedStop = UserDefaults.standard.bool(forKey: ProfileStore.shared.key("prisme.player.bedstop"))
        ui.aspect = UserDefaults.standard.string(forKey: ProfileStore.shared.key("prisme.player.aspect")) ?? "auto"
        ui.loadHabits()
        ui.nightActive = nightWanted
        ui.touch = { [weak self] in self?.noteInput() }
        ui.togglePause = { [weak self] in self?.togglePause() }
        ui.setAudio = { [weak self] i in self?.player.currentAudioTrackIndex = i; self?.ui.audioCur = i; self?.toast("Audio : " + (self?.ui.audio.first { $0.id == i }?.name ?? "")) }
        ui.setSub = { [weak self] i in self?.player.currentVideoSubTitleIndex = i; self?.ui.subCur = i; self?.saidRestore = nil }
        ui.setVersion = { [weak self] i in self?.switchVersion(i) }
        ui.setAspect = { [weak self] a in self?.applyAspect(a); UserDefaults.standard.set(a, forKey: ProfileStore.shared.key("prisme.player.aspect")) }
        ui.setNight = { [weak self] n in self?.changeNight(n) }
        ui.setBedStop = { [weak self] on in
            guard let self else { return }
            self.ui.bedStop = on
            UserDefaults.standard.set(on, forKey: ProfileStore.shared.key("prisme.player.bedstop"))
            self.toast(on ? "Arrêt à " + PlayerUI.hm(self.ui.bedMinutes) + " : pause et place gardée" : "Arrêt au coucher désactivé")
        }
        ui.whatSaid = { [weak self] in self?.whatSaid() }
        ui.stillWatching = { [weak self] in self?.endSleepAsk(pause: false) }
        ui.pauseForLater = { [weak self] in self?.endSleepAsk(pause: true) }
    }

    private func start(at: Double? = nil) {
        if player.state != .stopped { player.stop() }     // une seule connexion
        seeked = false; retried = false; shownTracks = false
        restartAt = at
        ui.message = nil; ui.loading = true
        let url = req.versions.indices.contains(versionIndex) ? req.versions[versionIndex].url : req.url
        let media = VLCMedia(url: url)
        media.addOption(":network-caching=2000")
        if ui.nightActive {
            // son de nuit : compresseur de VLC (sons forts adoucis) — se règle au démarrage de la lecture
            for o in [":audio-filter=compressor", ":compressor-rms-peak=0.2", ":compressor-attack=25", ":compressor-release=100",
                      ":compressor-threshold=-20", ":compressor-ratio=4", ":compressor-knee=4.5", ":compressor-makeup-gain=7"] { media.addOption(o) }
        }
        player.media = media
        applyEqualizer()
        player.play()
        showOSD()
    }

    private var duration: Double { Double(player.media?.length.intValue ?? 0) / 1000 }
    private var position: Double { Double(player.time.intValue) / 1000 }

    private func savePosition(at p0: Double? = nil) {
        let d = duration, p = p0 ?? position
        guard d > 60, p > 0 else { return }
        let r = req
        Task { @MainActor in WatchStore.shared.save(key: r.key, pos: p, dur: d, title: r.title, icon: r.icon, item: r.item, ep: r.subtitle.isEmpty ? nil : r.subtitle) }
    }

    private func refresh() {
        ui.pos = position; ui.dur = duration; ui.paused = !player.isPlaying
    }

    private func showOSD() {
        refresh()
        ui.osd = true
        hideWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.player.isPlaying, !self.ui.interactive else { return }
            self.ui.osd = false
        }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: w)
    }

    private func toast(_ t: String) {
        ui.toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in if self?.ui.toast == t { self?.ui.toast = nil } }
    }

    private func noteInput() { lastInput = Date(); lastInputPos = position }

    private func togglePause() {
        if player.isPlaying { player.pause() } else { player.play() }
        showOSD()
    }

    /// Avance / retour : les appuis rapides s'additionnent, le saut se fait une seule fois.
    private func seek(_ s: Double) {
        ui.pending += s
        showOSD()
        seekWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let target = max(0, min(self.duration - 2, self.position + self.ui.pending))
            self.ui.pending = 0
            self.player.time = VLCTime(int: Int32(target * 1000))
            self.refresh()
        }
        seekWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    // MARK: télécommande (quand aucun panneau n'est ouvert ; sinon c'est l'interface qui reçoit les touches)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return super.pressesBegan(presses, with: event) }
        noteInput()
        if ui.interactive { return super.pressesBegan(presses, with: event) }
        switch press.type {
        case .menu:
            // Retour maintenu : quitter ; Retour court : cacher le bandeau, ou le montrer (avec la consigne) s'il est caché
            menuDown = Date()
            let w = DispatchWorkItem { [weak self] in self?.quit() }
            menuWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: w)
        case .leftArrow: seek(-10)
        case .rightArrow: seek(10)
        case .upArrow: ui.panel = .shortcuts; ui.osd = true
        case .downArrow: ui.options = true; ui.osd = true
        case .select where (cutDone || bedDone) && !player.isPlaying:
            closeWork?.cancel(); ui.message = nil; player.play(); showOSD()
        case .select: if ui.osd { togglePause() } else { showOSD() }
        case .playPause: togglePause()
        default: super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first, press.type == .menu, let d = menuDown else { return super.pressesEnded(presses, with: event) }
        menuDown = nil
        guard Date().timeIntervalSince(d) < 0.7 else { return }
        menuWork?.cancel()
        if ui.message != nil && (cutDone || bedDone) { quit(); return }
        if ui.osd { ui.osd = false } else {
            ui.hint = "Retour maintenu : quitter · ↑ raccourcis puis tous les réglages · ↓ options"
            showOSD()
        }
    }

    private func quit() { stop(); onClose() }

    // MARK: lecture

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // reprise : on saute à la position enregistrée (ou à celle d'avant un changement) dès que la durée est connue
            if !self.seeked, self.duration > 0 {
                self.seeked = true
                let to = self.restartAt ?? (self.req.startAt > 0 ? self.req.startAt : nil)
                if let to { self.player.time = VLCTime(int: Int32(to * 1000)) }
                self.restartAt = nil
                self.lastInputPos = to ?? 0
            }
            if !self.shownTracks, self.duration > 0 { self.shownTracks = true; self.readTracks() }
            if self.ui.osd || self.ui.interactive { self.refresh() } else { self.ui.pos = self.position }
            if let r = self.saidRestore, self.position >= r.until {
                // « Qu'a-t-il dit ? » : le passage est revu, les sous-titres d'avant reviennent
                self.player.currentVideoSubTitleIndex = r.sub; self.ui.subCur = r.sub; self.saidRestore = nil
            }
            self.checkCut()
            self.checkSleep()
        }
    }

    private func readTracks() {
        let an = player.audioTrackNames as? [String] ?? [], ai = player.audioTrackIndexes as? [NSNumber] ?? []
        ui.audio = zip(ai, an).filter { $0.0.int32Value >= 0 }.map { PlayerOption(id: $0.0.int32Value, name: $0.1) }
        ui.audioCur = player.currentAudioTrackIndex
        let sn = player.videoSubTitlesNames as? [String] ?? [], si = player.videoSubTitlesIndexes as? [NSNumber] ?? []
        ui.subs = zip(si, sn).map { PlayerOption(id: $0.0.int32Value, name: $0.1) }
        ui.subCur = player.currentVideoSubTitleIndex
        applyAspect(ui.aspect)
        var info: [(String, String)] = []
        let sz = player.videoSize
        if sz.width > 0 { info.append(("Image", "\(Int(sz.width)) × \(Int(sz.height))")) }
        info.append(("Durée", PlayerUI.hms(duration)))
        info.append(("Pistes audio", "\(max(1, ui.audio.count))"))
        info.append(("Sous-titres", "\(ui.subs.filter { $0.id >= 0 }.count)"))
        let ch = player.numberOfChapters(forTitle: player.currentTitleIndex)
        if ch > 0 { info.append(("Chapitres", "\(ch)")) }
        let url = req.versions.indices.contains(versionIndex) ? req.versions[versionIndex].url : req.url
        info.append(("Serveur", url.host ?? "—"))       // jamais l'adresse complète (elle contient tes identifiants)
        info.append(("Son de nuit", ui.nightActive ? "actif" : "inactif"))
        ui.info = info
    }

    // MARK: image, versions

    private func applyAspect(_ a: String) {
        ui.aspect = a
        func c(_ s: String?) -> UnsafeMutablePointer<CChar>? { s.flatMap { strdup($0) } }
        switch a {
        case "fill":
            let b = view.bounds.size
            player.videoAspectRatio = nil
            player.videoCropGeometry = c("\(Int(b.width)):\(Int(b.height))")
        case "16:9", "4:3": player.videoCropGeometry = nil; player.videoAspectRatio = c(a)
        case "21:9": player.videoAspectRatio = nil; player.videoCropGeometry = c("21:9")
        default: player.videoAspectRatio = nil; player.videoCropGeometry = nil
        }
    }

    private func switchVersion(_ i: Int) {
        guard req.versions.indices.contains(i), i != versionIndex else { return }
        let p = position
        versionIndex = i; ui.versionCur = i
        start(at: p)
        toast("Version : " + req.versions[i].label)
    }

    // MARK: son de nuit

    private static func nowMinutes() -> Int { let c = Calendar.current.dateComponents([.hour, .minute], from: Date()); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }
    /// minutes depuis minuit, les heures avant 5 h comptées comme « 24 h + » (même échelle que l'heure du coucher)
    private static func eveningNow() -> Int { let n = nowMinutes(); return n < 300 ? n + 1440 : n }

    private var nightWanted: Bool {
        switch ui.night {
        case "on": return true
        case "off": return false
        default: return Self.eveningNow() >= ui.bedMinutes
        }
    }

    /// égaliseur de VLC : graves baissés, voix (1 à 4 kHz) remontées, aigus forts adoucis — s'applique sans couper la lecture
    private func applyEqualizer() {
        guard ui.nightActive else { player.equalizer = nil; return }
        let eq = VLCAudioEqualizer()
        for b in eq.bands {
            let f = b.frequency
            b.amplification = f < 250 ? -6 : (f >= 1000 && f <= 4000 ? 4 : (f > 8000 ? -2 : 0))
        }
        eq.preAmplification = 2
        player.equalizer = eq
    }

    private func changeNight(_ n: String) {
        ui.night = n
        UserDefaults.standard.set(n, forKey: ProfileStore.shared.key("prisme.player.night"))
        let want = nightWanted
        guard want != ui.nightActive else { return }
        ui.nightActive = want
        // le compresseur ne se règle qu'au démarrage : relance au même moment
        start(at: position)
        toast(want ? "Son de nuit activé : voix plus claires, sons forts adoucis" : "Son de nuit désactivé")
    }

    /// Toutes les 20 s : « Auto après le coucher » (une seule relance), arrêt au coucher.
    private func minuteCheck() {
        if ui.night == "auto", !ui.nightActive, nightWanted, player.isPlaying { changeNight("auto") }
        checkBed()
    }

    // MARK: « Qu'a-t-il dit ? »

    private func whatSaid() {
        ui.options = false
        let here = position
        let names = ui.subs.filter { $0.id >= 0 }
        let fr = names.first { n in
            let x = n.name.lowercased()
            return x.contains("fran") || x.contains("french") || x.range(of: #"\b(fr|fre|fra|vf|vff|vfq)\b"#, options: .regularExpression) != nil
        }
        player.time = VLCTime(int: Int32(max(0, here - 10) * 1000))
        if let f = fr {
            if ui.subCur != f.id { saidRestore = (until: here + 1, sub: ui.subCur) }
            player.currentVideoSubTitleIndex = f.id; ui.subCur = f.id
            toast("10 s en arrière · sous-titres français pour ce passage")
        } else {
            toast("10 s en arrière · pas de sous-titres français dans ce fichier")
        }
        showOSD()
    }

    // MARK: marque-page du sommeil

    private func checkSleep() {
        guard player.isPlaying, ui.sleepLeft == nil, !bedDone, !cutDone else { return }
        guard Date().timeIntervalSince(lastInput) >= sleepAfter else { return }
        ui.sleepLeft = 15
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self, let s = self.ui.sleepLeft else { t.invalidate(); return }
            if s <= 1 { t.invalidate(); self.endSleepAsk(pause: true) } else { self.ui.sleepLeft = s - 1 }
        }
    }

    private func endSleepAsk(pause: Bool) {
        sleepTimer?.invalidate(); sleepTimer = nil
        ui.sleepLeft = nil
        if pause {
            // pause, et la place gardée est celle de la dernière touche (pas celle où on s'est endormi)
            player.pause()
            let back = lastInputPos
            savePosition(at: back)
            ui.message = "Pause · ta place est gardée à " + PlayerUI.hms(back) + "\nlà où tu as arrêté de réagir.\n\nOK pour reprendre"
            seekOnResume = back
        }
        noteInput()
    }
    private var seekOnResume: Double?

    // MARK: arrêt à l'heure du coucher

    private func checkBed() {
        guard ui.bedStop, !bedDone, !cutDone, player.isPlaying else { return }
        guard Self.eveningNow() >= ui.bedMinutes else { return }
        bedDone = true
        // l'arrêt au coucher passe avant « Tu regardes toujours ? »
        sleepTimer?.invalidate(); ui.sleepLeft = nil
        player.pause()
        savePosition()
        ui.message = "Il est " + PlayerUI.hm(Self.nowMinutes()) + " · c'est l'heure de dormir\nBonne nuit ! La suite t'attend sur la fiche et dans « Reprendre ».\n\nOK pour continuer quand même · fermeture dans 10 s"
        let w = DispatchWorkItem { [weak self] in guard let self, !self.player.isPlaying else { return }; self.quit() }
        closeWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: w)
    }

    /// Partie 1 d'un film en deux soirées : pause à la coupure, position gardée, « Bonne nuit ! », fermeture après 10 s.
    private func checkCut() {
        guard let s = req.stopAt, !cutDone, !bedDone, duration > 0 else { return }
        if cutAt == nil {
            cutAt = s
            // chapitres du fichier : on se cale sur le début de chapitre le plus proche (± 10 min), sinon l'heure choisie
            let ch = player.chapterDescriptions(ofTitle: player.currentTitleIndex) as? [[String: Any]] ?? []
            let starts = ch.compactMap { ($0[VLCChapterDescriptionTimeOffset] as? NSNumber)?.doubleValue }.map { $0 / 1000 }.filter { $0 > 60 }
            if let best = starts.min(by: { abs($0 - s) < abs($1 - s) }), abs(best - s) <= 600 { cutAt = best }
        }
        guard let c = cutAt, position >= c else { return }
        cutDone = true
        sleepTimer?.invalidate(); ui.sleepLeft = nil
        player.pause()
        savePosition()
        let rest = max(1, Int((duration - position) / 60))
        ui.message = "FIN DE LA PARTIE 1\nBonne nuit !\nLa partie 2 (\(rest >= 60 ? "\(rest / 60) h " + String(format: "%02d", rest % 60) : "\(rest) min")) t'attend sur la fiche et dans « Reprendre ».\n\nOK pour continuer quand même · fermeture dans 10 s"
        let w = DispatchWorkItem { [weak self] in guard let self, !self.player.isPlaying else { return }; self.quit() }
        closeWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: w)
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.player.state {
            case .playing:
                self.ui.loading = false; self.ui.paused = false
                if self.ui.message != nil && !self.cutDone && !self.bedDone { self.ui.message = nil }
                if let b = self.seekOnResume { self.seekOnResume = nil; self.player.time = VLCTime(int: Int32(b * 1000)) }
            case .paused:
                self.ui.loading = false; self.ui.paused = true
            case .opening, .buffering:
                if !self.player.isPlaying { self.ui.loading = true }
            case .error:
                if !self.retried { self.retried = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.player.play() }; return }
                self.ui.loading = false
                self.ui.message = "Lecture impossible.\nEssaie une autre version depuis la fiche, ou réessaie plus tard (ton abonnement est peut-être utilisé sur un autre appareil)."
            case .ended:
                self.ui.loading = false
                self.savePosition()
                if let n = self.req.next?() { self.req = n; self.versionIndex = 0; self.setupUI(); self.start() }   // épisode suivant
                else { self.quit() }
            default: break
            }
        }
    }
}
