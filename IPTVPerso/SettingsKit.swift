import SwiftUI

// MARK: - Lot 5 : réglages du simulateur (sa-*) — catalogue, lignes à choix qui s'ouvrent, point « modifié »,
// « Rétablir les réglages conseillés », recherche d'un réglage.
// Chaque réglage garde l'emplacement où l'appli le lisait déjà (aucune valeur existante n'est déplacée ni effacée) ;
// les nouveaux ont leur valeur conseillée par défaut.

struct PrefSpec: Identifiable {
    enum Where { case app, profile }
    let id: String
    let cat: String
    var group: String? = nil
    let title: String
    let desc: String
    var at: Where = .app
    /// clé de stockage : app → « prisme.pref.<key> » ; profil → clé du profil actif (ProfileStore.key)
    let key: String
    /// valeurs enregistrées et leur libellé ; un interrupteur a [false, true]
    let values: [AnyHashable]
    let labels: [String]
    let def: AnyHashable
    var rec: AnyHashable? = nil
    /// interrupteur (oui / non) ; une valeur à deux choix nommés (« Légères / HD ») reste une liste
    var asList = false
    var toggle: Bool { !asList && values.count == 2 && values.allSatisfy { type(of: $0.base) == Bool.self } }

    @MainActor var storageKey: String { at == .app ? "prisme.pref." + key : ProfileStore.shared.key(key) }
    @MainActor var current: AnyHashable {
        guard let o = UserDefaults.standard.object(forKey: storageKey) else { return def }
        // lit le type enregistré (Bool, nombre ou texte) dans le type des valeurs du réglage
        if def is Bool { return ((o as? NSNumber)?.boolValue ?? ((o as? String) == "true" || (o as? String) == "1")) as AnyHashable }
        if def is Int { return ((o as? NSNumber)?.intValue ?? Int((o as? String) ?? "") ?? (def as! Int)) as AnyHashable }
        if def is String { return ((o as? String) ?? def as! String) as AnyHashable }
        return def
    }
    @MainActor var index: Int { values.firstIndex(of: current) ?? values.firstIndex(of: def) ?? 0 }
    @MainActor var modified: Bool { current != def }
    @MainActor func set(_ v: AnyHashable) {
        UserDefaults.standard.set(v.base, forKey: storageKey)
        NotificationCenter.default.post(name: .prismePrefs, object: nil)
        DataCount.write("réglage : \(title) → \(labels[values.firstIndex(of: v) ?? 0])")
    }
    @MainActor func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: .prismePrefs, object: nil)
    }
}

/// État partagé de la page Réglages : liste ouverte, recherche.
@MainActor
final class PrefUI: ObservableObject {
    static let shared = PrefUI()
    @Published var open: String?
    /// ligne qui doit reprendre la sélection après un choix dans sa liste
    @Published var back: String?
    @Published var query = ""
    @Published var searching = false
}

@MainActor
enum PrefCatalog {
    static let tf: [AnyHashable] = [false, true]
    static let all: [PrefSpec] = [
        // Langues et sous-titres
        PrefSpec(id: "subsFR", cat: "lang", title: "Sous-titres français par défaut",
                 desc: "Pour les profils réglés sur « Comme le réglage général ». Un profil peut aussi dire « Toujours » ou « Jamais ».",
                 key: "subsFR", values: tf, labels: ["désactivé", "activé"], def: false),
        PrefSpec(id: "subsVO", cat: "lang", title: "Sous-titres français si seule la VO existe",
                 desc: "Plus besoin d'aller les chercher : ils s'activent tout seuls quand le film n'a pas de piste audio française.",
                 key: "subsVO", values: tf, labels: ["désactivé", "activé"], def: false),
        PrefSpec(id: "subSize", cat: "lang", title: "Taille des sous-titres", desc: "L'aperçu au-dessus montre le résultat tout de suite.",
                 key: "subSize", values: [0, 1, 2, 3], labels: AppPrefs.subSizes, def: 1),
        PrefSpec(id: "subBack", cat: "lang", title: "Fond des sous-titres", desc: "Le bandeau reste lisible même sur les scènes claires.",
                 key: "subBack", values: [0, 1, 2], labels: AppPrefs.subBacks, def: 0),
        PrefSpec(id: "subColor", cat: "lang", title: "Couleur des sous-titres", desc: "Le jaune se lit mieux sur les vieux films.",
                 key: "subColor", values: [0, 1], labels: AppPrefs.subColors, def: 0),
        // Lecture et image
        PrefSpec(id: "maxQ", cat: "play", title: "Qualité préférée",
                 desc: "Utile si ta connexion sature le soir : prisme prend la meilleure source sous cette limite (sauf si tu en as choisi une).",
                 key: "maxQ", values: [0, 1, 2], labels: AppPrefs.qualities, def: 0, rec: 0),
        PrefSpec(id: "hw", cat: "play", title: "Décodage matériel",
                 desc: "Laisse-le activé : l'Apple TV décode l'image elle-même. À couper seulement si une vidéo saccade ou s'affiche mal.",
                 key: "hw", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "rate", cat: "play", title: "Adapter la fréquence d'images",
                 desc: "L'Apple TV passe à la cadence du film (24, 25 ou 50 images par seconde) : les mouvements sont plus fluides. Il faut aussi activer « Adapter la fréquence » dans Réglages › Vidéo et audio de l'Apple TV.",
                 key: "matchRate", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "hdr", cat: "play", title: "Adapter la plage dynamique (HDR)",
                 desc: "L'Apple TV passe en HDR seulement quand le film l'est vraiment. Il faut aussi activer « Adapter la plage dynamique » dans les réglages de l'Apple TV.",
                 key: "matchHDR", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "night", cat: "play", title: "Son de nuit",
                 desc: "Adoucit les scènes fortes et met les voix en avant. Le lecteur peut le changer pour un film ou une chaîne.",
                 at: .profile, key: "prisme.player.night", values: ["auto", "on", "off"], labels: ["Auto après l'heure du coucher", "Toujours", "Jamais"], def: "auto"),
        PrefSpec(id: "bedstop", cat: "play", title: "Arrêt automatique au coucher",
                 desc: "Met en pause à la fin de la scène en cours quand ton heure de coucher arrive.",
                 at: .profile, key: "prisme.player.bedstop", values: tf, labels: ["désactivé", "activé"], def: false),
        PrefSpec(id: "skip", cat: "play", title: "Saut avant / arrière",
                 desc: "Pour les flèches gauche et droite pendant un film ou un épisode.",
                 key: "skip", values: [5, 10, 15, 30], labels: ["5 s", "10 s", "15 s", "30 s"], def: 10),
        // TV en direct
        PrefSpec(id: "openLive", cat: "live", title: "Ouvrir prisme sur la TV en direct",
                 desc: "Comme une box : à l'ouverture, la dernière chaîne regardée s'allume tout de suite.",
                 key: "openLive", values: tf, labels: ["désactivé", "activé"], def: false),
        PrefSpec(id: "lbest", cat: "live", title: "Toujours ouvrir la meilleure source",
                 desc: "Ne plus afficher le choix des sources : la meilleure copie de la chaîne démarre tout de suite.",
                 key: "lbest", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "startAsk", cat: "live", title: "Proposer de reprendre au début",
                 desc: "Quand le programme a commencé et que la chaîne a le replay, prisme propose de le voir depuis le début.",
                 key: "startAsk", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "bgv", cat: "live", title: "Aperçu vidéo en fond",
                 desc: "Utilise ta connexion · coupé automatiquement avant chaque lecture.",
                 key: "bgv", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "failover", cat: "live", title: "Bascule automatique si la source coupe",
                 desc: "Passe à la source suivante de la chaîne (autre qualité ou autre fournisseur) si l'image ne revient pas.",
                 key: "failover", values: [0, 5, 10, 20, 25], labels: ["désactivée", "5 secondes", "10 secondes", "20 secondes", "25 secondes"], def: 25),
        // Guide TV
        PrefSpec(id: "epgAuto", cat: "epg", title: "Téléchargement automatique au démarrage",
                 desc: "Le guide est retéléchargé à l'ouverture de prisme s'il a plus de 12 heures.",
                 key: "epgAuto", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "epgShift", cat: "epg", title: "Décalage horaire de l'EPG",
                 desc: "Si les programmes de ton fournisseur sont décalés d'une heure ou plus. Appliqué au prochain téléchargement du guide.",
                 key: "epgShift", values: [-3, -2, -1, 0, 1, 2, 3], labels: ["−3 h", "−2 h", "−1 h", "0 h", "+1 h", "+2 h", "+3 h"], def: 0),
        // Accueils et notes — fiches
        PrefSpec(id: "ficheMode", cat: "homes", group: "Fiches en arrière-plan", title: "Fiches TMDB",
                 desc: "Automatique : dès qu'un fournisseur est ajouté. La nuit seulement : entre 1 h et 7 h. Jamais : une fiche arrive quand tu l'ouvres.",
                 key: "ficheMode", values: [0, 2, 1], labels: ["Automatique", "La nuit seulement", "Jamais"], def: 0),
        PrefSpec(id: "ficheAfter", cat: "homes", group: "Fiches en arrière-plan", title: "Après le premier passage",
                 desc: "Seulement les nouveautés : les fois suivantes, prisme ne télécharge que les films et séries arrivés chez le fournisseur.",
                 key: "ficheAfter", values: [0, 1], labels: ["Seulement les nouveautés", "Tout revérifier chaque semaine"], def: 1),
        PrefSpec(id: "fichePlay", cat: "homes", group: "Fiches en arrière-plan", title: "Pendant la lecture",
                 desc: "Pour ne pas gêner la vidéo.", key: "fichePlay", values: [0, 1], labels: ["Mettre en pause", "Continuer lentement"], def: 0),
        PrefSpec(id: "posterHD", cat: "homes", group: "Fiches en arrière-plan", title: "Qualité des affiches",
                 desc: "Légères : ≈ 60 Mo pour 1 000 fiches. HD : ≈ 160 Mo pour 1 000 fiches.", key: "posterHD", values: tf, labels: ["Légères", "HD"], def: true, asList: true),
        // Accueil Films
        PrefSpec(id: "heroTrl", cat: "homes", group: "Accueil Films", title: "Bande-annonce quand tu restes sur la bannière",
                 desc: "La bande-annonce du titre de la grande affiche démarre si tu restes dessus, avec un compte à rebours ; une touche pour revenir.",
                 key: "heroTrl", values: [0, 5, 10, 15, 30], labels: ["désactivée", "après 5 s", "après 10 s", "après 15 s", "après 30 s"], def: 10),
        PrefSpec(id: "heroVol", cat: "homes", group: "Accueil Films", title: "Son de cette bande-annonce",
                 desc: "Le son de la bande-annonce de la grande affiche.", key: "heroVol", values: [0, 1, 2], labels: ["coupé", "faible", "normal"], def: 1),
        // Accueil Séries (par profil, déjà lus par le lecteur)
        PrefSpec(id: "recap", cat: "homes", group: "Accueil Séries", title: "Résumé automatique avant de reprendre",
                 desc: "Quand tu reprends une série laissée depuis longtemps, le résumé de 60 s passe d'abord (Retour pour le passer).",
                 at: .profile, key: "prisme.play.recap", values: [0, 7, 14], labels: ["jamais", "après 7 jours", "après 14 jours"], def: 7),
        PrefSpec(id: "autoskip", cat: "homes", group: "Accueil Séries", title: "Passer l'intro une fois, prisme s'en souvient",
                 desc: "Après deux épisodes où tu as passé l'intro, prisme la passe tout seul (un retour en arrière annule).",
                 at: .profile, key: "prisme.play.autoskip", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "spoiler", cat: "homes", group: "Accueil Séries", title: "Zéro spoiler (épisodes plus loin que le tien floutés)",
                 desc: "Titres, images et résumés des épisodes que tu n'as pas encore vus restent floutés.",
                 at: .profile, key: "prisme.play.spoiler", values: tf, labels: ["désactivé", "activé"], def: true),
        PrefSpec(id: "binge", cat: "homes", group: "Accueil Séries", title: "« Encore un ? » après plusieurs épisodes",
                 desc: "Une petite question après plusieurs épisodes d'affilée, avec l'heure de fin et ton heure de coucher.",
                 at: .profile, key: "prisme.play.binge", values: [0, 2, 3, 4], labels: ["jamais", "après 2 épisodes", "après 3 épisodes", "après 4 épisodes"], def: 3),
        // Notes
        PrefSpec(id: "showTMDB", cat: "homes", group: "Notes et métadonnées", title: "Afficher la note TMDB",
                 desc: "La note ★ des fiches, de la grande affiche et des rangées.", key: "showTMDB", values: tf, labels: ["masquée", "affichée"], def: true),
    ]

    static func spec(_ id: String) -> PrefSpec? { all.first { $0.id == id } }
    static func of(_ cat: String) -> [PrefSpec] { all.filter { $0.cat == cat } }
    static func modified(_ cat: String) -> Bool { of(cat).contains { $0.modified } }
    static func reset(_ cat: String) {
        for s in of(cat) { s.reset() }
        DataCount.write("réglages conseillés rétablis : " + cat)
    }
    /// recherche (sans accents, mots dans le désordre, une faute de frappe tolérée par mot)
    /// comme le simulateur : l'expression entière, au début d'un mot (mot entier si moins de 4 lettres) ;
    /// 2 points si elle est dans le titre ou le début de l'explication, 1 point ailleurs
    static func search(_ q: String) -> [(cat: String, spec: PrefSpec?, title: String, desc: String)] {
        let strip = { (t: String) in t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased() }
        let k = strip(q).trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty, let re = try? NSRegularExpression(pattern: "(^|[^a-z0-9])" + NSRegularExpression.escapedPattern(for: k) + (k.count < 4 ? "(?![a-z])" : "")) else { return [] }
        let hit = { (t: String) -> Bool in let x = strip(t); return re.firstMatch(in: x, range: NSRange(x.startIndex..., in: x)) != nil }
        var out: [(String, PrefSpec?, String, String, Int)] = []
        for s in all {
            let t = s.title + " " + s.desc + " " + s.labels.joined(separator: " ")
            let m = hit(String(t.prefix(60))) ? 2 : hit(t + " " + catName(s.cat)) ? 1 : 0
            if m > 0 { out.append((s.cat, s, s.title, s.desc, m)) }
        }
        for x in extraRows {
            let t = x.1 + " " + x.2
            let m = hit(String(t.prefix(60))) ? 2 : hit(t + " " + catName(x.0)) ? 1 : 0
            if m > 0 { out.append((x.0, nil, x.1, x.2, m)) }
        }
        // aucune correspondance exacte : on tolère une faute de frappe (« sous-titrse », « lnague »)
        if out.isEmpty {
            let Q = SearchText.keys(q)
            for s in all {
                let m = SearchText.score(Q, SearchText.keys(s.title + " " + s.desc + " " + catName(s.cat)))?.s ?? 0
                if m > 0 { out.append((s.cat, s, s.title, s.desc, 1)) }
            }
            for x in extraRows where (SearchText.score(Q, SearchText.keys(x.1 + " " + x.2 + " " + catName(x.0)))?.s ?? 0) > 0 {
                out.append((x.0, nil, x.1, x.2, 1))
            }
        }
        // tri stable : à score égal, l'ordre des rubriques
        return out.enumerated().sorted { ($0.element.4, -$0.offset) > ($1.element.4, -$1.offset) }.prefix(24).map { ($0.element.0, $0.element.1, $0.element.2, $0.element.3) }
    }
    /// lignes qui ne sont pas des choix (ouvrent leur rubrique)
    static let extraRows: [(String, String, String)] = [
        ("prof", "Profils", "nom, couleur, âge, heure du coucher, langue, code, goûts, qui regarde"),
        ("prov", "Ajouter un fournisseur", "iPhone, lien ou identifiants, abonnement, playlist, Xtream"),
        ("prov", "Journal des incidents", "coupures, erreurs, fournisseur en panne"),
        ("prov", "Tester mes serveurs", "temps de réponse, vitesse, connexion"),
        ("lang", "Version préférée", "langue, VF, VFF, VFQ, VOSTFR, doublage"),
        ("lang", "Sous-titres", "taille, fond, couleur, français, VO"),
        ("live", "Sources mémorisées", "chaîne, qualité, fournisseur, oublier"),
        ("live", "Chaînes masquées", "réafficher une chaîne"),
        ("epg", "Actualiser l'EPG maintenant", "guide TV, programmes"),
        ("homes", "Clé TMDB", "fiches, affiches, notes"),
        ("homes", "Rangées masquées", "accueil, rangée, rétablir"),
        ("par", "Contrôle parental", "code, verrouiller, limite d'âge, enfant"),
        ("data", "Sauvegarde", "iPhone, autre Apple TV, restaurer, cache, version, appareil"),
    ]
    static func catName(_ id: String) -> String {
        ["prof": "Profils", "prov": "Fournisseurs", "lang": "Langues et sous-titres", "play": "Lecture et image", "live": "TV en direct",
         "epg": "Guide TV", "homes": "Accueils et notes", "par": "Contrôle parental", "data": "Sauvegarde et mises à jour"][id] ?? id
    }
}

// MARK: - lignes

/// Ligne d'un réglage du catalogue : interrupteur, ou valeur « › » qui ouvre la liste des choix sous la ligne
/// (simulateur sa-opts : coche sur le choix actif, « conseillé » sur le choix recommandé).
struct SpecRow: View {
    let spec: PrefSpec
    var after: ((AnyHashable) -> Void)? = nil
    @ObservedObject var ui = PrefUI.shared
    @StateObject private var m = PrefsModel()
    var body: some View {
        let _ = m.tick
        let open = ui.open == spec.id
        VStack(alignment: .leading, spacing: 6) {
            if spec.toggle {
                PrefRow(title: spec.title, toggle: (spec.current as? Bool) ?? false, sub: spec.desc, modified: spec.modified, id: "sa-" + spec.id) {
                    let v = !((spec.current as? Bool) ?? false)
                    spec.set(v); after?(v)
                }
            } else {
                PrefRow(title: spec.title, value: spec.labels[spec.index], rec: spec.rec != nil && spec.current == spec.rec,
                        sub: spec.desc, icon: open ? "chevron.down" : "chevron.right", modified: spec.modified, id: "sa-" + spec.id,
                        regain: ui.back == spec.id) {
                    withAnimation(.easeOut(duration: 0.2)) { ui.open = open ? nil : spec.id }
                }
                if open {
                    ForEach(0..<spec.values.count, id: \.self) { i in
                        PrefOption(label: spec.labels[i], on: spec.index == i, rec: spec.rec == spec.values[i], sub: spec.desc, id: "sa-o-\(spec.id)-\(i)", grab: spec.index == i) {
                            spec.set(spec.values[i]); after?(spec.values[i])
                            ui.back = spec.id
                            withAnimation(.easeOut(duration: 0.2)) { ui.open = nil }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if ui.back == spec.id { ui.back = nil } }
                        }
                    }
                }
            }
        }
    }
}

/// Choix sous une ligne ouverte (simulateur .sa-op)
struct PrefOption: View {
    let label: String
    let on: Bool
    var rec = false
    var sub: String? = nil
    var id = ""
    var grab = false
    let action: () -> Void
    @FocusState private var f: Bool
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(label).font(P.font(24, .medium))   // simulateur .sa-op : 16 px
                if rec { SetRecBadge() }
                Spacer()
                if on { Image(systemName: "checkmark").font(P.font(20, .bold)) }
            }
            .padding(.leading, 54).padding(.trailing, 22).frame(height: 62)
        }
        .buttonStyle(PrefRowStyle())
        .focused($f)
        .accessibilityIdentifier(id)
        .onChange(of: f) { _, x in if x { PrefHelp.shared.text = sub } }
        .onAppear { if grab { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { f = true } } }
    }
}

/// pastille « conseillé » (simulateur .sa-rec)
struct SetRecBadge: View {
    var body: some View {
        Text("conseillé").font(P.font(15, .bold)).foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.5))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Color(red: 0.25, green: 0.85, blue: 0.5).opacity(0.16), in: Capsule())
    }
}

/// point « modifié » (simulateur .sa-mod : petit point bleu)
struct ModDot: View {
    var body: some View { Circle().fill(Color(red: 0.4, green: 0.6, blue: 1)).frame(width: 11, height: 11) }
}

/// Ligne des réglages (simulateur .sa-det .it) : fond transparent, blanche quand elle est sélectionnée.
struct PrefRowStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.foregroundStyle(f ? Color.black : P.ink).environment(\.colorScheme, f ? .light : .dark)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(f ? Color.white : Color.clear))
                .scaleEffect(f ? 1.01 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 14, y: 8)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

/// « Rétablir les réglages conseillés » (simulateur sa-btn, à droite du titre), seulement si un réglage a changé
struct ResetButton: View {
    let cat: String
    @StateObject private var m = PrefsModel()
    var body: some View {
        let _ = m.tick
        if PrefCatalog.modified(cat) {
            Button {
                PrefCatalog.reset(cat)
                AppToast.shared.say("Réglages conseillés rétablis")
            } label: { Text("Rétablir les réglages conseillés").font(P.font(19, .semibold)).padding(.horizontal, 18).padding(.vertical, 10) }
            .buttonStyle(PrefRowStyle())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1.5).allowsHitTesting(false))
            .accessibilityIdentifier("sa-reset")
        }
    }
}

/// petit intitulé de groupe (simulateur .sa-grp : 11 px, majuscules espacées)
struct PrefGroup: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(P.font(18, .bold)).tracking(2.5).foregroundStyle(P.faint).padding(.horizontal, 22).padding(.top, 14)
    }
}

// MARK: - recherche d'un réglage (clavier prisme du lot 3)

struct PrefSearchPanel: View {
    let openCat: (String) -> Void
    @ObservedObject var ui = PrefUI.shared
    @FocusState private var key: String?
    private static let rows: [[String]] = [["a", "b", "c", "d", "e", "f"], ["g", "h", "i", "j", "k", "l"], ["m", "n", "o", "p", "q", "r"],
                                           ["s", "t", "u", "v", "w", "x"], ["y", "z", "'", "-", "⌫", "␣"]]
    var body: some View {
        HStack(alignment: .top, spacing: 34) {
            VStack(spacing: 10) {
                ForEach(0..<Self.rows.count, id: \.self) { r in
                    HStack(spacing: 10) {
                        ForEach(Self.rows[r], id: \.self) { k in
                            Button { tap(k) } label: { Text(k == "␣" ? "espace" : k).font(P.font(k == "␣" ? 16 : 26, .semibold)).frame(width: 58, height: 54) }
                                .buttonStyle(KeyStyle()).focused($key, equals: k).accessibilityIdentifier("sk-" + k)
                        }
                    }
                }
            }
            .focusSection()
            VStack(alignment: .leading, spacing: 8) {
                let R = PrefCatalog.search(ui.query)
                Text(ui.query.isEmpty ? "Tape un mot : « son », « langue », « code »…" : "Résultats pour « \(ui.query) »").font(P.font(28, .bold))
                if !ui.query.isEmpty && R.isEmpty { Text("Aucun réglage ne correspond · essaie « son », « langue », « code »…").font(P.font(21)).foregroundStyle(P.dim) }
                ForEach(0..<R.count, id: \.self) { i in
                    let r = R[i]
                    if r.cat != (i > 0 ? R[i - 1].cat : "") { PrefGroup(title: PrefCatalog.catName(r.cat)) }
                    if let s = r.spec { SpecRow(spec: s) }
                    else { PrefRow(title: r.title, value: "Ouvrir", sub: r.desc, id: "sr-" + r.title) { openCat(r.cat) } }
                }
            }
            .focusSection()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { key = "a" } }
    }
    private func tap(_ k: String) {
        switch k {
        case "⌫": if !ui.query.isEmpty { ui.query.removeLast() }
        case "␣": ui.query += " "
        default: ui.query += k
        }
        DataCount.write("recherche réglage « \(ui.query) »")
    }
}

/// touche du clavier des réglages (même rendu que le clavier de la recherche)
struct KeyStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.foregroundStyle(f ? Color.black : .white)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.08)))
                .scaleEffect(f ? 1.08 : 1).animation(.easeOut(duration: 0.12), value: f)
        }
    }
}
