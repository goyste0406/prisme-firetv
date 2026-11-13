import SwiftUI

// MARK: - Écrans des profils (simulateur) : Réglages › Profils, fiche d'un profil, « Qui regarde ? »

/// Affichage global des fenêtres de profil (pastille de la barre du haut, pastille de la fiche film).
@MainActor
final class ProfileUI: ObservableObject {
    static let shared = ProfileUI()
    /// fenêtre « Qui regarde ? · Choisis un profil »
    @Published var picker = false
    /// écran plein « Qui regarde ? » (ouverture de prisme)
    @Published var launch = false
    /// déjà montré à cette ouverture (ne pas le remontrer)
    var shownAtLaunch = false
    /// ouvrir les réglages directement sur la fiche d'un profil
    @Published var editProfile: String?
}

// MARK: Réglages › Profils

struct ProfilesPanel: View {
    @ObservedObject var ps = ProfileStore.shared
    @ObservedObject var ui = ProfileUI.shared
    @State private var editing: String?
    @State private var desc = "Choisis un profil pour le régler."
    @FocusState private var focus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let id = editing, let p = ps.profile(id) {
                ProfileDetail(p: p, desc: $desc, back: { let i = id; editing = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = i } })
            } else {
                list
            }
            Spacer(minLength: 20)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1.5)
            Text(desc).font(P.font(23)).foregroundStyle(.white.opacity(0.6)).padding(.top, 22).lineLimit(2)
        }
        .onAppear { if let e = ui.editProfile { editing = e.isEmpty ? nil : e; ui.editProfile = nil } }
        .onChange(of: ui.editProfile) { _, e in if let e { editing = e.isEmpty ? nil : e; ui.editProfile = nil } }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Profils").font(P.font(49, .bold)).padding(.bottom, 14)
            HStack(alignment: .top, spacing: 24) {
                ForEach(ps.profiles) { p in
                    Button { editing = p.id } label: { tile(ProfileAvatar(p: p, size: 132), p.name, sub(p)) }
                        .buttonStyle(AvatarTileStyle())
                        .focused($focus, equals: p.id)
                        .onChange(of: focus) { _, f in if f == p.id { desc = "OK pour régler le profil de \(p.name) : âge, heure du coucher, langue, couleur…" } }
                }
                if ps.profiles.count < 6 {
                    Button { if let p = ps.add() { editing = p.id } } label: {
                        tile(AnyView(ZStack {
                            Circle().fill(Color.white.opacity(0.06))
                            Circle().strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [9, 7])).foregroundStyle(.white.opacity(0.4))
                            Image(systemName: "plus").font(.system(size: 54, weight: .light))
                        }.frame(width: 132, height: 132)), "Ajouter", " ")
                    }
                    .buttonStyle(AvatarTileStyle())
                    .focused($focus, equals: "add")
                    .onChange(of: focus) { _, f in if f == "add" { desc = "Jusqu'à 6 profils, chacun avec sa liste, sa progression et ses réglages." } }
                }
            }
            .padding(.vertical, 12).focusSection()
            Text("POUR TOUS LES PROFILS").font(P.font(23, .bold)).tracking(3.2).foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 24).padding(.top, 20).padding(.bottom, 10)
            Button { ps.ask.toggle() } label: {
                SettingLine(title: "À l'ouverture de prisme", value: ps.ask ? "Demander qui regarde ›" : "Ouvrir le dernier profil utilisé ›")
            }
            .buttonStyle(SettingRowStyle())
            .focused($focus, equals: "ask")
            .onChange(of: focus) { _, f in if f == "ask" { desc = "« Qui regarde ? » s'affiche à l'ouverture de prisme, s'il y a plusieurs profils." } }
        }
    }

    private func tile<V: View>(_ av: V, _ name: String, _ sub: String) -> some View {
        VStack(spacing: 10) {
            av
            Text(name).font(P.font(28, .bold)).lineLimit(1)
            SubLabel(text: sub).font(P.font(23)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
        }
        .frame(width: 195).padding(.vertical, 18)
    }

    private func sub(_ p: Profile) -> String {
        if p.id == ps.current { return "actif" }
        if p.kids { return "enfant" }
        if let a = p.maxAge { return "lock|" + Profile.ageLabel(a) }
        return " "
    }
}

/// Fiche d'un profil (simulateur « profDet ») : lignes avec la valeur à droite, choix dépliés sous la ligne.
struct ProfileDetail: View {
    let p: Profile
    @Binding var desc: String
    let back: () -> Void
    @ObservedObject var ps = ProfileStore.shared
    @State private var open: String?
    @State private var confirm: String?
    @State private var name = ""
    @FocusState private var focus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                ProfileAvatar(p: p, size: 108)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROFILS ›").font(P.font(23, .bold)).tracking(3.2).foregroundStyle(.white.opacity(0.6))
                    (Text(p.name).font(P.font(49, .bold)) + Text(p.id == ps.current ? " · actif" : "").font(P.font(26)).foregroundColor(.white.opacity(0.75)))
                }
            }
            .padding(.bottom, 14)
            VStack(spacing: 4) { rows }.padding(.vertical, 6).padding(.horizontal, 8)
        }
        .onExitCommand { if open != nil { open = nil } else { back() } }
        .defaultFocus($focus, "name")
        .onAppear { name = p.name }
    }

    @ViewBuilder private var rows: some View {
        // Nom : clavier de l'Apple TV
        HStack {
            Text("Nom").font(P.font(32, .semibold))
            Spacer()
            TextField("Nom", text: $name).font(P.font(28)).multilineTextAlignment(.trailing).frame(width: 420)
                .focused($focus, equals: "name")
                .onSubmit { var x = p; let n = name.trimmingCharacters(in: .whitespaces); if !n.isEmpty { x.name = String(n.prefix(20)); ps.update(x) } }
        }
        .padding(.horizontal, 24).frame(height: 108)
        .onChange(of: focus) { _, f in if f == "name" { desc = "OK pour changer le nom avec le clavier à l'écran (ou celui de l'iPhone)." } }

        row("pcol", "Couleur", AnyView(HStack(spacing: 10) { Circle().fill(p.tint).frame(width: 22, height: 22); Text(open == "pcol" ? "⌄" : "›") }),
            "Aide à reconnaître le profil d'un coup d'œil sur l'écran « Qui regarde ? ».")
        if open == "pcol" { options(Array(Profile.colors.indices), cur: p.color, key: "pcol") { i in AnyView(HStack(spacing: 14) { Circle().fill(Profile.colors[i]).frame(width: 26, height: 26); Text("Couleur \(i + 1)") }) } set: { var x = p; x.color = $0; ps.update(x) } }

        row("pemo", "Image", AnyView(HStack(spacing: 10) { if let ic = p.icon { Image(systemName: ic) } else { Text("Initiale") }; Text(open == "pemo" ? "⌄" : "›") }),
            "L'initiale du prénom ou une petite icône dessinée.")
        if open == "pemo" { options(Array(Profile.icons.indices), cur: Profile.icons.firstIndex(of: p.icon) ?? 0, key: "pemo") { i in AnyView(HStack(spacing: 14) { if let ic = Profile.icons[i] { Image(systemName: ic).frame(width: 34) ; Text(iconName(ic)) } else { Text("Initiale") } }) } set: { var x = p; x.icon = Profile.icons[$0]; ps.update(x) } }

        toggle("pkids", "Profil enfant", p.kids, "Limite « Tous publics » : seuls l'animation, le familial et les programmes jeunesse restent (genres TMDB).") { var x = p; x.kids.toggle(); ps.update(x) }

        row("page", "Limite d'âge", AnyView(Text(Profile.ageLabel(p.maxAge) + (open == "page" ? " ⌄" : " ›"))),
            "Les films et séries classés au-dessus de la limite (classification française TMDB) sont cachés. Un titre sans classification connue reste visible.")
        if open == "page" { options(Array(Profile.ages.indices), cur: Profile.ages.firstIndex(of: p.maxAge) ?? 0, key: "page") { i in AnyView(Text(Profile.ageLabel(Profile.ages[i]))) } set: { var x = p; x.maxAge = Profile.ages[$0]; ps.update(x) } }

        row("pbed", "Heure du coucher", AnyView(Text(bedText(p.bed) + (open == "pbed" ? " ⌄" : " ›"))),
            "Sert au son de nuit automatique, à l'arrêt au coucher et aux conseils « Ce soir ».")
        if open == "pbed" { options(Array(Profile.beds.indices), cur: Profile.beds.firstIndex(of: p.bed) ?? 2, key: "pbed") { i in AnyView(Text(bedText(Profile.beds[i]))) } set: { var x = p; x.bed = Profile.beds[$0]; ps.update(x) } }

        row("plang", "Version préférée", AnyView(Text((Profile.langNames[p.lang] ?? p.lang) + (open == "plang" ? " ⌄" : " ›"))),
            "Chaque profil a sa langue : VF pour l'un, VOSTFR pour l'autre. La version choisie automatiquement sur les fiches en tient compte.")
        if open == "plang" { options(Array(Profile.langs.indices), cur: Profile.langs.firstIndex(of: p.lang) ?? 0, key: "plang") { i in AnyView(Text(Profile.langNames[Profile.langs[i]] ?? "")) } set: { var x = p; x.lang = Profile.langs[$0]; ps.update(x) } }

        row("pst", "Sous-titres", AnyView(Text(Profile.subNames[min(2, p.subs)] + (open == "pst" ? " ⌄" : " ›"))),
            "Remplace le réglage général pour ce profil seulement (appliqué dans le lecteur).")
        if open == "pst" { options([0, 1, 2], cur: p.subs, key: "pst") { i in AnyView(Text(Profile.subNames[i])) } set: { var x = p; x.subs = $0; ps.update(x) } }

        action("puse", "Utiliser ce profil maintenant", p.id == ps.current ? "profil actif" : "Utiliser ›",
               "Change de profil sans repasser par l'écran « Qui regarde ? ».") { if p.id != ps.current { ps.use(p.id) } }
        let st = ps.stats(p.id)
        action("phist", "Effacer l'historique de ce profil", confirm == "hist" ? "OK encore pour confirmer" : "\(st.seen) vus · \(st.hist) dans l'historique ›",
               "Garde la liste et les réglages, remet à zéro ce qui a été regardé.", danger: confirm == "hist") {
            if confirm == "hist" { ps.clearHistory(p.id); confirm = nil } else { confirm = "hist" }
        }
        if p.id != "p1" && ps.profiles.count > 1 {
            action("pdel", "Supprimer ce profil", confirm == "del" ? "OK encore pour confirmer" : "›",
                   "Supprime le profil, sa liste et sa progression. Le profil de Steven, qui porte les données d'origine, ne peut pas être supprimé.", red: true, danger: confirm == "del") {
                if confirm == "del" { ps.remove(p.id); back() } else { confirm = "del" }
            }
        }
    }

    private func row(_ key: String, _ title: String, _ value: AnyView, _ d: String) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { open = open == key ? nil : key }; confirm = nil } label: {
            SettingLine(title: title, valueView: value)
        }
        .buttonStyle(SettingRowStyle())
        .focused($focus, equals: key)
        .onChange(of: focus) { _, f in if f == key { desc = d } }
    }

    private func toggle(_ key: String, _ title: String, _ on: Bool, _ d: String, _ act: @escaping () -> Void) -> some View {
        Button { act(); confirm = nil } label: { SettingLine(title: title, valueView: AnyView(Switch(on: on))) }
            .buttonStyle(SettingRowStyle())
            .focused($focus, equals: key)
            .onChange(of: focus) { _, f in if f == key { desc = d } }
    }

    private func action(_ key: String, _ title: String, _ value: String, _ d: String, red: Bool = false, danger: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            SettingLine(title: title, valueView: AnyView(Text(value).fontWeight(danger ? .bold : .regular).foregroundStyle(danger ? Color(red: 1, green: 0.42, blue: 0.42) : Color.primary)), red: red)
        }
        .buttonStyle(SettingRowStyle())
        .focused($focus, equals: key)
        .onChange(of: focus) { _, f in if f == key { desc = d } else if f != nil && confirm != nil && f != key && (key == "phist" || key == "pdel") && confirm == (key == "phist" ? "hist" : "del") { confirm = nil } }
    }

    private func options(_ idx: [Int], cur: Int, key: String, label: @escaping (Int) -> AnyView, set: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 2) {
            ForEach(idx, id: \.self) { i in
                Button { set(i); withAnimation(.easeOut(duration: 0.2)) { open = nil }; let k = key; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = k } } label: {
                    HStack { label(i).font(P.font(27)); Spacer(); if i == cur { Image(systemName: "checkmark").font(P.font(24, .bold)) } }
                        .padding(.horizontal, 30).frame(height: 76)
                }
                .buttonStyle(SettingRowStyle(radius: 18))
                .focused($focus, equals: key + "-\(i)")
            }
        }
        .padding(.leading, 40)
        .onAppear { let k = key; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = k + "-\(cur)" } }
    }

    private func bedText(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
    private func iconName(_ ic: String) -> String {
        ["film": "Cinéma", "popcorn": "Pop-corn", "paperplane": "Avion en papier", "soccerball": "Ballon", "gamecontroller": "Manette", "moon": "Lune", "cat": "Chat"][ic] ?? ic
    }
}

/// Ligne de réglage du simulateur (« it ») : intitulé à gauche 32 pt, valeur à droite 28 pt.
struct SettingLine: View {
    let title: String
    var value: String? = nil
    var valueView: AnyView? = nil
    var red = false
    var body: some View {
        HStack {
            Text(title).font(P.font(32, .semibold)).foregroundStyle(red ? Color(red: 1, green: 0.42, blue: 0.42) : Color.primary)
            Spacer(minLength: 20)
            Group { if let valueView { valueView } else if let value { Text(value) } }.font(P.font(28)).opacity(0.7).lineLimit(1)
        }
        .padding(.horizontal, 24).frame(height: 108)
    }
}

struct SettingRowStyle: ButtonStyle {
    var radius: CGFloat = 22
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, radius: radius) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let radius: CGFloat
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white).environment(\.colorScheme, f ? .light : .dark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(f ? Color.white : Color.clear))
                .scaleEffect(f ? 1.015 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 18, y: 10)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// Interrupteur du simulateur (« sw ») : vert quand il est actif.
struct Switch: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.gray.opacity(0.45)).frame(width: 75, height: 45)
            Circle().fill(.white).frame(width: 37, height: 37).padding(4)
        }
        .animation(.easeOut(duration: 0.15), value: on)
    }
}

/// Tuile ronde d'un profil : la pastille grandit et prend un liseré blanc à la sélection.
struct AvatarTileStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.white.opacity(f ? 0.12 : 0)))
                .scaleEffect(f ? 1.08 : (c.isPressed ? 0.97 : 1))
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

// MARK: Pastille du profil (barre du haut, fiche film)

/// Pastille de la barre du haut (simulateur « whotab ») : OK ouvre « Qui regarde ? ».
struct TopBarProfile: View {
    @ObservedObject var ps = ProfileStore.shared
    var body: some View {
        Button { ProfileUI.shared.picker = true } label: { ProfileAvatar(p: ps.me, size: 45).frame(width: 30) }
            .buttonStyle(TabPillStyle(selected: false))
            .accessibilityLabel("Profil " + ps.me.name)
    }
}

/// Pastille de la fiche film (simulateur « who ») : avatar, prénom, ▾.
struct ProfileChip: View {
    @ObservedObject var ps = ProfileStore.shared
    var body: some View {
        Button { ProfileUI.shared.picker = true } label: {
            HStack(spacing: 14) {
                ProfileAvatar(p: ps.me, size: 48)
                Text(ps.me.name).font(P.font(28, .semibold)).lineLimit(1)
                Text("▾").font(P.font(21, .semibold)).opacity(0.7)
            }
            .padding(.leading, 10).padding(.trailing, 22).frame(height: 66)
        }
        .buttonStyle(ChipGlassStyle())
    }
}

struct ChipGlassStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .background(f ? Color.white : Color(red: 10 / 255, green: 11 / 255, blue: 15 / 255).opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(f ? 0 : 0.2), lineWidth: 1.5))
                .scaleEffect(f ? 1.06 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

// MARK: Fenêtre « Qui regarde ? · Choisis un profil » (simulateur « fxwho »)

struct ProfilePickerModal: View {
    @ObservedObject var ps = ProfileStore.shared
    let close: () -> Void
    let manage: () -> Void
    @FocusState private var focus: String?

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.9).ignoresSafeArea()
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("QUI REGARDE ?").font(P.font(21, .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
                Text("Choisis un profil").font(P.font(42, .bold)).padding(.bottom, 14)
                ForEach(ps.profiles) { p in
                    let st = ps.stats(p.id)
                    Button { ps.use(p.id); close() } label: {
                        pickRow(AnyView(ProfileAvatar(p: p, size: 74)), p.name,
                                (p.limit != nil ? "lock|" + Profile.ageLabel(p.limit) + " · " : "") + "\(st.seen) film\(st.seen > 1 ? "s" : "") vu\(st.seen > 1 ? "s" : "") · \(st.hist) dans l'historique",
                                radio: p.id == ps.current)
                    }
                    .buttonStyle(PickRowStyle())
                    .focused($focus, equals: p.id)
                    .contextMenu { Button("Modifier ce profil") { ProfileUI.shared.editProfile = p.id; manage() } }
                }
                Button { ps.use(ProfileStore.guestID); close() } label: {
                    pickRow(AnyView(ZStack { Circle().fill(Color(hex: "#64748b")); Image(systemName: "person").font(.system(size: 32)) }.frame(width: 74, height: 74)),
                            "Invité", "Regarder sans rien changer : ni historique, ni reprises", radio: ps.isGuest)
                }
                .buttonStyle(PickRowStyle()).focused($focus, equals: "guest")
                if ps.profiles.count < 6 {
                    Button { if let p = ps.add() { ProfileUI.shared.editProfile = p.id; manage() } } label: {
                        pickRow(AnyView(ZStack { Circle().strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [7, 6])).foregroundStyle(.white.opacity(0.45)); Image(systemName: "plus").font(.system(size: 30, weight: .light)) }.frame(width: 64, height: 64).frame(width: 74)),
                                "Ajouter un profil", "Nom, couleur, langue, limite d'âge…", radio: nil)
                    }
                    .buttonStyle(PickRowStyle()).focused($focus, equals: "add")
                }
                Button(action: manage) { Label("Gérer les profils", systemImage: "gearshape").font(P.font(28, .semibold)).padding(.horizontal, 30).frame(height: 64) }
                    .buttonStyle(ChipGlassStyle()).padding(.top, 12)
                Text("Maintiens le clic sur un profil pour le modifier").font(P.font(21)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .padding(46)
            .frame(width: 960, alignment: .leading)
            .background(Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.8), in: RoundedRectangle(cornerRadius: 46, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 60, y: 30)
            .focusSection()
        }
        .onAppear { let c = ps.isGuest ? "guest" : ps.current; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = c } }
        .onExitCommand { close() }
    }

    private func pickRow(_ av: AnyView, _ name: String, _ sub: String, radio: Bool?) -> some View {
        HStack(spacing: 22) {
            av
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(P.font(28, .bold)).lineLimit(1)
                SubLabel(text: sub).font(P.font(22)).opacity(0.7).lineLimit(1)
            }
            Spacer(minLength: 10)
            if let radio {
                ZStack {
                    Circle().strokeBorder(lineWidth: 3).frame(width: 40, height: 40)
                    if radio { Circle().frame(width: 22, height: 22) }
                }
            }
        }
        .padding(.horizontal, 20).frame(height: 110)
    }
}

struct PickRowStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(f ? Color.white : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(f ? 1.02 : 1).animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

// MARK: Écran « Qui regarde ? » à l'ouverture (simulateur « wa »)

struct WhoIsWatchingScreen: View {
    @ObservedObject var ps = ProfileStore.shared
    @ObservedObject var watch = WatchStore.shared
    let done: (_ resume: MediaItem?) -> Void
    let manage: () -> Void
    @State private var guess = ""
    @State private var countdown = 5
    @State private var moved = false
    @State private var resume: [String: (MediaItem, WatchStore.Entry)] = [:]
    @State private var news: [String: [MediaItem]] = [:]
    @FocusState private var focus: String?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var focusedID: String { focus ?? guess }
    private var bgColor: Color { ps.profile(focusedID)?.tint ?? Color(hex: "#334455") }

    var body: some View {
        ZStack {
            Color(red: 11 / 255, green: 13 / 255, blue: 19 / 255)
            RadialGradient(colors: [bgColor.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 900)
                .animation(.easeInOut(duration: 0.5), value: focusedID)
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Text(!moved && countdown > 0 ? "\(hello) \(ps.profile(guess)?.name ?? "") ?" : "Qui regarde ?").font(P.font(72, .bold))
                    Text(!moved && countdown > 0 ? "prisme t'ouvre ton profil dans \(countdown) s · choisis-en un autre si ce n'est pas toi"
                         : "OK pour choisir · ▶︎ pour reprendre directement · maintiens pour modifier").font(P.font(28)).foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, 150)
                HStack(alignment: .top, spacing: 80) {
                    ForEach(ps.profiles) { p in
                        Button { choose(p.id, play: false) } label: { person(p) }
                            .buttonStyle(WhoStyle())
                            .focused($focus, equals: p.id)
                            .contextMenu { Button("Modifier ce profil") { ps.use(p.id); ProfileUI.shared.editProfile = p.id; manage() } }
                            .onPlayPauseCommand { choose(p.id, play: true) }
                    }
                    Button { choose(ProfileStore.guestID, play: false) } label: {
                        whoItem(AnyView(ZStack { Circle().fill(Color(hex: "#64748b")); Image(systemName: "person").font(.system(size: 76, weight: .regular)) }), "Invité", "sans historique")
                    }.buttonStyle(WhoStyle()).focused($focus, equals: ProfileStore.guestID)
                    if ps.profiles.count < 6 {
                        Button { if let p = ps.add() { ps.use(p.id); ProfileUI.shared.editProfile = p.id; manage() } } label: {
                            whoItem(AnyView(ZStack { Circle().fill(Color.white.opacity(0.05)); Circle().strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 8])).foregroundStyle(.white.opacity(0.4)); Image(systemName: "plus").font(.system(size: 80, weight: .ultraLight)) }), "Ajouter", "nom au clavier ou sur l'iPhone")
                        }.buttonStyle(WhoStyle()).focused($focus, equals: "add")
                    }
                }
                .padding(.top, 80)
                .focusSection()
                card.frame(height: 170).padding(.top, 60)
                Button(action: manage) { Text("Gérer les profils").font(P.font(30, .semibold)).padding(.horizontal, 36).frame(height: 78) }
                    .buttonStyle(ChipGlassStyle()).padding(.top, 10)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guess = ps.guess()
            let g = guess
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = g }
        }
        .task { await loadCards() }
        // Retour : on garde le profil proposé (sans quitter prisme)
        .onExitCommand { choose(guess.isEmpty ? ps.current : guess, play: false) }
        .onReceive(timer) { _ in
            guard !moved else { return }
            if countdown > 0 { countdown -= 1 }
            if countdown == 0 { moved = true; choose(guess, play: false) }
        }
        .onChange(of: focus) { _, f in if let f, f != guess { moved = true } }
    }

    private var hello: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 5 && h < 12 ? "Bonjour" : h < 18 && h >= 12 ? "Bon après-midi" : "Bonsoir"
    }

    private func person(_ p: Profile) -> some View {
        let n = news[p.id]?.count ?? 0
        return whoItem(AnyView(ZStack(alignment: .topTrailing) {
            ProfileAvatar(p: p, size: 190)
            if n > 0 {
                Text("\(n)").font(P.font(28, .bold)).frame(width: 52, height: 52).background(Circle().fill(Color(red: 0.94, green: 0.27, blue: 0.27)))
                    .overlay(Circle().stroke(Color(red: 11 / 255, green: 13 / 255, blue: 19 / 255), lineWidth: 4)).offset(x: 6, y: -6)
            }
            if !moved && countdown > 0 && p.id == guess {
                Circle().trim(from: 0, to: CGFloat(countdown) / 5).stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 226, height: 226).offset(x: 18, y: -18)
                    .animation(.linear(duration: 1), value: countdown)
            }
        }), p.name, p.limit != nil ? "lock|" + Profile.ageLabel(p.limit) : " ")
    }

    private func whoItem(_ av: AnyView, _ name: String, _ sub: String) -> some View {
        VStack(spacing: 16) {
            av.frame(width: 190, height: 190)
            Text(name).font(P.font(32, .bold)).lineLimit(1)
            SubLabel(text: sub).font(P.font(22)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center).lineLimit(2).frame(width: 230)
        }
        .frame(width: 230)
    }

    /// Carte « Steven regardait Lupin · 18 % vu » (vraies données du profil sélectionné).
    @ViewBuilder private var card: some View {
        let id = focusedID
        if id == ProfileStore.guestID {
            cardBox(nil, "MODE INVITÉ", "Regarder sans rien changer", "Ni historique, ni reprises, ni Ma liste touchés · effacé en changeant de profil", nil, nil)
        } else if let p = ps.profile(id) {
            let r = resume[id], nw = news[id] ?? []
            if r == nil && nw.isEmpty {
                cardBox(nil, p.name.uppercased(), "Rien en cours", "OK : ouvrir son accueil", nil, nil)
            } else {
                cardBox(r?.0, (r != nil ? p.name + " regardait" : p.name).uppercased(), r?.0.displayTitle ?? "—",
                        r.map { ($0.0.kind == .series ? "Série" : "Film") + " · \(Int(($0.1.pos / max(1, $0.1.dur)) * 100)) % vu" } ?? "",
                        nw.isEmpty ? nil : "\(nw.count) nouveauté\(nw.count > 1 ? "s" : "") dans sa liste : " + nw.prefix(2).map(\.displayTitle).joined(separator: ", "),
                        r.map { $0.1.pos / max(1, $0.1.dur) })
            }
        }
    }

    private func cardBox(_ it: MediaItem?, _ k: String, _ t: String, _ s: String, _ n: String?, _ pct: Double?) -> some View {
        HStack(spacing: 26) {
            if let it {
                ZStack(alignment: .bottomLeading) {
                    ArtView(backdrop: it.backdropURL, poster: it.posterURL, maxPixel: 600, fill: true).frame(width: 198, height: 111).clipped()
                    if let pct { Rectangle().fill(.white).frame(width: 198 * pct, height: 5) }
                }.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(k).font(P.font(19, .heavy)).tracking(2.8).foregroundStyle(.white.opacity(0.6))
                Text(t).font(P.font(30, .bold)).lineLimit(1)
                Text(s).font(P.font(22)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                if let n { Text(n).font(P.font(22)).foregroundStyle(P.gold).lineLimit(1) }
            }
            Spacer(minLength: 10)
            if it != nil {
                VStack(alignment: .trailing, spacing: 4) { Text("▶︎ reprendre tout de suite"); Text("OK : ouvrir son accueil") }.font(P.font(21)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(20).frame(width: 1006, alignment: .leading)
        .background(Color(red: 15 / 255, green: 17 / 255, blue: 24 / 255).opacity(0.85), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1.5))
    }

    private func choose(_ id: String, play: Bool) {
        moved = true
        ps.use(id)
        done(play ? resume[id]?.0 : nil)
    }

    /// Reprise et nouveautés de Ma liste de chaque profil (ajoutées chez le fournisseur ces 7 derniers jours).
    private func loadCards() async {
        let week = Int(Date().timeIntervalSince1970) - 7 * 86400
        for p in ps.profiles {
            let e = WatchStore.entries(for: p.id)
            if let last = e.values.filter({ $0.dur > 0 && $0.pos > 30 && $0.pos / $0.dur < 0.92 && !$0.item.hasPrefix("replay:") }).max(by: { $0.at < $1.at }),
               let it = await MediaStore.items(ids: [last.item]).first { resume[p.id] = (it, last) }
            let favs = UserDefaults.standard.stringArray(forKey: ProfileStore.storageKey("prisme.media.favs", for: p.id)) ?? []
            if !favs.isEmpty { news[p.id] = await MediaStore.items(ids: favs).filter { $0.added > week } }
        }
    }
}

struct WhoStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(.white)
                .overlay(alignment: .top) { Circle().stroke(Color.white, lineWidth: f ? 8 : 0).frame(width: 206, height: 206).offset(y: -8) }
                .scaleEffect(f ? 1.08 : (c.isPressed ? 0.96 : 1))
                .shadow(color: .black.opacity(f ? 0.5 : 0), radius: 24, y: 12)
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

/// Petit texte sous un profil ; « lock|… » affiche le cadenas dessiné (pas d'emoji).
struct SubLabel: View {
    let text: String
    var body: some View {
        if text.hasPrefix("lock|") { Text(Image(systemName: "lock")) + Text(" " + text.dropFirst(5)) } else { Text(text) }
    }
}
