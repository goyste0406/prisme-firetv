import SwiftUI
import TVVLCKit

// MARK: - Outils communs

/// Affiche un chargement, puis le contenu, ou une erreur avec bouton Réessayer.
struct AsyncContent<T, Content: View>: View {
    let load: () async throws -> T
    @ViewBuilder let content: (T) -> Content
    @State private var result: Result<T, Error>?

    var body: some View {
        Group {
            switch result {
            case .none:
                ProgressView("Chargement…")
            case .success(let value):
                content(value)
            case .failure(let error):
                VStack(spacing: 20) {
                    Text("Erreur").font(.title2)
                    Text(error.localizedDescription).foregroundStyle(.secondary)
                    Button("Réessayer") { Task { await run() } }
                }
            }
        }
        .task { if result == nil { await run() } }
    }

    private func run() async {
        result = nil
        do { result = .success(try await load()) }
        catch { result = .failure(error) }
    }
}

struct PosterCard: View {
    let title: String
    let imageURL: String?

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "film").font(.largeTitle)
                    }
                }
            }
            .frame(width: 240, height: 360)
            .clipped()
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 240)
        }
    }
}

private let posterColumns = [GridItem(.adaptive(minimum: 240), spacing: 40)]

// MARK: - Lecteur

struct PlayItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

/// Lecteur basé sur VLC (TVVLCKit) : lit directement les flux .ts, .mkv, .avi… que le lecteur d'Apple refuse.
struct PlayerView: View {
    let item: PlayItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VLCPlayerRepresentable(item: item, onClose: { dismiss() })
            .ignoresSafeArea()
    }
}

struct VLCPlayerRepresentable: UIViewControllerRepresentable {
    let item: PlayItem
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> VLCPlayerController {
        VLCPlayerController(url: item.url, title: item.title, onClose: onClose)
    }

    func updateUIViewController(_ controller: VLCPlayerController, context: Context) {}

    static func dismantleUIViewController(_ controller: VLCPlayerController, coordinator: ()) {
        controller.stop()
    }
}

final class VLCPlayerController: UIViewController, VLCMediaPlayerDelegate {
    private let url: URL
    private let titleText: String
    private let onClose: () -> Void
    private let player = VLCMediaPlayer()
    private let videoView = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let banner = UILabel()
    private let message = UILabel()
    private var hideBanner: DispatchWorkItem?

    init(url: URL, title: String, onClose: @escaping () -> Void) {
        self.url = url
        self.titleText = title
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        videoView.frame = view.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        banner.text = titleText
        banner.font = .systemFont(ofSize: 38, weight: .semibold)
        banner.textColor = .white
        banner.shadowColor = .black
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        message.font = .systemFont(ofSize: 30, weight: .medium)
        message.textColor = .white
        message.numberOfLines = 0
        message.textAlignment = .center
        message.isHidden = true
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 90),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -70),
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualToConstant: 1200),
        ])

        player.drawable = videoView
        player.delegate = self
        let media = VLCMedia(url: url)
        media.addOption(":network-caching=1500")
        player.media = media
        spinner.startAnimating()
        player.play()
        showBanner()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    func stop() {
        if player.isPlaying || player.state != .stopped { player.stop() }
    }

    private func showBanner() {
        hideBanner?.cancel()
        banner.alpha = 1
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.4) { self?.banner.alpha = 0 }
        }
        hideBanner = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return super.pressesBegan(presses, with: event) }
        switch press.type {
        case .menu:
            stop()
            onClose()
        case .playPause, .select:
            if player.isPlaying { player.pause() } else { player.play() }
            showBanner()
        default:
            super.pressesBegan(presses, with: event)
        }
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.player.state {
            case .playing, .paused:
                self.spinner.stopAnimating()
                self.message.isHidden = true
            case .opening, .buffering:
                if !self.player.isPlaying { self.spinner.startAnimating() }
            case .error:
                self.spinner.stopAnimating()
                self.message.text = "Lecture impossible.\nLe flux ne répond pas ou ton abonnement est déjà utilisé sur un autre appareil."
                self.message.isHidden = false
            case .ended:
                self.spinner.stopAnimating()
                self.message.text = "Fin de la diffusion."
                self.message.isHidden = false
            default:
                break
            }
        }
    }
}

// MARK: - Films

struct MoviesView: View {
    let api: XtreamAPI

    var body: some View {
        NavigationStack {
            AsyncContent(load: { try await api.vodCategories() }) { categories in
                List {
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            MovieGridView(api: api, categoryID: category.id, title: category.name)
                        }
                    }
                }
            }
            .navigationTitle("Films")
        }
    }
}

struct MovieGridView: View {
    let api: XtreamAPI
    let categoryID: String?
    let title: String
    @State private var playing: PlayItem?

    var body: some View {
        AsyncContent(load: { try await api.vodStreams(categoryID: categoryID) }) { movies in
            ScrollView {
                LazyVGrid(columns: posterColumns, spacing: 50) {
                    ForEach(movies) { movie in
                        Button {
                            if let url = api.movieURL(movie) {
                                playing = PlayItem(url: url, title: movie.displayName)
                            }
                        } label: {
                            PosterCard(title: movie.displayName, imageURL: movie.stream_icon)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(40)
            }
        }
        .navigationTitle(title)
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
    }
}

// MARK: - Séries

struct SeriesView: View {
    let api: XtreamAPI

    var body: some View {
        NavigationStack {
            AsyncContent(load: { try await api.seriesCategories() }) { categories in
                List {
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            SeriesGridView(api: api, categoryID: category.id, title: category.name)
                        }
                    }
                }
            }
            .navigationTitle("Séries")
        }
    }
}

struct SeriesGridView: View {
    let api: XtreamAPI
    let categoryID: String?
    let title: String

    var body: some View {
        AsyncContent(load: { try await api.series(categoryID: categoryID) }) { list in
            ScrollView {
                LazyVGrid(columns: posterColumns, spacing: 50) {
                    ForEach(list) { serie in
                        NavigationLink {
                            SeriesDetailView(api: api, serie: serie)
                        } label: {
                            PosterCard(title: serie.displayName, imageURL: serie.cover)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(40)
            }
        }
        .navigationTitle(title)
    }
}

struct SeriesDetailView: View {
    let api: XtreamAPI
    let serie: SeriesItem
    @State private var playing: PlayItem?

    var body: some View {
        AsyncContent(load: { try await api.seriesInfo(id: serie.id) }) { info in
            List {
                if let plot = serie.plot, !plot.isEmpty {
                    Text(plot).foregroundStyle(.secondary)
                }
                ForEach(info.seasons) { season in
                    Section("Saison \(season.id)") {
                        ForEach(season.episodes) { episode in
                            Button {
                                if let url = api.episodeURL(episode) {
                                    playing = PlayItem(url: url, title: episode.title ?? serie.displayName)
                                }
                            } label: {
                                Text("Épisode \(episode.episode_num ?? "?") – \(episode.title ?? "")")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(serie.displayName)
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
    }
}

