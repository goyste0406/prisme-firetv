import SwiftUI

// MARK: - Réglages 1.7.1 : les rubriques du simulateur (Langues et sous-titres, Lecture et image, TV en direct, Guide TV,
// Accueils et notes, Contrôle parental, Sauvegarde et mises à jour). Seules des options qui fonctionnent vraiment.

/// Explication du réglage sélectionné, affichée en bas du panneau (simulateur : « Choisis un réglage pour voir à quoi il sert »)
final class PrefHelp: ObservableObject {
    static let shared = PrefHelp()
    @Published var text: String?
}

struct PrefHelpFooter: View {
    @ObservedObject var h = PrefHelp.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(Color.white.opacity(0.12))
            Text(h.text ?? "Choisis un réglage pour voir à quoi il sert.").font(P.font(21)).foregroundStyle(P.dim).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
        .onDisappear { h.text = nil }
    }
}

/// Ligne de réglage (même apparence que les autres lignes des réglages) : titre, valeur ou interrupteur ;
/// son explication s'affiche en bas du panneau quand la ligne est sélectionnée.
struct PrefRow: View {
    let title: String
    var value: String = ""
    var toggle: Bool? = nil
    var sub: String? = nil
    var icon: String = "chevron.right"
    let action: () -> Void
    @FocusState private var f: Bool
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title).font(P.font(24, .semibold))
                Spacer()
                if let toggle { Switch(on: toggle).scaleEffect(0.8) }
                else {
                    if !value.isEmpty { Text(value).font(P.font(21)).opacity(0.65).lineLimit(1) }
                    Image(systemName: icon).font(P.font(18, .bold)).opacity(0.5)
                }
            }
            .padding(.horizontal, 22).frame(height: 72)
        }
        .buttonStyle(RowStyle())
        .focused($f)
        .onChange(of: f) { _, on in if on { PrefHelp.shared.text = sub } }
    }
}

/// Ligne d'information (non modifiable)
struct PrefInfo: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .top) { Text(title).foregroundStyle(P.dim); Spacer(minLength: 30); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
            .font(P.font(23)).padding(.horizontal, 22).frame(maxWidth: .infinity)
    }
}

struct PrefHeader: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(P.font(44, .bold))
            if let sub { Text(sub).font(P.font(22)).foregroundStyle(P.dim) }
        }
    }
}

/// Valeurs des réglages, relues à chaque changement
final class PrefsModel: ObservableObject {
    @Published var tick = 0
    private var obs: NSObjectProtocol?
    init() { obs = NotificationCenter.default.addObserver(forName: .prismePrefs, object: nil, queue: .main) { [weak self] _ in self?.tick += 1 } }
    func cycle(_ k: String, _ cur: Int, _ n: Int) { AppPrefs.set(k, (cur + 1) % n) }
    func cycle<T: Equatable>(_ k: String, _ cur: T, _ all: [T]) { let i = all.firstIndex(of: cur) ?? 0; AppPrefs.set(k, all[(i + 1) % all.count]) }
    func toggle(_ k: String, _ cur: Bool) { AppPrefs.set(k, !cur) }
}

private func onOff(_ b: Bool) -> String { b ? "activé" : "désactivé" }

// MARK: Langues et sous-titres

struct LangPanel: View {
    @StateObject private var m = PrefsModel()
    @ObservedObject var ps = ProfileStore.shared
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Langues et sous-titres")
        SubPreview(size: AppPrefs.subSize, back: AppPrefs.subBack, color: AppPrefs.subColor)
        PrefRow(title: "Version préférée (\(ps.me.name))", value: Profile.langNames[ps.me.lang] ?? ps.me.lang,
                sub: "La version (VFF, VF, VOSTFR…) se règle par profil : OK pour régler celle de \(ps.me.name).") {
            ProfileUI.shared.editProfile = ps.current
        }
        PrefRow(title: "Sous-titres français par défaut", toggle: AppPrefs.subsFR,
                sub: "Pour les profils réglés sur « Comme le réglage général ». Un profil peut aussi dire « Toujours » ou « Jamais ».") { m.toggle("subsFR", AppPrefs.subsFR) }
        PrefRow(title: "Sous-titres français si seule la VO existe", toggle: AppPrefs.subsIfVO,
                sub: "Plus besoin d'aller les chercher : ils s'activent tout seuls quand le film n'a pas de piste audio française.") { m.toggle("subsVO", AppPrefs.subsIfVO) }
        PrefRow(title: "Taille des sous-titres", value: AppPrefs.subSizes[AppPrefs.subSize], sub: "L'aperçu au-dessus montre le résultat tout de suite.") { m.cycle("subSize", AppPrefs.subSize, 4) }
        PrefRow(title: "Fond des sous-titres", value: AppPrefs.subBacks[AppPrefs.subBack], sub: "Le bandeau reste lisible même sur les scènes claires.") { m.cycle("subBack", AppPrefs.subBack, 3) }
        PrefRow(title: "Couleur des sous-titres", value: AppPrefs.subColors[AppPrefs.subColor], sub: "Le jaune se lit mieux sur les vieux films.") { m.cycle("subColor", AppPrefs.subColor, 2) }
        PrefHelpFooter()
    }
}

/// Aperçu des sous-titres sur une image sombre et claire
struct SubPreview: View {
    let size: Int, back: Int, color: Int
    var body: some View {
        let fs: CGFloat = [26, 32, 40, 50][max(0, min(3, size))]
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(white: 0.75), Color(white: 0.3), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("Je t'avais dit de ne pas ouvrir cette porte.")
                .font(.system(size: fs, weight: .semibold))
                .foregroundStyle(color == 1 ? Color.yellow : .white)
                .shadow(color: back == 0 ? .black.opacity(0.9) : .clear, radius: 3)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(back == 1 ? Color.black.opacity(0.66) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity).frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: Lecture et image

struct PlayPanel: View {
    @StateObject private var m = PrefsModel()
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Lecture et image")
        PrefRow(title: "Qualité préférée", value: AppPrefs.qualities[AppPrefs.maxQuality],
                sub: "Utile si ta connexion sature le soir : prisme prend la meilleure version ou source sous cette limite (sauf si tu en choisis une).") { m.cycle("maxQ", AppPrefs.maxQuality, 3) }
        PrefInfo(title: "Moteur de lecture", value: "VLC · lit MKV, AVI, MP4 et les flux en direct")
        PrefRow(title: "Décodage matériel", toggle: AppPrefs.hwDecode,
                sub: "Laisse-le activé : l'Apple TV décode l'image elle-même. À couper seulement si une vidéo saccade ou s'affiche mal.") { m.toggle("hw", AppPrefs.hwDecode) }
        PrefRow(title: "Saut avant / arrière", value: "\(AppPrefs.skip) s", sub: "Flèches gauche et droite pendant un film ou un épisode.") { m.cycle("skip", AppPrefs.skip, AppPrefs.skips) }
        PrefInfo(title: "Son de nuit, arrêt au coucher", value: "dans le lecteur (flèche bas) · retenus par profil")
        PrefHelpFooter()
    }
}

// MARK: TV en direct

struct LivePanel: View {
    @StateObject private var m = PrefsModel()
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "TV en direct")
        PrefRow(title: "Ouvrir prisme sur la TV en direct", toggle: AppPrefs.openOnLive,
                sub: "Comme une box : à l'ouverture, la dernière chaîne regardée s'allume tout de suite.") { m.toggle("openLive", AppPrefs.openOnLive) }
        PrefRow(title: "Bascule automatique si la source ne démarre pas", value: AppPrefs.failover == 0 ? "désactivée" : "\(AppPrefs.failover) secondes",
                sub: "Passe à la source suivante de la chaîne (autre qualité ou autre fournisseur). OK pour changer : désactivée, 5, 10, 20 ou 25 secondes.") {
            m.cycle("failover", AppPrefs.failover, AppPrefs.failovers)
        }
        PrefRow(title: "Chaînes et guide", value: store.importing != nil ? "mise à jour…" : "\(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["live"] ?? 0) })) chaînes · \(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["epg"] ?? 0) })) programmes",
                sub: "OK pour recharger les chaînes et le guide de tes fournisseurs.") { for p in store.active { store.refresh(p.id) } }
        PrefInfo(title: "Chaînes récentes et favorites", value: "\(prefs.recent.count) récentes · \(prefs.favorites.count) favorites")
        PrefHelpFooter()
    }
}

// MARK: Guide TV

struct EPGPanel: View {
    @StateObject private var m = PrefsModel()
    @EnvironmentObject var store: ProviderStore
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Guide TV")
        PrefRow(title: "Téléchargement automatique au démarrage", toggle: AppPrefs.epgAuto,
                sub: "Le guide est retéléchargé à l'ouverture de prisme s'il a plus de 12 heures.") { m.toggle("epgAuto", AppPrefs.epgAuto) }
        PrefRow(title: "Actualiser le guide maintenant", value: store.guideBusy ? "en cours…" : "dernière mise à jour : " + (store.guideLast == .distantPast ? "—" : Fmt.dateTime(store.guideLast))) {
            store.refreshGuide()
        }
        PrefRow(title: "Décalage horaire du guide", value: (AppPrefs.epgShift > 0 ? "+" : "") + "\(AppPrefs.epgShift) h",
                sub: "Si les programmes de ton fournisseur sont décalés d'une heure ou plus. Appliqué au prochain téléchargement du guide.") {
            m.cycle("epgShift", AppPrefs.epgShift, [0, 1, 2, 3, -3, -2, -1])
        }
        PrefInfo(title: "Sources", value: "\(store.active.count) × xmltv.php · \(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["epg"] ?? 0) })) programmes\nimages des programmes : guide, xmltvfr.fr, TMDB")
        PrefHelpFooter()
    }
}

// MARK: Accueils et notes

struct HomesPanel: View {
    @StateObject private var m = PrefsModel()
    @ObservedObject var fiches = FicheService.shared
    @State private var key = TmdbKey.value ?? ""
    @State private var confirm = false
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Accueils et notes", sub: "Affiches, images de fond, résumés, distribution, sagas, notes et « où le regarder » (TMDB).")
        SecureField("Clé API TMDB (v3)", text: $key).frame(maxWidth: 900)
        PrefRow(title: "Enregistrer la clé", value: TmdbKey.value == nil ? "aucune clé" : "clé enregistrée", icon: "key.fill") {
            TmdbKey.set(key.trimmingCharacters(in: .whitespaces)); fiches.restart()
        }
        if TmdbKey.value == nil { Text("Crée une clé gratuite sur themoviedb.org › Paramètres › API, puis tape-la ici. Elle reste sur cette Apple TV.").font(P.font(21)).foregroundStyle(P.dim) }
        else if let e = fiches.lastError { Text(e).font(P.font(21, .semibold)).foregroundStyle(P.live) }
        else if fiches.total > 0 {
            ProgressView(value: Double(fiches.done), total: Double(max(1, fiches.total))).tint(P.gold).frame(maxWidth: 900)
            Text(fiches.running ? "Fiches : \(fiches.done) sur \(fiches.total) · en arrière-plan (une fiche ouverte est cherchée tout de suite)" : fiches.paused ? "Fiches en pause" : "Fiches à jour").font(P.font(21)).foregroundStyle(P.dim)
        }
        PrefRow(title: "Téléchargement des fiches", value: AppPrefs.ficheMode == 0 ? "Automatique" : "Jamais",
                sub: "Automatique : prisme télécharge les fiches dès qu'un fournisseur est ajouté. Jamais : une fiche arrive quand tu l'ouvres.") {
            m.cycle("ficheMode", AppPrefs.ficheMode, 2)
            if AppPrefs.ficheMode == 0 { fiches.start() } else { fiches.pause(); fiches.paused = false }
        }
        if AppPrefs.ficheMode == 0 {
            PrefRow(title: fiches.paused ? "Reprendre le téléchargement" : "Mettre en pause", sub: "Jusqu'à ce que tu relances. Rien n'est perdu.") {
                if fiches.paused { fiches.resume() } else { fiches.pause() }
            }
        }
        PrefRow(title: "Tout retélécharger", value: confirm ? "OK encore pour confirmer" : "", sub: "Efface les fiches téléchargées par prisme et recommence. Ma liste, l'historique et tes réglages ne sont pas touchés.") {
            if confirm { confirm = false; Task { await fiches.redownloadAll() } } else { confirm = true }
        }
        PrefInfo(title: "Notes affichées", value: "note TMDB · IMDb, Rotten Tomatoes, AlloCiné : non disponibles sans service payant ou clé")
        PrefHelpFooter()
    }
}

// MARK: Contrôle parental

struct ParentalPanel: View {
    @StateObject private var m = PrefsModel()
    @ObservedObject var ps = ProfileStore.shared
    @State private var code = ""
    @State private var editing = false
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Contrôle parental")
        PrefInfo(title: "Contenus pour adultes", value: "jamais chargés, quel que soit le profil")
        PrefRow(title: "Code parental", value: AppPrefs.parentalCode == nil ? "aucun" : "défini · OK pour changer", sub: "4 chiffres, demandés pour entrer dans les Réglages quand ils sont verrouillés.") { editing = true }
        if editing {
            HStack(spacing: 16) {
                SecureField("Nouveau code (4 chiffres)", text: $code).keyboardType(.numberPad).frame(maxWidth: 500)
                Button("Enregistrer") {
                    let c = code.filter(\.isNumber)
                    if c.count == 4 { UserDefaults.standard.set(c, forKey: "prisme.pref.code"); AppPrefs.set("codeSet", true) }
                    code = ""; editing = false
                }
                if AppPrefs.parentalCode != nil {
                    Button("Supprimer le code") { UserDefaults.standard.removeObject(forKey: "prisme.pref.code"); AppPrefs.set("lock", false); editing = false }
                }
            }
        }
        if AppPrefs.parentalCode != nil {
            PrefRow(title: "Verrouiller les réglages", toggle: AppPrefs.lockSettings, sub: "Le code parental est demandé pour entrer dans les Réglages.") { m.toggle("lock", AppPrefs.lockSettings) }
        }
        PrefRow(title: "Limites par profil", value: "\(ps.profiles.filter { $0.limit != nil }.count) profil(s) limité(s)", sub: "Profil enfant et limite d'âge se règlent dans chaque profil.") {
            ProfileUI.shared.editProfile = ps.current
        }
        PrefHelpFooter()
    }
}

/// Réglages verrouillés : code demandé avant d'entrer
struct SettingsLock: View {
    let unlock: () -> Void
    @State private var code = ""
    @State private var wrong = false
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill").font(.system(size: 60))
            Text("Réglages verrouillés").font(P.font(44, .bold))
            Text(wrong ? "Code incorrect, réessaie." : "Tape le code parental.").font(P.font(24)).foregroundStyle(wrong ? P.live : P.dim)
            SecureField("Code", text: $code).keyboardType(.numberPad).frame(width: 420)
                .onSubmit { if code == AppPrefs.parentalCode { unlock() } else { wrong = true; code = "" } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Sauvegarde et mises à jour

struct DataPanel: View {
    @EnvironmentObject var store: ProviderStore
    @StateObject private var phone = BackupLink(mode: .phone)
    @StateObject private var inbox = BackupLink(mode: .receive)
    @StateObject private var sender = TVSender()
    @State private var show = ""          // "", "phone", "receive", "send"
    @State private var dbSize: Int64 = 0
    @State private var done: String?
    @State private var undoConfirm = false
    var body: some View {
        // les lignes sont regroupées : la fenêtre « Restaurer cette sauvegarde ? » et le suivi des codes s'appliquent
        // au panneau entier (posés sur la dernière ligne seule, la fenêtre ne s'ouvrait pas sur la TV)
        VStack(alignment: .leading, spacing: 26) {
        PrefHeader(title: "Sauvegarde et mises à jour")
        Text("iCloud demande un compte Apple développeur payant : avec ton installation par Apparition, prisme passe par ton Wi-Fi.").font(P.font(20)).foregroundStyle(P.faint)
        PrefRow(title: "Sauvegarde sur l'iPhone", value: show == "phone" ? "code affiché" : "",
                sub: "Scanne le code avec l'iPhone : télécharge la sauvegarde (profils, Ma liste, reprises, goûts, réglages, fournisseurs) ou renvoie-en une à restaurer.") {
            show = show == "phone" ? "" : "phone"
        }
        if show == "phone" { qrBlock(phone) }
        PrefRow(title: "Recevoir d'une autre Apple TV", value: show == "receive" ? "en attente…" : "",
                sub: "Rend cette Apple TV visible sur le Wi-Fi. Sur l'autre Apple TV : Réglages › Sauvegarde › Envoyer vers une autre Apple TV.") {
            show = show == "receive" ? "" : "receive"
        }
        if show == "receive" {
            Text(inbox.failed ?? (inbox.address == nil ? "Préparation…" : "Visible sur le Wi-Fi sous le nom « prisme · \(UIDevice.current.name) ». Reste sur cet écran.")).font(P.font(21)).foregroundStyle(P.dim).padding(.horizontal, 22)
        }
        PrefRow(title: "Envoyer vers une autre Apple TV", value: show == "send" ? "\(sender.peers.count) trouvée(s)" : "",
                sub: "Les données de cette Apple TV remplacent celles de l'autre, après confirmation sur l'autre.") {
            show = show == "send" ? "" : "send"
        }
        if show == "send" {
            if sender.peers.isEmpty { Text("Recherche des Apple TV en réception sur ton Wi-Fi…").font(P.font(21)).foregroundStyle(P.dim).padding(.horizontal, 22) }
            ForEach(sender.peers) { p in PrefRow(title: p.name, value: "envoyer", icon: "paperplane") { sender.send(to: p) } }
            if let s = sender.state { Text(s).font(P.font(21, .semibold)).padding(.horizontal, 22) }
        }
        if Backup.canUndo {
            PrefRow(title: "Annuler la dernière restauration", value: undoConfirm ? "OK encore pour confirmer" : "", sub: "Remet les données d'avant la dernière restauration.") {
                if undoConfirm { undoConfirm = false; done = Backup.undo() ? Self.restartMsg : "Annulation impossible." } else { undoConfirm = true }
            }
        }
        if let done { Text(done).font(P.font(22, .semibold)).foregroundStyle(P.gold).padding(.horizontal, 22) }
        PrefInfo(title: "Catalogue et guide", value: ByteCountFormatter.string(fromByteCount: dbSize, countStyle: .file))
        PrefInfo(title: "Affiches en cache", value: ByteCountFormatter.string(fromByteCount: Int64(URLCache.shared.currentDiskUsage), countStyle: .file))
        PrefRow(title: "Vider le cache des images", sub: "Les affiches et logos se retéléchargent au besoin. Tes favoris, Ma liste, tes reprises et tes réglages ne sont jamais effacés par ce bouton.") {
            URLCache.shared.removeAllCachedResponses(); dbSize = Database.shared.fileSize
        }
        PrefInfo(title: "Version", value: "prisme " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ") pour Apple TV")
        PrefInfo(title: "Identifiant", value: Bundle.main.bundleIdentifier ?? "?")
        PrefInfo(title: "Mises à jour", value: "nouvelle version installée avec Apparition, comme une mise à jour : tes données restent")
        PrefInfo(title: "Appareil", value: UIDevice.current.name + " · tvOS " + UIDevice.current.systemVersion)
        PrefInfo(title: "Code source", value: "github.com/goyste0406/prisme-firetv (branche appletv)")
        PrefInfo(title: "Fournisseurs · profils", value: "\(store.providers.count) · \(ProfileStore.shared.profiles.count)")
        }
            .task(id: store.catalogVersion) { dbSize = await Database.shared.read { $0.fileSize } }
            .onChange(of: show) { _, s in
                if s == "phone" { phone.start() } else { phone.stop() }
                if s == "receive" { inbox.start() } else { inbox.stop() }
                if s == "send" { sender.start() } else { sender.stop(); sender.state = nil }
            }
            .onDisappear { phone.stop(); inbox.stop(); sender.stop() }
            .onAppear {
                // visite « envoi » (deux simulateurs) : cette Apple TV se met d'elle-même en réception
                if Debug.demoServer != nil, Debug.arg("prisme.debug.receive") == "1" { show = "receive" }
            }
            .onReceive(inbox.$received) { r in
                // visite « envoi » : la fenêtre de confirmation reste affichée N secondes (capture), puis la restauration est acceptée
                guard let r, Debug.demoServer != nil, let n = Debug.arg("prisme.debug.acceptAfter").flatMap(Double.init) else { return }
                DataCount.write("sauvegarde reçue de \(r.device) (\(r.profiles.joined(separator: ", ")))")
                DispatchQueue.main.asyncAfter(deadline: .now() + n) {
                    done = Backup.restore(r) ? Self.restartMsg : "Restauration impossible."
                    inbox.received = nil
                    DataCount.write("restauration acceptée")
                }
            }
            .alert(item: Binding(get: { (phone.received ?? inbox.received).map { Pending(s: $0) } }, set: { if $0 == nil { phone.received = nil; inbox.received = nil } })) { p in
                Alert(title: Text("Restaurer cette sauvegarde ?"),
                      message: Text("Sauvegarde du \(p.s.date) (\(p.s.device)) · profils : \(p.s.profiles.joined(separator: ", ")).\n\nLes profils, Ma liste, les reprises, les goûts, les réglages et les fournisseurs de cette Apple TV seront remplacés. Une copie de ceux d'aujourd'hui est gardée pour annuler."),
                      primaryButton: .destructive(Text("Restaurer")) { done = Backup.restore(p.s) ? Self.restartMsg : "Restauration impossible."; show = "" },
                      secondaryButton: .cancel(Text("Annuler")))
            }
        PrefHelpFooter()
    }
    struct Pending: Identifiable { let s: Backup.Summary; var id: String { s.date + s.device } }
    static let restartMsg = "Fait ✓ · ferme prisme (deux appuis sur le bouton TV, puis fais glisser prisme vers le haut) et rouvre-la pour retrouver ces données."

    private func qrBlock(_ l: BackupLink) -> some View {
        HStack(alignment: .top, spacing: 30) {
            if let img = l.qr { Image(uiImage: img).interpolation(.none).resizable().frame(width: 260, height: 260).clipShape(RoundedRectangle(cornerRadius: 18)) }
            VStack(alignment: .leading, spacing: 10) {
                Text(l.failed ?? (l.address == nil ? "Préparation…" : "Scanne ce code avec l'appareil photo de l'iPhone (même Wi-Fi).")).font(P.font(22))
                if let a = l.address { Text(a).font(P.font(19)).foregroundStyle(P.faint).accessibilityIdentifier("backup-address").accessibilityLabel(a) }
                if l.downloads > 0 { Text("Sauvegarde téléchargée ✓").font(P.font(21, .semibold)).foregroundStyle(P.gold) }
            }
        }
        .padding(.horizontal, 22)
    }
}
