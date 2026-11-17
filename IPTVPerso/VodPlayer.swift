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
    /// TV en direct (simulateur : même lecteur, variante « tv ») : la liste de chaînes en cours et la chaîne de départ
    var live: [Channel] = []
    var liveIndex = 0

    /// Lecture d'une chaîne (zapping dans `channels`) avec le lecteur commun aux films et séries
    static func live(_ channels: [Channel], start: Int) -> VodRequest {
        var r = VodRequest(url: URL(string: "about:blank")!, key: "", item: "", title: "", subtitle: "", icon: "", startAt: 0)
        r.live = channels; r.liveIndex = max(0, min(start, channels.count - 1))
        return r
    }
}

struct VodPlayerView: View {
    let request: VodRequest
    @Environment(\.dismiss) private var dismiss
    @State private var bridge = PlayerBridge()
    var body: some View {
        VodPlayerRepresentable(request: request, bridge: bridge, onClose: { dismiss() }).ignoresSafeArea()
            // Retour court sans panneau ouvert : sans ce gestionnaire, SwiftUI fermerait la présentation plein écran
            // (donc tout le lecteur). Les panneaux ont leur propre gestionnaire, prioritaire.
            .onExitCommand { bridge.vc?.shortBack() }
    }
}

/// Lien entre la vue SwiftUI du lecteur et son contrôleur UIKit.
final class PlayerBridge { weak var vc: VodPlayerController? }

/// Vue transparente qui peut prendre le focus (les touches de la télécommande remontent ensuite au lecteur).
final class PressCatcher: UIView {
    /// coupé pendant qu'un panneau est ouvert, pour que le focus ne glisse jamais du panneau vers cette vue
    var active = true
    override var canBecomeFocused: Bool { active }
}

struct VodPlayerRepresentable: UIViewControllerRepresentable {
    let request: VodRequest
    let bridge: PlayerBridge
    let onClose: () -> Void
    func makeUIViewController(context: Context) -> VodPlayerController {
        let c = VodPlayerController(request: request, onClose: onClose); bridge.vc = c; return c
    }
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
    /// vue invisible qui garde le focus quand aucun panneau n'est ouvert : sans elle, rien n'a le focus dans le lecteur
    /// et Retour court remonte jusqu'à la présentation plein écran, qui ferme le lecteur
    private let catcher = PressCatcher()
    private let ui = PlayerUI()
    private var host: UIHostingController<PlayerOverlay>!
    private var watch: AnyCancellable?
    private var wasInteractive = false
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
    // marque-page du sommeil
    private var lastInput = Date()
    private var lastInputPos: Double = 0
    private var sleepTimer: Timer?
    // « Qu'a-t-il dit ? »
    /// « Qu'a-t-il dit ? » : sous-titres d'avant, à rétablir une fois le passage revu.
    /// `armed` ne passe à vrai qu'une fois le recul réellement fait (le lecteur peut annoncer l'ancienne position un instant).
    private var saidRestore: (until: Double, sub: Int32, armed: Bool)?
    private var saidWant: Int32?
    // reprise après un changement (version, son de nuit)
    private var restartAt: Double?
    private var versionIndex = 0
    private var shownTracks = false
    /// numéro de la lecture en cours : un événement de VLC arrivé en retard (chaîne, source ou version précédente)
    /// ne peut plus rallumer la roulette ni afficher une erreur sur la nouvelle lecture
    private var gen = 0
    /// dernière position vue : la roulette s'éteint dès que l'image avance réellement (VLC n'annonce pas toujours
    /// « lecture » après une mise en mémoire tampon)
    private var lastTick: Double = -1
    private var stallWork: DispatchWorkItem?
    // TV en direct
    private var isLive: Bool { !req.live.isEmpty }
    private var liveIndex = 0
    private var sources: [Channel] = []
    private var sourceIndex = 0
    private var zapWork: DispatchWorkItem?
    private var recent: [Int] = []

    private var sleepAfter: TimeInterval { Double(Debug.sleepAfterSeconds ?? 90 * 60) }

    init(request: VodRequest, onClose: @escaping () -> Void) {
        self.req = request; self.onClose = onClose
        self.liveIndex = request.liveIndex
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        videoView.frame = view.bounds; videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)
        catcher.frame = view.bounds; catcher.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(catcher)

        setupUI()
        host = UIHostingController(rootView: PlayerOverlay(m: ui))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds; host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        // quand le panneau s'ouvre ou se ferme, la sélection de l'Apple TV entre dans l'interface ou en sort
        // (uniquement à ce changement : redemander la sélection à chaque tic de la progression la ramenait sans cesse
        // sur la première ligne du panneau, et la flèche bas ne descendait plus)
        watch = ui.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.ui.interactive != self.wasInteractive else { return }
                self.wasInteractive = self.ui.interactive
                self.catcher.active = !self.ui.interactive
                self.setNeedsFocusUpdate(); self.updateFocusIfNeeded()
            }
        }

        player.drawable = videoView
        player.delegate = self
        start()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.savePosition() }
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.minuteCheck() }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { ui.interactive ? [host.view] : [catcher] }

    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }

    func stop() {
        stallWork?.cancel(); zapWork?.cancel()
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
        ui.setSub = { [weak self] i in self?.player.currentVideoSubTitleIndex = i; self?.ui.subCur = i; self?.saidRestore = nil; self?.saidWant = nil }
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
        if isLive {
            ui.live = true
            ui.setVersion = { [weak self] i in self?.switchSource(i) }
            ui.zapTo = { [weak self] i, now in self?.zap(to: i, now: now) }
            loadLive()
        }
        ui.stillWatching = { [weak self] in self?.endSleepAsk(pause: false) }
        ui.pauseForLater = { [weak self] in self?.endSleepAsk(pause: true) }
    }

    private func start(at: Double? = nil) {
        if player.state != .stopped { player.stop() }     // une seule connexion
        gen += 1
        seeked = false; retried = false; shownTracks = false; lastTick = -1
        restartAt = at
        ui.message = nil; ui.loading = true
        var url = req.versions.indices.contains(versionIndex) ? req.versions[versionIndex].url : req.url
        if isLive {
            guard sources.indices.contains(sourceIndex), let p = ProviderStore.sharedProvider(sources[sourceIndex].pid),
                  let u = p.liveURL(sources[sourceIndex]) else {
                ui.loading = false; ui.message = "Ce fournisseur n'est plus disponible."; return
            }
            url = u
            let ch = sources[sourceIndex]
            Task { @MainActor in LivePrefs.shared.played(ch) }
        }
        let media = VLCMedia(url: url)
        media.addOption(isLive ? ":network-caching=1500" : ":network-caching=2000")
        // Réglages (1.7.1) : apparence des sous-titres, décodage matériel
        for o in AppPrefs.subOptions { media.addOption(o) }
        if !AppPrefs.hwDecode { media.addOption(":avcodec-hw=none") }
        if ui.nightActive {
            // son de nuit : compresseur de VLC (sons forts adoucis) — se règle au démarrage de la lecture
            for o in [":audio-filter=compressor", ":compressor-rms-peak=0.2", ":compressor-attack=25", ":compressor-release=100",
                      ":compressor-threshold=-20", ":compressor-ratio=4", ":compressor-knee=4.5", ":compressor-makeup-gain=7"] { media.addOption(o) }
        }
        player.media = media
        applyEqualizer()
        player.play()
        showOSD()
        armStall()
    }

    /// Filet de sécurité : si rien n'avance au bout de 25 s, la roulette laisse place à un message clair
    /// (au lieu de tourner indéfiniment quand le flux ne répond plus sans erreur de VLC).
    private func armStall() {
        stallWork?.cancel()
        let g = gen
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.gen == g, self.ui.loading, self.ui.message == nil else { return }
            if self.isLive, AppPrefs.failover > 0, self.trySource(after: self.sourceIndex) { return }
            self.ui.loading = false
            self.ui.message = self.isLive ? "Cette chaîne ne répond pas.\nChoisis une autre chaîne ou une autre source, ou réessaie plus tard."
                                          : "La lecture ne démarre pas.\nEssaie une autre version depuis la fiche, ou réessaie plus tard."
        }
        stallWork = w
        // Réglages › TV en direct : délai de bascule vers la source suivante (25 s par défaut, comme avant)
        let delay = isLive && AppPrefs.failover > 0 ? Double(AppPrefs.failover) : 25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
    }

    private var duration: Double { Double(player.media?.length.intValue ?? 0) / 1000 }
    private var position: Double { Double(player.time.intValue) / 1000 }

    private func savePosition(at p0: Double? = nil) {
        guard !isLive else { return }
        let d = duration, p = p0 ?? position
        guard d > 60, p > 0 else { return }
        let r = req
        Task { @MainActor in WatchStore.shared.save(key: r.key, pos: p, dur: d, title: r.title, icon: r.icon, item: r.item, ep: r.subtitle.isEmpty ? nil : r.subtitle) }
    }

    private func refresh() {
        ui.paused = !player.isPlaying
        guard !isLive else { return }   // en direct, la barre suit le programme du guide (loadLive)
        ui.pos = position; ui.dur = duration
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
        if ui.interactive {
            // Retour non pris par le panneau : ne jamais le laisser remonter (tvOS fermerait tout le lecteur) ;
            // (c'est le panneau qui remonte d'un niveau, via son « onExitCommand » : ne pas le faire une 2e fois ici)
            if press.type == .menu { ui.log("VC began menu (panneau)"); return }
            return super.pressesBegan(presses, with: event)
        }
        switch press.type {
        case .menu: return   // Retour : traité par shortBack() (via SwiftUI)
        case .leftArrow where isLive, .rightArrow where isLive: showOSD()
        case .leftArrow: seek(-Double(AppPrefs.skip))
        case .rightArrow: seek(Double(AppPrefs.skip))
        case .upArrow: ui.panel = .shortcuts; ui.osd = true
        case .downArrow where isLive: ui.panel = .full; ui.osd = true     // TV : la liste des chaînes
        case .downArrow: ui.options = true; ui.osd = true
        case .select where (cutDone || bedDone) && !player.isPlaying:
            closeWork?.cancel(); ui.message = nil; player.play(); showOSD()
        case .select: if ui.osd { togglePause() } else { showOSD() }
        case .playPause: togglePause()
        default: super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first, press.type == .menu else { return super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first, press.type == .menu else { return super.pressesCancelled(presses, with: event) }
    }

    /// Retour court : remonter d'un niveau (panneau → bandeau → quitter le lecteur)
    func shortBack() {
        ui.log("shortBack interactive=\(ui.interactive)")
        noteInput()
        if ui.sleepLeft != nil { ui.stillWatching(); return }
        if ui.interactive { ui.back("lecteur"); return }
        if ui.message != nil && (cutDone || bedDone) { quit(); return }
        // comportement validé (1.7) : 1re pression = fermer le panneau ouvert (ci-dessus), 2e pression = quitter la vidéo,
        // bandeau affiché ou non (tvOS réserve « Retour maintenu » à l'écran d'accueil de l'Apple TV)
        quit()
    }

    private func quit() { ui.log("quit"); stop(); onClose() }

    // MARK: lecture

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        let g = gen
        DispatchQueue.main.async { [weak self] in
            guard let self, self.gen == g else { return }
            // l'image avance : la lecture tourne, quelle que soit la dernière annonce de VLC
            let p = self.position
            if self.ui.loading, self.lastTick >= 0, p != self.lastTick { self.ui.loading = false; self.stallWork?.cancel() }
            self.lastTick = p
            if self.isLive {
                if !self.shownTracks, p > 0 { self.shownTracks = true; self.readTracks() }
                self.checkSleep()
                return
            }
            // reprise : on saute à la position enregistrée (ou à celle d'avant un changement) dès que la durée est connue
            if !self.seeked, self.duration > 0 {
                self.seeked = true
                let to = self.restartAt ?? (self.req.startAt > 0 ? self.req.startAt : nil)
                if let to { self.player.time = VLCTime(int: Int32(to * 1000)) }
                self.restartAt = nil
                self.lastInputPos = to ?? 0
            }
            if !self.shownTracks, self.duration > 0 { self.shownTracks = true; self.readTracks(); self.defaultSubs() }
            if self.ui.osd || self.ui.interactive { self.refresh() } else { self.ui.pos = self.position }
            if var r = self.saidRestore, !r.armed, self.position < r.until - min(3, r.until * 0.5) { r.armed = true; self.saidRestore = r }
            if let r = self.saidRestore, r.armed, self.position >= r.until {
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
        if !isLive { info.append(("Durée", PlayerUI.hms(duration))) }
        info.append(("Pistes audio", "\(max(1, ui.audio.count))"))
        info.append(("Sous-titres", "\(ui.subs.filter { $0.id >= 0 }.count)"))
        // un direct n'a pas de « titre » (index -1) : ne jamais demander ses chapitres à VLC
        let ti = player.currentTitleIndex
        if !isLive, ti >= 0 {
            let ch = player.numberOfChapters(forTitle: ti)
            if ch > 0 { info.append(("Chapitres", "\(ch)")) }
        }
        let url = req.versions.indices.contains(versionIndex) ? req.versions[versionIndex].url : req.url
        if isLive, sources.indices.contains(sourceIndex) {
            info.append(("Source", LiveSourceLabel.text(sources[sourceIndex])))
        } else {
            info.append(("Serveur", url.host ?? "—"))
        }       // jamais l'adresse complète (elle contient tes identifiants)
        info.append(("Son de nuit", ui.nightActive ? "actif" : "inactif"))
        ui.info = info
    }

    /// Sous-titres au démarrage (1.7.1) : réglage du profil (« Toujours en français » / « Jamais »), sinon réglages
    /// généraux (« Sous-titres français par défaut », « … si seule la VO existe »). Rien ne change si aucun n'est activé.
    private func defaultSubs() {
        let prof = ProfileStore.shared.me.subs
        let fr = ui.subs.filter { $0.id >= 0 }.first { n in
            let x = n.name.lowercased()
            return !x.contains("forc") && (x.contains("fran") || x.contains("french") || x.range(of: #"\b(fr|fre|fra)\b"#, options: .regularExpression) != nil)
        }
        func frAudio() -> Bool { ui.audio.contains { a in let x = a.name.lowercased(); return x.contains("fran") || x.contains("french") || x.range(of: #"\b(fr|fre|fra|vf|vff)\b"#, options: .regularExpression) != nil } }
        var want: Int32?
        if prof == 2 { want = -1 }
        else if prof == 1 || AppPrefs.subsFR { want = fr?.id }
        else if AppPrefs.subsIfVO, !ui.audio.isEmpty, !frAudio() { want = fr?.id }
        guard let w = want, w != ui.subCur else { return }
        player.currentVideoSubTitleIndex = w; ui.subCur = w
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
        if isLive { loadLive() }
    }

    // MARK: TV en direct (variante « tv » du lecteur du simulateur)

    private var liveChannel: Channel { req.live[liveIndex] }

    /// Chaîne en cours : ses sources (qualité · fournisseur, la meilleure d'abord), le programme et la liste des chaînes.
    private func loadLive() {
        let ch = liveChannel
        if sources.isEmpty || sources.first.map({ ChannelTools.key($0) != ChannelTools.key(ch) }) ?? true {
            let copies = LiveIndex.entry(ch)?.copies ?? [ch]
            sources = copies.isEmpty ? [ch] : copies
            sourceIndex = max(0, sources.firstIndex { $0.id == ch.id } ?? 0)
            // Réglages › Lecture : qualité maximale (la meilleure source sous la limite, si la chaîne a été prise « au mieux »)
            if sourceIndex == 0, AppPrefs.maxQuality > 0,
               let i = sources.firstIndex(where: { ChannelTools.quality($0.name) <= AppPrefs.maxRank }) { sourceIndex = i }
        }
        ui.versions = sources.map { LiveSourceLabel.text($0) }
        ui.versionCur = sourceIndex
        let name = ChannelTools.clean(ch.name)
        ui.kicker = "DIRECT · " + name.uppercased() + (ch.num > 0 ? " · CANAL \(ch.num)" : "")
        ui.cur = liveIndex
        let list = req.live, idx = liveIndex
        Task { @MainActor in
            let (n, x) = await LiveStore.nowNext(ch)
            guard self.liveIndex == idx else { return }
            self.ui.title = n?.title ?? name
            if let n {
                self.ui.dur = n.stopDate.timeIntervalSince(n.startDate)
                self.ui.pos = Date().timeIntervalSince(n.startDate)
                self.ui.liveStart = n.startDate; self.ui.liveStop = n.stopDate
            } else { self.ui.dur = 0; self.ui.pos = 0; self.ui.liveStart = nil; self.ui.liveStop = nil }
            self.ui.meta = x.map { "Ensuite à " + Fmt.hm($0.startDate) + " · " + $0.title } ?? (n == nil ? "Programme non communiqué" : "")
            // la liste des chaînes du panneau (programme en cours, ensuite) : seulement autour de la chaîne, pour rester léger
            let lo = max(0, idx - 30), hi = min(list.count, idx + 31)
            var rows: [LiveRow] = []
            for i in lo..<hi {
                let c = list[i]
                let (cn, cx) = await LiveStore.nowNext(c)
                rows.append(LiveRow(id: i, name: ChannelTools.clean(c.name), now: cn?.title ?? "Programme non communiqué",
                                    progress: cn?.progress() ?? 0, next: cx.map { "ensuite " + Fmt.hm($0.startDate) + " · " + $0.title } ?? ""))
            }
            guard self.liveIndex == idx else { return }
            self.ui.channels = rows
            self.ui.recent = self.recent.filter { $0 != idx && list.indices.contains($0) }.prefix(4).map { ($0, ChannelTools.clean(list[$0].name)) }
        }
    }

    /// Zapping : la chaîne affichée change tout de suite ; le flux suit (aussitôt à l'appui sur OK, 1 s après
    /// un simple passage dans la liste, comme le simulateur) pour ne pas ouvrir dix connexions en descendant la liste.
    private func zap(to i: Int, now: Bool) {
        guard req.live.indices.contains(i), i != liveIndex else { return }
        zapWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recent.removeAll { $0 == self.liveIndex }; self.recent.insert(self.liveIndex, at: 0)
            self.liveIndex = i; self.sources = []
            self.loadLive(); self.start()
        }
        zapWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (now ? 0 : 1), execute: w)
    }

    /// « Source » du panneau : autre qualité ou autre fournisseur de la même chaîne
    private func switchSource(_ i: Int) {
        guard sources.indices.contains(i), i != sourceIndex else { return }
        sourceIndex = i; ui.versionCur = i
        start()
        toast("Source : " + LiveSourceLabel.text(sources[i]))
    }

    /// Bascule automatique sur la source suivante quand celle-ci ne répond pas ; false s'il n'y en a plus.
    private func trySource(after i: Int) -> Bool {
        guard isLive, i + 1 < sources.count else { return false }
        sourceIndex = i + 1; ui.versionCur = sourceIndex
        toast("La source ne répond pas · " + LiveSourceLabel.text(sources[sourceIndex]))
        start()
        return true
    }

    // MARK: « Qu'a-t-il dit ? »

    private func whatSaid() {
        ui.options = false
        let here = position
        // pistes relues maintenant : certaines n'apparaissent qu'après quelques secondes de lecture
        readTracks()
        let names = ui.subs.filter { $0.id >= 0 }
        let fr = names.first { n in
            let x = n.name.lowercased()
            return !x.contains("forc") && (x.contains("fran") || x.contains("french") || x.range(of: #"\b(fr|fre|fra|vf|vff|vfq)\b"#, options: .regularExpression) != nil)
        } ?? names.first { n in let x = n.name.lowercased(); return x.contains("fran") || x.contains("french") }
        // un nouvel appui pendant un passage déjà revu garde les sous-titres d'origine
        let original = saidRestore?.sub ?? ui.subCur
        player.time = VLCTime(int: Int32(max(0, here - 10) * 1000))
        guard let f = fr else {
            saidRestore = nil; saidWant = nil
            toast("10 s en arrière · pas de sous-titres français dans ce fichier")
            showOSD(); return
        }
        saidRestore = original == f.id ? nil : (until: here + 1, sub: original, armed: false)
        saidWant = f.id
        // la piste est demandée après le recul, puis vérifiée : redemandée tant qu'elle n'est pas active (3 essais)
        applySaid(f.id, attempt: 0)
        toast("10 s en arrière · sous-titres français pour ce passage")
        showOSD()
    }

    private func applySaid(_ id: Int32, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.35 : 0.6)) { [weak self] in
            guard let self, self.saidWant == id else { return }
            if self.player.currentVideoSubTitleIndex != id { self.player.currentVideoSubTitleIndex = id }
            self.ui.subCur = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.saidWant == id else { return }
                if self.player.currentVideoSubTitleIndex == id {
                    PerfLog.ev("qu'a-t-il dit : piste \(id) active (essai \(attempt + 1))")
                    self.saidWant = nil
                } else if attempt < 2 {
                    self.applySaid(id, attempt: attempt + 1)
                } else {
                    PerfLog.ev("qu'a-t-il dit : piste \(id) refusée par le lecteur")
                    self.saidWant = nil
                    self.toast("Sous-titres français indisponibles pour ce passage")
                }
            }
        }
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
        // l'état et la lecture concernés sont relevés tout de suite (et non plus tard, quand l'état a déjà changé)
        let st = (aNotification.object as? VLCMediaPlayer)?.state ?? player.state
        let g = gen
        DispatchQueue.main.async { [weak self] in
            guard let self, self.gen == g else { return }
            switch st {
            case .playing:
                self.ui.loading = false; self.ui.paused = false; self.stallWork?.cancel()
                if self.ui.message != nil && !self.cutDone && !self.bedDone { self.ui.message = nil }
                if let b = self.seekOnResume { self.seekOnResume = nil; self.player.time = VLCTime(int: Int32(b * 1000)) }
            case .paused:
                self.ui.loading = false; self.ui.paused = true
            case .opening, .buffering:
                if !self.player.isPlaying { self.ui.loading = true }
            case .error:
                if !self.retried { self.retried = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if self.gen == g { self.player.play() } }; return }
                // en direct : la source suivante (autre qualité ou autre fournisseur), comme le simulateur
                if self.isLive, self.trySource(after: self.sourceIndex) { return }
                self.ui.loading = false; self.stallWork?.cancel()
                self.ui.message = self.isLive ? "Cette chaîne ne répond pas.\nChoisis une autre chaîne ou une autre source, ou réessaie plus tard (ton abonnement est peut-être utilisé sur un autre appareil)."
                    : "Lecture impossible.\nEssaie une autre version depuis la fiche, ou réessaie plus tard (ton abonnement est peut-être utilisé sur un autre appareil)."
            case .ended where self.isLive:
                self.ui.loading = false; self.ui.message = "La diffusion s'est arrêtée."
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
