import SwiftUI
import UIKit
import TVVLCKit

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

/// Lecteur des films et séries : VLC, reprise là où tu t'étais arrêté, ±10 s avec gauche/droite, ±60 s en maintenant.
final class VodPlayerController: UIViewController, VLCMediaPlayerDelegate {
    private var req: VodRequest
    private let onClose: () -> Void
    private let player = VLCMediaPlayer()
    private let videoView = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let titleL = UILabel(), subL = UILabel(), timeL = UILabel(), remainL = UILabel(), message = UILabel()
    private let bar = UIProgressView(progressViewStyle: .default)
    private var hideWork: DispatchWorkItem?
    private var saveTimer: Timer?
    private var seeked = false
    private var retried = false
    private var pendingSeek: Double = 0
    private var cutAt: Double?
    private var cutDone = false
    private var seekWork: DispatchWorkItem?

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
        spinner.color = .white; spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        card.layer.cornerRadius = 28; card.clipsToBounds = true; card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        let times = UIStackView(arrangedSubviews: [timeL, UIView(), remainL])
        let stack = UIStackView(arrangedSubviews: [subL, titleL, bar, times])
        stack.axis = .vertical; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        subL.font = .systemFont(ofSize: 24, weight: .semibold); subL.textColor = UIColor(white: 1, alpha: 0.7)
        titleL.font = .systemFont(ofSize: 40, weight: .bold); titleL.textColor = .white
        timeL.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium); timeL.textColor = .white
        remainL.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium); remainL.textColor = UIColor(white: 1, alpha: 0.7)
        bar.progressTintColor = .white; bar.trackTintColor = UIColor(white: 1, alpha: 0.2)
        message.font = .systemFont(ofSize: 30, weight: .medium); message.textColor = .white
        message.numberOfLines = 0; message.textAlignment = .center; message.isHidden = true
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 80), card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -80),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 36), stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -36),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 26), stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -26),
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor), message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualToConstant: 1200),
        ])
        player.drawable = videoView
        player.delegate = self
        start()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.savePosition() }
    }

    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }

    func stop() {
        savePosition()
        saveTimer?.invalidate(); saveTimer = nil
        if player.isPlaying || player.state != .stopped { player.stop() }
    }

    private func start() {
        titleL.text = req.title; subL.text = req.subtitle
        if player.state != .stopped { player.stop() }     // une seule connexion
        seeked = false; retried = false; message.isHidden = true
        let media = VLCMedia(url: req.url)
        media.addOption(":network-caching=2000")
        player.media = media
        spinner.startAnimating()
        player.play()
        showCard()
    }

    private var duration: Double { Double(player.media?.length.intValue ?? 0) / 1000 }
    private var position: Double { Double(player.time.intValue) / 1000 }

    private func savePosition() {
        let d = duration, p = position
        guard d > 60, p > 0 else { return }
        let r = req
        Task { @MainActor in WatchStore.shared.save(key: r.key, pos: p, dur: d, title: r.title, icon: r.icon, item: r.item, ep: r.subtitle.isEmpty ? nil : r.subtitle) }
    }

    private static func hms(_ t: Double) -> String {
        let s = max(0, Int(t)), h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }

    private func refreshCard() {
        let d = duration, p = pendingSeek != 0 ? max(0, min(d, position + pendingSeek)) : position
        bar.progress = d > 0 ? Float(p / d) : 0
        timeL.text = Self.hms(p) + (pendingSeek != 0 ? (pendingSeek > 0 ? "  (+\(Int(pendingSeek)) s)" : "  (\(Int(pendingSeek)) s)") : "")
        remainL.text = d > 0 ? "-" + Self.hms(d - p) + " · fin à " + Fmt.hm(Date().addingTimeInterval(d - p)) : ""
    }

    private func showCard() {
        refreshCard()
        hideWork?.cancel()
        UIView.animate(withDuration: 0.2) { self.card.alpha = 1 }
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.player.isPlaying else { return }
            UIView.animate(withDuration: 0.4) { self.card.alpha = 0 }
        }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: w)
    }

    /// Avance / retour : les appuis rapides s'additionnent, le saut se fait une seule fois.
    private func seek(_ s: Double) {
        pendingSeek += s
        showCard()
        seekWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let target = max(0, min(self.duration - 2, self.position + self.pendingSeek))
            self.pendingSeek = 0
            self.player.time = VLCTime(int: Int32(target * 1000))
            self.refreshCard()
        }
        seekWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return super.pressesBegan(presses, with: event) }
        switch press.type {
        case .menu: stop(); onClose()
        case .leftArrow: seek(-10)
        case .rightArrow: seek(10)
        case .select where cutDone && !player.isPlaying:
            cutClose?.cancel(); message.isHidden = true; player.play(); showCard()
        case .upArrow, .downArrow, .select: showCard()
        case .playPause:
            if player.isPlaying { player.pause() } else { player.play() }
            showCard()
        default: super.pressesBegan(presses, with: event)
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // reprise : on saute à la position enregistrée dès que la durée est connue
            if !self.seeked, self.req.startAt > 0, self.duration > 0 {
                self.seeked = true
                self.player.time = VLCTime(int: Int32(self.req.startAt * 1000))
            }
            if self.card.alpha > 0 { self.refreshCard() }
            self.checkCut()
        }
    }

    /// Partie 1 d'un film en deux soirées : pause à la coupure, position gardée, « Bonne nuit ! », fermeture après 10 s.
    private func checkCut() {
        guard let s = req.stopAt, !cutDone, duration > 0 else { return }
        if cutAt == nil {
            cutAt = s
            // chapitres du fichier : on se cale sur le début de chapitre le plus proche (± 10 min), sinon l'heure choisie
            let ch = player.chapterDescriptions(ofTitle: player.currentTitleIndex) as? [[String: Any]] ?? []
            let starts = ch.compactMap { ($0[VLCChapterDescriptionTimeOffset] as? NSNumber)?.doubleValue }.map { $0 / 1000 }.filter { $0 > 60 }
            if let best = starts.min(by: { abs($0 - s) < abs($1 - s) }), abs(best - s) <= 600 { cutAt = best }
        }
        guard let c = cutAt, position >= c else { return }
        cutDone = true
        player.pause()
        savePosition()
        let rest = max(1, Int((duration - position) / 60))
        message.text = "FIN DE LA PARTIE 1\nBonne nuit !\nLa partie 2 (\(rest >= 60 ? "\(rest / 60) h " + String(format: "%02d", rest % 60) : "\(rest) min")) t'attend sur la fiche et dans « Reprendre ».\n\nOK pour continuer quand même · fermeture dans 10 s"
        message.isHidden = false
        let w = DispatchWorkItem { [weak self] in guard let self, !self.player.isPlaying else { return }; self.stop(); self.onClose() }
        cutClose = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: w)
    }
    private var cutClose: DispatchWorkItem?

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.player.state {
            case .playing, .paused:
                self.spinner.stopAnimating(); self.message.isHidden = true
            case .opening, .buffering:
                if !self.player.isPlaying { self.spinner.startAnimating() }
            case .error:
                if !self.retried { self.retried = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.player.play() }; return }
                self.spinner.stopAnimating()
                self.message.text = "Lecture impossible.\nEssaie une autre version depuis la fiche, ou réessaie plus tard (ton abonnement est peut-être utilisé sur un autre appareil)."
                self.message.isHidden = false
            case .ended:
                self.spinner.stopAnimating()
                self.savePosition()
                if let n = self.req.next?() { self.req = n; self.start() }   // épisode suivant
                else { self.stop(); self.onClose() }
            default: break
            }
        }
    }
}
