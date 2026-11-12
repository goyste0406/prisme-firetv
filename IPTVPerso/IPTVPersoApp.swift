import SwiftUI

@main
struct IPTVPersoApp: App {
    @StateObject private var store = ProviderStore.shared

    init() {
        // affiches et logos : 30 Mo en mémoire, 300 Mo sur le disque au plus (le plus ancien est supprimé d'abord)
        URLCache.shared = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.providers.isEmpty {
                    AddProviderView(firstLaunch: true)
                } else {
                    MainTabView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .onAppear { store.refreshIfStale() }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var store: ProviderStore

    var body: some View {
        TabView {
            LiveHomeView()
                .tabItem { Label("TV en direct", systemImage: "tv") }
            MediaHomeView(kind: .film)
                .tabItem { Label("Films", systemImage: "film") }
            MediaHomeView(kind: .series)
                .tabItem { Label("Séries", systemImage: "play.rectangle.on.rectangle") }
            ProvidersSettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
        }
        .overlay(alignment: .topTrailing) { ImportBadge().padding(40) }
    }
}

/// Petit indicateur discret pendant que le catalogue se met à jour en arrière-plan.
struct ImportBadge: View {
    @EnvironmentObject var store: ProviderStore
    var body: some View {
        if store.importing != nil {
            HStack(spacing: 12) {
                ProgressView(value: store.progress).frame(width: 120).tint(.white)
                Text(store.status).font(.system(size: 20)).lineLimit(1)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
