import Foundation

// MARK: - 1.8 phase 1 : ce que le lecteur retient
//
// - Réglages de lecture (valeurs du simulateur par défaut, branchés plus tard dans Réglages › Lecture, phase 6E).
// - Mémoire par série et par profil : moment de l'intro appris, générique, langue choisie, intro passée auto oui/non.
// - Notes de fin de film (👍 / 👎) et films « passés » (on ne redemande pas).
// - Journal de visionnage : chaque séance réellement regardée (date, titre, durée jouée), par profil.
// Tout est ajouté à côté de l'existant : rien n'est modifié ni effacé.

/// Réglages de lecture (phase 6E les rendra modifiables). Lus à chaque usage : un changement s'applique tout de suite.
@MainActor
enum PlaybackPrefs {
    private static var ud: UserDefaults { .standard }
    private static func k(_ s: String) -> String { ProfileStore.shared.key("prisme.play." + s) }
    // valeurs lues aussi sous forme de texte (« 1 », « true ») : c'est ainsi qu'arrivent les réglages de la visite de test
    private static func num(_ s: String) -> Double? {
        let o = ud.object(forKey: k(s))
        if let n = o as? NSNumber { return n.doubleValue }
        if let t = o as? String { return Double(t) ?? (t == "true" ? 1 : t == "false" ? 0 : nil) }
        return nil
    }
    /// « Passer l'intro » automatique quand le moment est confirmé (simulateur : activé)
    static var autoSkip: Bool { num("autoskip").map { $0 != 0 } ?? true }
    /// zéro spoiler : titres, images et résumés des épisodes à venir floutés (simulateur : activé)
    static var zeroSpoiler: Bool { num("spoiler").map { $0 != 0 } ?? true }
    /// « Encore un ? » après N épisodes d'affilée (simulateur : 3 ; 0 = jamais)
    static var binge: Int { num("binge").map { Int($0) } ?? 3 }
    /// carte « Épisode suivant » : secondes avant la fin quand ni chapitre ni moment appris (45 s, voir le plan)
    static var cardLead: Double { num("cardlead") ?? 45 }
    /// compte à rebours de la carte épisode (simulateur : 10 s) et de « À suivre » (simulateur : 15 s)
    static let episodeCountdown = 10
    static let filmCountdown = 15
}

/// Mémoire d'une série pour le profil actif.
struct SeriesMemory: Codable {
    /// intros confirmées : clé d'épisode (« S1E2 ») → début et fin (secondes)
    var intros: [String: [Double]] = [:]
    /// intro passée automatiquement pour cette série (rubrique « Réglages de cette série »)
    var autoSkip = true
    /// générique : secondes avant la fin où tu lances l'épisode suivant ou quittes (moyenne des dernières fois)
    var creditsLead: [Double] = []
    /// langue retenue : audio (« fr », « en »…), sous-titres (« fr », « en », « off » ; nil = choix par défaut)
    var audio: String?
    var subs: String?
    /// version choisie sur la fiche (« fournisseur|VF 4K »)
    var version: String?

    @MainActor static func key(_ series: String) -> String { ProfileStore.shared.key("prisme.series.mem." + series) }
    @MainActor static func load(_ series: String) -> SeriesMemory {
        guard let d = UserDefaults.standard.data(forKey: key(series)), let m = try? JSONDecoder().decode(SeriesMemory.self, from: d) else { return SeriesMemory() }
        return m
    }
    @MainActor func save(_ series: String) {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: SeriesMemory.key(series)) }
    }

    /// Intro apprise : le groupe le plus nombreux d'intros proches (moins de 10 s d'écart au début et à la fin).
    /// `confirmed` = au moins 2 épisodes différents (passage automatique possible) ; `from` = l'épisode le plus récent du groupe.
    func learned() -> (start: Double, end: Double, count: Int, from: String)? {
        let L = intros.filter { $0.value.count == 2 }.map { (k: $0.key, s: $0.value[0], e: $0.value[1]) }
        guard !L.isEmpty else { return nil }
        var best: [(k: String, s: Double, e: Double)] = []
        for a in L {
            let g = L.filter { abs($0.s - a.s) < 10 && abs($0.e - a.e) < 10 }
            if g.count > best.count { best = g }
        }
        // si deux groupes de même taille se disputent (intros qui ne se ressemblent pas), pas de majorité
        let others = L.filter { b in !best.contains { $0.k == b.k } }
        if best.count == 1, !others.isEmpty { return (best[0].s, best[0].e, 1, Self.label(best.map(\.k).sorted(by: Self.epOrder).last!)) }
        let s = best.map(\.s).sorted()[best.count / 2], e = best.map(\.e).sorted()[best.count / 2]
        return (s, e, best.count, Self.label(best.map(\.k).sorted(by: Self.epOrder).last!))
    }

    var creditsAverage: Double? {
        guard !creditsLead.isEmpty else { return nil }
        return creditsLead.suffix(5).reduce(0, +) / Double(min(5, creditsLead.count))
    }

    static func epKey(_ s: Int, _ e: Int) -> String { "S\(s)E\(e)" }
    static func label(_ k: String) -> String {
        let n = k.dropFirst().split(separator: "E")
        return n.count == 2 ? "S\(n[0]) · É\(n[1])" : k
    }
    static func epOrder(_ a: String, _ b: String) -> Bool {
        func n(_ k: String) -> (Int, Int) { let p = k.dropFirst().split(separator: "E").compactMap { Int($0) }; return p.count == 2 ? (p[0], p[1]) : (0, 0) }
        return n(a) < n(b)
    }
}

/// Langue d'une piste audio ou de sous-titres d'après son nom (« Français 5.1 », « English », « [fre] »…).
enum TrackLang {
    static func code(_ name: String) -> String? {
        let x = name.lowercased()
        func has(_ re: String) -> Bool { x.range(of: re, options: .regularExpression) != nil }
        if x.contains("fran") || x.contains("french") || has(#"\b(fr|fre|fra|vf|vff|vfq)\b"#) { return "fr" }
        if x.contains("english") || x.contains("anglais") || has(#"\b(en|eng)\b"#) { return "en" }
        if x.contains("espa") || x.contains("spanish") || has(#"\b(es|spa)\b"#) { return "es" }
        if x.contains("deutsch") || x.contains("german") || x.contains("allemand") || has(#"\b(de|ger|deu)\b"#) { return "de" }
        if x.contains("ital") || has(#"\b(it|ita)\b"#) { return "it" }
        if x.contains("japan") || x.contains("japon") || has(#"\b(ja|jpn)\b"#) { return "ja" }
        if x.contains("korea") || x.contains("coréen") || has(#"\b(ko|kor)\b"#) { return "ko" }
        return nil
    }
    static func name(_ c: String) -> String {
        ["fr": "français", "en": "anglais", "es": "espagnol", "de": "allemand", "it": "italien", "ja": "japonais", "ko": "coréen"][c] ?? c
    }
    /// « anglaise », « française » (« Pas de piste anglaise dans cet épisode »)
    static func adjF(_ c: String) -> String {
        ["fr": "française", "en": "anglaise", "es": "espagnole", "de": "allemande", "it": "italienne", "ja": "japonaise", "ko": "coréenne"][c] ?? c
    }
    static func isForced(_ name: String) -> Bool { name.lowercased().contains("forc") }
}

/// Notes de fin de film (👍 / 👎), par profil. Elles comptent dans les goûts comme un « j'aime » du test
/// (TasteStore les lit), mais restent à part : refaire le test ne les efface pas.
enum FilmRatings {
    struct Rated: Codable { var v: Int; var genres: [String]; var kw: [Int]; var dir: String; var cast: [String]; var title: String }
    static func key(_ pid: String) -> String { ProfileStore.storageKey("prisme.rated", for: pid) }
    static func skipKey(_ pid: String) -> String { ProfileStore.storageKey("prisme.rated.skip", for: pid) }

    static func all(_ pid: String) -> [String: Rated] {
        guard let d = UserDefaults.standard.data(forKey: key(pid)), let m = try? JSONDecoder().decode([String: Rated].self, from: d) else { return [:] }
        return m
    }
    static func value(_ work: String, pid: String) -> Int? { all(pid)[work]?.v }

    @MainActor static func rate(_ it: MediaItem, _ v: Int, pid p0: String? = nil) {
        let pid = p0 ?? ProfileStore.shared.me.id
        var m = all(pid)
        let f = it.fiche
        m[it.workKey] = Rated(v: v, genres: Genres.canon(f?.genres ?? ""), kw: Array(f?.keywordIDs ?? []), dir: f?.director ?? "",
                              cast: (f?.cast ?? []).prefix(4).map(\.n), title: it.displayTitle)
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: key(pid)) }
        HomeCacheReset.run(); TasteStore.shared.invalidate(pid)
        DataCount.write("note [\(pid)] : \(it.displayTitle) \(v > 0 ? "👍" : "👎")")
    }
    static func skip(_ work: String, pid: String) {
        var s = Set(UserDefaults.standard.stringArray(forKey: skipKey(pid)) ?? [])
        s.insert(work)
        UserDefaults.standard.set(Array(s), forKey: skipKey(pid))
    }
    /// faut-il demander « Tu as aimé … ? » : jamais pour un film déjà noté (test des goûts ou fin de film) ou passé
    @MainActor static func shouldAsk(_ work: String, pid: String) -> Bool {
        if all(pid)[work] != nil { return false }
        if (UserDefaults.standard.stringArray(forKey: skipKey(pid)) ?? []).contains(work) { return false }
        if TasteStore.shared.answers(pid)?.judged[work] != nil { return false }
        return true
    }
}

/// Journal de visionnage : une ligne par séance réellement regardée (temps joué, sans les pauses ni les sauts).
enum WatchJournal {
    struct Session { let profile: String; let start: Date; let item: String; let key: String; let title: String; let ep: String; let kind: String; let seconds: Int }

    static func add(_ s: Session) {
        guard s.seconds >= 30 else { return }   // moins de 30 s : un essai, pas une séance
        Task.detached {
            await Database.shared.read { db in
                db.run("INSERT INTO journal(profile,at,item,key,title,ep,kind,seconds) VALUES(?,?,?,?,?,?,?,?)",
                       [s.profile, Int(s.start.timeIntervalSince1970), s.item, s.key, s.title, s.ep, s.kind, s.seconds])
            }
            if Debug.demoServer != nil { await MainActor.run { DataCount.write("journal [\(s.profile)] : \(s.kind) « \(s.title)\(s.ep.isEmpty ? "" : " · " + s.ep) » \(s.seconds) s") } }
        }
    }

    /// Séances d'un profil depuis une date (Ma semaine, phase 2 ; bandeau du dimanche, phase 5)
    /// Ma semaine › « Retirer de l'historique » : les séances de ce titre, pour ce profil seulement (choix de l'utilisateur)
    static func remove(profile: String, item: String) async {
        await Database.shared.read { db in db.run("DELETE FROM journal WHERE profile=? AND item=?", [profile, item]) }
        if Debug.demoServer != nil { await MainActor.run { DataCount.write("journal [\(profile)] : séances de \(item) retirées") } }
    }

    static func sessions(profile: String, since: Date) async -> [Session] {
        await Database.shared.read { db in
            var out: [Session] = []
            db.query("SELECT profile,at,item,key,title,ep,kind,seconds FROM journal WHERE profile=? AND at>=? ORDER BY at", [profile, Int(since.timeIntervalSince1970)]) { r in
                out.append(Session(profile: r.str(0), start: Date(timeIntervalSince1970: TimeInterval(r.int(1))), item: r.str(2), key: r.str(3),
                                   title: r.str(4), ep: r.str(5), kind: r.str(6), seconds: r.int(7)))
            }
            return out
        }
    }
}

// MARK: - « Préviens-moi » (simulateur : fin de saison, épisode absent chez le fournisseur)
// Une alerte par profil : « série|saison|épisode » (épisode 0 : toute la saison). Ajout seulement, aucune donnée existante
// n'est touchée. L'annonce de l'arrivée se fera dans le bandeau « Cette nuit » (lot 4), à partir des imports réels.
@MainActor
enum SeriesAlerts {
    private static var storeKey: String { ProfileStore.shared.key("prisme.series.alerts") }
    static var all: [String] { UserDefaults.standard.stringArray(forKey: storeKey) ?? [] }
    static func key(_ series: String, _ s: Int, _ e: Int) -> String { "\(series)|\(s)|\(e)" }
    static func has(_ series: String, _ s: Int, _ e: Int) -> Bool { all.contains(key(series, s, e)) }
    static func add(_ series: String, _ s: Int, _ e: Int) {
        let k = key(series, s, e)
        guard !all.contains(k) else { return }
        UserDefaults.standard.set(all + [k], forKey: storeKey)
        DataCount.write("alerte : " + k)
    }
}


// MARK: - Lot 2 : Ma liste (simulateur favAt, remind)
// Par profil, uniquement des ajouts : la date et l'origine de chaque ajout (« depuis sa fiche »…), avec le titre et
// l'affiche (pour « Plus disponible » quand le fournisseur retire le titre), et les titres « gardés » (« Tu l'avais
// oublié ? » ne les rappelle plus). Un titre déjà dans la liste avant cette version n'a pas de date : elle n'est pas
// connue, on n'en invente pas.
@MainActor
enum MyListMeta {
    struct Info: Codable, Equatable { var at: Date?; var from: String; var title: String; var poster: String }
    private static func k(_ pid: String) -> String { ProfileStore.storageKey("prisme.mylist.meta", for: pid) }
    private static func kk(_ pid: String) -> String { ProfileStore.storageKey("prisme.mylist.keep", for: pid) }
    static func all(_ pid: String = ProfileStore.shared.me.id) -> [String: Info] {
        guard let d = UserDefaults.standard.data(forKey: k(pid)), let m = try? JSONDecoder().decode([String: Info].self, from: d) else { return [:] }
        return m
    }
    private static func save(_ m: [String: Info], _ pid: String) {
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: k(pid)) }
    }
    /// ajout à Ma liste : date, origine, titre, affiche
    static func added(_ it: MediaItem, from: String) {
        let pid = ProfileStore.shared.me.id
        var m = all(pid)
        m[it.id] = Info(at: Date(), from: from, title: it.displayTitle, poster: it.posterURL)
        save(m, pid)
        DataCount.write("ma liste [\(pid)] : + \(it.displayTitle) \(from)")
    }
    static func removed(_ id: String) {
        let pid = ProfileStore.shared.me.id
        var m = all(pid); m.removeValue(forKey: id); save(m, pid)
    }
    /// titres déjà dans la liste : on garde leur nom et leur affiche (sans date)
    static func remember(_ items: [MediaItem]) {
        let pid = ProfileStore.shared.me.id
        var m = all(pid), changed = false
        for it in items {
            if var x = m[it.id] {
                if x.title.isEmpty || x.poster.isEmpty { x.title = it.displayTitle; x.poster = it.posterURL; m[it.id] = x; changed = true }
            } else { m[it.id] = Info(at: nil, from: "", title: it.displayTitle, poster: it.posterURL); changed = true }
        }
        if changed { save(m, pid) }
    }
    static var kept: Set<String> { Set(UserDefaults.standard.stringArray(forKey: kk(ProfileStore.shared.me.id)) ?? []) }
    static func keep(_ id: String) {
        let pid = ProfileStore.shared.me.id
        UserDefaults.standard.set(Array(kept.union([id])), forKey: kk(pid))
        DataCount.write("ma liste [\(pid)] : gardé \(id)")
    }
    /// test seulement : un titre de la liste que le fournisseur n'a plus
    static func debugGone(_ id: String, title: String) {
        let pid = ProfileStore.shared.me.id
        var m = all(pid); m[id] = Info(at: Date().addingTimeInterval(-20 * 86400), from: "depuis sa fiche", title: title, poster: ""); save(m, pid)
    }
    /// test seulement : date d'ajout ancienne (vérifier « Tu l'avais oublié ? »)
    static func debugAge(_ id: String, days: Int) {
        let pid = ProfileStore.shared.me.id
        var m = all(pid)
        var x = m[id] ?? Info(at: nil, from: "depuis sa fiche", title: "", poster: "")
        x.at = Date().addingTimeInterval(-Double(days) * 86400); x.from = "depuis sa fiche"
        m[id] = x; save(m, pid)
    }
}
