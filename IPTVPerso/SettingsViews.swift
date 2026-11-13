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

// MARK: - Réglages (simulateur : catégories à gauche, panneau en verre à droite)

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: ProviderStore
    @State private var adding = false
    @State private var confirmDelete: Provider?
    @State private var dbSize: Int64 = 0
    @State private var tmdbKey = TmdbKey.value ?? ""
    @State private var section = "prof"
    @ObservedObject var pui = ProfileUI.shared
    @ObservedObject var fiches = FicheService.shared
    @FocusState private var catFocus: String?

    private static let cats: [(String, String, String)] = [
        ("prof", "person", "Profils"), ("prov", "rectangle.stack", "Fournisseurs"), ("tmdb", "star.square", "Fiches et notes (TMDB)"),
        ("store", "internaldrive", "Stockage"), ("about", "info.circle", "À propos"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(claimFocus: true)
            HStack(alignment: .top, spacing: 34) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<ProvidersSettingsView.cats.count, id: \.self) { i in
                        let c = ProvidersSettingsView.cats[i]
                        Button { section = c.0 } label: {
                            Label(c.2, systemImage: c.1).font(P.font(25, .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).frame(height: 66)
                        }
                        .buttonStyle(SideStyle(selected: section == c.0))
                        .focused($catFocus, equals: c.0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 470)
                .focusSection()
                .onChange(of: catFocus) { f in if let f { section = f } }

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) { panel }
                        .padding(40).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glass(36)
                .focusSection()
            }
            .padding(.horizontal, 90).padding(.bottom, 60)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $adding) { AddProviderView() }
        .alert(item: $confirmDelete) { p in
            Alert(title: Text("Supprimer \(p.name) ?"), message: Text("Ses chaînes, films et séries seront retirés de prisme."),
                  primaryButton: .destructive(Text("Supprimer")) { store.remove(p.id) }, secondaryButton: .cancel(Text("Annuler")))
        }
        .task(id: store.catalogVersion) { dbSize = await Database.shared.read { $0.fileSize } }
        .onChange(of: pui.editProfile) { _, e in if e != nil { section = "prof" } }
    }

    @ViewBuilder private var panel: some View {
        switch section {
        case "tmdb": tmdbPanel
        case "store": storePanel
        case "about": aboutPanel
        case "prof": ProfilesPanel()
        default: providersPanel
        }
    }

    @ViewBuilder private var providersPanel: some View {
        Text("Fournisseurs").font(P.font(44, .bold))
        ForEach(store.providers) { p in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Circle().fill(p.on ? Color(red: 0.19, green: 0.82, blue: 0.35) : P.faint).frame(width: 14, height: 14)
                    Text(p.name).font(P.font(30, .bold))
                    Spacer()
                    if store.importing == p.id { ProgressView(value: store.progress).tint(.white).frame(width: 240) }
                }
                Text(summary(p)).font(P.font(21)).foregroundStyle(P.dim)
                VStack(spacing: 10) {
                    settingRow(p.on ? "Utilisé dans prisme" : "Pas utilisé", value: p.on ? "Oui" : "Non", icon: p.on ? "checkmark.circle.fill" : "circle") { store.toggle(p.id) }
                    settingRow("Actualiser le catalogue", value: store.importing != nil ? "en cours…" : "", icon: "arrow.clockwise") { if store.importing == nil { store.refresh(p.id) } }
                    settingRow("Supprimer ce fournisseur", value: "", icon: "trash") { confirmDelete = p }
                }
            }
            .padding(24).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))
        }
        settingRow("Ajouter un fournisseur", value: "", icon: "plus") { adding = true }
        if let e = store.lastError { Text("Dernière erreur : " + e).font(P.font(21, .semibold)).foregroundStyle(P.live) }
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
        return parts.isEmpty ? "Catalogue pas encore chargé" : parts.joined(separator: " · ")
    }
}
