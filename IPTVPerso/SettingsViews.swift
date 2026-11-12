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
        VStack(spacing: 28) {
            Text(firstLaunch ? "Bienvenue dans prisme" : "Ajouter un fournisseur").font(.system(size: 52, weight: .bold))
            if firstLaunch { Text("Entre les informations de ton abonnement Xtream.").foregroundStyle(.secondary) }
            TextField("Nom (ex : Mon fournisseur)", text: $name)
            TextField("Serveur (ex : http://monserveur.com:8080)", text: $server)
            TextField("Nom d'utilisateur", text: $username)
            SecureField("Mot de passe", text: $password)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Button {
                Task { await add() }
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Fournisseurs") {
                    ForEach(store.providers) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(p.name).font(.headline)
                                Spacer()
                                if store.importing == p.id { ProgressView(value: store.progress).frame(width: 200) }
                            }
                            Text(summary(p)).font(.callout).foregroundStyle(.secondary)
                        }
                        Toggle("Utiliser ce fournisseur", isOn: Binding(get: { p.on }, set: { _ in store.toggle(p.id) }))
                        Button("Actualiser le catalogue") { store.refresh(p.id) }.disabled(store.importing != nil)
                        Button("Supprimer ce fournisseur", role: .destructive) { confirmDelete = p }
                    }
                    Button("Ajouter un fournisseur") { adding = true }
                }
                if let e = store.lastError {
                    Section("Dernière erreur") { Text(e).foregroundStyle(.red) }
                }
                Section("Stockage") {
                    LabeledContent("Catalogue et guide", value: ByteCountFormatter.string(fromByteCount: dbSize, countStyle: .file))
                    LabeledContent("Affiches en cache", value: ByteCountFormatter.string(fromByteCount: Int64(URLCache.shared.currentDiskUsage), countStyle: .file))
                    Button("Vider le cache des affiches") { URLCache.shared.removeAllCachedResponses(); dbSize = Database.shared.fileSize }
                }
                Section("À propos") {
                    LabeledContent("Version", value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")")
                    LabeledContent("Identifiant", value: Bundle.main.bundleIdentifier ?? "?")
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $adding) { AddProviderView() }
            .alert(item: $confirmDelete) { p in
                Alert(title: Text("Supprimer \(p.name) ?"), message: Text("Ses chaînes, films et séries seront retirés de prisme."),
                      primaryButton: .destructive(Text("Supprimer")) { store.remove(p.id) }, secondaryButton: .cancel(Text("Annuler")))
            }
            .task(id: store.catalogVersion) { dbSize = await Database.shared.read { $0.fileSize } }
        }
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
