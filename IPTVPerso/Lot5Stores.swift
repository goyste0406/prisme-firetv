import SwiftUI

// MARK: - Lot 5 : petites mémoires (ajouts seulement, validés)
// - rangées des accueils masquées et leur ordre, par profil (simulateur h.hid / h.ord)
// - TV : sources mémorisées (après 3 choix identiques) et chaînes masquées (simulateur LS.direct, LS.pref, LS.hidden)
// - lecture en cours (pour mettre les fiches en pause pendant la lecture)

/// Rangées des accueils Films / Séries, par profil : ordre et rangées masquées.
@MainActor
enum HiddenRows {
    static let films: [(String, String)] = [("reprendre", "Reprendre"), ("pourtoi", "Pour toi"), ("top", "Top 10 du moment"), ("new", "Nouveau sur prisme"),
                                           ("bec", "Parce que tu as aimé…"), ("liste", "Ma liste"), ("explore", "Explorer"), ("browse", "Parcourir")]
    static let series: [(String, String)] = [("reprendre", "Reprendre"), ("pourtoi", "Pour toi"), ("top", "Top 10 séries"), ("new", "Nouveau sur prisme"),
                                            ("liste", "Ma liste"), ("browse", "Parcourir")]
    static func rows(_ k: MediaKind) -> [(String, String)] { k == .film ? films : series }
    private static func key(_ k: MediaKind, _ w: String) -> String { ProfileStore.shared.key("prisme.home.\(k.rawValue).\(w)") }
    static func hidden(_ k: MediaKind) -> [String] { UserDefaults.standard.stringArray(forKey: key(k, "hid")) ?? [] }
    static func list(_ k: MediaKind) -> [String] { let h = hidden(k); return rows(k).filter { h.contains($0.0) }.map(\.1) }
    static func order(_ k: MediaKind) -> [String] {
        let all = rows(k).map(\.0)
        let saved = (UserDefaults.standard.stringArray(forKey: key(k, "ord")) ?? []).filter { all.contains($0) }
        return saved + all.filter { !saved.contains($0) }
    }
    static func hide(_ k: MediaKind, _ r: String) {
        var h = hidden(k); if !h.contains(r) { h.append(r) }
        UserDefaults.standard.set(h, forKey: key(k, "hid")); changed()
        DataCount.write("rangée masquée : \(k.rawValue) \(r)")
    }
    static func move(_ k: MediaKind, _ r: String, _ d: Int) {
        let vis = order(k).filter { !hidden(k).contains($0) }
        var o = order(k)
        guard let i = vis.firstIndex(of: r), vis.indices.contains(i + d), let a = o.firstIndex(of: r), let b = o.firstIndex(of: vis[i + d]) else { return }
        o.swapAt(a, b)
        UserDefaults.standard.set(o, forKey: key(k, "ord")); changed()
        DataCount.write("rangée déplacée : \(k.rawValue) \(r) \(d > 0 ? "descendue" : "montée")")
    }
    static func reset(_ k: MediaKind) {
        UserDefaults.standard.removeObject(forKey: key(k, "hid")); UserDefaults.standard.removeObject(forKey: key(k, "ord")); changed()
        DataCount.write("rangées rétablies : \(k.rawValue)")
    }
    static func name(_ k: MediaKind, _ r: String) -> String { rows(k).first { $0.0 == r }?.1 ?? r }
    private static func changed() { NotificationCenter.default.post(name: .prismePrefs, object: nil) }
}

/// Menu « OK maintenu » d'une affiche des accueils (simulateur : vu, ma liste, monter / descendre, masquer la rangée).
struct HomeRowMenu {
    let build: (MediaItem?) -> [(String, () -> Void)]
}
private struct HomeRowMenuKey: EnvironmentKey { static let defaultValue: HomeRowMenu? = nil }
extension EnvironmentValues {
    var homeRowMenu: HomeRowMenu? { get { self[HomeRowMenuKey.self] } set { self[HomeRowMenuKey.self] = newValue } }
}
struct HomeTileMenuMod: ViewModifier {
    @Environment(\.homeRowMenu) var menu
    let item: MediaItem?
    func body(content: Content) -> some View {
        if let m = menu {
            let acts = m.build(item)
            content.contextMenu { ForEach(0..<acts.count, id: \.self) { i in Button(acts[i].0) { acts[i].1() } } }
        } else { content }
    }
}
extension View {
    /// tuile d'une rangée d'accueil : menu « OK maintenu » si la rangée en fournit un
    func homeTileMenu(_ item: MediaItem?) -> some View { modifier(HomeTileMenuMod(item: item)) }
}

/// TV en direct : sources mémorisées et chaînes masquées (pour tous les profils, comme le simulateur).
@MainActor
final class LiveMemory: ObservableObject {
    static let shared = LiveMemory()
    private let ud = UserDefaults.standard
    /// chaîne (identité) → copie à ouvrir directement
    @Published private(set) var direct: [String: String]
    /// chaîne → copie → nombre de fois choisie
    @Published private(set) var picks: [String: [String: Int]]
    /// chaînes masquées (identité) et leur nom
    @Published private(set) var hidden: [String: String]
    private init() {
        direct = ud.dictionary(forKey: "prisme.live.direct") as? [String: String] ?? [:]
        picks = ud.dictionary(forKey: "prisme.live.picks") as? [String: [String: Int]] ?? [:]
        hidden = ud.dictionary(forKey: "prisme.live.hidden") as? [String: String] ?? [:]
    }
    private func save() {
        ud.set(direct, forKey: "prisme.live.direct"); ud.set(picks, forKey: "prisme.live.picks"); ud.set(hidden, forKey: "prisme.live.hidden")
    }
    /// une copie choisie dans la liste des sources ; renvoie vrai au 3e choix identique (proposer de la mémoriser)
    func picked(_ key: String, _ src: String) -> Bool {
        var p = picks[key] ?? [:]
        p[src, default: 0] += 1
        picks[key] = p; save()
        return p[src] == 3 && direct[key] == nil
    }
    func remember(_ key: String, _ src: String, name: String) {
        direct[key] = src; save()
        DataCount.write("source mémorisée : \(name) → \(src)")
    }
    func forget(_ key: String) { direct.removeValue(forKey: key); picks.removeValue(forKey: key); save() }
    func hide(_ key: String, name: String) { hidden[key] = name; save(); DataCount.write("chaîne masquée : " + name) }
    func show(_ key: String) { hidden.removeValue(forKey: key); save() }
    func isHidden(_ key: String) -> Bool { hidden[key] != nil }
}

/// Lecture en cours (film, épisode, chaîne) : les fiches en arrière-plan se mettent en pause ou ralentissent.
enum PlaybackActivity {
    nonisolated(unsafe) static var count = 0
    static var playing: Bool { count > 0 }
}

/// Fiches en arrière-plan : « La nuit seulement » (1 h – 7 h) et « Pendant la lecture » (pause ou lentement).
enum FicheGate {
    static func wait() async {
        while !Task.isCancelled {
            let mode = UserDefaults.standard.object(forKey: "prisme.pref.ficheMode") as? Int ?? 0
            let h = Calendar.current.component(.hour, from: Date())
            if mode == 2 && !(1..<7).contains(h) { try? await Task.sleep(nanoseconds: 60_000_000_000); continue }
            if PlaybackActivity.playing {
                let slow = (UserDefaults.standard.object(forKey: "prisme.pref.fichePlay") as? Int ?? 0) == 1
                if slow { try? await Task.sleep(nanoseconds: 3_000_000_000); return }
                try? await Task.sleep(nanoseconds: 5_000_000_000); continue
            }
            return
        }
    }
}
