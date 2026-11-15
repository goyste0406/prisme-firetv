import SwiftUI

/// Ajouter un fournisseur en 4 étapes, comme le simulateur : Connexion › Vérification › Contenu › Importation.
/// Connexion : avec l'iPhone (code QR), en collant un lien, ou en saisissant les identifiants.
/// Vérification : abonnement, connexions, guide, replay — sans ouvrir aucune chaîne.
/// Contenu : chaînes / films / séries et catégories françaises proposées par prisme ; adultes jamais chargés ; nom et couleur.
/// Importation : une barre par type, puis « Regarder la TV maintenant » ou « Terminer ».
struct AddProviderFlow: View {
    var firstLaunch = false
    let close: () -> Void
    let watchTV: () -> Void
    @EnvironmentObject var store: ProviderStore
    @StateObject private var phone = PhonePairing()

    @State private var step = 0
    @State private var way: String?          // phone, link, form
    @State private var link = ""
    @State private var url = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var name = ""
    @State private var color = 0

    @State private var an: ProviderAnalysis?
    @State private var shown = 0
    @State private var analyzing = false
    @State private var anError: String?
    @State private var keep: [String: Bool] = ["live": true, "vod": true, "series": true]
    @State private var cats: [ProviderAnalysis.Cat] = []
    @State private var sub = false
    @State private var catTab = "live"
    @State private var showOthers = false

    @State private var newID: String?
    @State private var done = false
    @State private var importError: String?
    @FocusState private var focus: String?

    private static let steps = ["Connexion", "Vérification", "Contenu", "Importation"]
    private static let TN: [String: (String, String, String)] = ["live": ("TV en direct", "chaînes", "chaîne"), "vod": ("Films", "films", "film"), "series": ("Séries", "séries", "série")]
    private static let types = ["live", "vod", "series"]

    var body: some View {
        ZStack(alignment: .topLeading) {
            PrismeBackground(tint: step >= 2 ? Provider.colors[color] : nil)
            HStack(spacing: 34) {
                Text(firstLaunch && store.providers.filter({ $0.id != newID }).isEmpty ? "Bienvenue sur prisme" : "Ajouter un fournisseur").font(P.font(49, .bold))
                Spacer()
                stepsBar
            }
            .padding(.horizontal, 120).padding(.top, 64)
            Group {
                switch step {
                case 0: connection
                case 1: verification
                case 2: sub ? AnyView(categories) : AnyView(content)
                default: importing
                }
            }
            .padding(.horizontal, 120).padding(.top, 195).padding(.bottom, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: backAction)
        .onAppear {
            let used = Set(store.providers.compactMap(\.color))
            color = (0..<Provider.colors.count).first { !used.contains($0) } ?? 0
            focusSoon(firstLaunch ? "w-phone" : "w-phone")
        }
        .onDisappear { phone.stop() }
        .onChange(of: phone.received) { _, r in if let r { fromPhone(r) } }
        .onChange(of: store.importing) { _, now in checkImport(now) }
    }

    // MARK: barre des étapes

    private var stepsBar: some View {
        HStack(spacing: 15) {
            ForEach(0..<4, id: \.self) { i in
                if i > 0 { Rectangle().fill(Color.white.opacity(0.18)).frame(width: 41, height: 3.5) }
                HStack(spacing: 15) {
                    ZStack {
                        Circle().fill(i == step ? Color.white : (i < step ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.white.opacity(0.12)))
                        Text(i < step ? "✓" : "\(i + 1)").font(P.font(22, .heavy)).foregroundStyle(i == step ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white)
                    }
                    .frame(width: 45, height: 45)
                    Text(AddProviderFlow.steps[i]).font(P.font(24, .semibold)).foregroundStyle(i <= step ? .white : .white.opacity(0.55))
                }
            }
        }
    }

    // MARK: étape 1 : connexion

    @ViewBuilder private var connection: some View {
        switch way {
        case "phone": phoneWay
        case "link": linkWay
        case "form": formWay
        default: wayChoice
        }
    }

    private var wayChoice: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text((store.providers.isEmpty ? "Pour commencer, ajoute ton abonnement IPTV. " : "") + "Comment veux-tu l'ajouter ?").font(P.font(38)).foregroundStyle(.white.opacity(0.72))
            HStack(spacing: 38) {
                wayCard("phone", "iphone", "Avec mon iPhone", "Tu scannes un code sur la TV, puis tu colles le lien ou les identifiants reçus par e-mail ou WhatsApp. Rien à taper à la télécommande.", rec: true)
                wayCard("link", "link", "Coller un lien", "Le lien M3U ou « get.php » donné par ton fournisseur : prisme y trouve tout seul le serveur et l'utilisateur.")
                wayCard("form", "appletvremote.gen4", "Saisir les identifiants", "Adresse du serveur et utilisateur Xtream, à la télécommande ou avec le clavier de l'iPhone.")
            }
            .padding(.top, 38).focusSection()
            HStack(spacing: 19) {
                Image(systemName: "lock").font(P.font(30))
                Text("Tes identifiants restent sur cette Apple TV (trousseau Apple) et ne sont envoyés qu'à ton fournisseur.").font(P.font(26))
            }
            .foregroundStyle(.white.opacity(0.7)).padding(.top, 41)
            if !firstLaunch {
                Button("Annuler", action: close).buttonStyle(PVButtonStyle()).padding(.top, 40).focused($focus, equals: "w-cancel")
            }
        }
    }

    private func wayCard(_ id: String, _ icon: String, _ title: String, _ text: String, rec: Bool = false) -> some View {
        Button { way = id; if id == "phone" { phone.start() }; focusSoon(id == "phone" ? "ph-back" : id == "link" ? "l-field" : "f-url") } label: {
            WayCardLabel(icon: icon, title: title, text: text, rec: rec)
        }
        .buttonStyle(WayCardStyle())
        .focused($focus, equals: "w-" + id)
    }

    private var phoneWay: some View {
        HStack(alignment: .center, spacing: 75) {
            ZStack {
                RoundedRectangle(cornerRadius: 41, style: .continuous).fill(.white)
                if let img = phone.qr { Image(uiImage: img).interpolation(.none).resizable().scaledToFit().padding(30) }
                else { ProgressView().tint(.black) }
            }
            .frame(width: 488, height: 488)
            VStack(alignment: .leading, spacing: 34) {
                Text("Scanne ce code avec ton iPhone").font(P.font(49, .heavy))
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Ouvre l'appareil photo et vise le code")
                    Text("2. Une page prisme s'ouvre sur ton iPhone")
                    Text("3. Colle le lien ou les identifiants, puis « Envoyer à la TV »")
                }
                .font(P.font(34)).lineSpacing(6)
                HStack(spacing: 22) {
                    ProgressView().tint(.white)
                    Text(phone.failed ?? "En attente de ton iPhone…").font(P.font(30, .semibold))
                    Text("même Wi-Fi que l'Apple TV").font(P.font(24)).opacity(0.6)
                }
                .padding(.horizontal, 34).padding(.vertical, 22)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                if let a = phone.address { Text(a).font(P.font(22)).foregroundStyle(.white.opacity(0.5)) }
                HStack(spacing: 22) {
                    Button("Autre méthode") { phone.stop(); way = nil; focusSoon("w-phone") }.buttonStyle(PVButtonStyle()).focused($focus, equals: "ph-back")
                }
            }
        }
        .padding(.top, 20)
    }

    private var linkWay: some View {
        VStack(alignment: .leading, spacing: 34) {
            Text("Colle le lien reçu de ton fournisseur (avec le clavier de l'iPhone), ou tape-le").font(P.font(34)).foregroundStyle(.white.opacity(0.72))
            PVField(label: "Lien", text: $link, placeholder: "http://serveur.com:8080/get.php?username=…&password=…").focused($focus, equals: "l-field")
            linkChips
            HStack(spacing: 22) {
                Button("Continuer") { goFromLink() }.buttonStyle(PVButtonStyle(primary: true)).disabled(!(LinkInfo.parse(link).map { !$0.user.isEmpty } ?? false))
                Button("Autre méthode") { way = nil; focusSoon("w-link") }.buttonStyle(PVButtonStyle())
            }
            .focusSection()
        }
    }

    @ViewBuilder private var linkChips: some View {
        if let q = LinkInfo.parse(link) {
            HStack(spacing: 15) {
                chip("✓ Serveur " + LinkInfo.host(q.url), ok: true)
                chip(q.user.isEmpty ? "utilisateur manquant" : "✓ Utilisateur " + q.user, ok: !q.user.isEmpty)
                chip(q.pass.isEmpty ? "mot de passe : à saisir ensuite" : "✓ Mot de passe trouvé", ok: !q.pass.isEmpty)
                chip(q.m3u ? "lien M3U : prisme passera par l'accès Xtream, plus rapide" : "accès Xtream", ok: false)
            }
        } else {
            Text("prisme reconnaît les liens get.php, player_api.php, M3U et les liens de chaîne (…/live/utilisateur/mot-de-passe/…).").font(P.font(28)).foregroundStyle(.white.opacity(0.72))
        }
    }

    private func chip(_ t: String, ok: Bool) -> some View {
        Text(t).font(P.font(26, .semibold)).lineLimit(1)
            .foregroundStyle(ok ? Color(red: 0.65, green: 0.94, blue: 0.74) : .white)
            .padding(.horizontal, 24).padding(.vertical, 15)
            .background(Capsule().fill(ok ? Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.2) : Color.white.opacity(0.1)))
    }

    private var formWay: some View {
        VStack(alignment: .leading, spacing: 22) {
            PVField(label: "Adresse du serveur", text: $url, placeholder: "http://monserveur.com:8080", hint: LinkInfo.urlHint(url)).focused($focus, equals: "f-url")
            PVField(label: "Utilisateur", text: $user, placeholder: "ton identifiant")
            PVField(label: "Mot de passe", text: $pass, placeholder: "ton mot de passe", secure: true)
            PVField(label: "Nom (facultatif)", text: $name, placeholder: LinkInfo.serverName(url).isEmpty ? "ex. Lune" : "proposé : " + LinkInfo.serverName(url))
            HStack(spacing: 19) {
                Image(systemName: "iphone").font(P.font(30))
                Text("Astuce : quand un champ est sélectionné, ton iPhone propose son clavier (notification « Clavier Apple TV »).").font(P.font(26))
            }
            .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 22) {
                Button("Continuer") { goVerify() }.buttonStyle(PVButtonStyle(primary: true))
                    .disabled(!(LinkInfo.urlOK(url) && !user.trimmingCharacters(in: .whitespaces).isEmpty && !pass.isEmpty))
                Button("Autre méthode") { way = nil; focusSoon("w-form") }.buttonStyle(PVButtonStyle())
            }
            .focusSection()
        }
    }

    private func goFromLink() {
        guard let q = LinkInfo.parse(link) else { return }
        url = q.url; user = q.user
        if !q.pass.isEmpty { pass = q.pass; goVerify() }
        else { way = "form"; focusSoon("f-url") }
    }

    private func fromPhone(_ r: PhoneSubmission) {
        if !r.link.isEmpty, let q = LinkInfo.parse(r.link) { url = q.url; user = q.user; pass = q.pass.isEmpty ? r.pass : q.pass }
        else { url = r.server; user = r.user; pass = r.pass }
        if !r.name.isEmpty { name = r.name }
        phone.stop()
        if LinkInfo.urlOK(url) && !user.isEmpty && !pass.isEmpty { goVerify() } else { way = "form"; focusSoon("f-url") }
    }

    // MARK: étape 2 : vérification

    private func goVerify() {
        url = LinkInfo.normalized(url); user = user.trimmingCharacters(in: .whitespaces)
        if name.trimmingCharacters(in: .whitespaces).isEmpty { name = LinkInfo.serverName(url).isEmpty ? "Mon fournisseur" : LinkInfo.serverName(url) }
        step = 1; an = nil; shown = 0; anError = nil; analyzing = true
        let acc = XtreamAccount(server: url, username: user, password: pass)
        let others = store.active.map(\.id)
        Task {
            do {
                let a = try await ProviderAnalysis.run(acc, others: others) { partial in an = partial; reveal() }
                an = a; analyzing = false
                cats = a.cats
                for t in AddProviderFlow.types where (a.totals[t] ?? 0) == 0 { keep[t] = false }
                reveal()
            } catch {
                analyzing = false
                anError = ProviderStore.message(error)
                focusSoon("v-redo")
            }
        }
    }

    /// Les lignes apparaissent l'une après l'autre (simulateur), au rythme des réponses du serveur.
    private func reveal() {
        guard let a = an else { return }
        let total = a.checks(user: user).count
        let ready = !a.auth ? total : (analyzing ? min(total, 4 + (a.epgBytes != 0 ? 1 : 0) + (a.totals["live"] != nil ? 1 : 0)) : total)
        func tick() {
            guard shown < ready else { if !analyzing { focusSoon(bad ? "v-redo" : "v-go") }; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shown += 1; tick() }
        }
        tick()
    }

    private var bad: Bool { an.map { $0.checks(user: user).contains { $0.level == .bad } } ?? (anError != nil) }

    private var verification: some View {
        HStack(alignment: .top, spacing: 75) {
            VStack(spacing: 11) {
                let L = an?.checks(user: user) ?? []
                ForEach(Array(L.enumerated()), id: \.offset) { i, c in checkLine(c, state: i < shown ? 0 : (i == shown ? 1 : 2)) }
                if L.isEmpty && anError == nil { checkLine(ProviderAnalysis.Check(title: "Serveur joignable", detail: "", level: .ok), state: 1) }
                if let e = anError { PVError(text: "Connexion impossible : " + e + " Vérifie l'adresse du serveur, puis réessaie.") }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 26) {
                if let a = an, !analyzing, shown >= a.checks(user: user).count {
                    if bad {
                        PVError(text: "Le serveur refuse ce compte ou l'abonnement n'est plus actif. Vérifie l'utilisateur et le mot de passe, puis recommence.")
                        Button("Recommencer") { step = 0; way = "form"; focusSoon("f-url") }.buttonStyle(PVButtonStyle(primary: true)).focused($focus, equals: "v-redo")
                    } else {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("REÇU DE TON FOURNISSEUR").font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.66))
                            Text(AddProviderFlow.types.filter { (a.totals[$0] ?? 0) > 0 }.map { "\(Fmt.n(a.totals[$0]!)) \(AddProviderFlow.TN[$0]!.1)" }.joined(separator: " · ").ifEmpty("aucun contenu"))
                                .font(P.font(28, .semibold)).lineSpacing(6)
                            if a.maxConn == 1 {
                                Text("Ton abonnement n'autorise qu'une connexion à la fois : prisme coupe les aperçus vidéo avant chaque lecture pour ne jamais te bloquer.").font(P.font(26)).foregroundStyle(.white.opacity(0.72))
                            }
                            Text("prisme te préviendra 7 jours avant l'expiration.").font(P.font(26)).foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(34).pvGlass(38)
                        Button("Continuer") { step = 2; sub = false; focusSoon("c-live") }.buttonStyle(PVButtonStyle(primary: true)).focused($focus, equals: "v-go")
                    }
                } else if anError != nil {
                    Button("Recommencer") { step = 0; way = way ?? "form"; focusSoon("f-url") }.buttonStyle(PVButtonStyle(primary: true)).focused($focus, equals: "v-redo")
                } else {
                    Text("prisme vérifie ton abonnement sans ouvrir aucune chaîne : ta connexion reste libre.").font(P.font(28)).foregroundStyle(.white.opacity(0.72)).lineSpacing(6)
                }
            }
            .frame(width: 619)
        }
    }

    /// state : 0 fait, 1 en cours, 2 en attente
    private func checkLine(_ c: ProviderAnalysis.Check, state: Int) -> some View {
        HStack(spacing: 26) {
            ZStack {
                if state == 0 {
                    Circle().fill(c.level == .ok ? Color(red: 0.2, green: 0.78, blue: 0.35) : c.level == .warn ? Color(red: 1, green: 0.62, blue: 0.04) : Color(red: 0.9, green: 0.28, blue: 0.3))
                    Text(c.level == .bad ? "✕" : c.level == .warn ? "!" : "✓").font(P.font(28, .heavy))
                } else if state == 1 { ProgressView().tint(.white) }
            }
            .frame(width: 52, height: 52)
            Text(c.title).font(P.font(34))
            Spacer(minLength: 20)
            if state == 0 { Text(c.detail).font(P.font(26)).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.trailing) }
        }
        .padding(.horizontal, 34).padding(.vertical, 22)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .opacity(state == 2 ? 0.4 : 1)
    }

    // MARK: étape 3 : contenu

    private func kept(_ t: String) -> Int { cats.filter { $0.type == t && $0.on }.reduce(0) { $0 + $1.count } }
    private func keptN(_ t: String) -> Int { cats.filter { $0.type == t && $0.on }.count }
    private func tot(_ t: String) -> Int { cats.filter { $0.type == t && $0.lang.g != .adult }.reduce(0) { $0 + $1.count } }
    private func dupN(_ t: String) -> Int { cats.filter { $0.type == t && $0.on }.reduce(0) { $0 + $1.dup } }

    private var content: some View {
        HStack(alignment: .top, spacing: 56) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CE QUE PRISME VA IMPORTER").font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.66)).padding(.leading, 30).padding(.bottom, 8)
                ForEach(AddProviderFlow.types, id: \.self) { t in typeRow(t) }
                langRow
                adultRow
                dupNote
            }
            .frame(maxWidth: .infinity).focusSection()
            nameColor.frame(width: 675).focusSection()
        }
    }

    private func typeRow(_ t: String) -> some View {
        let none = tot(t) == 0
        let subtitle: String = none ? "rien reçu de ce fournisseur" : "\(Fmt.n(kept(t))) \(AddProviderFlow.TN[t]!.1) en français sur \(Fmt.n(tot(t))) · \(keptN(t)) catégorie" + (keptN(t) > 1 ? "s" : "")
        return Button { if !none { keep[t] = !(keep[t] ?? true) } } label: {
            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AddProviderFlow.TN[t]!.0).font(P.font(32, .bold))
                    Text(subtitle).font(P.font(24)).opacity(0.66).lineLimit(1)
                }
                Spacer()
                PVSwitch(on: (keep[t] ?? true) && !none)
            }
        }
        .buttonStyle(PVItemStyle()).focused($focus, equals: "c-" + t)
    }

    private var langRow: some View {
        let chk = cats.filter { $0.lang.g == .chk }.count
        let subtitle: String = (chk > 0 ? "\(chk) catégorie" + (chk > 1 ? "s" : "") + " sans langue vérifiée" + (chk > 1 ? "s" : "") + " sur leurs titres · " : "") + "voir et ajuster"
        let n = cats.filter(\.on).count
        return Button { sub = true; catTab = "live"; focusSoon("ct-live") } label: {
            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Catégories françaises").font(P.font(32, .bold))
                    Text(subtitle).font(P.font(24)).opacity(0.66).lineLimit(1)
                }
                Spacer()
                Text("\(n) gardées ›").font(P.font(28)).opacity(0.78)
            }
        }
        .buttonStyle(PVItemStyle())
    }

    private var adultRow: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Contenus pour adultes").font(P.font(32, .bold))
                Text("jamais chargés").font(P.font(24)).opacity(0.66)
            }
            Spacer()
            Text("toujours masqués 🔒").font(P.font(28)).opacity(0.78)
        }
        .padding(.horizontal, 30).frame(minHeight: 101)
    }

    @ViewBuilder private var dupNote: some View {
        let others: [String] = store.active.filter { $0.id != newID }.map(\.name)
        if !others.isEmpty {
            dupText(others).font(P.font(28)).lineSpacing(6).padding(.horizontal, 34).padding(.vertical, 26).pvGlass(34).padding(.top, 11)
        }
    }

    private func dupText(_ others: [String]) -> Text {
        let who = others.joined(separator: " et ")
        var parts: [String] = [], total = 0
        for t in AddProviderFlow.types where keep[t] ?? true {
            let n = dupN(t)
            guard n > 0 else { continue }
            total += n
            parts.append("\(Fmt.n(n)) " + (n > 1 ? AddProviderFlow.TN[t]!.1 : AddProviderFlow.TN[t]!.2))
        }
        if parts.isEmpty { return Text("Aucun doublon avec \(who) : tout ce contenu est nouveau.") }
        let head = Text(parts.joined(separator: ", ") + " existe" + (total > 1 ? "nt" : "") + " déjà chez \(who).").bold()
        return head + Text(" prisme les réunit : une seule fiche avec les deux sources, la meilleure d'abord, l'autre si la première coupe.")
    }

    private var nameColor: some View {
        let can = AddProviderFlow.types.contains { (keep[$0] ?? true) && keptN($0) > 0 }
        return VStack(alignment: .leading, spacing: 26) {
            Text("NOM ET COULEUR").font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.66))
            TextField(LinkInfo.serverName(url).ifEmpty("Mon fournisseur"), text: $name).font(P.font(38))
            HStack(spacing: 22) {
                ForEach(0..<Provider.colors.count, id: \.self) { i in
                    Button { color = i } label: { Circle().fill(Provider.colors[i]).frame(width: 56, height: 56) }
                        .buttonStyle(ColorDotStyle(selected: i == color))
                }
            }
            .padding(.vertical, 8).focusSection()
            Text("La couleur repère ce fournisseur dans les réglages et les sources.").font(P.font(26)).foregroundStyle(.white.opacity(0.72))
            Button("Importer") { startImport() }.buttonStyle(PVButtonStyle(primary: true)).padding(.top, 19).disabled(!can)
        }
    }

    private var categories: some View {
        HStack(alignment: .top, spacing: 56) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 15) {
                    ForEach(AddProviderFlow.types, id: \.self) { t in
                        Button { catTab = t; showOthers = false } label: { Text("\(AddProviderFlow.TN[t]!.0) · \(keptN(t))").font(P.font(28, .semibold)) }
                            .buttonStyle(CatTabStyle(selected: catTab == t)).focused($focus, equals: "ct-" + t)
                    }
                }
                .focusSection()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) { catList }.padding(6)
                }
                .clipped()
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 11) {
                    Text(AddProviderFlow.TN[catTab]!.0.uppercased()).font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.66))
                    (Text(Fmt.n(kept(catTab))).font(P.font(56, .heavy)) + Text(" " + AddProviderFlow.TN[catTab]!.1).font(P.font(30, .semibold)))
                    Text("\(keptN(catTab)) catégories gardées sur \(cats.filter { $0.type == catTab }.count) · \(Fmt.n(tot(catTab))) \(AddProviderFlow.TN[catTab]!.1) au total").font(P.font(26)).foregroundStyle(.white.opacity(0.72))
                }
                .padding(34).frame(maxWidth: .infinity, alignment: .leading).pvGlass(38)
                Text("Comment prisme trie : un repère FR, VF, VFF, VFQ, VOSTFR ou TRUEFRENCH dans le nom, un nom écrit en français, sinon les titres de la catégorie. « AFRICA » ou « FRIENDS » ne passent pas pour du français.")
                    .font(P.font(26)).foregroundStyle(.white.opacity(0.72)).lineSpacing(6)
                Button("Valider") { sub = false; focusSoon("c-live") }.buttonStyle(PVButtonStyle(primary: true))
                Button("Revenir au choix de prisme") {
                    for i in cats.indices { cats[i].on = cats[i].lang.g != .adult && cats[i].lang.proposed(cats[i].name) }
                }
                .buttonStyle(PVButtonStyle())
            }
            .frame(width: 619).focusSection()
        }
    }

    @ViewBuilder private var catList: some View {
        let groups: [(CatLang.Group, String, String)] = [(.fr, "Françaises", "reconnues à leur nom"), (.fo, "Francophones", "Belgique, Québec, Suisse, Afrique : à ton choix"),
                                                        (.chk, "À vérifier", "pas de langue dans le nom : prisme a regardé les titres"), (.xx, "Autres langues", "ignorées, tu peux en ajouter une")]
        let C = cats.indices.filter { cats[$0].type == catTab }
        if C.isEmpty { Text("Rien reçu de ce fournisseur pour \(AddProviderFlow.TN[catTab]!.0.lowercased()).").font(P.font(28)).foregroundStyle(.white.opacity(0.72)).padding(30) }
        ForEach(groups, id: \.0) { g, h, d in
            let I = C.filter { cats[$0].lang.g == g }
            if !I.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 15) {
                    Text(h).font(P.font(28, .semibold))
                    Text("\(I.count)").font(P.font(24, .bold)).padding(.horizontal, 15).padding(.vertical, 2).background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                    Spacer()
                    Text(d).font(P.font(24)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 30).padding(.top, 26).padding(.bottom, 11)
                if g == .xx && !showOthers {
                    Button { showOthers = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Afficher les \(I.count) catégories ignorées").font(P.font(32, .bold))
                                Text(I.prefix(4).map { cats[$0].name }.joined(separator: " · ") + (I.count > 4 ? "…" : "")).font(P.font(24)).opacity(0.66).lineLimit(1)
                            }
                            Spacer()
                            Text("›").font(P.font(28)).opacity(0.78)
                        }
                    }
                    .buttonStyle(PVItemStyle())
                } else {
                    ForEach(I, id: \.self) { i in
                        Button { cats[i].on.toggle() } label: {
                            HStack(spacing: 26) {
                                PVSwitch(on: cats[i].on)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(cats[i].name).font(P.font(32, .bold)).lineLimit(1)
                                    Text("\(Fmt.n(cats[i].count)) \(cats[i].count > 1 ? AddProviderFlow.TN[catTab]!.1 : AddProviderFlow.TN[catTab]!.2) · \(cats[i].lang.why)").font(P.font(24)).opacity(0.66).lineLimit(1)
                                }
                                Spacer()
                                if cats[i].lang.g == .chk {
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.18)).frame(width: 131, height: 11)
                                        Capsule().fill(Color(red: 0.61, green: 0.91, blue: 0.75)).frame(width: 131 * CGFloat(cats[i].lang.pct) / 100, height: 11)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PVItemStyle())
                    }
                }
            }
        }
        let ad = C.filter { cats[$0].lang.g == .adult }.count
        if ad > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 15) {
                Text("Adultes").font(P.font(28, .semibold))
                Text("\(ad)").font(P.font(24, .bold)).padding(.horizontal, 15).padding(.vertical, 2).background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                Spacer()
                Text("jamais chargées, même si tu changes les réglages ici").font(P.font(24)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 30).padding(.top, 26)
        }
    }

    // MARK: étape 4 : importation

    private func startImport() {
        let hidden = cats.filter { !$0.on && $0.lang.g != .adult && $0.id != "*" }.map { $0.type + ":" + $0.id }
        let skip = AddProviderFlow.types.filter { !(keep[$0] ?? true) || keptN($0) == 0 }
        let n = name.trimmingCharacters(in: .whitespaces).ifEmpty(LinkInfo.serverName(url).ifEmpty("Mon fournisseur"))
        importError = nil; done = false; step = 3
        newID = store.addVerified(name: n, server: url, user: user, pass: pass, color: color, hidden: hidden, skip: skip,
                                  ping: an?.ms, maxConn: an?.maxConn, expires: an?.expires)
        name = n
    }

    private func checkImport(_ now: String?) {
        guard step == 3, let id = newID, now != id, let p = store.provider(id) else { return }
        if p.lastImport != nil { done = true; focusSoon("i-tv") }
        else if let e = p.lastError { importError = e; focusSoon("i-back") }
    }

    private static let phases: [(String, String, Double, Double)] = [("live", "Chaînes", 0.12, 0.30), ("vod", "Films", 0.30, 0.50), ("series", "Séries", 0.50, 0.62), ("epg", "Guide TV", 0.62, 1.0), ("save", "Enregistrement", 1.0, 1.0)]

    private var importing: some View {
        let p = newID.flatMap { store.provider($0) }
        let running = store.importing == newID
        let pct = running ? store.progress : (done ? 1 : 0)
        let L = AddProviderFlow.phases.filter { k, _, _, _ in k == "save" || (k == "epg" ? (keep["live"] ?? true) && (an?.epgBytes ?? 0) > 2000 : (keep[k] ?? true) && keptN(k) > 0) }
        return HStack(alignment: .top, spacing: 75) {
            VStack(alignment: .leading, spacing: 30) {
                ForEach(L, id: \.0) { k, label, a, b in
                    let v = done ? 1 : (b <= a ? 0 : min(1, max(0, (pct - a) / (b - a))))
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text(label).font(P.font(32, .semibold))
                            Spacer()
                            Text(v >= 1 ? "✓ " + doneLabel(k, p) : v > 0 ? "\(Int(v * 100)) %" : "en attente").font(P.font(28)).foregroundStyle(.white.opacity(0.72))
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.14)).frame(height: 15)
                            GeometryReader { g in Capsule().fill(.white).frame(width: g.size.width * v, height: 15) }.frame(height: 15)
                        }
                    }
                }
                Text(running ? store.status : "").font(P.font(26)).foregroundStyle(.white.opacity(0.72)).frame(minHeight: 80, alignment: .topLeading)
                if let e = importError { PVError(text: "Import impossible : " + e) }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 26) {
                if done {
                    Button("Regarder la TV maintenant") { phone.stop(); watchTV() }.buttonStyle(PVButtonStyle(primary: true)).focused($focus, equals: "i-tv")
                    Button("Terminer") { phone.stop(); close() }.buttonStyle(PVButtonStyle()).focused($focus, equals: "i-end")
                    (Text(name + " est prêt.").bold() + Text(store.providers.count > 1 ? "\nTes catalogues sont fusionnés. Les affiches et les fiches complètes arrivent ensuite en arrière-plan." : "\nLes affiches et les fiches complètes arrivent ensuite en arrière-plan."))
                        .font(P.font(28)).lineSpacing(6).padding(30).pvGlass(34)
                } else if importError != nil {
                    Button("Revenir au contenu") { if let id = newID { store.remove(id) }; newID = nil; step = 2; focusSoon("c-live") }
                        .buttonStyle(PVButtonStyle(primary: true)).focused($focus, equals: "i-back")
                } else {
                    Text("L'import continue même si tu quittes cet écran.").font(P.font(26)).foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 638).focusSection()
        }
    }

    private func doneLabel(_ k: String, _ p: Provider?) -> String {
        guard let c = p?.counts else { return "" }
        switch k {
        case "live": return "\(Fmt.n(c["live"] ?? 0)) flux de chaînes"
        case "vod": return "\(Fmt.n(c["vod"] ?? 0)) films"
        case "series": return "\(Fmt.n(c["series"] ?? 0)) séries"
        case "epg": return "\(Fmt.n(c["epg"] ?? 0)) programmes"
        default: return "sur cette Apple TV"
        }
    }

    // MARK: navigation

    private func backAction() {
        switch step {
        case 0:
            if way != nil { phone.stop(); let w = way!; way = nil; focusSoon("w-" + w) }
            else if !firstLaunch { close() }
        case 1: step = 0; focusSoon("w-" + (way ?? "phone")); if way == "phone" { phone.start() }
        case 2: if sub { sub = false; focusSoon("c-live") } else { step = 1; focusSoon("v-go") }
        default: if done || importError != nil { if done { close() } }
        }
    }

    private func focusSoon(_ k: String) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = k } }
}

/// Carte d'un moyen d'ajout (simulateur .pv-wc) : blanche quand elle est sélectionnée.
struct WayCardLabel: View {
    let icon: String
    let title: String
    let text: String
    var rec = false
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Image(systemName: icon).font(P.font(46))
            if rec { Text("le plus simple").font(P.font(22, .bold)).padding(.horizontal, 17).padding(.vertical, 6).background(RecBadge()) }
            Text(title).font(P.font(41, .bold))
            Text(text).font(P.font(28)).lineSpacing(5).opacity(0.75)
            Spacer(minLength: 0)
        }
        .padding(45).frame(maxWidth: .infinity, minHeight: 469, alignment: .topLeading)
    }
}

private struct RecBadge: View {
    @Environment(\.isFocused) var f
    var body: some View { RoundedRectangle(cornerRadius: 13).fill(f ? Color(red: 0.84, green: 0.96, blue: 0.89) : Color(red: 0.47, green: 0.86, blue: 0.63).opacity(0.2)) }
}

struct WayCardStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white)
                .background(RoundedRectangle(cornerRadius: 45, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 45, style: .continuous).stroke(Color.white.opacity(f ? 0 : 0.1), lineWidth: 1.5))
                .scaleEffect(f ? 1.04 : 1).shadow(color: .black.opacity(f ? 0.45 : 0), radius: 38, y: 34)
                .animation(.easeOut(duration: 0.16), value: f)
        }
    }
}

/// Onglets de catégories (simulateur .pv-chip.tab)
struct CatTabStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, selected: selected) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white)
                .padding(.horizontal, 30).padding(.vertical, 17)
                .background(Capsule().fill(f ? Color.white : Color.white.opacity(selected ? 0.24 : 0.1)))
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

extension String {
    func ifEmpty(_ other: String) -> String { trimmingCharacters(in: .whitespaces).isEmpty ? other : self }
}
