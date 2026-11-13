import SwiftUI

@main
struct IPTVPersoApp: App {
    @StateObject private var store = ProviderStore.shared

    init() {
        // affiches et logos : 30 Mo en mémoire, 300 Mo sur le disque au plus (le plus ancien est supprimé d'abord)
        URLCache.shared = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        HomeCacheHook.install()
        Debug.legacySeedBeforeStores()
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
            .onAppear { Debug.seedIfNeeded(); store.refreshIfStale(); FicheService.shared.start() }
            .onChange(of: store.catalogVersion) { _ in FicheService.shared.restart() }
        }
    }
}

/// Racine : fond prisme et page de l'onglet choisi. Chaque page porte la barre du haut (comme dans le simulateur).
/// Les fiches s'ouvrent par-dessus, en plein écran, sans la barre.
struct MainTabView: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var nav = Nav.shared
    @ObservedObject var profiles = ProfileStore.shared
    @ObservedObject var pui = ProfileUI.shared
    @State private var debugOpen: MediaItem?
    @State private var resumeOpen: MediaItem?
    @State private var asked = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PrismeBackground()
                Group {
                    switch nav.tab {
                    case .films: MediaHomeView(kind: .film)
                    case .series: MediaHomeView(kind: .series)
                    case .live: LiveHomeView()
                    case .mine: MineView()
                    case .search: SearchView()
                    case .settings: ProvidersSettingsView()
                    }
                }
                .id("\(nav.tab.rawValue)|\(profiles.current)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(pui.picker)
                if pui.picker {
                    ProfilePickerModal(close: { pui.picker = false }, manage: { pui.picker = false; nav.tab = .settings; if pui.editProfile == nil { pui.editProfile = "" } })
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: pui.picker)
            .ignoresSafeArea()
            .navigationDestination(item: $debugOpen) { it in DetailView(item: it) }
            .navigationDestination(item: $resumeOpen) { it in DetailView(item: it) }
        }
        .fullScreenCover(isPresented: $pui.launch) {
            WhoIsWatchingScreen(done: { it in pui.launch = false; if let it { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { resumeOpen = it } } },
                                manage: { pui.launch = false; nav.tab = .settings; if pui.editProfile == nil { pui.editProfile = "" } })
        }
        .onAppear {
            // « Qui regarde ? » à l'ouverture, s'il y a plusieurs profils et si c'est demandé dans les réglages
            guard !asked else { return }
            asked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if profiles.ask && profiles.profiles.count > 1 && Debug.open == nil && Debug.tab == nil { pui.launch = true }
            }
        }
        .task {
            // test du simulateur uniquement : onglet ou fiche demandés en argument de lancement
            if let t = Debug.tab { nav.tab = ["films": .films, "series": .series, "live": .live, "mine": .mine, "settings": .settings][t] ?? nav.tab }
            guard let o = Debug.open else { return }
            for _ in 0..<120 {
                if let it = await MediaStore.items(ids: [o]).first {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    debugOpen = await MediaStore.items(ids: [o]).first ?? it
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

/// Petit indicateur discret pendant que le catalogue se met à jour en arrière-plan.
struct ImportBadge: View {
    @EnvironmentObject var store: ProviderStore
    var body: some View {
        if store.importing != nil {
            HStack(spacing: 12) {
                ProgressView(value: store.progress).frame(width: 120).tint(.white)
                Text(store.status).font(P.font(19, .medium)).foregroundStyle(P.dim).lineLimit(1)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
            .glass(30)
            .frame(maxWidth: 520, alignment: .trailing)
        }
    }
}
