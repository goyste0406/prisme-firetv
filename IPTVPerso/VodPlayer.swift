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

    /// 1.8 phase 1 : épisode (carte « Épisode suivant », intro, langue retenue, panneau Épisodes) ou film (À suivre, avis)
    var episode: EpisodeCtx? = nil
    var film: FilmCtx? = nil

    /// Lecture d'une chaîne (zapping dans `channels`) avec le lecteur commun aux films et séries
    static func live(_ channels: [Channel], start: Int) -> VodRequest {
        var r = VodRequest(url: URL(string: "about:blank")!, key: "", item: "", title: "", subtitle: "", icon: "", startAt: 0)
        r.live = channels; r.liveIndex = max(0, min(start, channels.count - 1))
        return r
    }
}

/// Un épisode dans le panneau « Épisodes » du lecteur.
struct PanelEpisode: Identifiable, Equatable {
    let season: Int, number: Int, title: String, minutes: Int, image: String
    var id: String { "\(season)-\(number)" }
}

/// Ce que le lecteur sait de l'épisode lu (série, suivant, liste du panneau).
struct EpisodeCtx {
    let series: String           // id de la série
    let seriesTitle: String
    let season: Int, number: Int
    let epTitle: String
    let provider: String
    let version: String          // « VF · 4K »
    var image = ""               // image large de la série (carte « Épisode suivant »)
    var episodes: [PanelEpisode] = []
    /// épisode suivant chez le fournisseur (nil : aucun)
    var next: PanelEpisode?
    var nextPlot = ""
    /// l'épisode qui suit dans l'ordre (S·É+1) manque chez le fournisseur (« É4 pas encore chez ton fournisseur »)
    var missingNext: Int?
    /// date annoncée par TMDB pour le prochain épisode (« AAAA-MM-JJ »), saisons annoncées par TMDB
    var tmdbNext = ""
    var tmdbSeasons = 0
    /// lance un autre épisode (S, É) de la même série chez le même fournisseur
    var jump: ((Int, Int) -> VodRequest?)? = nil
    var epKey: String { SeriesMemory.epKey(season, number) }
}

/// Ce que le lecteur sait du film lu (scène après le générique, film suivant).
struct FilmCtx {
    let item: MediaItem
    /// TMDB : « scène pendant / après le générique »
    var post: Bool { let k = item.fiche?.keywordNames ?? []; return k.contains("aftercreditsstinger") || k.contains("duringcreditsstinger") }
    /// film proposé à la fin (calculé pendant la lecture)
    var pick: (() async -> FilmPick?)? = nil
}

struct FilmPick {
    let item: MediaItem
    let reason: String
    let minutes: Int
    let request: () -> VodRequest?
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
    // 1.8 phase 1 : fin de lecture, intro, langue, journal
    private var mem = SeriesMemory()
    private var intro: (s: Double, e: Double, chap: Bool)?
    private var introDone = false
    private var introAutoAt: (date: Date, end: Double)?
    private var introNoAuto = false
    private var creditsChapter: Double?
    private var endShown = false
    private var creditsWatch = false
    private var cdTimer: Timer?
    private var cardActions: [() -> Void] = []
    private var cardBackAction: () -> Void = {}
    private var played: Double = 0
    private var playedLast: Double = -1
    private var sessionStart = Date()
    private var binge = 0
    private var bingeAsked = false
    private var lastEpisodeEnd: Date?
    private var pick: FilmPick?
    private var postPending = false
    private var rated = false
    private var langApplied = false
    private var debugFromUsed = false

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
        cdTimer?.invalidate(); cdTimer = nil
        flushJournal()
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
        ui.setAudio = { [weak self] i in self?.player.currentAudioTrackIndex = i; self?.ui.audioCur = i; self?.toast("Audio : " + (self?.ui.audio.first { $0.id == i }?.name ?? "")); self?.rememberLang() }
        ui.setSub = { [weak self] i in self?.player.currentVideoSubTitleIndex = i; self?.ui.subCur = i; self?.saidRestore = nil; self?.saidWant = nil; self?.rememberLang() }
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
        setupEnd()
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

    private func toast(_ t: String, seconds: Double = 3.5) {
        ui.toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in if self?.ui.toast == t { self?.ui.toast = nil } }
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
            let from = self.position
            let target = max(0, min(self.duration - 2, from + self.ui.pending))
            self.ui.pending = 0
            self.noteJump(from: from, to: target)
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
        if ui.cardActive, press.type != .menu { cardPress(press.type); return }
        if ui.card == .intro, press.type == .select { skipIntro(); return }
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
        if ui.cardActive { cardBackAction(); return }
        if ui.message != nil && (cutDone || bedDone) { quit(); return }
        // comportement validé (1.7) : 1re pression = fermer le panneau ouvert (ci-dessus), 2e pression = quitter la vidéo,
        // bandeau affiché ou non (tvOS réserve « Retour maintenu » à l'écran d'accueil de l'Apple TV)
        // 1.8 : un film vu à 85 % ou plus demande d'abord « Tu as aimé … ? » (une seule fois par film)
        if askRateBeforeQuit() { return }
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
            // journal : seulement le temps réellement joué (ni les pauses ni les sauts)
            if self.player.isPlaying, self.playedLast >= 0, p - self.playedLast > 0, p - self.playedLast < 3 { self.played += p - self.playedLast }
            self.playedLast = p
            if self.isLive {
                if !self.shownTracks, p > 0 { self.shownTracks = true; self.readTracks() }
                self.checkSleep()
                return
            }
            // reprise : on saute à la position enregistrée (ou à celle d'avant un changement) dès que la durée est connue
            if !self.seeked, self.duration > 0 {
                self.seeked = true
                var to = self.restartAt ?? (self.req.startAt > 0 ? self.req.startAt : nil)
                if !self.debugFromUsed || Debug.playFromEach { self.debugFromUsed = true; if let d = Debug.playFrom { to = d } }
                if let to { self.player.time = VLCTime(int: Int32(to * 1000)) }
                self.restartAt = nil
                self.lastInputPos = to ?? 0
            }
            if !self.shownTracks, self.duration > 0 { self.shownTracks = true; self.readTracks(); self.defaultSubs(); self.afterTracks() }
            if self.ui.osd || self.ui.interactive { self.refresh() } else { self.ui.pos = self.position }
            if var r = self.saidRestore, !r.armed, self.position < r.until - min(3, r.until * 0.5) { r.armed = true; self.saidRestore = r }
            if let r = self.saidRestore, r.armed, self.position >= r.until {
                // « Qu'a-t-il dit ? » : le passage est revu, les sous-titres d'avant reviennent
                self.player.currentVideoSubTitleIndex = r.sub; self.ui.subCur = r.sub; self.saidRestore = nil
            }
            self.checkCut()
            self.checkSleep()
            self.checkEnd()
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
            self.flushJournal()
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
                self.savePosition(at: self.duration)
                self.endedFlow()
            default: break
            }
        }
    }
}

// MARK: - 1.8 phase 1 : fin de lecture (épisode et film), intro, langue retenue, journal
// Un seul moteur pour les deux lecteurs : mêmes cartes, même compte à rebours (arrêté pendant la pause), même règle
// pour Retour, même journal. Priorités : arrêt au coucher, « Tu regardes toujours ? », « Encore un ? »,
// scène après le générique, épisode suivant / À suivre, « Tu as aimé ? » — jamais deux fenêtres à la fois.

extension VodPlayerController {

    /// À chaque nouvelle lecture (épisode suivant, autre épisode, film suivant) : état de fin remis à zéro.
    fileprivate func setupEnd() {
        cdTimer?.invalidate(); cdTimer = nil
        ui.card = .none; ui.countdown = nil; ui.prepared = false
        intro = nil; introDone = false; introAutoAt = nil; introNoAuto = false
        creditsChapter = nil; endShown = false; creditsWatch = false
        pick = nil; postPending = false; rated = false; langApplied = false
        if let e = req.episode {
            mem = SeriesMemory.load(e.series)
            ui.series = true
            ui.episodes = e.episodes
            ui.epCur = "\(e.season)-\(e.number)"
            ui.epSeason = e.season
            ui.seriesAutoSkip = mem.autoSkip
            // pastille « version » des réglages de la série (simulateur « Lune · 1080p »)
            if req.versions.isEmpty { ui.versions = [e.provider + (e.version.isEmpty ? "" : " · " + e.version)]; ui.versionCur = 0 }
            refreshEpisodeState()
            ui.playEpisode = { [weak self] s, n in self?.jumpTo(s, n) }
            ui.nextEpisode = { [weak self] in self?.goNextEpisode(manual: true) }
            ui.setStopAfter = { [weak self] on in
                guard let self else { return }
                self.ui.stopAfter = on
                self.toast(on ? "☾ prisme s'arrêtera après cet épisode" : "Arrêt après cet épisode désactivé")
                if self.ui.card == .episode { self.endShown = false; self.showEpisodeCard() }
            }
            ui.setSeriesAutoSkip = { [weak self] on in
                guard let self, let e = self.req.episode else { return }
                self.mem.autoSkip = on; self.mem.save(e.series); self.ui.seriesAutoSkip = on
                self.toast(on ? "Intro passée automatiquement pour " + e.seriesTitle : "Intro : bouton seulement pour " + e.seriesTitle)
            }
            ui.forgetIntro = { [weak self] in
                guard let self, let e = self.req.episode else { return }
                self.mem.intros = [:]; self.mem.save(e.series)
                self.ui.introLearned = ""
                if self.intro?.chap == false { self.intro = nil; if self.ui.card == .intro { self.ui.card = .none } }
                self.toast("Moment de l'intro oublié pour " + e.seriesTitle)
            }
            updateLearnedText()
        } else {
            ui.series = false
            ui.episodes = []
        }
        if let f = req.film, let p = f.pick {
            let key = req.key
            Task { @MainActor [weak self] in
                let x = await p()
                guard let self, self.req.key == key else { return }
                self.pick = x
            }
        }
    }

    private func refreshEpisodeState() {
        guard let e = req.episode else { return }
        let w = WatchStore.shared
        var seen = Set<String>(), prog: [String: Double] = [:]
        // historique de la série : l'épisode est reconnu à « Saison S · Épisode N » (début du sous-titre enregistré)
        let mine = w.entries.values.filter { $0.item == e.series }
        for x in e.episodes {
            let tag = "Saison \(x.season) · Épisode \(x.number)"
            if let f = mine.first(where: { ($0.ep ?? "") == tag || ($0.ep ?? "").hasPrefix(tag + " · ") }) {
                let fr = f.dur > 0 ? f.pos / f.dur : 0
                if fr >= 0.92 { seen.insert(x.id) } else if fr > 0.02 { prog[x.id] = fr }
            }
        }
        ui.epSeen = seen; ui.epProgress = prog
    }

    private func updateLearnedText() {
        if let l = mem.learned() {
            ui.introLearned = PlayerUI.hms(l.start) + " → " + PlayerUI.hms(l.end) + " · appris sur " + l.from + (l.count >= 2 ? " (confirmé \(l.count) fois)" : "")
        } else { ui.introLearned = "" }
    }

    // MARK: pistes : chapitres (intro, générique) et langue retenue pour la série

    fileprivate func afterTracks() {
        let d = duration
        guard d > 0 else { return }
        let ti = player.currentTitleIndex
        let ch = ti >= 0 ? (player.chapterDescriptions(ofTitle: ti) as? [[String: Any]] ?? []) : []
        let list: [(name: String, s: Double, e: Double)] = ch.compactMap { c in
            guard let o = (c[VLCChapterDescriptionTimeOffset] as? NSNumber)?.doubleValue else { return nil }
            let du = (c[VLCChapterDescriptionDuration] as? NSNumber)?.doubleValue ?? 0
            return ((c[VLCChapterDescriptionName] as? String) ?? "", o / 1000, (o + du) / 1000)
        }
        func match(_ n: String, _ re: String) -> Bool { n.range(of: re, options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) != nil }
        if let c = list.first(where: { match($0.name, #"intro|opening|ouverture|g[eé]n[eé]rique de d[eé]but"#) }), c.e > c.s, c.s < d * 0.5 {
            intro = (c.s, c.e, true)
        }
        if let c = list.last(where: { match($0.name, #"credits|cr[eé]dits|g[eé]n[eé]rique|ending|end titles"#) && !match($0.name, #"d[eé]but|opening"#) }), c.s > d * 0.5 {
            creditsChapter = c.s
        }
        if req.episode != nil, intro == nil, let l = mem.learned(), l.end < d * 0.5 { intro = (l.start, l.end, false) }
        applyLangMemory()
    }

    /// Langue choisie par toi pendant un épisode : retenue pour la série (la langue, pas le numéro de piste).
    fileprivate func rememberLang() {
        guard let e = req.episode else { return }
        mem.audio = ui.audio.first { $0.id == ui.audioCur }.flatMap { TrackLang.code($0.name) } ?? mem.audio
        if ui.subCur < 0 { mem.subs = "off" } else if let n = ui.subs.first(where: { $0.id == ui.subCur })?.name, !TrackLang.isForced(n) { mem.subs = TrackLang.code(n) ?? mem.subs }
        mem.save(e.series)
    }

    private func applyLangMemory() {
        defer { langApplied = true }
        guard req.episode != nil else { return }
        var notes: [String] = []
        if let a = mem.audio {
            let cur = ui.audio.first { $0.id == ui.audioCur }.flatMap { TrackLang.code($0.name) }
            if cur != a {
                if let t = ui.audio.first(where: { TrackLang.code($0.name) == a }) { player.currentAudioTrackIndex = t.id; ui.audioCur = t.id }
                else if ui.audio.count > 0 { notes.append("Pas de piste \(TrackLang.adjF(a)) dans cet épisode · audio " + (cur.map(TrackLang.name) ?? ui.audio.first { $0.id == ui.audioCur }?.name ?? "par défaut")) }
            }
        }
        if let sb = mem.subs {
            if sb == "off" { if ui.subCur >= 0 { player.currentVideoSubTitleIndex = -1; ui.subCur = -1 } }
            else if let t = ui.subs.first(where: { $0.id >= 0 && !TrackLang.isForced($0.name) && TrackLang.code($0.name) == sb }) {
                if t.id != ui.subCur { player.currentVideoSubTitleIndex = t.id; ui.subCur = t.id }
            } else { notes.append("Pas de sous-titres en \(TrackLang.name(sb)) dans cet épisode") }
        }
        if let n = notes.first { toast(n, seconds: 6) }
    }

    // MARK: intro

    /// Saut vers l'avant de plus de 20 s dans les 8 premières minutes : « l'intro va d'ici à là » pour cet épisode.
    fileprivate func noteJump(from: Double, to: Double) {
        guard let e = req.episode else { return }
        // retour en arrière juste après un passage automatique : ce n'était pas la bonne intro
        if let a = introAutoAt, Date().timeIntervalSince(a.date) < 20, to < a.end - 5 {
            introAutoAt = nil; introNoAuto = true
            if let k = mem.intros.keys.filter({ $0 != e.epKey }).sorted(by: SeriesMemory.epOrder).last { mem.intros[k] = nil; mem.save(e.series) }
            updateLearnedText()
            toast("Compris : intro pas passée automatiquement pour cet épisode")
            return
        }
        guard to - from > 20, from < 480, intro?.chap != true, mem.intros[e.epKey] == nil else { return }
        mem.intros[e.epKey] = [from, to]
        mem.save(e.series)
        updateLearnedText()
    }

    fileprivate func skipIntro() {
        guard let i = intro, let e = req.episode else { return }
        ui.card = .none; introDone = true
        player.time = VLCTime(int: Int32(i.e * 1000))
        // confirmation : ce moment est bien l'intro de cet épisode
        mem.intros[e.epKey] = [i.s, i.e]
        mem.save(e.series)
        updateLearnedText()
        showOSD()
    }

    private func checkIntro(_ p: Double) {
        guard let i = intro, !introDone, ui.card == .none || ui.card == .intro else { return }
        if p >= i.s, p < i.e - 1 {
            let l = mem.learned()
            let auto = PlaybackPrefs.autoSkip && mem.autoSkip && !introNoAuto && (l?.count ?? 0) >= 2
            if auto, player.isPlaying {
                introDone = true; ui.card = .none
                player.time = VLCTime(int: Int32(i.e * 1000))
                introAutoAt = (Date(), i.e)
                toast("⏭ Intro passée automatiquement · appris sur " + (l?.from ?? ""), seconds: 5)
            } else if ui.card != .intro {
                ui.introSub = (l?.count ?? 0) == 1 && !i.chap ? "appris sur " + (l?.from ?? "")
                    : (PlaybackPrefs.autoSkip && mem.autoSkip ? "prisme retiendra le moment pour les prochains épisodes" : "")
                ui.card = .intro
            }
        } else if ui.card == .intro {
            ui.card = .none
            if p >= i.e - 1 { introDone = true }
        }
    }

    // MARK: moment de la carte de fin

    fileprivate func checkEnd() {
        let p = position, d = duration
        guard d > 60, !isLive, !cutDone, !bedDone, ui.sleepLeft == nil else { return }
        if req.episode != nil {
            checkIntro(p)
            guard !endShown, !creditsWatch else { return }
            let lead = creditsChapter ?? mem.creditsAverage.map { d - $0 } ?? (d - PlaybackPrefs.cardLead)
            if p >= max(d * 0.5, lead) { endShown = true; showEpisodeCard() }
        } else if let f = req.film {
            guard !endShown else { return }
            let lead = max(d - 420, creditsChapter ?? 0)
            guard p >= max(d * 0.2, lead) else { return }
            endShown = true
            if f.post { postPending = true; showPostCard() }
            else if pick != nil { showFilmCard(countdown: true) }
        }
    }

    // MARK: cartes

    private func showCard(_ c: PlayerUI.Card, _ info: EndCardInfo, actions: [() -> Void], back: @escaping () -> Void, sel: Int = 0, countdown: Int? = nil, onZero: (() -> Void)? = nil) {
        cdTimer?.invalidate(); cdTimer = nil
        ui.endInfo = info
        cardActions = actions
        cardBackAction = back
        ui.cardSel = sel
        ui.countdown = countdown
        ui.prepared = false
        ui.card = c
        guard countdown != nil else { return }
        cdTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self, let n = self.ui.countdown else { t.invalidate(); return }
            // compte à rebours arrêté pendant la pause et pendant « Tu regardes toujours ? »
            guard self.player.isPlaying, self.ui.sleepLeft == nil else { return }
            if n <= 1 { t.invalidate(); self.ui.countdown = 0; onZero?() }
            else {
                self.ui.countdown = n - 1
                if n - 1 <= 6, !self.ui.prepared { self.ui.prepared = true }
            }
        }
    }

    private func closeCard() {
        cdTimer?.invalidate(); cdTimer = nil
        ui.card = .none; ui.countdown = nil
    }

    fileprivate func cardPress(_ t: UIPress.PressType) {
        let n = cardActions.count + (ui.endInfo.rateButtons && (ui.card == .film || ui.card == .post) ? 2 : 0)
        switch t {
        case .leftArrow where ui.card != .encore: ui.cardSel = max(0, ui.cardSel - 1)
        case .rightArrow where ui.card != .encore: ui.cardSel = min(max(0, n - 1), ui.cardSel + 1)
        case .upArrow where ui.card == .encore: ui.cardSel = max(0, ui.cardSel - 1)
        case .downArrow where ui.card == .encore: ui.cardSel = min(max(0, n - 1), ui.cardSel + 1)
        case .select:
            if cardActions.indices.contains(ui.cardSel) { cardActions[ui.cardSel]() }
            else if ui.endInfo.rateButtons { rateFromCard(ui.cardSel == cardActions.count ? 1 : -1) }
        case .playPause: togglePause()
        default: break
        }
    }

    // MARK: épisode

    private func episodeLabel(_ s: Int, _ n: Int) -> String { "S\(s) · É\(n)" }

    fileprivate func showEpisodeCard() {
        guard let e = req.episode else { return }
        var c = EndCardInfo()
        c.image = e.image
        if let n = e.next, e.missingNext == nil {
            let last = ui.stopAfter
            c.kicker = last ? "DERNIER ÉPISODE DE LA SOIRÉE" : "ÉPISODE SUIVANT DANS"
            c.title = episodeLabel(n.season, n.number) + (n.title.isEmpty ? "" : " · « " + n.title + " »")
            c.plot = e.nextPlot
            c.plotHidden = PlaybackPrefs.zeroSpoiler && !ui.epSeen.contains(n.id)
            c.lines = [e.version.isEmpty ? "chez " + e.provider + " · préparé pendant le générique, 1 seule connexion"
                                         : e.version + " · " + e.provider + " · préparé pendant le générique, 1 seule connexion"]
            if last {
                c.buttons = ["Terminer la soirée"]
                showCard(.episode, c, actions: [{ [weak self] in self?.endNight() }], back: { [weak self] in self?.watchCredits() })
            } else {
                c.buttons = ["▶ Épisode suivant", "Voir le générique"]
                showCard(.episode, c, actions: [{ [weak self] in self?.goNextEpisode(manual: true) }, { [weak self] in self?.watchCredits() }],
                         back: { [weak self] in self?.watchCredits() }, countdown: PlaybackPrefs.episodeCountdown,
                         onZero: { [weak self] in self?.goNextEpisode(manual: false) })
            }
        } else {
            c.kicker = "FIN DE L'ÉPISODE"
            c.title = endTitle(e)
            // date annoncée par TMDB : seulement pour la suite de la série, pas pour un épisode qui manque au milieu
            if e.missingNext == nil, let d = announced(e) { c.lines = [d] }
            c.image = ""
            c.buttons = ["Fermer"]
            showCard(.episode, c, actions: [{ [weak self] in self?.quit() }], back: { [weak self] in self?.watchCredits() })
        }
    }

    /// Fin sans épisode suivant : manquant, saison finie ou tout vu (simulateur).
    private func endTitle(_ e: EpisodeCtx) -> String {
        if let m = e.missingNext { return "É\(m) pas encore chez ton fournisseur" }
        let lastSeason = e.episodes.map(\.season).max() ?? e.season
        if e.tmdbSeasons > lastSeason || !e.tmdbNext.isEmpty {
            return e.season == lastSeason && !e.tmdbNext.isEmpty && e.tmdbSeasons <= lastSeason
                ? "É\(e.number + 1) pas encore chez ton fournisseur" : "Saison \(e.season) finie !"
        }
        return "Tu as tout vu !"
    }

    private func announced(_ e: EpisodeCtx) -> String? {
        guard !e.tmdbNext.isEmpty, let d = Fiche.dayFormat.date(from: e.tmdbNext), d > Date().addingTimeInterval(-86400) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEEE d MMMM"
        return "Prochain épisode annoncé le " + f.string(from: d)
    }

    /// « Voir le générique » (ou Retour) : la carte disparaît, l'épisode va jusqu'au bout, pas d'enchaînement.
    private func watchCredits() {
        closeCard(); creditsWatch = true
        showOSD()
    }

    fileprivate func endedFlow() {
        cdTimer?.invalidate(); cdTimer = nil
        if let e = req.episode {
            if ui.stopAfter, e.next != nil { endNight(); return }
            if ui.card == .episode, ui.countdown != nil { goNextEpisode(manual: false); return }
            // fin réelle de l'épisode : carte « Fin de l'épisode », sans compte à rebours
            var c = EndCardInfo()
            c.kicker = "FIN DE L'ÉPISODE"
            if let n = e.next, e.missingNext == nil {
                c.title = "Ensuite : " + episodeLabel(n.season, n.number) + (n.title.isEmpty || (PlaybackPrefs.zeroSpoiler && !ui.epSeen.contains(n.id)) ? "" : " · « " + n.title + " »")
                c.buttons = ["▶ Épisode suivant", "Fermer"]
                showCard(.episode, c, actions: [{ [weak self] in self?.goNextEpisode(manual: true) }, { [weak self] in self?.quit() }], back: { [weak self] in self?.quit() })
            } else {
                c.title = endTitle(e)
                if e.missingNext == nil, let d = announced(e) { c.lines = [d] }
                c.buttons = ["Fermer"]
                showCard(.episode, c, actions: [{ [weak self] in self?.quit() }], back: { [weak self] in self?.quit() })
            }
            return
        }
        if req.film != nil {
            if ui.card == .film, let p = pick, ui.countdown != nil { playFilm(p); return }
            if let p = pick, !lateFor(p.minutes) { showFilmCard(countdown: true); return }
            if pick != nil { showFilmCard(countdown: false); return }
            if askRateBeforeQuit() { return }
        }
        quit()
    }

    /// Épisode suivant : le compteur « d'affilée » avance ; « Encore un ? » après N épisodes ; arrêt prévu après celui-ci.
    fileprivate func goNextEpisode(manual: Bool) {
        guard let e = req.episode else { return }
        if manual, duration > 0, position > duration * 0.8 {
            // moment où tu passes à la suite : retenu comme début du générique pour cette série
            mem.creditsLead.append(duration - position); mem.creditsLead = Array(mem.creditsLead.suffix(5)); mem.save(e.series)
        }
        closeCard()
        if ui.stopAfter { endNight(); return }
        guard e.next != nil, e.missingNext == nil, let n = req.next?() else { showEpisodeCard(); return }
        // « d'affilée » : sans quitter le lecteur ni faire une pause de plus de 15 minutes
        if let l = lastEpisodeEnd, Date().timeIntervalSince(l) > 15 * 60 { binge = 0 }
        binge += 1; lastEpisodeEnd = Date()
        savePosition(at: duration)
        if PlaybackPrefs.binge > 0, binge >= PlaybackPrefs.binge, !bingeAsked {
            bingeAsked = true
            askEncore(next: n)
            return
        }
        switchTo(n, toast: true)
    }

    private func switchTo(_ n: VodRequest, toast t: Bool) {
        flushJournal()
        req = n; versionIndex = 0
        setupUI(); start()
        if t, let e = n.episode { toast("⚡ " + episodeLabel(e.season, e.number) + " enchaîne sans attente · " + (e.version.isEmpty ? "" : e.version + " · ") + e.provider) }
    }

    private func jumpTo(_ s: Int, _ n: Int) {
        guard let e = req.episode, let r = e.jump?(s, n) else { return }
        savePosition()
        closeCard()
        switchTo(r, toast: false)
    }

    private func askEncore(next n: VodRequest) {
        player.pause()
        guard let e = n.episode else { switchTo(n, toast: true); return }
        let mins = e.episodes.first { $0.season == e.season && $0.number == e.number }?.minutes ?? 0
        let endMin = Self.eveningNow() + max(1, mins)
        ui.bingeCount = binge
        ui.encoreEp = episodeLabel(e.season, e.number)
        ui.encoreEnd = PlayerUI.hm(endMin)
        ui.encoreBed = PlayerUI.hm(ui.bedMinutes)
        ui.encoreLate = endMin > ui.bedMinutes
        showCard(.encore, EndCardInfo(), actions: [
            { [weak self] in self?.binge = 0; self?.bingeAsked = false; self?.closeCard(); self?.switchTo(n, toast: true) },
            { [weak self] in self?.closeCard(); self?.switchTo(n, toast: false); self?.ui.stopAfter = true; self?.toast("☾ Un dernier : prisme s'arrêtera après " + "S\(e.season) · É\(e.number)") },
            { [weak self] in self?.closeCard(); self?.quit() },
        ], back: { [weak self] in self?.closeCard(); self?.quit() }, sel: ui.encoreLate ? 1 : 0)
    }

    /// « Arrêt après cet épisode » / « Terminer la soirée » : le lecteur se ferme avec « 🌙 Bonne nuit ».
    private func endNight() {
        closeCard()
        player.pause()
        savePosition(at: duration)
        ui.message = "🌙 Bonne nuit\nprisme a arrêté après cet épisode."
        let w = DispatchWorkItem { [weak self] in self?.quit() }
        closeWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    // MARK: film

    private func lateFor(_ minutes: Int) -> Bool {
        guard minutes > 0 else { return false }
        return Self.eveningNow() + minutes > ui.bedMinutes
    }

    private func showPostCard() {
        var c = EndCardInfo()
        c.kicker = "🎬 SCÈNE APRÈS LE GÉNÉRIQUE"
        c.title = "Reste jusqu'au bout"
        c.buttons = ["D'accord", "Ignorer"]
        c.rateButtons = true
        c.rated = req.film.flatMap { FilmRatings.value($0.item.workKey, pid: ProfileStore.shared.me.id) }
        c.lines = ["Une scène t'attend à la toute fin."]
        showCard(.post, c, actions: [{ [weak self] in self?.closeCard() }, { [weak self] in self?.postPending = false; self?.closeCard() }],
                 back: { [weak self] in self?.closeCard() })
    }

    private func showFilmCard(countdown: Bool) {
        guard let p = pick else { return }
        let late = lateFor(p.minutes)
        var c = EndCardInfo()
        c.kicker = countdown && !late ? "À SUIVRE · LECTURE DANS" : "À SUIVRE"
        c.title = p.item.fiche?.title.isEmpty == false ? p.item.fiche!.title : p.item.clean.title
        c.image = p.item.posterURL
        c.poster = true
        let y = (p.item.fiche?.year ?? 0) > 0 ? p.item.fiche!.year : p.item.clean.year
        var meta: [String] = []
        if y > 0 { meta.append(String(y)) }
        if p.minutes > 0 { meta.append(runtimeText(p.minutes)); meta.append("fin à " + Fmt.hm(Date().addingTimeInterval(Double(p.minutes) * 60))) }
        c.lines = [p.reason] + (meta.isEmpty ? [] : [meta.joined(separator: " · ")]) + (late ? ["finirait après ton coucher : lancement à ta demande"] : [])
        c.buttons = ["▶ Regarder maintenant", "Rester"]
        c.rateButtons = true
        c.rated = req.film.flatMap { FilmRatings.value($0.item.workKey, pid: ProfileStore.shared.me.id) }
        showCard(.film, c, actions: [{ [weak self] in self?.playFilm(p) }, { [weak self] in self?.stayAfterCard() }],
                 back: { [weak self] in self?.stayAfterCard() }, countdown: countdown && !late ? PlaybackPrefs.filmCountdown : nil,
                 onZero: { [weak self] in self?.playFilm(p) })
    }

    private func stayAfterCard() {
        closeCard()
        // à la toute fin du film, « Rester » ferme le lecteur (en demandant ton avis si besoin)
        if player.state == .ended || (duration > 0 && position >= duration - 2) { if !askRateBeforeQuit() { quit() } }
        else { showOSD() }
    }

    private func playFilm(_ p: FilmPick) {
        closeCard()
        guard let r = p.request() else { toast("Ce film n'est plus disponible chez ton fournisseur"); return }
        savePosition(at: duration)
        switchTo(r, toast: false)
        toast("▶ " + r.title)
    }

    private func rateFromCard(_ v: Int) {
        guard let f = req.film else { return }
        FilmRatings.rate(f.item, v)
        rated = true
        var c = ui.endInfo; c.rated = v; ui.endInfo = c
        toast(v > 0 ? "👍 Noté : tes recommandations en tiennent compte" : "👎 Noté : moins de films comme celui-ci")
    }

    /// « Tu as aimé … ? » : fin du film ou départ après 85 % ; jamais deux fois pour le même film.
    fileprivate func askRateBeforeQuit() -> Bool {
        guard let f = req.film, !rated, ui.card != .rate, duration > 0, position / duration >= 0.85,
              FilmRatings.shouldAsk(f.item.workKey, pid: ProfileStore.shared.me.id) else { return false }
        rated = true
        player.pause()
        ui.rateTitle = f.item.fiche?.title.isEmpty == false ? f.item.fiche!.title : f.item.clean.title
        let w = f.item.workKey, pid = ProfileStore.shared.me.id
        showCard(.rate, EndCardInfo(), actions: [
            { [weak self] in FilmRatings.rate(f.item, 1); self?.closeCard(); self?.quit() },
            { [weak self] in FilmRatings.rate(f.item, -1); self?.closeCard(); self?.quit() },
            { [weak self] in FilmRatings.skip(w, pid: pid); self?.closeCard(); self?.quit() },
        ], back: { [weak self] in FilmRatings.skip(w, pid: pid); self?.closeCard(); self?.quit() })
        return true
    }

    // MARK: journal

    fileprivate func flushJournal() {
        let sec = Int(played)
        played = 0; playedLast = -1
        let start = sessionStart
        sessionStart = Date()
        let pid = ProfileStore.shared.me.id
        if isLive {
            guard req.live.indices.contains(liveIndex) else { return }
            let ch = req.live[liveIndex]
            WatchJournal.add(.init(profile: pid, start: start, item: "live:" + ch.id, key: "", title: ChannelTools.clean(ch.name), ep: "", kind: "tv", seconds: sec))
        } else if let e = req.episode {
            WatchJournal.add(.init(profile: pid, start: start, item: req.item, key: req.key, title: e.seriesTitle, ep: episodeLabel(e.season, e.number), kind: "episode", seconds: sec))
        } else {
            WatchJournal.add(.init(profile: pid, start: start, item: req.item, key: req.key, title: req.title, ep: "", kind: req.item.hasPrefix("replay:") ? "replay" : "film", seconds: sec))
        }
    }
}
