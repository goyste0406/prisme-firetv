import SwiftUI
import UIKit
import TVVLCKit

/// Lecteur de la TV en direct : VLC, une seule connexion à la fois, zapping haut/bas dans la liste en cours.
struct LivePlayerView: View {
    let channels: [Channel]
    let start: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LivePlayerRepresentable(channels: channels, start: start, onClose: { dismiss() })
            .ignoresSafeArea()
    }
}

struct LivePlayerRepresentable: UIViewControllerRepresentable {
    let channels: [Channel]
    let start: Int
    let onClose: () -> Void
    func makeUIViewController(context: Context) -> LivePlayerController { LivePlayerController(channels: channels, index: start, onClose: onClose) }
    func updateUIViewController(_ c: LivePlayerController, context: Context) {}
    static func dismantleUIViewController(_ c: LivePlayerController, coordinator: ()) { c.stop() }
}

final class LivePlayerController: UIViewController, VLCMediaPlayerDelegate {
    private let channels: [Channel]
    private var index: Int
    private let onClose: () -> Void
    private let player = VLCMediaPlayer()
    private let videoView = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let chLabel = UILabel(), nowLabel = UILabel(), nextLabel = UILabel(), message = UILabel()
    private let bar = UIProgressView(progressViewStyle: .default)
    private var hideCard: DispatchWorkItem?
    private var retried = false
    private var zapWork: DispatchWorkItem?

    init(channels: [Channel], index: Int, onClose: @escaping () -> Void) {
        self.channels = channels; self.index = max(0, min(index, channels.count - 1)); self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        videoView.frame = view.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        card.layer.cornerRadius = 28; card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        let stack = UIStackView(arrangedSubviews: [chLabel, nowLabel, bar, nextLabel])
        stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        chLabel.font = .systemFont(ofSize: 26, weight: .bold); chLabel.textColor = UIColor(white: 1, alpha: 0.7)
        nowLabel.font = .systemFont(ofSize: 40, weight: .bold); nowLabel.textColor = .white
        nextLabel.font = .systemFont(ofSize: 24, weight: .medium); nextLabel.textColor = UIColor(white: 1, alpha: 0.65)
        bar.progressTintColor = .white; bar.trackTintColor = UIColor(white: 1, alpha: 0.2)

        message.font = .systemFont(ofSize: 30, weight: .medium); message.textColor = .white
        message.numberOfLines = 0; message.textAlignment = .center; message.isHidden = true
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 80),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -80),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -36),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -26),
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualToConstant: 1200),
        ])

        for dir in [UISwipeGestureRecognizer.Direction.up, .down] {
            let g = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            g.direction = dir
            view.addGestureRecognizer(g)
        }
        player.drawable = videoView
        player.delegate = self
        play()
    }

    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }

    func stop() {
        zapWork?.cancel()
        if player.isPlaying || player.state != .stopped { player.stop() }
    }

    private var current: Channel { channels[index] }

    private func play() {
        let ch = current
        Task { @MainActor in LivePrefs.shared.played(ch.id) }
        showCard()
        guard let prov = ProviderStore.sharedProvider(ch.pid), let url = prov.liveURL(ch) else {
            message.text = "Ce fournisseur n'est plus disponible."; message.isHidden = false; return
        }
        // une seule connexion : l'ancien flux est coupé avant d'ouvrir le nouveau
        if player.state != .stopped { player.stop() }
        message.isHidden = true
        retried = false
        let media = VLCMedia(url: url)
        media.addOption(":network-caching=1500")
        player.media = media
        spinner.startAnimating()
        player.play()
    }

    /// Zapping : la bannière change tout de suite, le flux suit 350 ms après le dernier appui (zapper vite ne lance pas 10 connexions).
    private func zap(_ step: Int) {
        guard channels.count > 1 else { return }
        index = (index + step + channels.count) % channels.count
        showCard()
        zapWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.play() }
        zapWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
    }

    @objc private func swiped(_ g: UISwipeGestureRecognizer) { zap(g.direction == .up ? -1 : 1) }

    private func showCard() {
        let ch = current
        chLabel.text = (ch.num > 0 ? "\(ch.num) · " : "") + ch.name
        nowLabel.text = ch.name; nextLabel.text = ""; bar.progress = 0
        Task { @MainActor in
            let (n, x) = await LiveStore.nowNext(ch)
            guard self.current.id == ch.id else { return }
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            self.nowLabel.text = n?.title ?? ch.name
            self.bar.progress = Float(n?.progress() ?? 0)
            self.bar.isHidden = n == nil
            if let x { self.nextLabel.text = "Ensuite à \(f.string(from: x.startDate)) · \(x.title)" }
            else if let n { self.nextLabel.text = "Jusqu'à \(f.string(from: n.stopDate))" }
            else { self.nextLabel.text = "Programme non communiqué" }
        }
        hideCard?.cancel()
        UIView.animate(withDuration: 0.2) { self.card.alpha = 1 }
        let w = DispatchWorkItem { [weak self] in UIView.animate(withDuration: 0.4) { self?.card.alpha = 0 } }
        hideCard = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: w)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return super.pressesBegan(presses, with: event) }
        switch press.type {
        case .menu: stop(); onClose()
        case .upArrow: zap(-1)
        case .downArrow: zap(1)
        case .select: showCard()
        case .playPause: if player.isPlaying { player.pause() } else { player.play() }; showCard()
        default: super.pressesBegan(presses, with: event)
        }
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.player.state {
            case .playing, .paused:
                self.spinner.stopAnimating(); self.message.isHidden = true
            case .opening, .buffering:
                if !self.player.isPlaying { self.spinner.startAnimating() }
            case .error:
                // une nouvelle tentative, puis un message clair
                if !self.retried { self.retried = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.player.play() }; return }
                self.spinner.stopAnimating()
                self.message.text = "Cette chaîne ne répond pas.\nZappe vers le haut ou le bas, ou réessaie plus tard (ton abonnement est peut-être déjà utilisé sur un autre appareil)."
                self.message.isHidden = false
            case .ended:
                self.spinner.stopAnimating()
                self.message.text = "La diffusion s'est arrêtée."; self.message.isHidden = false
            default: break
            }
        }
    }
}

extension ProviderStore {
    /// Lecture des fournisseurs depuis n'importe quel fil (le lecteur n'est pas sur l'acteur principal).
    nonisolated static func sharedProvider(_ id: String) -> Provider? {
        guard let d = UserDefaults.standard.data(forKey: "prisme.providers"),
              let list = try? JSONDecoder().decode([Provider].self, from: d) else { return nil }
        return list.first { $0.id == id }
    }
}
