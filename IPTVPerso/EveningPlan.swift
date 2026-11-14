import SwiftUI

// MARK: - « Ce soir ? » sur la fiche film (simulateur : bInfo, planHtml, planMsg, whyc, « En 2 soirées »)
//
// Tout est calculé avec de vraies données : la durée du film (TMDB, sinon le fournisseur), l'heure du coucher du
// PROFIL ACTIF et son historique à lui (jamais celui d'un autre profil). Une donnée absente = rien n'est affiché.

struct EveningPlan {
    /// minutes depuis minuit (peuvent dépasser 1440 : après minuit)
    let now: Int, end: Int, bed: Int
    var late: Int { end - bed }

    /// `remaining` en minutes ; nil si la durée est inconnue
    static func make(remaining: Int?, bed: Int, at date: Date = Date()) -> EveningPlan? {
        guard let r = remaining, r > 0 else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let n = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        // entre minuit et 5 h, le coucher « de ce soir » est déjà passé : on le ramène sur la même journée (comme le simulateur)
        // (et un coucher noté « 00:38 » au lieu de « 24:38 » est ramené après minuit quand il est encore la soirée)
        // (coucher 23:00 vu à 00:18 → hier 23:00, soit -60 ; coucher 01:00 noté 25:00 → 60 ; un coucher noté « 00:38 » au lieu
        //  de « 24:38 » pendant la soirée est ramené après minuit)
        let b = n < 300 ? (bed < 300 ? bed : bed - 1440) : (bed < 300 ? bed + 1440 : bed)
        return EveningPlan(now: n, end: n + r, bed: b)
    }

    static func hm(_ m: Int) -> String { let x = ((m % 1440) + 1440) % 1440; return String(format: "%02d:%02d", x / 60, x % 60) }
    static func dur(_ m: Int) -> String { m >= 60 ? "\(m / 60) h " + String(format: "%02d", m % 60) : "\(m) min" }

    /// planMsg du simulateur
    var message: (bold: String, rest: String) {
        let b = "Fin à " + EveningPlan.hm(end)
        if late > 10 { return (b, " · " + EveningPlan.dur(late) + " après ton coucher") }
        if late > -30 { return (b, " · juste avant ton coucher") }
        return (b, " · il te restera " + EveningPlan.dur(-late))
    }
    /// « En 2 soirées » : quand le film finit plus de 10 min après le coucher
    var needSplit: Bool { late > 10 }
}

/// Frise « TA SOIRÉE » : axe, barre du film (maintenant → fin), trait bleu du coucher, libellés.
struct EveningTimeline: View {
    let p: EveningPlan
    var body: some View {
        let t0 = Double(min(p.now, p.bed) - 15), t1 = Double(max(p.end, p.bed) + 30)
        let X: (Int) -> Double = { (Double($0) - t0) / (t1 - t0) }
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.white.opacity(0.14)).frame(height: 11).offset(y: 26)
                Capsule().fill(LinearGradient(colors: [P.gold, Color(red: 1, green: 0.54, blue: 0.24)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(14, w * (X(p.end) - X(p.now))), height: 26).offset(x: w * X(p.now), y: 19)
                Rectangle().fill(Color(red: 0.49, green: 0.83, blue: 0.99)).frame(width: 4, height: 60).offset(x: w * X(p.bed) - 2, y: 4)
                // film court par rapport à la soirée : « maintenant » et « fin » se chevauchaient → un seul libellé
                if X(p.end) - X(p.now) < 0.22 {
                    label("maintenant → fin " + EveningPlan.hm(p.end), X(p.now), w, color: .white.opacity(0.62))
                } else {
                    label("maintenant", X(p.now), w, color: .white.opacity(0.62))
                    label("fin " + EveningPlan.hm(p.end), X(p.end), w, color: .white.opacity(0.62))
                }
                if abs(X(p.bed) - X(p.now)) > 0.14 && abs(X(p.bed) - X(p.end)) > 0.14 {
                    label("☾ " + EveningPlan.hm(p.bed), X(p.bed), w, color: Color(red: 0.49, green: 0.83, blue: 0.99))
                }
            }
        }
        .frame(height: 84)
    }

    /// libellé centré sous sa position ; collé à gauche au début, à droite à la fin (l0 / l1 du simulateur)
    private func label(_ t: String, _ x: Double, _ w: CGFloat, color: Color) -> some View {
        let box: CGFloat = 320
        let al: Alignment = x < 0.08 ? .leading : x > 0.92 ? .trailing : .center
        let dx: CGFloat = x < 0.08 ? w * x : x > 0.92 ? w * x - box : w * x - box / 2
        return Text(t).font(P.font(21)).foregroundStyle(color).lineLimit(1).frame(width: box, alignment: al).offset(x: dx, y: 54)
    }
}

/// Puce « pourquoi ce film » (simulateur whyc : la première raison qui s'applique, comme le simulateur).
struct WhyReason: Equatable { let icon: String; let text: String }

enum WhyBuilder {
    /// Raisons tirées de l'historique du profil actif seulement.
    @MainActor
    static func reasons(fiche: Fiche?, rating: Double, item: MediaItem, pids: [String]) async -> [WhyReason] {
        var out: [WhyReason] = []
        let watch = WatchStore.shared
        // films vus en entier (≥ 85 %) par ce profil
        let seenIDs = watch.entries.values.filter { $0.item.hasPrefix("film:") && $0.dur > 0 && $0.pos / $0.dur >= 0.85 && $0.item != item.id }.map(\.item)
        let seen = seenIDs.isEmpty ? [] : await MediaStore.items(ids: Array(Set(seenIDs)))
        if let f = fiche {
            // « Suite de Dune » : un film précédent de la même saga a été vu
            if f.coll > 0, let mate = seen.filter({ ($0.fiche?.coll ?? 0) == f.coll && ($0.fiche?.year ?? 0) <= f.year && $0.fiche?.tmdb != f.tmdb })
                .max(by: { ($0.fiche?.year ?? 0) < ($1.fiche?.year ?? 0) }) {
                out.append(WhyReason(icon: "puzzlepiece", text: "Suite de " + (mate.displayTitle.components(separatedBy: " :").first ?? mate.displayTitle)))
            }
            // « Avec Zendaya » : un acteur de ce film joue dans un film fini par ce profil
            let names = Set(f.cast.prefix(8).map(\.n))
            if let a = f.cast.prefix(8).first(where: { c in seen.contains { s in s.fiche?.tmdb != f.tmdb && (s.fiche?.cast.prefix(12).contains { $0.n == c.n } ?? false) } }), names.contains(a.n) {
                out.append(WhyReason(icon: "star", text: "Avec " + a.n))
            }
            // « Ton genre préféré » : au moins 3 films finis, et ce genre dans plus de 30 % d'entre eux
            let gs = seen.compactMap { $0.fiche?.genres }.map { $0.components(separatedBy: ", ") }
            if gs.count >= 3 {
                let mine = f.genres.components(separatedBy: ", ")
                if mine.contains(where: { g in Double(gs.filter { $0.contains(g) }.count) / Double(gs.count) > 0.3 }) {
                    out.append(WhyReason(icon: "sparkles", text: "Ton genre préféré"))
                }
            }
        }
        if rating >= 7.5 { out.append(WhyReason(icon: "trophy", text: "★ " + String(format: "%.1f", rating).replacingOccurrences(of: ".", with: ",") + " · " + ratingWord(rating))) }
        return out
    }
}

/// Coupures possibles pour « En 2 soirées ». L'app ne sait pas détecter les fins de scène : elle propose des points
/// approximatifs autour de la moitié du film. Pendant la lecture, si le fichier contient des chapitres, l'arrêt se
/// cale sur le début de chapitre le plus proche (± 10 min) ; sinon il a lieu à l'heure choisie.
enum SplitStore {
    static func cuts(_ minutes: Int) -> [Int] { [0.45, 0.5, 0.55].map { Int((Double(minutes) * $0).rounded()) } }
    private static var key: String { "prisme.split" }
    /// coupure choisie (en secondes) par film, pour le profil actif
    @MainActor static func get(_ id: String) -> Double? { (UserDefaults.standard.dictionary(forKey: ProfileStore.shared.key(key)) as? [String: Double])?[id] }
    @MainActor static func set(_ id: String, _ s: Double?) {
        var d = (UserDefaults.standard.dictionary(forKey: ProfileStore.shared.key(key)) as? [String: Double]) ?? [:]
        d[id] = s
        UserDefaults.standard.set(d, forKey: ProfileStore.shared.key(key))
    }
}

/// Fenêtre « EN 2 SOIRÉES » (simulateur fxsplit).
struct SplitModal: View {
    let title: String
    let minutes: Int
    let start: (Int) -> Void
    let close: () -> Void
    @State private var sel = 1
    @FocusState private var focus: Int?

    var body: some View {
        let C = SplitStore.cuts(minutes)
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let n = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.9).ignoresSafeArea()
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("EN 2 SOIRÉES").font(P.font(22, .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
                Text(title).font(P.font(54, .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Text("Choisis où t'arrêter ce soir. prisme s'arrête tout seul : au début du chapitre le plus proche si le film en a, sinon à l'heure choisie (prisme ne détecte pas les fins de scène). Ta place est gardée pour la deuxième soirée.")
                    .font(P.font(26)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 6)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.16)).frame(height: 10)
                        // repères verticaux comme le simulateur (le choisi en or, lumineux)
                        ForEach(C.indices, id: \.self) { i in
                            Capsule().fill(i == sel ? P.gold : Color.white.opacity(0.55)).frame(width: i == sel ? 9 : 6, height: 40)
                                .shadow(color: i == sel ? P.gold.opacity(0.7) : .clear, radius: 8)
                                .offset(x: g.size.width * CGFloat(C[i]) / CGFloat(max(1, minutes)) - (i == sel ? 4.5 : 3))
                        }
                    }
                }.frame(height: 42)
                HStack { Text("0"); Spacer(); Text(EveningPlan.dur(minutes)) }.font(P.font(21)).foregroundStyle(.white.opacity(0.6)).padding(.bottom, 8)
                ForEach(C.indices, id: \.self) { i in
                    Button { sel = i } label: {
                        HStack(spacing: 24) {
                            // bouton radio à gauche (simulateur)
                            ZStack {
                                Circle().stroke(.foreground, lineWidth: 3).opacity(0.55).frame(width: 40, height: 40)
                                if i == sel { Circle().fill(.foreground).frame(width: 20, height: 20) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Arrêt vers " + EveningPlan.dur(C[i]) + " · vers " + EveningPlan.hm(n + C[i])).font(P.font(30, .semibold))
                                Text((i == 1 ? "à la moitié" : i == 0 ? "un peu avant la moitié" : "un peu après la moitié") + " · partie 2 : " + EveningPlan.dur(minutes - C[i])).font(P.font(23)).opacity(0.7)
                            }
                            Spacer()
                        }.padding(.horizontal, 28).frame(height: 100)
                    }
                    .buttonStyle(SourceRowStyle())
                    .focused($focus, equals: i)
                }
                HStack(spacing: 16) {
                    Button { start(C[sel]) } label: { PlayLabel(title: "Lancer la partie 1") }.buttonStyle(FicheButtonStyle(prim: true)).focused($focus, equals: 99)
                    Button(action: close) { Text("Annuler").font(P.font(30, .semibold)) }.buttonStyle(FicheButtonStyle())
                }.padding(.top, 8)
            }
            .padding(50).frame(width: 1140, alignment: .leading)
            .background(Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.8), in: RoundedRectangle(cornerRadius: 46, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
            .focusSection()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = 1 } }
        .onExitCommand { close() }
    }
}
