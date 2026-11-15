import Foundation

/// Test des goûts : les grands classiques du simulateur (« une dizaine de grands classiques du cinéma et des séries
/// que presque tout le monde a vus »), de toutes les époques et de tous les genres, français et internationaux,
/// animation et films familiaux compris. Proposés même s'ils ne sont pas chez tes fournisseurs (l'affiche vient de TMDB).
enum TasteClassics {
    /// (titre, année, genres TMDB en français) — liste MF du simulateur, dans son ordre (les plus connus d'abord)
    static let films: [(String, Int, String)] = [
        ("Intouchables", 2011, "Comédie, Drame"),
        ("Titanic", 1997, "Drame, Romance"),
        ("Bienvenue chez les Ch'tis", 2008, "Comédie"),
        ("Harry Potter à l'école des sorciers", 2001, "Aventure, Fantastique"),
        ("Le Roi lion", 1994, "Animation, Familial"),
        ("Le Seigneur des anneaux : La Communauté de l'anneau", 2001, "Aventure, Fantastique"),
        ("Avatar", 2009, "Science-Fiction, Aventure"),
        ("Le Dîner de cons", 1998, "Comédie"),
        ("Les Visiteurs", 1993, "Comédie, Fantastique"),
        ("Pirates des Caraïbes : La Malédiction du Black Pearl", 2003, "Aventure, Fantastique"),
        ("Forrest Gump", 1994, "Drame, Romance"),
        ("Astérix & Obélix : Mission Cléopâtre", 2002, "Comédie, Aventure"),
        ("Retour vers le futur", 1985, "Science-Fiction, Comédie"),
        ("Jurassic Park", 1993, "Aventure, Science-Fiction"),
        ("Le Fabuleux Destin d'Amélie Poulain", 2001, "Comédie, Romance"),
        ("Shrek", 2001, "Animation, Comédie"),
        ("Matrix", 1999, "Action, Science-Fiction"),
        ("Gladiator", 2000, "Action, Drame"),
        ("La Grande Vadrouille", 1966, "Comédie, Guerre"),
        ("Avengers : Endgame", 2019, "Action, Science-Fiction"),
        ("La Reine des neiges", 2013, "Animation, Familial"),
        ("Taxi", 1998, "Action, Comédie"),
        ("Inception", 2010, "Science-Fiction, Action"),
        ("Les Bronzés font du ski", 1979, "Comédie"),
        ("Le Parrain", 1972, "Crime, Drame"),
        ("Qu'est-ce qu'on a fait au Bon Dieu ?", 2014, "Comédie"),
        ("Pulp Fiction", 1994, "Crime, Thriller"),
        ("Les Choristes", 2004, "Drame, Musique"),
        ("Toy Story", 1995, "Animation, Familial"),
        ("Skyfall", 2012, "Action, Thriller"),
        ("Pretty Woman", 1990, "Romance, Comédie"),
        ("Le Silence des agneaux", 1991, "Thriller, Crime"),
        ("Top Gun : Maverick", 2022, "Action, Drame"),
        ("Interstellar", 2014, "Science-Fiction, Drame"),
        ("Il faut sauver le soldat Ryan", 1998, "Guerre, Histoire"),
        ("Ça", 2017, "Horreur"),
        ("OSS 117 : Le Caire, nid d'espions", 2006, "Comédie, Aventure"),
        ("Joker", 2019, "Crime, Thriller"),
        ("Love Actually", 2003, "Romance, Comédie"),
        ("Mission : Impossible", 1996, "Action, Thriller"),
        ("Le Loup de Wall Street", 2013, "Crime, Comédie"),
        ("Conjuring : Les Dossiers Warren", 2013, "Horreur, Thriller"),
        ("Bohemian Rhapsody", 2018, "Musique, Drame"),
        ("Le Prénom", 2012, "Comédie"),
        ("Seven", 1995, "Crime, Mystère"),
        ("N'oublie jamais", 2004, "Romance, Drame"),
        ("Moi, moche et méchant", 2010, "Animation, Comédie"),
        ("Oppenheimer", 2023, "Histoire, Drame"),
        ("Dune", 2021, "Science-Fiction, Aventure"),
        ("La La Land", 2016, "Romance, Musique"),
        ("Le Comte de Monte-Cristo", 2024, "Aventure, Drame"),
        ("Coco", 2017, "Animation, Familial")
    ]
    /// liste MS du simulateur
    static let series: [(String, Int, String)] = [
        ("Friends", 1994, "Comédie"),
        ("Game of Thrones", 2011, "Science-Fiction & Fantastique, Drame"),
        ("Breaking Bad", 2008, "Crime, Drame"),
        ("La casa de papel", 2017, "Crime, Drame"),
        ("Stranger Things", 2016, "Science-Fiction & Fantastique, Mystère"),
        ("Les Simpson", 1989, "Animation, Comédie"),
        ("Grey's Anatomy", 2005, "Drame"),
        ("Lupin", 2021, "Crime, Mystère"),
        ("Dr House", 2004, "Drame, Mystère"),
        ("The Big Bang Theory", 2007, "Comédie"),
        ("The Walking Dead", 2010, "Drame, Action & Adventure"),
        ("Kaamelott", 2005, "Comédie"),
        ("Squid Game", 2021, "Action & Adventure, Drame"),
        ("Prison Break", 2005, "Action & Adventure, Crime"),
        ("How I Met Your Mother", 2005, "Comédie"),
        ("Peaky Blinders", 2013, "Crime, Drame"),
        ("Esprits criminels", 2005, "Crime, Mystère"),
        ("HPI", 2021, "Comédie, Crime"),
        ("Desperate Housewives", 2004, "Drame, Mystère"),
        ("Mercredi", 2022, "Science-Fiction & Fantastique, Comédie"),
        ("The Crown", 2016, "Drame"),
        ("Narcos", 2015, "Crime, Drame"),
        ("Le Bureau des Légendes", 2015, "Drame, Crime"),
        ("Dix pour cent", 2015, "Comédie, Drame"),
        ("Sherlock", 2010, "Crime, Mystère"),
        ("Vikings", 2013, "Action & Adventure, Drame"),
        ("The Office", 2005, "Comédie"),
        ("La Chronique des Bridgerton", 2020, "Romance, Drame"),
        ("The Last of Us", 2023, "Drame, Action & Adventure")
    ]

    /// Les classiques en titres utilisables par le test : ceux de tes fournisseurs (avec leur fiche TMDB) d'abord,
    /// les autres d'après une recherche TMDB (affiche, note, genres). Le rang dans la liste sert de « notoriété ».
    static func load(pids: [String]) async -> [MediaItem] {
        let all = films.map { ($0, MediaKind.film) } + series.map { ($0, MediaKind.series) }
        let total = Double(all.count)
        // 1. dans le catalogue (fiche TMDB déjà téléchargée)
        var keyOf: [String: (Int, MediaKind)] = [:]
        for (i, e) in all.enumerated() {
            for y in [e.0.1, e.0.1 - 1, e.0.1 + 1] { keyOf[e.1.rawValue + "#" + TitleTools.fold(e.0.0) + "|" + String(y)] = (i, e.1) }
        }
        var found: [Int: MediaItem] = [:]
        for k in [MediaKind.film, .series] {
            let keys = keyOf.filter { $0.value.1 == k }.map { String($0.key.split(separator: "#", maxSplits: 1)[1]) }
            let fiches = await Database.shared.read { _ in FicheStore.byKeys(k, keys) }
            let ids = fiches.values.map { k.rawValue + ":" + $0.pid + ":" + $0.sid }
            let items = await MediaStore.items(ids: ids)
            for it in items where pids.contains(it.pid) {
                if let i = keyOf[k.rawValue + "#" + it.clean.key]?.0, found[i] == nil { found[i] = it }
            }
        }
        // 2. les autres : recherche TMDB (6 à la fois)
        var out = found
        if let key = TmdbKey.value {
            let missing = all.indices.filter { found[$0] == nil }
            await withTaskGroup(of: (Int, MediaItem?).self) { g in
                var next = 0
                func add() {
                    guard next < missing.count else { return }
                    let i = missing[next]; next += 1
                    let e = all[i]
                    g.addTask { (i, await search(e.0, kind: e.1, key: key)) }
                }
                for _ in 0..<6 { add() }
                while let (i, it) = await g.next() {
                    if let it { out[i] = it }
                    add()
                }
            }
        }
        // notoriété : rang dans la liste (le test prend « les plus connus » d'après cette note)
        return out.sorted { $0.key < $1.key }.map { i, it in
            var m = it
            if let f = m.fiche {
                m.fiche = Fiche(tmdb: f.tmdb, title: f.title, overview: f.overview, poster: f.poster, backdrop: f.backdrop,
                                genres: f.genres.isEmpty ? all[i].0.2 : f.genres, runtime: f.runtime,
                                vote: 10 - 4 * Double(i) / total, year: f.year, coll: f.coll, collName: f.collName, cast: f.cast, wp: f.wp,
                                pid: f.pid, sid: f.sid, country: f.country, director: f.director, logo: f.logo, companies: f.companies,
                                cert: f.cert, keywords: f.keywords)
            }
            return m
        }
    }

    private static func search(_ e: (String, Int, String), kind: MediaKind, key: String) async -> MediaItem? {
        let tv = kind == .series
        let d = await TmdbAPI(key: key).get(tv ? "/search/tv" : "/search/movie",
                                            [("query", e.0), (tv ? "first_air_date_year" : "year", String(e.1)), ("language", "fr-FR")])
        guard let r = (d?["results"] as? [[String: Any]])?.first, let id = r["id"] as? Int else { return nil }
        let poster = (r["poster_path"] as? String) ?? ""
        guard !poster.isEmpty else { return nil }
        let title = (r[tv ? "name" : "title"] as? String) ?? e.0
        let f = Fiche(tmdb: id, title: title, overview: (r["overview"] as? String) ?? "", poster: poster,
                      backdrop: (r["backdrop_path"] as? String) ?? "", genres: e.2, runtime: 0, vote: (r["vote_average"] as? Double) ?? 0,
                      year: e.1, coll: 0, collName: "", cast: [], wp: WatchProviders(), pid: "", sid: "")
        return MediaItem(kind: kind, pid: "tmdb", sid: String(id), name: title, year: e.1, icon: "", cid: "", ext: "",
                         rating: 0, added: 0, tmdb: String(id), plot: "", fiche: f)
    }
}
