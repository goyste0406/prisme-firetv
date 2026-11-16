import SwiftUI

// Réglages › Fournisseurs, « Gérer » et l'ajout en 4 étapes (simulateur : provRows, plmHtml, pv).
// Les dimensions du simulateur sont multipliées par 1,875 (écran de 1 024 px → 1 920 points).

// MARK: - Panneau des réglages

struct ProvidersPanel: View {
    @EnvironmentObject var store: ProviderStore
    @ObservedObject var incidents = Incidents.shared
    let manage: (String) -> Void
    let add: () -> Void
    let log: () -> Void
    var classify: () -> Void = {}
    var restore: (String, Int)? = nil
    @State private var desc = "Choisis un réglage pour voir à quoi il sert."
    @State private var totals: (live: Int, vod: Int, series: Int, grouped: Int)?
    @State private var testing = false
    @FocusState private var focus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Fournisseurs").font(P.font(49, .bold)).padding(.bottom, 14)
            row("log", SettingLine(title: "Journal des incidents", value: incidents.items.isEmpty ? "aucun ›" : "\(incidents.items.count) ›"),
                "Heure, fournisseur, titre, cause et solution utilisée : à montrer à ton fournisseur si ça se répète.", log)
            ForEach(store.providers) { p in
                row("pl-" + p.id, ProviderLine(p: p, importing: store.importing == p.id, progress: store.progress), describe(p)) { manage(p.id) }
            }
            row("add", SettingLine(title: "＋ Ajouter un fournisseur", value: "iPhone, lien ou identifiants ›"),
                "Avec ton iPhone (code QR), en collant le lien du fournisseur ou en saisissant les identifiants. prisme vérifie l'abonnement et ne garde que les catégories françaises.", add)
            Text("CATALOGUE").font(P.font(23, .bold)).tracking(3.2).foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 24).padding(.top, 26).padding(.bottom, 6)
            SettingLine(title: "Fournisseurs actifs", value: "\(store.active.count) / \(store.providers.count)")
            SettingLine(title: "Contenu total", value: totals.map { "\(Fmt.n($0.live)) chaînes · \(Fmt.n($0.vod)) films · \(Fmt.n($0.series)) séries" } ?? "…")
            SettingLine(title: "Titres et chaînes avec plusieurs sources", value: totals.map { "\(Fmt.n($0.grouped)) regroupés" } ?? "…")
            row("class", SettingLine(title: "Classement des chaînes TV", value: "vérifier ›"),
                "Chaque chaîne avec sa catégorie (Généraliste, Sport…), la raison de ce classement et toutes ses sources.", classify)
            row("test", SettingLine(title: "Tester mes serveurs", value: testing ? "mesure en cours…" : pings()),
                "Mesure le temps de réponse de chaque fournisseur, sans ouvrir aucun flux.") {
                guard !testing else { return }
                testing = true
                Task { await store.testServers(); testing = false }
            }
            Spacer(minLength: 20)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1.5)
            Text(desc).font(P.font(23)).foregroundStyle(.white.opacity(0.6)).padding(.top, 22).lineLimit(2)
        }
        .task(id: store.catalogVersion) { totals = await CatalogTotals.compute(pids: store.active.map(\.id)) }
        .onChange(of: restore?.1) { _, _ in
            guard let r = restore?.0 else { return }
            let key = r.hasPrefix("pl-") && !store.providers.contains(where: { "pl-" + $0.id == r }) ? "add" : r   // fournisseur supprimé
            for d in [0.15, 0.45] { DispatchQueue.main.asyncAfter(deadline: .now() + d) { focus = key } }
        }
    }

    private func row<V: View>(_ key: String, _ label: V, _ d: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) { label }
            .buttonStyle(SettingRowStyle())
            .focused($focus, equals: key)
            .onChange(of: focus) { _, f in if f == key { desc = d } }
    }

    private func pings() -> String {
        let L = store.active.compactMap { p in p.ping.map { "\(p.name) \($0) ms" } }
        return (L.isEmpty ? "temps de réponse" : L.joined(separator: " · ")) + " ›"
    }

    private func describe(_ p: Provider) -> String {
        var s = LinkInfo.host(p.account.baseURL) + " · " + p.username
        if let e = p.expires { s += " · expire le " + Fmt.date(e) }
        if let m = p.maxConn, m > 0 { s += " · \(m) connexion" + (m > 1 ? "s simultanées" : " à la fois") }
        return s + " · OK pour gérer ses catégories"
    }
}

/// Ligne d'un fournisseur (simulateur : pastille de couleur, nom, contenu, expiration, connexions)
struct ProviderLine: View {
    let p: Provider
    var importing = false
    var progress: Double = 0
    var body: some View {
        HStack(spacing: 22) {
            Circle().fill(p.on ? p.tint : Color.gray).frame(width: 19, height: 19)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(P.font(32, .semibold))
                Text(sub).font(P.font(23)).opacity(0.62).lineLimit(1)
            }
            Spacer(minLength: 20)
            if importing { ProgressView(value: progress).frame(width: 160) }
            Text(state).font(P.font(28)).opacity(0.7).lineLimit(1)
        }
        .padding(.horizontal, 24).frame(height: 124)
    }
    private var sub: String {
        guard p.lastImport != nil else { return "catalogue pas encore chargé" }
        return "\(Fmt.n(p.counts["live"] ?? 0)) chaînes · \(Fmt.n(p.counts["vod"] ?? 0)) films · \(Fmt.n(p.counts["series"] ?? 0)) séries"
    }
    private var state: String {
        switch p.health {
        case .off: return "inactif ›"
        case .expired: return "⚠︎ abonnement expiré ›"
        case .failing(let e): return "⚠︎ " + e.replacingOccurrences(of: ".", with: "") + " ›"
        case .never, .ok:
            var L: [String] = []
            if let e = p.expires { let d = Int(ceil(e.timeIntervalSinceNow / 86400)); L.append(d < 0 ? "expiré" : "expire dans \(d) j") }
            if let m = p.maxConn, m > 0 { L.append("\(m) connexion" + (m > 1 ? "s" : "")) }
            return (L.isEmpty ? "actif" : L.joined(separator: " · ")) + " ›"
        }
    }
}

/// Totaux du catalogue fusionné (en arrière-plan)
enum CatalogTotals {
    static func compute(pids: [String]) async -> (live: Int, vod: Int, series: Int, grouped: Int) {
        guard !pids.isEmpty else { return (0, 0, 0, 0) }
        let st = ProviderStore.shared
        let index = await LiveIndex.all(pids: pids, version: st.catalogVersion)
        let ph = pids.map { _ in "?" }.joined(separator: ",")
        let (v, s, g) = await Database.shared.read { db -> (Int, Int, Int) in
            func works(_ t: String) -> (Int, Int) {
                var count: [String: Int] = [:]
                db.query("SELECT name, tmdb FROM \(t) WHERE pid IN (\(ph))", pids.map { $0 as Any? }) { r in
                    let k = r.str(1).isEmpty ? TitleTools.clean(r.str(0), year: CatalogImporter.year(in: r.str(0))).key : "t" + r.str(1)
                    count[k, default: 0] += 1
                }
                return (count.count, count.values.filter { $0 > 1 }.count)
            }
            let a = works("vod"), b = works("series")
            return (a.0, b.0, a.1 + b.1)
        }
        return (index.count, v, s, g + index.filter { $0.sources > 1 }.count)
    }
}

extension Fmt {
    /// 12 345 → « 12 345 »
    static func n(_ x: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "fr_FR")
        return (f.string(from: NSNumber(value: x)) ?? "\(x)").replacingOccurrences(of: "\u{202F}", with: " ")
    }
}

// MARK: - Classement des chaînes TV (diagnostic)

/// Chaque chaîne de la TV en direct avec sa catégorie, la raison de ce classement et toutes ses sources :
/// pour vérifier le classement avec les vraies chaînes de tes fournisseurs (TF1 en Généraliste, etc.).
struct ChannelClassView: View {
    @EnvironmentObject var store: ProviderStore
    let close: () -> Void
    struct Row: Identifiable { let id: String; let name: String; let why: String; let sources: String }
    @State private var byUnivers: [Univers: [Row]] = [:]
    @State private var selected: Univers = .generaliste
    @State private var loaded = false
    @FocusState private var focus: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("RÉGLAGES › FOURNISSEURS").font(P.font(21, .bold)).tracking(3).foregroundStyle(.white.opacity(0.6))
                Text("Classement des chaînes TV").font(P.font(52, .bold))
                Text("catégorie de chaque chaîne, raison du classement et sources · Retour pour fermer").font(P.font(23)).foregroundStyle(P.dim)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Univers.allCases) { u in
                            Button { selected = u } label: { Text("\(u.label) · \(byUnivers[u]?.count ?? 0)") }
                                .buttonStyle(XModeStyle(selected: selected == u))
                                .focused($focus, equals: "u-" + u.rawValue)
                        }
                    }
                    .padding(.vertical, 14).padding(.horizontal, 6)
                }
                .focusSection()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if !loaded { Text("Lecture des chaînes…").font(P.font(26)).foregroundStyle(P.dim).padding(.vertical, 30) }
                        else if (byUnivers[selected] ?? []).isEmpty { Text("Aucune chaîne dans cette catégorie.").font(P.font(26)).foregroundStyle(P.dim).padding(.vertical, 30) }
                        ForEach(byUnivers[selected] ?? []) { r in
                            Button {} label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(r.name).font(P.font(27, .semibold))
                                    Text("Classée : " + r.why).font(P.font(21)).opacity(0.7)
                                    Text(r.sources).font(P.font(21)).opacity(0.7).lineLimit(2)
                                }
                                .padding(.vertical, 12).padding(.horizontal, 20)
                            }
                            .buttonStyle(SettingRowStyle(radius: 18))
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 600)
                .focusSection()
            }
            .padding(54).frame(width: 1500).glass(40)
        }
        .onExitCommand(perform: close)
        .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = "u-" + selected.rawValue }
            let pids = store.active.map(\.id)
            let index = await LiveIndex.all(pids: pids, version: store.catalogVersion)
            let cats = await Database.shared.read { db -> [String: String] in
                var c: [String: String] = [:]
                db.query("SELECT pid,cid,name FROM category WHERE type='live'", []) { r in c[r.str(0) + ":" + r.str(1)] = r.str(2) }
                return c
            }
            var out: [Univers: [Row]] = [:]
            for e in index {
                let cat0 = cats[e.ch.pid + ":" + e.ch.cid] ?? ""
                var why = Univers.reason(clean: e.name, category: cat0)
                // univers venu du groupe d'une autre source de la même chaîne
                if Univers.of(clean: e.name, category: cat0) != e.univers,
                   let c = e.copies.first(where: { Univers.of(clean: e.name, category: cats[$0.pid + ":" + $0.cid] ?? "") == e.univers }) {
                    why = "groupe « \(cats[c.pid + ":" + c.cid] ?? "") » chez " + (store.provider(c.pid)?.name ?? "un autre fournisseur")
                }
                let src = e.copies.map { LiveSourceLabel.text($0) + " (« " + $0.name + " »)" }.joined(separator: ", ")
                out[e.univers, default: []].append(Row(id: e.id, name: e.name, why: why,
                                                       sources: "\(e.sources) source" + (e.sources > 1 ? "s" : "") + " : " + src))
            }
            byUnivers = out
            loaded = true
        }
    }
}

// MARK: - Journal des incidents

struct IncidentLogView: View {
    @ObservedObject var incidents = Incidents.shared
    let close: () -> Void
    @FocusState private var focus: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("RÉGLAGES › FOURNISSEURS").font(P.font(21, .bold)).tracking(3).foregroundStyle(.white.opacity(0.6))
                Text("Journal des incidents").font(P.font(52, .bold))
                Text("à montrer à ton fournisseur si ça se répète · Retour pour fermer").font(P.font(23)).foregroundStyle(P.dim)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if incidents.items.isEmpty { Text("Aucun incident pour l'instant.").font(P.font(26)).foregroundStyle(P.dim).padding(.vertical, 30) }
                        ForEach(incidents.items) { x in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(Fmt.dateTime(x.at) + " · " + x.provider + " · " + x.title).font(P.font(25, .semibold))
                                Text("Cause : " + x.cause + "  ·  Solution : " + x.fix).font(P.font(22)).foregroundStyle(P.dim)
                            }
                            .padding(.vertical, 12).padding(.horizontal, 20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
                .frame(maxHeight: 560)
                Button("Fermer", action: close).buttonStyle(GlassStyle(radius: 20, minH: 70)).focused($focus)
            }
            .padding(54).frame(width: 1300).glass(40)
        }
        .onExitCommand(perform: close)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = true } }
    }
}

// MARK: - Gérer un fournisseur

struct ProviderManageView: View {
    @EnvironmentObject var store: ProviderStore
    let pid: String
    let close: () -> Void
    @State private var cats: [(type: String, id: String, name: String, count: Int)] = []
    @State private var hidden: Set<String> = []
    @State private var changed = false
    @State private var confirmDelete = false
    @State private var editing = false
    @FocusState private var focus: String?

    var body: some View {
        ZStack {
            PrismeBackground(tint: store.provider(pid)?.tint)
            if let p = store.provider(pid) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("GÉRER LE FOURNISSEUR").font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.6)).padding(.leading, 34)
                        Text(p.name).font(P.font(75, .bold)).padding(.leading, 34).padding(.top, 8).padding(.bottom, 24)
                        group {
                            SettingLine(title: "Serveur", value: (p.expires.map { "expire le " + Fmt.date($0) } ?? ""))
                                .overlay(alignment: .bottomLeading) { Text(LinkInfo.host(p.account.baseURL) + " · " + p.username).font(P.font(21)).opacity(0.55).padding(.leading, 24).padding(.bottom, 12) }
                            line("on", SettingLine(title: "Fournisseur actif", valueView: AnyView(Switch(on: p.on)))) { store.toggle(pid) }
                            SettingLine(title: "Contenu affiché", value: "\(Fmt.n(p.counts["live"] ?? 0)) chaînes · \(Fmt.n(p.counts["vod"] ?? 0)) films · \(Fmt.n(p.counts["series"] ?? 0)) séries")
                            line("all", SettingLine(title: "Afficher toutes les catégories", value: hidden.isEmpty ? "aucune masquée" : "\(hidden.count) masquée" + (hidden.count > 1 ? "s" : ""))) {
                                if !hidden.isEmpty { hidden = []; changed = true; save() }
                            }
                            line("ref", SettingLine(title: "Actualiser le fournisseur", value: store.importing == pid ? "\(Int(store.progress * 100)) % · " + store.status : (p.lastImport.map { "à jour le " + Fmt.dateTime($0) } ?? "player_api.php"))) {
                                store.refresh(pid)
                            }
                            if let e = p.lastError { SettingLine(title: "Dernière erreur", value: e).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.42)) }
                            line("edit", SettingLine(title: "Modifier le nom, la couleur ou les identifiants", value: "›")) { editing = true }
                            line("del", SettingLine(title: "Supprimer le fournisseur", valueView: AnyView(Text(confirmDelete ? "OK encore pour confirmer" : "").fontWeight(.bold)), red: true)) {
                                if confirmDelete { store.remove(pid); close() } else { confirmDelete = true }
                            }
                        }
                        ForEach(["live", "vod", "series"], id: \.self) { t in
                            let L = cats.filter { $0.type == t }
                            if !L.isEmpty {
                                let shown = L.filter { !hidden.contains(t + ":" + $0.id) }.count
                                Text(["live": "Catégories TV en direct", "vod": "Catégories films", "series": "Catégories séries"][t]! + " · \(shown) affichée" + (shown > 1 ? "s" : "") + " sur \(L.count)")
                                    .font(P.font(23, .bold)).tracking(2.5).textCase(.uppercase).foregroundStyle(.white.opacity(0.55))
                                    .padding(.leading, 34).padding(.top, 34).padding(.bottom, 10)
                                group {
                                    ForEach(L, id: \.id) { c in
                                        let hk = t + ":" + c.id, h = hidden.contains(hk)
                                        line("c-" + hk, CategoryLine(name: TitleTools.category(c.name), sub: h ? "masquée" : "\(Fmt.n(c.count)) " + (["live": "chaînes", "vod": "films", "series": "séries"][t] ?? ""), on: !h)) {
                                            if h { hidden.remove(hk) } else { hidden.insert(hk) }
                                            changed = true; save()
                                        }
                                    }
                                }
                            }
                        }
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 300).padding(.top, 110)
                }
            }
        }
        .ignoresSafeArea()
        .onExitCommand { leave() }
        .onChange(of: focus) { _, f in if f != "del" { confirmDelete = false } }
        .task(id: store.catalogVersion) { await load() }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "on" } }
        .fullScreenCover(isPresented: $editing) { ProviderEditView(pid: pid, close: { editing = false }) }
    }

    private func group<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) { c() }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .focusSection()
    }

    private func line<V: View>(_ key: String, _ v: V, _ act: @escaping () -> Void) -> some View {
        Button(action: act) { v }.buttonStyle(SettingRowStyle()).focused($focus, equals: key)
    }

    private func save() {
        guard var p = store.provider(pid) else { return }
        p.hidden = hidden.isEmpty ? nil : Array(hidden).sorted()
        store.update(p)
    }

    /// En quittant : si des catégories ont changé, le catalogue du fournisseur est rechargé avec ce choix.
    private func leave() {
        if changed { store.refresh(pid) }
        close()
    }

    private func load() async {
        hidden = Set(store.provider(pid)?.hidden ?? [])
        let id = pid
        cats = await Database.shared.read { db in
            var out: [(String, String, String, Int)] = []
            var counts: [String: Int] = [:]
            for (t, table) in [("live", "live"), ("vod", "vod"), ("series", "series")] {
                db.query("SELECT cid, COUNT(*) FROM \(table) WHERE pid=? GROUP BY cid", [id]) { r in counts[t + ":" + r.str(0)] = r.int(1) }
            }
            db.query("SELECT type, cid, name FROM category WHERE pid=? ORDER BY type, pos", [id]) { r in
                out.append((r.str(0), r.str(1), r.str(2), counts[r.str(0) + ":" + r.str(1)] ?? 0))
            }
            return out
        }.map { (type: $0.0, id: $0.1, name: $0.2, count: $0.3) }
    }
}

/// Ligne de catégorie : interrupteur à droite, nombre de contenus dessous.
struct CategoryLine: View {
    let name: String
    let sub: String
    let on: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(P.font(30, .semibold)).lineLimit(1)
                Text(sub).font(P.font(21)).opacity(0.6)
            }
            Spacer(minLength: 20)
            Switch(on: on)
        }
        .padding(.horizontal, 24).frame(height: 100)
    }
}

// MARK: - Modifier un fournisseur

struct ProviderEditView: View {
    @EnvironmentObject var store: ProviderStore
    let pid: String
    let close: () -> Void
    @State private var name = ""
    @State private var server = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var color = 0
    @State private var checking = false
    @State private var err: String?
    @FocusState private var focus: String?

    var body: some View {
        ZStack {
            PrismeBackground(tint: Provider.colors[color % Provider.colors.count])
            VStack(alignment: .leading, spacing: 22) {
                Text("Modifier " + (store.provider(pid)?.name ?? "")).font(P.font(49, .bold))
                PVField(label: "Nom", text: $name, placeholder: "ex. Lune").focused($focus, equals: "name")
                PVField(label: "Adresse du serveur", text: $server, placeholder: "http://monserveur.com:8080", hint: LinkInfo.urlHint(server))
                PVField(label: "Utilisateur", text: $user, placeholder: "ton identifiant")
                PVField(label: "Mot de passe", text: $pass, placeholder: "inchangé", secure: true)
                HStack(spacing: 22) {
                    Text("Couleur").font(P.font(28, .semibold)).foregroundStyle(.white.opacity(0.75)).frame(width: 394, alignment: .leading)
                    ForEach(0..<Provider.colors.count, id: \.self) { i in
                        Button { color = i } label: { Circle().fill(Provider.colors[i]).frame(width: 56, height: 56) }
                            .buttonStyle(ColorDotStyle(selected: i == color))
                    }
                }
                .padding(.horizontal, 34).focusSection()
                if let err { PVError(text: err) }
                HStack(spacing: 22) {
                    Button(checking ? "Vérification…" : "Enregistrer") { Task { await save() } }.buttonStyle(PVButtonStyle(primary: true)).disabled(checking)
                    Button("Annuler", action: close).buttonStyle(PVButtonStyle())
                }
                .focusSection()
            }
            .frame(width: 1400)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: close)
        .onAppear {
            if let p = store.provider(pid) { name = p.name; server = p.server; user = p.username; color = p.color ?? 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = "name" }
        }
    }

    private func save() async {
        guard var p = store.provider(pid) else { return }
        let credsChanged = LinkInfo.normalized(server) != LinkInfo.normalized(p.server) || user != p.username || !pass.isEmpty
        p.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? p.name : name.trimmingCharacters(in: .whitespaces)
        p.color = color
        if credsChanged {
            var q = p
            q.server = LinkInfo.normalized(server); q.username = user.trimmingCharacters(in: .whitespaces)
            if !pass.isEmpty { q.password = pass }
            checking = true; err = nil
            do { try await XtreamAPI(account: q.account).authenticate() }
            catch { checking = false; err = ProviderStore.message(error); return }
            checking = false
            q.lastError = nil
            store.update(q)
            store.refresh(pid)
        } else {
            store.update(p)
        }
        close()
    }
}

// MARK: - Éléments du parcours d'ajout (simulateur : pv-*)

/// Champ (simulateur .pv-fld) : intitulé à gauche, saisie à droite, petit contrôle éventuel.
struct PVField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var hint: (String, Bool)? = nil
    var secure = false
    var body: some View {
        HStack(spacing: 26) {
            Text(label).font(P.font(28, .semibold)).foregroundStyle(.white.opacity(0.75)).frame(width: 394, alignment: .leading)
            Group {
                if secure { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text) }
            }
            .font(P.font(32, .semibold))
            .autocorrectionDisabled().textInputAutocapitalization(.never)
            if let h = hint, !h.0.isEmpty {
                Text(h.0).font(P.font(24, .semibold)).foregroundStyle(h.1 ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color(red: 1, green: 0.7, blue: 0.25)).lineLimit(1).fixedSize()
            }
        }
        .padding(.horizontal, 34).frame(minHeight: 116)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1.5))
    }
}

/// Bouton du parcours (simulateur .pv-btn / .pv-btn.pri)
struct PVButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, primary: primary) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let primary: Bool
        @Environment(\.isFocused) var f
        @Environment(\.isEnabled) var enabled
        var body: some View {
            c.label.font(P.font(30, .semibold)).lineLimit(1)
                .foregroundStyle(f || primary ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white)
                .padding(.horizontal, 41).frame(minHeight: 82)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(f ? Color.white : (primary ? Color.white.opacity(0.9) : Color.white.opacity(0.06))))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(f || primary ? Color.clear : Color.white.opacity(0.28), lineWidth: 1.5))
                .opacity(enabled ? 1 : 0.4)
                .scaleEffect(f ? 1.05 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 24, y: 12)
                .animation(.easeOut(duration: 0.16), value: f)
        }
    }
}

/// Pastille de couleur (simulateur .pv-col)
struct ColorDotStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label
                .overlay(Circle().stroke(Color.white, lineWidth: selected || f ? 5 : 0))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: f ? 6 : 0).padding(-8))
                .scaleEffect(f ? 1.25 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// Encadré d'erreur (simulateur .pv-err)
struct PVError: View {
    let text: String
    var body: some View {
        Text(text).font(P.font(28)).lineSpacing(6)
            .padding(.horizontal, 34).padding(.vertical, 26).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.9, green: 0.28, blue: 0.3).opacity(0.18), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color(red: 0.9, green: 0.28, blue: 0.3).opacity(0.45), lineWidth: 1.5))
    }
}

/// Verre du parcours (simulateur .pv-glass)
extension View {
    func pvGlass(_ r: CGFloat) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: r, style: .continuous))
            .background(Color(red: 30 / 255, green: 33 / 255, blue: 44 / 255).opacity(0.42), in: RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1.5))
    }
}

/// Ligne à interrupteur ou à valeur (simulateur .pv-it)
struct PVItemStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white).environment(\.colorScheme, f ? .light : .dark)
                .padding(.horizontal, 30).padding(.vertical, 18).frame(minHeight: 101).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(f ? Color.white : Color.clear))
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

struct PVSwitch: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            // simulateur (.sw) : éteint = fond sombre translucide, visible aussi sur une ligne sélectionnée (blanche)
            Capsule().fill(on ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.black.opacity(0.22)).frame(width: 94, height: 56)
            Circle().fill(.white).frame(width: 45, height: 45).shadow(color: .black.opacity(0.3), radius: 4, y: 2).padding(5.5)
        }
        .animation(.easeOut(duration: 0.2), value: on)
    }
}
