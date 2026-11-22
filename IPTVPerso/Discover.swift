import SwiftUI

// MARK: - Lot 4 : découverte — petites mémoires par profil, message global, bandeau « Cette nuit »
// Uniquement des ajouts (validés) : dernière ouverture et jour du bandeau, films « Préviens-moi », rappels TV,
// alertes déjà annoncées. Rien d'existant n'est modifié ni effacé.

/// Petit message en bas au centre (simulateur #toast), au-dessus de toutes les pages.
@MainActor
final class AppToast: ObservableObject {
    static let shared = AppToast()
    @Published var text: String?
    func say(_ t: String, seconds: Double = 3.5) {
        text = t
        DataCount.write("message : " + t)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in if self?.text == t { self?.text = nil } }
    }
}

struct AppToastView: View {
    @ObservedObject var t = AppToast.shared
    var body: some View {
        ZStack {
            if let s = t.text {
                Text(s).font(P.font(27, .medium)).lineLimit(1).padding(.horizontal, 36).padding(.vertical, 21)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(red: 40 / 255, green: 40 / 255, blue: 48 / 255).opacity(0.75)))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1.5)))
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 60)
                    .accessibilityIdentifier("toast").transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.25), value: t.text)
    }
}

/// Jour et heure utilisés par « Le moment » et le bandeau (simulateur de test : forcés par argument).
enum DiscoverClock {
    /// `prisme.debug.day` : « mon », « fri », « sat », « sun », « dec » ; `prisme.debug.hour` : 0-23
    static var now: Date {
        var d = Date()
        let cal = Calendar.current
        if let day = Debug.arg("prisme.debug.day") {
            let wd = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7][day]
            if day == "dec" {
                var c = cal.dateComponents([.year, .hour, .minute], from: d); c.month = 12; c.day = 10
                d = cal.date(from: c) ?? d
            } else if let w = wd {
                // le prochain jour voulu (même heure), hors décembre
                var c = cal.dateComponents([.year, .hour, .minute], from: d); c.month = 11; c.day = 16   // lundi 16 novembre 2026
                let base = cal.date(from: c) ?? d
                d = cal.date(byAdding: .day, value: (w + 5) % 7, to: base) ?? d
            }
        }
        if let h = Debug.arg("prisme.debug.hour").flatMap(Int.init) {
            d = cal.date(bySettingHour: h, minute: 0, second: 0, of: d) ?? d
        }
        return d
    }
    static var minutes: Int { let c = Calendar.current.dateComponents([.hour, .minute], from: now); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }
    /// le soir (17 h – 21 h 30) : la télé passe en premier dans la grande affiche
    static var evening: Bool { let m = minutes; return m >= 17 * 60 && m <= 21 * 60 + 30 }
}

/// Dernière ouverture de prisme et jour où le bandeau « Cette nuit » a été montré (par profil).
@MainActor
enum NightLog {
    private static func k(_ b: String, _ pid: String) -> String { ProfileStore.storageKey(b, for: pid) }
    static func lastVisit(_ pid: String) -> Date? {
        let t = UserDefaults.standard.double(forKey: k("prisme.night.last", pid))
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    static func setVisit(_ pid: String, _ d: Date = Date()) { UserDefaults.standard.set(d.timeIntervalSince1970, forKey: k("prisme.night.last", pid)) }
    static func shownDay(_ pid: String) -> String { UserDefaults.standard.string(forKey: k("prisme.night.day", pid)) ?? "" }
    static func setShown(_ pid: String, _ day: String) { UserDefaults.standard.set(day, forKey: k("prisme.night.day", pid)) }
}

/// « Préviens-moi » sur un film pas encore chez le fournisseur (« Bientôt chez toi »).
@MainActor
enum FilmAlerts {
    struct A: Codable, Equatable { var tmdb: Int; var title: String; var at: Date; var done: Bool = false }
    private static var key: String { ProfileStore.shared.key("prisme.film.alerts") }
    static var all: [A] {
        guard let d = UserDefaults.standard.data(forKey: key), let L = try? JSONDecoder().decode([A].self, from: d) else { return [] }
        return L
    }
    private static func save(_ L: [A]) { if let d = try? JSONEncoder().encode(L) { UserDefaults.standard.set(d, forKey: key) } }
    static func has(_ tmdb: Int) -> Bool { all.contains { $0.tmdb == tmdb && !$0.done } }
    /// ajoute ou retire l'alerte ; renvoie vrai si elle est maintenant active
    @discardableResult static func toggle(_ tmdb: Int, title: String) -> Bool {
        var L = all
        if let i = L.firstIndex(where: { $0.tmdb == tmdb && !$0.done }) { L.remove(at: i); save(L); DataCount.write("alerte film retirée : " + title); return false }
        L.append(A(tmdb: tmdb, title: title, at: Date())); save(L)
        DataCount.write("alerte film : " + title)
        return true
    }
    static func markDone(_ tmdb: Int) {
        var L = all
        for i in L.indices where L[i].tmdb == tmdb { L[i].done = true }
        save(L)
    }
}

/// « Me rappeler à 21:00 » : rappels TV gardés jusqu'à leur heure (tvOS n'alerte pas une appli fermée :
/// le rappel s'affiche si prisme est ouvert, ou au lancement suivant s'il a été manqué).
@MainActor
enum TVReminders {
    struct R: Codable, Equatable { var chID: String; var chName: String; var start: Int; var title: String }
    private static var key: String { ProfileStore.shared.key("prisme.tv.reminders") }
    static var all: [R] {
        guard let d = UserDefaults.standard.data(forKey: key), let L = try? JSONDecoder().decode([R].self, from: d) else { return [] }
        return L
    }
    private static func save(_ L: [R]) { if let d = try? JSONEncoder().encode(L) { UserDefaults.standard.set(d, forKey: key) } }
    static func has(_ chID: String, _ start: Int) -> Bool { all.contains { $0.chID == chID && $0.start == start } }
    static func add(_ r: R) {
        var L = all.filter { $0 != r }
        L.append(r); save(L)
        DataCount.write("rappel TV : \(r.title) · \(r.chName) · \(r.start)")
    }
    /// rappels arrivés à leur heure (retirés de la liste) ; ceux de plus de 3 h sont oubliés sans message
    static func due(now: Int = Int(Date().timeIntervalSince1970)) -> [R] {
        let L = all
        let d = L.filter { $0.start - 60 <= now && now - $0.start < 3 * 3600 }
        let keep = L.filter { $0.start - 60 > now }
        if keep.count != L.count { save(keep) }
        return d
    }
}

/// Alertes « Préviens-moi » des lots 1 et 2 déjà annoncées (elles restent enregistrées, seulement marquées).
@MainActor
enum AlertsDone {
    private static var key: String { ProfileStore.shared.key("prisme.alerts.done") }
    static var all: Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    static func add(_ k: String) { var s = all; s.insert(k); UserDefaults.standard.set(Array(s).sorted(), forKey: key) }
}

/// Titres de Ma liste vus « Plus disponible » (lot 2), pour annoncer leur retour.
@MainActor
enum MineGoneLog {
    private static var key: String { ProfileStore.shared.key("prisme.mylist.gonelog") }
    static var all: [String: String] { (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:] }
    static func note(_ L: [(String, String)]) {
        var m = all
        for (id, t) in L where m[id] == nil { m[id] = t }
        UserDefaults.standard.set(m, forKey: key)
    }
    static func back(_ id: String) { var m = all; m.removeValue(forKey: id); UserDefaults.standard.set(m, forKey: key) }
}

// MARK: - Bandeau « Cette nuit » (simulateur nightMsg)

enum NightBanner {
    /// Message du jour pour le profil, ou nil. Calculé à partir des vrais imports :
    /// films ajoutés chez le fournisseur depuis la dernière ouverture (date d'ajout du fournisseur, jamais la date de sortie),
    /// nouveaux épisodes des séries suivies, alertes arrivées ; le dimanche dès 18 h : les heures de la semaine.
    @MainActor
    static func message(pids: [String]) async -> (text: String, parts: [String])? {
        let pid = ProfileStore.shared.me.id
        let now = DiscoverClock.now
        let today = Fiche.dayFormat.string(from: now)
        let last = NightLog.lastVisit(pid)
        NightLog.setVisit(pid, Date())
        guard NightLog.shownDay(pid) != today else { return nil }
        // dimanche soir : le bilan de la semaine (journal réel)
        let wd = Calendar.current.component(.weekday, from: now), hr = Calendar.current.component(.hour, from: now)
        if wd == 1 && hr >= 18 {
            let secs = await WatchJournal.seconds(profile: pid, since: Date().addingTimeInterval(-7 * 86400))
            if secs > 0 {
                NightLog.setShown(pid, today)
                let h = (Double(secs) / 3600 * 10).rounded() / 10
                let hs = h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h).replacingOccurrences(of: ".", with: ",")
                return ("📊 Ta semaine : \(hs) h regardées · le détail dans Ma liste › Ma semaine", ["semaine"])
            }
        }
        // première ouverture avec cette version : on retient seulement la date (rien à comparer)
        guard let since = last else { return nil }
        let s = Int(since.timeIntervalSince1970)
        var bits: [String] = []
        // nouveaux épisodes : séries en cours ou « Préviens-moi », mises à jour chez le fournisseur depuis la dernière visite
        let followed = Set(WatchStore.shared.inProgress.filter { $0.item.hasPrefix("series:") }.map(\.item))
            .union(SeriesAlerts.all.compactMap { $0.components(separatedBy: "|").first })
        var newEp = 0
        var named: [String] = []
        if !followed.isEmpty {
            let items = await MediaStore.items(ids: Array(followed))
            for it in items where it.added > s {
                newEp += 1
                if SeriesAlerts.all.contains(where: { $0.hasPrefix(it.id + "|") }) {
                    let ks = SeriesAlerts.all.filter { $0.hasPrefix(it.id + "|") && !AlertsDone.all.contains($0) }
                    if !ks.isEmpty { named.append("🔔 " + it.displayTitle); ks.forEach(AlertsDone.add) }
                }
            }
        }
        // films « Préviens-moi » arrivés chez le fournisseur (même œuvre TMDB)
        for a in FilmAlerts.all where !a.done {
            let n = await Database.shared.read { db -> Int in
                var c = 0
                db.query("SELECT COUNT(*) FROM fiche WHERE kind='film' AND tmdb=?", [a.tmdb]) { r in c = r.int(0) }
                return c
            }
            if n > 0 { named.append("🔔 " + a.title + " est arrivé"); FilmAlerts.markDone(a.tmdb) }
        }
        // titres de Ma liste revenus chez le fournisseur (lot 2 : « Plus disponible »)
        for (id, title) in MineGoneLog.all {
            if await !MediaStore.items(ids: [id]).isEmpty { named.append("↩︎ " + title + " est de retour"); MineGoneLog.back(id) }
        }
        let nf = await MediaStore.count(.film, pids: pids, where: "added > ?", args: [s])
        if newEp > 0 { bits.append("\(newEp) nouvel\(newEp > 1 ? "s" : "") épisode\(newEp > 1 ? "s" : "")") }
        if nf > 0 { bits.append("\(nf) film\(nf > 1 ? "s" : "") ajouté\(nf > 1 ? "s" : "")") }
        bits += named.prefix(2)
        guard !bits.isEmpty else { return nil }
        NightLog.setShown(pid, today)
        return ("🌙 Cette nuit : " + bits.joined(separator: " · "), bits)
    }
}

/// Pilule en verre en haut au centre (simulateur .mn-night : top 84, 15 px, rayon 999, flou 24), 6,5 s puis s'efface.
struct NightPill: View {
    let text: String
    var body: some View {
        Text(text).font(P.font(22.5, .semibold)).foregroundStyle(.white).lineLimit(1)
            .padding(.horizontal, 27).padding(.vertical, 15)
            .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Color(red: 28 / 255, green: 31 / 255, blue: 42 / 255).opacity(0.62)))
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1.5)))
            .environment(\.colorScheme, .dark)
            .accessibilityIdentifier("cette-nuit").accessibilityLabel(text)
    }
}
