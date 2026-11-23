import SwiftUI

@main
struct IPTVPersoApp: App {
    @StateObject private var store = ProviderStore.shared

    init() {
        // affiches et logos : 30 Mo en mémoire, 300 Mo sur le disque au plus (le plus ancien est supprimé d'abord)
        URLCache.shared = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        HomeCacheHook.install()
        PerfLog.startMemSampler()
        ListFiles.purgeOld()
        Debug.legacySeedBeforeStores()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.providers.isEmpty || store.onboarding {
                    AddProviderFlow(firstLaunch: true, close: { store.onboarding = false }, watchTV: { store.onboarding = false; Nav.shared.tab = .live })
                        .onAppear { store.onboarding = true }
                } else {
                    MainTabView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .onAppear { Debug.seedIfNeeded(); DataCount.write("ouverture"); store.refreshIfStale(); FicheService.shared.start() }
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
    @State private var diag = ""
    /// lot 4 : bandeau « Cette nuit » et rappels TV
    @State private var night: String?
    @State private var reminder: TVReminders.R?
    @State private var reminderLive: LiveLaunch?
    @FocusState private var reminderFocus: Bool
    /// lot 6 : titre ouvert depuis une carte du Top Shelf (prisme://play… ou prisme://open…)
    @State private var linkOpen: LinkOpen?
    @State private var linked = false
    @State private var shelfPreview = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        mainBody
            .onOpenURL { openLink($0) }
            // lot 6 : la rangée du Top Shelf suit le profil, le catalogue et ce que tu regardes
            .onChange(of: profiles.version) { _, _ in TopShelfPublisher.schedule() }
            .onChange(of: profiles.current) { _, _ in TopShelfPublisher.schedule() }
            .onChange(of: store.catalogVersion) { _, _ in TopShelfPublisher.schedule(after: 20) }
            .onChange(of: phase) { _, p in if p == .background { TopShelfPublisher.schedule(after: 0) } }
            .overlay { if shelfPreview { ShelfPreviewScreen(close: { shelfPreview = false }) } }
    }

    private var mainBody: some View {
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
                // Retour depuis le contenu d'une page (rangées, grilles, colonne de la TV) : remonter d'abord à la barre
                // du haut, comme les applications Apple ; Retour depuis la barre du haut quitte prisme (comportement tvOS)
                .onExitCommand(perform: nav.barFocused ? nil : { nav.goToBar() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if Debug.demoServer != nil {
                    // simulateur de test uniquement : état de l'écran « Qui regarde ? » lisible par la visite automatique
                    Text(diag).font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("prisme.diag").accessibilityLabel(diag)
                }
            }
            .ignoresSafeArea()
            .navigationDestination(item: $debugOpen) { it in DetailView(item: it) }
            .navigationDestination(item: $resumeOpen) { it in DetailView(item: it) }
            .navigationDestination(item: $linkOpen) { o in DetailView(item: o.item, autoPlay: o.play) }
        }
        // fenêtres au-dessus de TOUT, y compris d'une fiche ouverte (la pastille de profil de la fiche ouvre la fenêtre)
        .disabled(pui.picker || pui.launch || pui.taste != nil)
        .overlay {
            if pui.picker {
                ProfilePickerModal(close: { pui.picker = false }, manage: { pui.picker = false; nav.tab = .settings; if pui.editProfile == nil { pui.editProfile = "" } })
                    .transition(.opacity)
            }
        }
        .overlay {
            // « Qui regarde ? » à l'ouverture : couche plein écran au-dessus de la page (comme la fenêtre des profils ;
            // une présentation « plein écran » système n'était pas affichée de façon fiable au lancement)
            if pui.launch {
                WhoIsWatchingScreen(done: { it in pui.shownAtLaunch = true; pui.launch = false; if let it { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { resumeOpen = it } } },
                                    manage: { pui.shownAtLaunch = true; pui.launch = false; nav.tab = .settings; if pui.editProfile == nil { pui.editProfile = "" } })
                    .focusSection()
                    .transition(.opacity)
            }
        }
        .overlay {
            // test « Mes goûts » (plein écran, au-dessus de tout)
            if let t = pui.taste {
                TasteTestView(pid: t, close: { pui.taste = nil }).focusSection().transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            // simulateur .mn-night : pilule en haut au centre, 6,5 s, puis s'efface
            // (top 84 du simulateur × 1,5 = 126, mesuré depuis le haut de l'écran, sans la marge de sécurité tvOS)
            if let n = night { NightPill(text: n).padding(.top, 126).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).ignoresSafeArea().transition(.opacity).allowsHitTesting(false) }
        }
        .overlay { AppToastView() }
        .overlay(alignment: .bottom) {
            // rappel TV arrivé à son heure (prisme ouvert) : le lancer ou fermer
            if let r = reminder {
                HStack(spacing: 24) {
                    Text("⏰ " + r.title + " · " + r.chName + " · " + Fmt.hm(Date(timeIntervalSince1970: TimeInterval(r.start)))).font(P.font(27, .semibold)).lineLimit(1)
                    Button { openReminder(r) } label: { Text("▶ Regarder").font(P.font(25, .semibold)) }
                        .buttonStyle(PrimaryStyle()).focused($reminderFocus).accessibilityIdentifier("rappel-regarder")
                    Button { reminder = nil } label: { Text("Fermer").font(P.font(25, .semibold)) }
                        .accessibilityIdentifier("rappel-fermer")
                }
                .padding(.horizontal, 36).padding(.vertical, 22)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1.5)))
                .environment(\.colorScheme, .dark)
                .padding(.bottom, 60)
                .focusSection()
                .onExitCommand { reminder = nil }
                .accessibilityIdentifier("rappel-tv")
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $reminderLive) { l in LivePlayerView(channels: [l.ch], start: 0) }
        .task(id: "\(profiles.current)|\(pui.launch)") {
            // « Cette nuit » : une fois par jour et par profil, après le choix du profil
            guard !pui.launch, !store.providers.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, let m = await NightBanner.message(pids: store.active.map(\.id)) else { return }
            DataCount.write("cette nuit : " + m.text)
            withAnimation(.easeOut(duration: 0.4)) { night = m.text }
            try? await Task.sleep(nanoseconds: 6_500_000_000)
            withAnimation(.easeOut(duration: 0.7)) { night = nil }
        }
        .task(id: profiles.current) {
            // rappels TV : vérifiés toutes les 20 s (et au lancement, pour un rappel manqué)
            while !Task.isCancelled {
                if reminder == nil, let r = TVReminders.due().first {
                    DataCount.write("rappel TV affiché : " + r.title)
                    withAnimation { reminder = r }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { reminderFocus = true }
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        .animation(.easeOut(duration: 0.2), value: pui.picker)
        .animation(.easeOut(duration: 0.3), value: pui.launch)
        .animation(.easeOut(duration: 0.3), value: pui.taste)
        .onAppear {
            // « Qui regarde ? » à l'ouverture, s'il y a plusieurs profils et si c'est demandé dans les réglages
            guard !asked else { return }
            asked = true
            Debug.seedIfNeeded()   // profils de test éventuels AVANT de décider (sans effet dans l'app installée)
            // présenté un peu après l'apparition de l'écran (une fenêtre plein écran présentée trop tôt peut être ignorée),
            // puis vérifié une seconde fois si la première tentative n'a pas pris
            for delay in [0.8, 2.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let want = profiles.ask && profiles.profiles.count > 1 && Debug.open == nil && Debug.tab == nil && !linked && !Debug.shelf && Debug.link == nil
                    if want && !pui.launch && !pui.shownAtLaunch { pui.launch = true }
                    diag = "ask=\(profiles.ask) profils=\(profiles.profiles.count) voulu=\(want) affiché=\(pui.launch) t=\(delay)"
                }
            }
        }
        .task {
            // lot 6 : première rangée du Top Shelf une fois le catalogue lu (test : tout de suite, avec l'aperçu)
            if let l = Debug.link, let u = URL(string: l) { try? await Task.sleep(nanoseconds: 2_000_000_000); openLink(u) }
            if Debug.shelf {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                await TopShelfPublisher.publish()
                shelfPreview = true
            } else {
                TopShelfPublisher.schedule(after: 25)
            }
        }
        .task {
            // test du simulateur uniquement : onglet ou fiche demandés en argument de lancement
            if let t = Debug.tab { nav.tab = ["films": .films, "series": .series, "live": .live, "mine": .mine, "search": .search, "settings": .settings][t] ?? nav.tab }
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

/// lot 6 : titre demandé par une carte du Top Shelf
struct LinkOpen: Identifiable, Hashable {
    let item: MediaItem
    let play: Bool
    var id: String { item.id + (play ? "|play" : "") }
}

extension MainTabView {
    /// prisme://play?id=…&p=… (reprise directe) ou prisme://open?id=…&p=… (fiche), comme le simulateur (fxhplay / fxhopen)
    fileprivate func openLink(_ url: URL) {
        guard url.scheme == "prisme", let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = c.queryItems?.first(where: { $0.name == "id" })?.value else { return }
        let play = c.host == "play"
        linked = true
        pui.launch = false; pui.shownAtLaunch = true; shelfPreview = false
        // la carte a été préparée pour ce profil : on le reprend (« À deux » garde le profil actif)
        if let p = c.queryItems?.first(where: { $0.name == "p" })?.value, p != "duo", p != profiles.current,
           profiles.profiles.contains(where: { $0.id == p }) { profiles.use(p) }
        PerfLog.ev("Top Shelf : lien " + url.absoluteString)
        Task {
            var it: MediaItem? = nil
            for _ in 0..<30 {   // au lancement, le catalogue peut mettre quelques secondes à être lisible
                it = await MediaStore.items(ids: [id]).first
                if it != nil { break }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            guard let it else { AppToast.shared.say("Ce titre n'est plus chez ton fournisseur"); return }
            nav.tab = it.kind == .film ? .films : .series
            debugOpen = nil; resumeOpen = nil; linkOpen = nil
            try? await Task.sleep(nanoseconds: 500_000_000)
            linkOpen = LinkOpen(item: it, play: play)
        }
    }

    fileprivate func openReminder(_ r: TVReminders.R) {
        reminder = nil
        Task {
            if let ch = await LiveIndex.resolve(ids: [r.chID]).first { reminderLive = LiveLaunch(ch: ch) }
            else { AppToast.shared.say("Cette chaîne n'est plus chez ton fournisseur") }
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
