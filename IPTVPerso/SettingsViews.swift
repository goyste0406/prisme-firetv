import SwiftUI

// MARK: - Ajouter un fournisseur

struct AddProviderView: View {
    var firstLaunch = false
    @EnvironmentObject var store: ProviderStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PrismeBackground()
            VStack(alignment: .leading, spacing: 26) {
                Brand()
                Text(firstLaunch ? "Bienvenue dans prisme" : "Ajouter un fournisseur").font(P.font(52, .bold))
                if firstLaunch { Text("Entre les informations de ton abonnement Xtream.").font(P.font(25)).foregroundStyle(P.dim) }
                TextField("Nom (ex : Mon fournisseur)", text: $name)
                TextField("Serveur (ex : http://monserveur.com:8080)", text: $server)
                TextField("Nom d'utilisateur", text: $username)
                SecureField("Mot de passe", text: $password)
                if let errorMessage { Text(errorMessage).font(P.font(22, .semibold)).foregroundStyle(P.live) }
                Button {
                    Task { await add() }
                } label: {
                    if loading { ProgressView().tint(.black) } else { Text("Se connecter").font(P.font(28, .bold)) }
                }
                .buttonStyle(PrimaryStyle())
                .disabled(loading || server.isEmpty || username.isEmpty || password.isEmpty)
            }
            .frame(width: 900)
            .padding(60)
            .glass(40)
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private func add() async {
        loading = true; errorMessage = nil
        do {
            try await store.add(name: name, server: server, user: username, pass: password)
            if !firstLaunch { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

private struct ManagedID: Identifiable { let id: String }

// MARK: - Réglages (simulateur : catégories à gauche, panneau en verre à droite)

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: ProviderStore
    @State private var adding = false
    @State private var managing: String?
    @State private var showLog = false
    @State private var showClass = false
    @State private var confirmDelete: Provider?
    @State private var dbSize: Int64 = 0
    @State private var tmdbKey = TmdbKey.value ?? ""
    @State private var section = Debug.settingsSection ?? "prof"
    @ObservedObject var pui = ProfileUI.shared
    @ObservedObject var fiches = FicheService.shared
    @ObservedObject var ui = PrefUI.shared
    @StateObject private var pm = PrefsModel()
    @FocusState private var catFocus: String?
    /// Au retour d'un écran ouvert depuis Fournisseurs (Gérer, ajout, journal), la sélection revient sur la ligne d'origine
    /// au lieu de retomber sur « Profils » (tvOS repose le focus sur le premier élément de la page).
    @State private var holdSection = false
    @State private var restoreRow: (String, Int)?

    private static let cats: [(String, String, String)] = [
        // les 9 rubriques du simulateur (1.7.1)
        ("prof", "person", "Profils"), ("prov", "rectangle.stack", "Fournisseurs"), ("lang", "captions.bubble", "Langues et sous-titres"),
        ("play", "play.rectangle", "Lecture et image"), ("live", "tv", "TV en direct"), ("epg", "list.bullet.rectangle", "Guide TV"),
        ("homes", "house", "Accueils et notes"), ("par", "lock", "Contrôle parental"), ("data", "icloud.and.arrow.up", "Sauvegarde et mises à jour"),
    ]

    /// Contrôle parental : réglages verrouillés par le code (demandé à chaque entrée dans les Réglages)
    @State private var unlocked = false

    var body: some View {
        let _ = pm.tick
        VStack(spacing: 0) {
            TopBar(claimFocus: true)
            if AppPrefs.lockSettings && !unlocked {
                SettingsLock { unlocked = true }.focusSection()
            } else {
            // simulateur .sa / .sa-side / .sa-det : colonne de 340 px à 48 px du bord, panneau à 412 px (× 1,5 sur Apple TV)
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 6) {
                    // simulateur .sa-q : « Rechercher un réglage » en haut de la colonne
                    Button { ui.searching = true; section = "search" } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "magnifyingglass").font(P.font(22, .semibold))
                            Text(ui.query.isEmpty ? "Rechercher un réglage" : ui.query).font(P.font(27, .medium)).lineLimit(1)
                            Spacer()
                        }
                        .opacity(ui.query.isEmpty ? 0.6 : 1)
                        .padding(.horizontal, 24).frame(height: 76)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(SideStyle(selected: section == "search"))
                    .focused($catFocus, equals: "search")
                    .accessibilityIdentifier("sa-q")
                    .padding(.bottom, 6)
                    ForEach(0..<ProvidersSettingsView.cats.count, id: \.self) { i in
                        let c = ProvidersSettingsView.cats[i]
                        Button { section = c.0 } label: {
                            HStack(spacing: 18) {
                                Image(systemName: c.1).font(P.font(23, .semibold)).frame(width: 32)
                                Text(c.2).font(P.font(25.5, .semibold))
                                Spacer()
                                if c.0 == "prov" && expiringSoon { Circle().fill(P.live).frame(width: 11, height: 11) }
                                else if PrefCatalog.modified(c.0) { ModDot() }
                            }
                            .padding(.horizontal, 24).frame(height: 64)
                        }
                        .buttonStyle(SideStyle(selected: section == c.0))
                        .focused($catFocus, equals: c.0)
                        .accessibilityIdentifier("sacat-" + c.0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 510)
                .focusSection()
                .onChange(of: catFocus) { f in if let f, !holdSection, f != "search" { section = f; ui.open = nil } }

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if section == "search" { PrefSearchPanel(openCat: { c in section = c; catFocus = c }) } else { panel }
                        }
                        .padding(.horizontal, 36).padding(.vertical, 33).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !["prof", "prov", "search"].contains(section) { PrefHelpFooter().padding(.horizontal, 36).padding(.bottom, 24) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // sur Apple TV une zone de défilement ne coupe pas ce qui dépasse : les lignes sortaient du panneau
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .glass(36)
                .focusSection()
            }
            .padding(.horizontal, 72).padding(.top, -24).padding(.bottom, 45)
            }
        }
        .ignoresSafeArea(edges: .top)
        // écran de classement ouvert : la sélection reste dedans (rien derrière n'est sélectionnable)
        .disabled(showClass)
        .fullScreenCover(isPresented: $adding) { AddProviderFlow(close: { adding = false }, watchTV: { adding = false; Nav.shared.tab = .live }) }
        .fullScreenCover(item: Binding(get: { managing.map { ManagedID(id: $0) } }, set: { managing = $0?.id })) { m in ProviderManageView(pid: m.id, close: { managing = nil }) }
        .overlay { if showLog { IncidentLogView(close: { showLog = false }) } }
        .overlay { if showClass { ChannelClassView(close: { showClass = false }) } }
        .alert(item: $confirmDelete) { p in
            Alert(title: Text("Supprimer \(p.name) ?"), message: Text("Ses chaînes, films et séries seront retirés de prisme."),
                  primaryButton: .destructive(Text("Supprimer")) { store.remove(p.id) }, secondaryButton: .cancel(Text("Annuler")))
        }
        .task(id: store.catalogVersion) { dbSize = await Database.shared.read { $0.fileSize } }
        .onChange(of: pui.editProfile) { _, e in if e != nil { section = "prof" } }
        .onChange(of: managing) { old, now in if now == nil, let o = old { comeBack("pl-" + o) } }
        .onChange(of: adding) { _, now in if !now { comeBack("add") } }
        .onChange(of: showLog) { _, now in if !now { comeBack("log") } }
        .onChange(of: showClass) { _, now in if !now { comeBack("class") } }
        .onAppear {
            // 253 : ouverte depuis l'anneau de chargement de la barre du haut
            if let s = Nav.shared.openSettings {
                Nav.shared.openSettings = nil
                section = s
                for d in [0.4, 1.0] { DispatchQueue.main.asyncAfter(deadline: .now() + d) { if catFocus != s { catFocus = s } } }
            }
            if let s = Debug.settingsSection {
                // simulateur de test : le focus peut arriver plus tard sur la colonne ; on insiste quelques fois
                for d in [0.6, 1.5, 3.0, 5.0] { DispatchQueue.main.asyncAfter(deadline: .now() + d) { if catFocus != s { catFocus = s; section = s } } }
            }
            // simulateur de test seulement (arguments de lancement)
            if Debug.addProvider { adding = true }
            if Debug.classify { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showClass = true } }
            if let n = Debug.manageProvider { managing = store.providers.first { $0.name == n }?.id }
        }
    }

    /// un abonnement expire dans moins de 7 jours (simulateur .sa-alert)
    private var expiringSoon: Bool { store.providers.contains { p in p.expires.map { $0.timeIntervalSinceNow < 7 * 86400 } ?? false } }

    private func comeBack(_ row: String) {
        holdSection = true
        section = "prov"
        restoreRow = (row, (restoreRow?.1 ?? 0) + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { holdSection = false }
    }

    @ViewBuilder private var panel: some View {
        switch section {
        case "lang": LangPanel()
        case "play": PlayPanel()
        case "live": LivePanel()
        case "epg": EPGPanel()
        case "homes", "tmdb": HomesPanel()
        case "par": ParentalPanel()
        case "data", "store", "about": DataPanel()
        case "prof": ProfilesPanel()
        default: providersPanel
        }
    }

    @ViewBuilder private var providersPanel: some View {
        ProvidersPanel(manage: { managing = $0 }, add: { adding = true }, log: { showLog = true }, classify: { showClass = true }, restore: restoreRow)
    }

    @ViewBuilder private var tmdbPanel: some View {
        Text("Fiches et notes (TMDB)").font(P.font(44, .bold))
        Text("Affiches, images de fond, résumés, distribution, sagas, notes et « où le regarder ».").font(P.font(22)).foregroundStyle(P.dim)
        SecureField("Clé API TMDB (v3)", text: $tmdbKey).frame(maxWidth: 900)
        settingRow("Enregistrer la clé", value: TmdbKey.value == nil ? "aucune clé" : "clé enregistrée", icon: "key.fill") {
            TmdbKey.set(tmdbKey.trimmingCharacters(in: .whitespaces)); fiches.restart()
        }
        if TmdbKey.value == nil { Text("Crée une clé gratuite sur themoviedb.org › Paramètres › API, puis tape-la ici. Elle reste sur cette Apple TV.").font(P.font(21)).foregroundStyle(P.dim) }
        else if let e = fiches.lastError { Text(e).font(P.font(21, .semibold)).foregroundStyle(P.live) }
        else if fiches.total > 0 {
            ProgressView(value: Double(fiches.done), total: Double(max(1, fiches.total))).tint(P.gold).frame(maxWidth: 900)
            Text(fiches.running ? "Fiches : \(fiches.done) sur \(fiches.total) · en arrière-plan (une fiche ouverte est cherchée tout de suite)" : "Fiches à jour").font(P.font(21)).foregroundStyle(P.dim)
        } else { Text(fiches.running ? "Recherche des fiches manquantes…" : "Fiches à jour").font(P.font(21)).foregroundStyle(P.dim) }
    }

    @ViewBuilder private var storePanel: some View {
        Text("Stockage").font(P.font(44, .bold))
        line("Catalogue et guide", ByteCountFormatter.string(fromByteCount: dbSize, countStyle: .file))
        line("Affiches en cache", ByteCountFormatter.string(fromByteCount: Int64(URLCache.shared.currentDiskUsage), countStyle: .file))
        settingRow("Vider le cache des affiches", value: "", icon: "trash") { URLCache.shared.removeAllCachedResponses(); dbSize = Database.shared.fileSize }
        Text("Tes favoris, Ma liste, tes reprises de lecture et tes réglages ne sont jamais effacés par ce bouton.").font(P.font(20)).foregroundStyle(P.faint)
    }

    @ViewBuilder private var aboutPanel: some View {
        Text("À propos").font(P.font(44, .bold))
        line("Version", (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")")
        line("Identifiant", Bundle.main.bundleIdentifier ?? "?")
        line("Fournisseurs", "\(store.providers.count)")
        line("Profils", "\(ProfileStore.shared.profiles.count) · données d'avant les profils rattachées à « \(ProfileStore.shared.profiles.first?.name ?? "Steven") »")
        if let d = UserDefaults.standard.object(forKey: "prisme.backup.1-5-3.done") as? Date { line("Copie de sécurité (avant les profils)", "faite le " + Fmt.date(d)) }
        settingRow("Revenir aux catégories", value: "", icon: "chevron.left") { catFocus = section }
    }

    /// Ligne de réglage (simulateur) : texte à gauche, valeur à droite, blanche quand elle est sélectionnée.
    private func settingRow(_ title: String, value: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).frame(width: 30)
                Text(title).font(P.font(24, .semibold))
                Spacer()
                if !value.isEmpty { Text(value).font(P.font(21)).opacity(0.65) }
                Image(systemName: "chevron.right").font(P.font(18, .bold)).opacity(0.5)
            }
            .padding(.horizontal, 22).frame(height: 72)
        }
        .buttonStyle(RowStyle())
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(P.dim); Spacer(); Text(v).fontWeight(.semibold) }.font(P.font(24)).frame(maxWidth: 1000)
    }

    private func summary(_ p: Provider) -> String {
        var parts: [String] = []
        if let c = p.counts["live"] { parts.append("\(c) chaînes") }
        if let c = p.counts["vod"] { parts.append("\(c) films") }
        if let c = p.counts["series"] { parts.append("\(c) séries") }
        if let c = p.counts["epg"] { parts.append(c > 0 ? "\(c) programmes au guide" : "pas de guide") }
        if let d = p.lastImport { parts.append("mis à jour le " + Fmt.dateTime(d)) }
        if let e = p.expires { parts.append("expire le " + Fmt.date(e)) }
        if let e = p.lastError { parts.append("⚠︎ " + e) }
        return parts.isEmpty ? "Catalogue pas encore chargé" : parts.joined(separator: " · ")
    }
}
