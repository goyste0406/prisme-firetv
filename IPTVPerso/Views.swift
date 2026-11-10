import SwiftUI
import AVKit

// MARK: - Connexion

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            Text("IPTV Perso").font(.largeTitle).bold()
            TextField("Serveur (ex : http://monserveur.com:8080)", text: $server)
            TextField("Nom d'utilisateur", text: $username)
            SecureField("Mot de passe", text: $password)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Button {
                Task { await login() }
            } label: {
                if loading { ProgressView() } else { Text("Se connecter") }
            }
            .disabled(loading || server.isEmpty || username.isEmpty || password.isEmpty)
        }
        .frame(maxWidth: 900)
        .padding(80)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private func login() async {
        loading = true
        errorMessage = nil
        let account = XtreamAccount(server: server, username: username, password: password)
        do {
            try await XtreamAPI(account: account).authenticate()
            state.account = account
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

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

struct PlayerView: UIViewControllerRepresentable {
    let item: PlayItem

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerItem = AVPlayerItem(url: item.url)
        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.value = item.title as NSString
        title.extendedLanguageTag = "und"
        playerItem.externalMetadata = [title]

        let player = AVPlayer(playerItem: playerItem)
        let controller = AVPlayerViewController()
        controller.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
    }
}

// MARK: - TV en direct

struct LiveTVView: View {
    let api: XtreamAPI

    var body: some View {
        NavigationStack {
            AsyncContent(load: { try await api.liveCategories() }) { categories in
                List {
                    NavigationLink("Toutes les chaînes") {
                        ChannelListView(api: api, categoryID: nil, title: "Toutes les chaînes")
                    }
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            ChannelListView(api: api, categoryID: category.id, title: category.name)
                        }
                    }
                }
            }
            .navigationTitle("TV en direct")
        }
    }
}

struct ChannelListView: View {
    let api: XtreamAPI
    let categoryID: String?
    let title: String
    @AppStorage("liveFormat") private var liveFormat = "m3u8"
    @State private var search = ""
    @State private var playing: PlayItem?

    var body: some View {
        AsyncContent(load: { try await api.liveStreams(categoryID: categoryID) }) { channels in
            let filtered = search.isEmpty
                ? channels
                : channels.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
            List(filtered) { channel in
                Button {
                    if let url = api.liveURL(channel, format: liveFormat) {
                        playing = PlayItem(url: url, title: channel.displayName)
                    }
                } label: {
                    HStack(spacing: 24) {
                        AsyncImage(url: URL(string: channel.stream_icon ?? "")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Image(systemName: "tv")
                        }
                        .frame(width: 80, height: 60)
                        Text(channel.displayName)
                    }
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle(title)
        .fullScreenCover(item: $playing) { PlayerView(item: $0).ignoresSafeArea() }
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
        .fullScreenCover(item: $playing) { PlayerView(item: $0).ignoresSafeArea() }
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
        .fullScreenCover(item: $playing) { PlayerView(item: $0).ignoresSafeArea() }
    }
}

// MARK: - Réglages

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("liveFormat") private var liveFormat = "m3u8"

    var body: some View {
        NavigationStack {
            Form {
                Section("Compte") {
                    LabeledContent("Serveur", value: state.account?.baseURL ?? "-")
                    LabeledContent("Utilisateur", value: state.account?.username ?? "-")
                }
                Section("Lecture") {
                    Picker("Format TV en direct", selection: $liveFormat) {
                        Text("HLS (m3u8) – recommandé").tag("m3u8")
                        Text("MPEG-TS (ts)").tag("ts")
                    }
                }
                Section {
                    Button("Se déconnecter", role: .destructive) { state.account = nil }
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
