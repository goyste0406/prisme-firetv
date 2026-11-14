import SwiftUI

// MARK: - Profils (simulateur : Réglages › Profils, « Qui regarde ? », pastille du profil)
//
// MIGRATION SANS PERTE : le premier profil (« p1 », nommé Steven) lit et écrit EXACTEMENT les clés d'avant
// (prisme.watch, prisme.media.favs, prisme.live.favs, prisme.live.recent, prisme.live.lastcat). Rien n'est copié,
// déplacé ni renommé : l'ancienne version de l'app retrouve ses données telles quelles. Les autres profils
// ont leurs propres clés (« prisme.watch@p2 »…). Une copie de sécurité figée des données d'avant est faite
// une seule fois au premier lancement (« prisme.backup.1-5-3.* ») et n'est jamais modifiée ensuite.

struct Profile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: Int = 0                // index dans Profile.colors
    var icon: String? = nil           // nil = initiale ; sinon une icône dessinée (SF Symbol, trait seul)
    var kids = false
    var maxAge: Int? = nil            // nil = aucune limite ; 0 = Tous publics ; 10, 12, 16
    var bed = 23 * 60                 // heure du coucher en minutes (22:00 … 01:00 → 1500)
    var lang = "auto"                 // auto, VF, VFF, VFQ, VOSTFR
    var subs = 0                      // 0 = comme le réglage général, 1 = toujours en français, 2 = jamais
    var hours: [Int] = Array(repeating: 0, count: 24)   // heures où ce profil regarde (pour deviner « Bonsoir Steven ? »)

    static let colors: [Color] = ["#f59e0b", "#ec4899", "#64748b", "#22c55e", "#3b82f6", "#a855f7", "#ef4444", "#14b8a6"].map(Color.init(hex:))
    /// Les « petits dessins » du simulateur (emojis) remplacés par des icônes dessinées, trait seul.
    static let icons: [String?] = [nil, "film", "popcorn", "paperplane", "soccerball", "gamecontroller", "moon", "cat"]
    static let ages: [Int?] = [nil, 16, 12, 10, 0]
    static let beds: [Int] = [22 * 60, 22 * 60 + 30, 23 * 60, 23 * 60 + 30, 24 * 60, 24 * 60 + 30, 25 * 60]
    static let langs = ["auto", "VF", "VFF", "VFQ", "VOSTFR"]
    static let langNames = ["auto": "Automatique (prisme retient tes choix)", "VF": "Français, tout doublage", "VFF": "VFF d'abord", "VFQ": "VFQ d'abord", "VOSTFR": "VOSTFR d'abord"]
    static let subNames = ["Comme le réglage général", "Toujours en français", "Jamais"]
    static func ageLabel(_ a: Int?) -> String { a == nil ? "Aucune" : a == 0 ? "Tous publics" : "\(a!) ans max" }

    var tint: Color { Profile.colors[color % Profile.colors.count] }
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased() }
    /// limite effective : un profil enfant est toujours « Tous publics »
    var limit: Int? { kids ? 0 : maxAge }
}

extension Color {
    init(hex: String) {
        let v = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()
    static let guestID = "guest"
    private let key = "prisme.profiles"

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var current: String = "p1"
    /// « À l'ouverture de prisme » : demander qui regarde (sinon le dernier profil utilisé)
    @Published var ask = true { didSet { save() } }
    /// change à chaque changement de profil : les écrans se rechargent
    @Published private(set) var version = 0
    /// Mode « Vous deux » : le second profil qui regarde avec le profil actif (jamais enregistré : à la réouverture
    /// de prisme on repart d'un profil seul). Le profil actif reste celui qui porte Ma liste et les réglages du lecteur.
    @Published private(set) var partner: String? = nil

    /// Filtre d'âge lu par la base de données (hors du fil principal).
    nonisolated(unsafe) static var ageLimit: Int? = nil
    nonisolated(unsafe) static var kidsOnly = false
    nonisolated(unsafe) static var langPref = "auto"

    private struct Saved: Codable { var profiles: [Profile]; var current: String; var ask: Bool }

    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Saved.self, from: d), !s.profiles.isEmpty {
            profiles = s.profiles; current = s.current; ask = s.ask
            if current != ProfileStore.guestID, !profiles.contains(where: { $0.id == current }) { current = profiles[0].id }
            if current == ProfileStore.guestID { current = profiles[0].id }
        } else {
            // premier lancement avec les profils : tout ce qui existe devient le profil de Steven
            ProfileStore.backupOnce()
            profiles = [Profile(id: "p1", name: "Steven")]
            current = "p1"; ask = true
            save()
        }
        publishFilters()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(Saved(profiles: profiles, current: current == ProfileStore.guestID ? (profiles.first?.id ?? "p1") : current, ask: ask)) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    /// Copie de sécurité figée des données d'avant les profils (une seule fois, jamais modifiée ensuite).
    private static func backupOnce() {
        let ud = UserDefaults.standard
        guard ud.object(forKey: "prisme.backup.1-5-3.done") == nil else { return }
        for k in perProfileKeys { if let v = ud.object(forKey: k) { ud.set(v, forKey: "prisme.backup.1-5-3." + k) } }
        ud.set(Date(), forKey: "prisme.backup.1-5-3.done")
    }

    static let perProfileKeys = ["prisme.watch", "prisme.media.favs", "prisme.live.favs", "prisme.live.recent", "prisme.live.lastcat", "prisme.split"]

    var isGuest: Bool { current == ProfileStore.guestID }
    var isDuo: Bool { partner != nil }
    var partnerProfile: Profile? { partner.flatMap { id in profiles.first { $0.id == id } } }
    /// les deux profils (ou le seul) qui regardent
    var watchers: [Profile] { [me] + (partnerProfile.map { [$0] } ?? []) }
    /// « Steven + Léa » ou « Steven »
    var watchersName: String { watchers.map(\.name).joined(separator: " + ") }
    /// Heure du coucher qui compte : la plus tôt des deux en mode « Vous deux » (les heures après minuit valent 24:00 et plus).
    var bedMinutes: Int { watchers.map { $0.bed < 300 ? $0.bed + 1440 : $0.bed }.min() ?? me.bed }
    var me: Profile { profiles.first { $0.id == current } ?? Profile(id: ProfileStore.guestID, name: "Invité", color: 2, icon: "person") }
    func profile(_ id: String) -> Profile? { profiles.first { $0.id == id } }

    /// Clé de stockage d'une donnée personnelle pour un profil : la clé d'origine pour « p1 » (Steven).
    nonisolated static func storageKey(_ base: String, for id: String) -> String { id == "p1" ? base : base + "@" + id }
    func key(_ base: String) -> String { ProfileStore.storageKey(base, for: current) }

    // MARK: changer, créer, modifier

    func use(_ id: String) {
        guard id == ProfileStore.guestID || profiles.contains(where: { $0.id == id }) else { return }
        if isGuest { ProfileStore.wipe(ProfileStore.guestID) }   // le mode invité ne garde rien
        partner = nil
        current = id
        if id == ProfileStore.guestID { ProfileStore.wipe(id) }
        save(); publishFilters(); reloadAll()
    }

    /// « Vous deux » : `a` devient le profil actif, `b` regarde avec lui.
    func useDuo(_ a: String, _ b: String) {
        guard a != b, profiles.contains(where: { $0.id == a }), profiles.contains(where: { $0.id == b }) else { return }
        if current != a { use(a) }
        partner = b
        publishFilters(); HomeCacheReset.run(); version += 1
    }
    /// Revenir au profil actif seul.
    func endDuo() {
        guard partner != nil else { return }
        partner = nil
        publishFilters(); HomeCacheReset.run(); version += 1
    }

    @discardableResult func add() -> Profile? {
        guard profiles.count < 6 else { return nil }
        var n = 2
        while profiles.contains(where: { $0.id == "p\(n)" }) { n += 1 }
        let p = Profile(id: "p\(n)", name: "Profil \(profiles.count + 1)", color: (profiles.count + 3) % Profile.colors.count)
        profiles.append(p); save()
        return p
    }

    func update(_ p: Profile) {
        guard let i = profiles.firstIndex(where: { $0.id == p.id }) else { return }
        profiles[i] = p; save()
        if p.id == current { publishFilters(); version += 1 }
    }

    /// Supprimer un profil (jamais celui de Steven, qui porte les données d'origine) : ses données à lui seul sont effacées.
    func remove(_ id: String) {
        guard id != "p1", profiles.count > 1, profiles.contains(where: { $0.id == id }) else { return }
        profiles.removeAll { $0.id == id }
        if partner == id { partner = nil }
        ProfileStore.wipe(id)
        if current == id { current = "p1"; publishFilters(); reloadAll() }
        save()
    }

    /// Effacer l'historique d'un profil (garde sa liste et ses réglages).
    func clearHistory(_ id: String) {
        UserDefaults.standard.removeObject(forKey: ProfileStore.storageKey("prisme.watch", for: id))
        if id == current { WatchStore.shared.reload() }
        version += 1
    }

    private static func wipe(_ id: String) {
        guard id != "p1" else { return }
        for k in perProfileKeys { UserDefaults.standard.removeObject(forKey: storageKey(k, for: id)) }
    }

    /// Une lecture a eu lieu à cette heure : sert à deviner qui regarde à l'ouverture.
    func noteUse() {
        guard !isGuest, let i = profiles.firstIndex(where: { $0.id == current }) else { return }
        let h = Calendar.current.component(.hour, from: Date())
        if profiles[i].hours.count != 24 { profiles[i].hours = Array(repeating: 0, count: 24) }
        profiles[i].hours[h] += 1; save()
    }

    /// Le profil le plus probable à cette heure (heures habituelles), sinon le dernier utilisé.
    func guess() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        var best: (String, Int)? = nil
        for p in profiles where p.hours.count == 24 {
            let s = p.hours[h] * 2 + p.hours[(h + 23) % 24] + p.hours[(h + 1) % 24]
            if s > 0, s > (best?.1 ?? 0) { best = (p.id, s) }
        }
        return best?.0 ?? (isGuest ? (profiles.first?.id ?? "p1") : current)
    }

    private func publishFilters() {
        let p = me
        // « Vous deux » : la limite d'âge la plus stricte des deux, et contenus enfants si l'un des deux est un profil enfant
        let limits = isGuest ? [] : watchers.compactMap(\.limit)
        ProfileStore.ageLimit = limits.min()
        ProfileStore.kidsOnly = !isGuest && watchers.contains { $0.kids }
        ProfileStore.langPref = isGuest ? "auto" : p.lang
    }

    private func reloadAll() {
        WatchStore.shared.reload()
        LivePrefs.shared.reload()
        HomeCacheReset.run()
        version += 1
    }

    // MARK: chiffres réels affichés dans « Qui regarde ? »

    /// Films vus (≥ 85 %) et nombre d'entrées de l'historique d'un profil.
    func stats(_ id: String) -> (seen: Int, hist: Int) {
        let e = WatchStore.entries(for: id)
        return (e.values.filter { $0.item.hasPrefix("film:") && $0.dur > 0 && $0.pos / $0.dur >= 0.85 }.count, e.count)
    }
}

/// Les accueils gardés en mémoire sont propres à un profil : on les vide au changement.
enum HomeCacheReset { nonisolated(unsafe) static var run: () -> Void = {} }

/// Pastille d'un profil : cercle de sa couleur avec l'initiale (ou son icône dessinée).
struct ProfileAvatar: View {
    let p: Profile
    var size: CGFloat = 60
    var body: some View {
        ZStack {
            Circle().fill(p.tint)
            if let ic = p.icon {
                Image(systemName: ic).font(.system(size: size * 0.42, weight: .regular)).foregroundStyle(.white)
            } else {
                Text(p.initial).font(.system(size: size * 0.48, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
