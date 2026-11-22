import SwiftUI

// MARK: - Réglages 1.7.1 : les rubriques du simulateur (Langues et sous-titres, Lecture et image, TV en direct, Guide TV,
// Accueils et notes, Contrôle parental, Sauvegarde et mises à jour). Seules des options qui fonctionnent vraiment.

/// Explication du réglage sélectionné, affichée en bas du panneau (simulateur : « Choisis un réglage pour voir à quoi il sert »)
final class PrefHelp: ObservableObject {
    static let shared = PrefHelp()
    @Published var text: String?
}

/// simulateur .sa-desc : fixé en bas du panneau, sous un filet, l'explication de la ligne sélectionnée
struct PrefHelpFooter: View {
    @ObservedObject var h = PrefHelp.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(Color.white.opacity(0.12))
            Text(h.text ?? "Choisis un réglage pour voir à quoi il sert.").font(P.font(19.5)).foregroundStyle(P.dim)
                .lineLimit(3).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .accessibilityIdentifier("sa-desc")
        }
        .onDisappear { h.text = nil }
    }
}

/// Ligne de réglage (même apparence que les autres lignes des réglages) : titre, valeur ou interrupteur ;
/// son explication s'affiche en bas du panneau quand la ligne est sélectionnée.
struct PrefRow: View {
    let title: String
    var value: String = ""
    var toggle: Bool? = nil
    /// pastille « conseillé » après la valeur
    var rec = false
    var sub: String? = nil
    var icon: String = "chevron.right"
    /// point « modifié » devant le titre (simulateur .sa-mod)
    var modified = false
    var id = ""
    /// la ligne prend la sélection dès qu'elle apparaît (confirmation qui vient de s'afficher)
    var grab = false
    let action: () -> Void
    @FocusState private var f: Bool
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if modified { ModDot() }
                Text(title).font(P.font(22.5, .semibold)).lineLimit(2)
                Spacer(minLength: 20)
                if let toggle { Switch(on: toggle).scaleEffect(0.8) }
                else {
                    if !value.isEmpty { Text(value).font(P.font(19.5)).opacity(0.65).lineLimit(1) }
                    if rec { SetRecBadge() }
                    Image(systemName: icon).font(P.font(17, .bold)).opacity(0.5)
                }
            }
            .padding(.horizontal, 22).frame(minHeight: 84)
        }
        .buttonStyle(PrefRowStyle())
        .focused($f)
        .accessibilityIdentifier(id.isEmpty ? title : id)
        .onChange(of: f) { _, on in if on { PrefHelp.shared.text = sub } }
        .onAppear { if grab { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { f = true } } }
    }
}

/// Ligne d'information (non modifiable)
struct PrefInfo: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .center) {
            Text(title).font(P.font(22.5, .semibold)); Spacer(minLength: 30)
            Text(value).font(P.font(19.5)).opacity(0.65).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 22).frame(maxWidth: .infinity).frame(minHeight: 84)
    }
}

struct PrefHeader: View {
    let title: String
    var sub: String? = nil
    /// rubrique : bouton « Rétablir les réglages conseillés » à droite du titre
    var cat: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title).font(P.font(33, .bold))
                Spacer()
                if let cat { ResetButton(cat: cat) }
            }
            // en montant depuis la première ligne, la sélection va sur « Rétablir » (et non sur la barre du haut)
            .focusSection()
            if let sub { Text(sub).font(P.font(19.5)).foregroundStyle(P.dim) }
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
        PrefHeader(title: "Langues et sous-titres", cat: "lang")
        SubPreview(size: AppPrefs.subSize, back: AppPrefs.subBack, color: AppPrefs.subColor)
        PrefRow(title: "Version préférée (\(ps.me.name))", value: Profile.langNames[ps.me.lang] ?? ps.me.lang,
                sub: "La version (VFF, VF, VOSTFR…) se règle par profil : OK pour régler celle de \(ps.me.name).", id: "sa-lang") {
            ProfileUI.shared.editProfile = ps.current
        }
        ForEach(PrefCatalog.of("lang")) { SpecRow(spec: $0) }
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
        PrefHeader(title: "Lecture et image", cat: "play")
        SpecRow(spec: PrefCatalog.spec("maxQ")!)
        PrefInfo(title: "Moteur de lecture", value: "VLC · lit MKV, AVI, MP4 et les flux en direct")
        ForEach(PrefCatalog.of("play").filter { $0.id != "maxQ" }) { SpecRow(spec: $0) }
    }
}

// MARK: TV en direct

struct LivePanel: View {
    @StateObject private var m = PrefsModel()
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var prefs = LivePrefs.shared
    @ObservedObject var mem = LiveMemory.shared
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "TV en direct", cat: "live")
        ForEach(["openLive", "lbest", "startAsk", "bgv", "failover"], id: \.self) { SpecRow(spec: PrefCatalog.spec($0)!) }
        // simulateur : sources mémorisées (« Oublier »), sinon une ligne qui explique quand elles apparaissent
        if mem.direct.isEmpty {
            PrefInfo(title: "Sources mémorisées", value: "Aucune")
            Text("prisme te proposera de mémoriser une source après 3 choix identiques").font(P.font(18)).foregroundStyle(P.faint).padding(.horizontal, 22).padding(.top, -14)
        } else {
            ForEach(mem.direct.keys.sorted(), id: \.self) { k in
                let name = LiveIndex.byKey[k]?.name ?? k.components(separatedBy: "|").last ?? k
                let c = LiveIndex.byKey[k]?.copies.first { $0.id == mem.direct[k] }
                PrefRow(title: name, value: "Oublier", sub: "Ouvre directement " + (c.map { LiveSourceLabel.text($0) } ?? "la source choisie") + ". OK pour l'oublier.", id: "sa-lf-" + name) {
                    mem.forget(k); AppToast.shared.say("Source oubliée : " + name)
                }
            }
        }
        if mem.hidden.isEmpty {
            PrefInfo(title: "Chaînes masquées", value: "Aucune")
        } else {
            ForEach(mem.hidden.keys.sorted(), id: \.self) { k in
                PrefRow(title: mem.hidden[k] ?? k, value: "Réafficher", sub: "Masquée depuis la TV en direct (OK maintenu sur la chaîne). OK pour la réafficher.", id: "sa-sh-" + (mem.hidden[k] ?? k)) {
                    mem.show(k); AppToast.shared.say("Chaîne réaffichée")
                }
            }
        }
        PrefRow(title: "Chaînes et guide préchargés au démarrage", value: store.importing != nil ? "mise à jour…" : (store.active.compactMap(\.lastImport).max().map { "à " + Fmt.hm($0) } ?? "—"),
                sub: "\(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["live"] ?? 0) })) chaînes · \(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["epg"] ?? 0) })) programmes · OK pour recharger", id: "sa-lreload") {
            for p in store.active { store.refresh(p.id) }
        }
        PrefInfo(title: "Chaînes récentes et favorites", value: "\(prefs.recent.count) récentes · \(prefs.favorites.count) favorites")
    }
}

// MARK: Guide TV

struct EPGPanel: View {
    @StateObject private var m = PrefsModel()
    @EnvironmentObject var store: ProviderStore
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Guide TV", cat: "epg")
        SpecRow(spec: PrefCatalog.spec("epgAuto")!)
        PrefRow(title: "Actualiser l'EPG maintenant", value: store.guideBusy ? "en cours…" : "dernière mise à jour : " + (store.guideLast == .distantPast ? "—" : Fmt.dateTime(store.guideLast)),
                sub: "Retélécharge le guide de tes fournisseurs.", id: "sa-epgnow") {
            store.refreshGuide()
        }
        SpecRow(spec: PrefCatalog.spec("epgShift")!)
        PrefInfo(title: "Sources", value: "\(store.active.count) × xmltv.php · \(Fmt.n(store.active.reduce(0) { $0 + ($1.counts["epg"] ?? 0) })) programmes")
    }
}

// MARK: Accueils et notes

struct HomesPanel: View {
    @StateObject private var m = PrefsModel()
    @ObservedObject var fiches = FicheService.shared
    @ObservedObject var ps = ProfileStore.shared
    @State private var key = TmdbKey.value ?? ""
    @State private var confirm = false
    @State private var misses = 0
    @State private var size: Int64 = 0
    var body: some View {
        let _ = m.tick
        PrefHeader(title: "Accueils et notes", cat: "homes")
        PrefGroup(title: "Fiches en arrière-plan")
        SpecRow(spec: PrefCatalog.spec("ficheMode")!) { v in
            if (v as? Int) == 1 { fiches.pause(); fiches.paused = false } else { fiches.start() }
        }
        Text(ficheStatus).font(P.font(18)).foregroundStyle(fiches.lastError != nil ? P.live : P.faint).padding(.horizontal, 22).padding(.top, -10)
        if AppPrefs.ficheMode != 1 {
            PrefRow(title: fiches.paused ? "Reprendre le téléchargement" : "Mettre en pause", sub: "Jusqu'à ce que tu relances. Rien n'est perdu.", id: "sa-fpause") {
                if fiches.paused { fiches.resume() } else { fiches.pause() }
            }
        }
        SpecRow(spec: PrefCatalog.spec("ficheAfter")!)
        SpecRow(spec: PrefCatalog.spec("fichePlay")!)
        SpecRow(spec: PrefCatalog.spec("posterHD")!)
        PrefRow(title: "Fiches non reconnues", value: misses == 0 ? "aucune" : "\(misses) · OK pour réessayer",
                sub: "Les titres que TMDB n'a pas trouvés tels quels. OK : prisme les recherche à nouveau.", id: "sa-funk") {
            guard misses > 0 else { return }
            Task { await Database.shared.read { $0.run("DELETE FROM fmiss") }; misses = 0; fiches.restart() }
        }
        PrefRow(title: "Tout retélécharger", value: confirm ? "OK encore pour confirmer" : "", sub: "Efface les fiches téléchargées par prisme et recommence. Ma liste, l'historique et tes réglages ne sont pas touchés.", id: "sa-fall") {
            if confirm { confirm = false; Task { await fiches.redownloadAll() } } else { confirm = true }
        }
        HStack(spacing: 16) {
            SecureField("Clé TMDB (v3)", text: $key).frame(maxWidth: 520)
            PrefRow(title: "Enregistrer la clé", value: TmdbKey.value == nil ? "aucune clé" : "clé enregistrée",
                    sub: "Crée une clé gratuite sur themoviedb.org › Paramètres › API, puis tape-la ici. Elle reste sur cette Apple TV.", icon: "key.fill", id: "sa-key") {
                TmdbKey.set(key.trimmingCharacters(in: .whitespaces)); fiches.restart()
            }
        }
        PrefGroup(title: "Accueil Films")
        SpecRow(spec: PrefCatalog.spec("heroTrl")!)
        SpecRow(spec: PrefCatalog.spec("heroVol")!)
        hiddenRow(.film)
        PrefGroup(title: "Accueil Séries")
        ForEach(["recap", "autoskip", "spoiler", "binge"], id: \.self) { SpecRow(spec: PrefCatalog.spec($0)!) }
        hiddenRow(.series)
        PrefGroup(title: "Notes et métadonnées")
        PrefInfo(title: "Fiches, affiches et casting", value: "TMDB")
        PrefInfo(title: "Tendances et recommandations", value: "TMDB (tendances de la semaine, titres recommandés)")
        PrefInfo(title: "Agrégateur de notes", value: "IMDb, Rotten Tomatoes, Metacritic, Letterboxd, AlloCiné, SensCritique : demandent un service payant (MDBList) · non activé")
        SpecRow(spec: PrefCatalog.spec("showTMDB")!)
            .task(id: fiches.version) {
                misses = await Database.shared.read { db in var n = 0; db.query("SELECT COUNT(*) FROM fmiss") { n = $0.int(0) }; return n }
            }
    }

    private var ficheStatus: String {
        if TmdbKey.value == nil { return "aucune clé TMDB · les fiches ne sont pas téléchargées" }
        if let e = fiches.lastError { return e }
        if fiches.paused { return "en pause" }
        if fiches.total > 0 && fiches.running { return "\(fiches.done) / \(fiches.total) · en arrière-plan (une fiche ouverte est cherchée tout de suite)" }
        return fiches.running ? "recherche des fiches manquantes…" : "fiches à jour"
    }

    @ViewBuilder private func hiddenRow(_ k: MediaKind) -> some View {
        let h = HiddenRows.list(k)
        PrefRow(title: "Rangées masquées (\(ps.me.name))", value: h.isEmpty ? "aucune" : h.joined(separator: ", ") + " · OK pour rétablir",
                sub: "« OK maintenu » sur le titre d'une rangée de l'accueil pour la masquer. Ici, OK les fait toutes revenir.", id: "sa-hid-" + k.rawValue) {
            guard !h.isEmpty else { return }
            HiddenRows.reset(k); AppToast.shared.say("Rangées rétablies")
        }
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
        PrefHeader(title: "Contrôle parental", cat: "par")
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
        // sauvegarde arrivée (iPhone ou autre Apple TV) : confirmation dans le panneau, sélection posée sur « Restaurer »
        // (la fenêtre d'alerte système ne s'ouvrait pas depuis ce panneau sur tvOS)
        if let r = phone.received ?? inbox.received {
            VStack(alignment: .leading, spacing: 8) {
                Text("Restaurer cette sauvegarde ?").font(P.font(28, .bold))
                Text("Sauvegarde du \(r.date) (\(r.device)) · profils : \(r.profiles.joined(separator: ", ")).").font(P.font(21)).foregroundStyle(P.dim)
                Text("Les profils, Ma liste, les reprises, les goûts, les réglages et les fournisseurs de cette Apple TV seront remplacés. Une copie de ceux d'aujourd'hui est gardée pour annuler.").font(P.font(20)).foregroundStyle(P.faint)
            }.padding(.horizontal, 22)
            PrefRow(title: "Restaurer", icon: "arrow.counterclockwise", grab: true) {
                done = Backup.restore(r) ? Self.restartMsg : "Restauration impossible."
                phone.received = nil; inbox.received = nil; show = ""
                DataCount.write("restauration confirmée sur la TV")
            }
            PrefRow(title: "Ne pas restaurer", icon: "xmark") { phone.received = nil; inbox.received = nil }
        }
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
        PrefGroup(title: "À propos et installation")
        PrefInfo(title: "Application", value: "prisme " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ") pour Apple TV")
        PrefInfo(title: "Identifiant", value: Bundle.main.bundleIdentifier ?? "?")
        PrefInfo(title: "Validité de l'installation", value: DeviceInfo.installValidity)
        PrefInfo(title: "Mises à jour", value: "nouvelle version installée avec Apparition, comme une mise à jour : tes données restent")
        PrefInfo(title: "Code source", value: "github.com/goyste0406/prisme-firetv (branche appletv)")
        PrefGroup(title: "Appareil")
        PrefInfo(title: DeviceInfo.model, value: "tvOS " + UIDevice.current.systemVersion + " · " + DeviceInfo.ram)
        PrefInfo(title: "Qualité maximale", value: DeviceInfo.maxQuality)
        PrefInfo(title: "Vidéo", value: DeviceInfo.video)
        PrefInfo(title: "Audio", value: DeviceInfo.audio)
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
    }
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
