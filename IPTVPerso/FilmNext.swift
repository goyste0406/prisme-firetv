import Foundation

// MARK: - 1.8 phase 1 : « À suivre » en fin de film (règles du simulateur)
// 1. la suite de la saga si tu ne l'as pas vue ;
// 2. sinon le premier titre de « Si tu hésites encore » (mode « Le meilleur mix ») que tu n'as pas commencé.
// Toujours un film présent chez tes fournisseurs et autorisé pour le profil ; sinon, pas de proposition.

enum FilmNext {
    @MainActor
    static func pick(for it: MediaItem) async -> FilmPick? {
        let store = ProviderStore.shared
        let pids = store.active.map(\.id)
        guard let f = it.fiche, !pids.isEmpty else { return nil }
        let watch = WatchStore.shared
        func seen(_ x: MediaItem) -> Bool { (watch.fraction(x.id) ?? 0) >= 0.85 }
        func started(_ x: MediaItem) -> Bool { watch.entries[x.id] != nil }

        // 1. saga : le volet qui suit celui-ci (dans l'ordre de la saga), présent, autorisé, pas vu
        if f.coll > 0 {
            let (_, parts) = await SagaStore.parts(f.coll)
            if let i = parts.firstIndex(where: { $0.tmdb == f.tmdb }), i + 1 < parts.count {
                let avail = await MediaStore.items(kind: .film, tmdb: parts[(i + 1)...].map(\.tmdb), pids: pids)
                for p in parts[(i + 1)...] {
                    guard let x = avail[p.tmdb], x.allowedForProfile else { continue }
                    if seen(x) { continue }
                    return make(x, reason: "La suite de la saga")
                }
            }
        }
        // 2. « Si tu hésites encore » : mêmes candidats et même calcul que la rangée de la fiche
        let genres = f.genres.components(separatedBy: CharacterSet(charactersIn: ",/")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let sim = await MediaStore.similar(of: it, genres: genres, pids: pids, limit: 60).map(\.0)
        var models: [TasteModel] = []
        for w in ProfileStore.shared.watchers { models.append(await TasteStore.shared.model(w.id)) }
        let no = NotInterested.list(ProfileStore.shared.me.id)
        let pool = sim.filter { $0.fiche?.tmdb != f.tmdb && $0.allowedForProfile && !no.contains($0.workKey) && !seen($0) }
        let title = f.title.isEmpty ? it.clean.title : f.title
        let res = await Task.detached(priority: .utility) { CrossPick.pick(base: f, title: title, cands: pool, recs: [], models: models, mode: .mix) }.value
        guard let r = res.first(where: { !started($0.item) }) else { return nil }
        return make(r.item, reason: "\(r.pct) % pour toi" + (r.why.isEmpty ? "" : " · " + r.why))
    }

    @MainActor
    private static func make(_ x: MediaItem, reason: String) -> FilmPick {
        let minutes = x.fiche?.runtime ?? 0
        return FilmPick(item: x, reason: reason, minutes: minutes, request: { request(x) })
    }

    /// Lecture d'un film depuis le lecteur (film suivant) : même bandeau que depuis sa fiche.
    @MainActor
    static func request(_ x: MediaItem, from: Double = 0) -> VodRequest? {
        guard let p = ProviderStore.shared.provider(x.pid), let url = p.movieURL(x) else { return nil }
        let f = x.fiche
        let title = (f?.title.isEmpty == false) ? f!.title : x.clean.title
        var r = VodRequest(url: url, key: x.id, item: x.id, title: title, subtitle: "", icon: x.posterURL, startAt: from)
        let y = (f?.year ?? 0) > 0 ? f!.year : x.clean.year
        r.kicker = "FILM" + (y > 0 ? " · \(y)" : "")
        let t = x.clean.tags
        let short = (t.first { ["VF", "MULTI", "VOSTFR"].contains($0) } ?? "VF") + " · " + (t.first { ["4K", "1080p"].contains($0) } ?? "HD")
        r.meta = short + " · chez " + p.name
        r.cast = f?.cast.prefix(6).map(\.n) ?? []
        r.film = FilmCtx(item: x, pick: { await FilmNext.pick(for: x) })
        return r
    }
}
