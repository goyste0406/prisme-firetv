import SwiftUI

@main
struct IPTVPersoApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if let account = state.account {
                    MainTabView(api: XtreamAPI(account: account))
                } else {
                    LoginView()
                }
            }
            .environmentObject(state)
        }
    }
}

/// Garde les identifiants Xtream sur l'Apple TV entre deux lancements.
@MainActor
final class AppState: ObservableObject {
    private let key = "xtream_account"

    @Published var account: XtreamAccount? {
        didSet {
            if let account, let data = try? JSONEncoder().encode(account) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(XtreamAccount.self, from: data) {
            account = saved
        }
    }
}

struct MainTabView: View {
    let api: XtreamAPI

    var body: some View {
        TabView {
            LiveTVView(api: api)
                .tabItem { Label("TV en direct", systemImage: "tv") }
            MoviesView(api: api)
                .tabItem { Label("Films", systemImage: "film") }
            SeriesView(api: api)
                .tabItem { Label("Séries", systemImage: "play.rectangle.on.rectangle") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
        }
    }
}
