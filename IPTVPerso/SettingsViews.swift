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

// MARK: - Réglages : fournisseurs

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: ProviderStore
    @State private var adding = false
    @State private var confirmDelete: Provider?
    @State private var dbSize: Int64 = 0
    @State private var tmdbKey = TmdbKey.value ?? ""
    @ObservedObject var fiches = FicheService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                Text("Réglages").font(P.font(64, .bold)).padding(.top, 190)

                card("Fournisseurs", icon: "antenna.radiowaves.left.and.right") {
                    ForEach(store.providers) { p in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                Circle().fill(p.on ? Color(red: 0.19, green: 0.82, blue: 0.35) : P.faint).frame(width: 14, height: 14)
                                Text(p.name).font(P.font(30, .bold))
                                Spacer()
                                if store.importing == p.id { ProgressView(value: store.progress).tint(.white).frame(width: 240) }
                            }
                            Text(summary(p)).font(P.font(21)).foregroundStyle(P.dim)
                            HStack(spacing: 18) {
                                Button { store.toggle(p.id) } label: { Label(p.on ? "Utilisé" : "Pas utilisé", systemImage: p.on ? "checkmark.circle.fill" : "circle").font(P.font(23, .semibold)) }
                                    .buttonStyle(GlassStyle(radius: 16, minH: 64, on: p.on))
                                Button { store.refresh(p.id) } label: { Label("Actualiser le catalogue", systemImage: "arrow.clockwise").font(P.font(23, .semibold)) }
                                    .buttonStyle(GlassStyle(radius: 16, minH: 64)).disabled(store.importing != nil)
                                Button { confirmDelete = p } label: { Label("Supprimer", systemImage: "trash").font(P.font(23, .semibold)) }
                                    .buttonStyle(GlassStyle(radius: 16, minH: 64))
                            }.focusSection()
                        }
                        .padding(22).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))
                    }
                    Button { adding = true } label: { Label("Ajouter un fournisseur", systemImage: "plus").font(P.font(24, .bold)) }
                        .buttonStyle(PrimaryStyle())
                    if let e = store.lastError { Text("Dernière erreur : " + e).font(P.font(21, .semibold)).foregroundStyle(P.live) }
                }

                card("Fiches TMDB", icon: "film.stack", sub: "affiches, acteurs, sagas, où regarder") {
                    SecureField("Clé API TMDB (v3)", text: $tmdbKey).frame(maxWidth: 900)
                    Button { TmdbKey.set(tmdbKey.trimmingCharacters(in: .whitespaces)); fiches.restart() } label: { Text("Enregistrer la clé").font(P.font(23, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 16, minH: 64))
                    if TmdbKey.value == nil { Text("Crée une clé gratuite sur themoviedb.org › Paramètres › API, puis tape-la ici. Elle reste sur cette Apple TV.").font(P.font(21)).foregroundStyle(P.dim) }
                    else if let e = fiches.lastError { Text(e).font(P.font(21, .semibold)).foregroundStyle(P.live) }
                    else if fiches.total > 0 {
                        ProgressView(value: Double(fiches.done), total: Double(max(1, fiches.total))).tint(P.gold).frame(maxWidth: 900)
                        Text(fiches.running ? "Fiches : \(fiches.done) sur \(fiches.total) · en arrière-plan" : "Fiches à jour").font(P.font(21)).foregroundStyle(P.dim)
                    } else { Text(fiches.running ? "Recherche des fiches manquantes…" : "Fiches à jour").font(P.font(21)).foregroundStyle(P.dim) }
                }

                card("Stockage", icon: "internaldrive") {
                    line("Catalogue et guide", ByteCountFormatter.string(fromByteCount: dbSize, countStyle: .file))
                    line("Affiches en cache", ByteCountFormatter.string(fromByteCount: Int64(URLCache.shared.currentDiskUsage), countStyle: .file))
                    Button { URLCache.shared.removeAllCachedResponses(); dbSize = Database.shared.fileSize } label: { Text("Vider le cache des affiches").font(P.font(23, .semibold)) }
                        .buttonStyle(GlassStyle(radius: 16, minH: 64))
                }

                card("À propos", icon: "info.circle") {
                    line("Version", (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")")
                    line("Identifiant", Bundle.main.bundleIdentifier ?? "?")
                }
                .focusable()
            }
            .padding(.horizontal, 180).padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollClipDisabled()
        .ignoresSafeArea()
        .sheet(isPresented: $adding) { AddProviderView() }
        .alert(item: $confirmDelete) { p in
            Alert(title: Text("Supprimer \(p.name) ?"), message: Text("Ses chaînes, films et séries seront retirés de prisme."),
                  primaryButton: .destructive(Text("Supprimer")) { store.remove(p.id) }, secondaryButton: .cancel(Text("Annuler")))
        }
        .task(id: store.catalogVersion) { dbSize = await Database.shared.read { $0.fileSize } }
    }

    private func card<C: View>(_ title: String, icon: String, sub: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(P.font(26, .semibold)).foregroundStyle(P.dim)
                SectionTitle(title: title, sub: sub)
            }
            content()
        }
        .padding(34).frame(maxWidth: 1560, alignment: .leading).glass(30)
        .focusSection()
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
        if let d = p.lastImport { parts.append("mis à jour le " + d.formatted(.dateTime.day().month().hour().minute())) }
        if let e = p.expires { parts.append("expire le " + e.formatted(.dateTime.day().month().year())) }
        return parts.isEmpty ? "Catalogue pas encore chargé" : parts.joined(separator: " · ")
    }
}
