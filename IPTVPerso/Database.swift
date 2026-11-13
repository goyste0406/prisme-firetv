import Foundation
import SQLite3

/// Petite couche SQLite (incluse dans tvOS, aucune dépendance).
/// Le catalogue (chaînes, films, séries, guide) vit ici, sur le disque de l'Apple TV :
/// on ne garde en mémoire que ce qui est à l'écran.
final class Database: @unchecked Sendable {
    static let shared = Database()

    private var db: OpaquePointer?
    /// Toutes les requêtes passent par cette file : une seule à la fois, jamais sur l'écran.
    let queue = DispatchQueue(label: "prisme.db", qos: .userInitiated)
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("prisme.sqlite")
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            // base abîmée : on repart d'une base vide (le catalogue se réimporte depuis les fournisseurs)
            sqlite3_close(db); db = nil
            try? FileManager.default.removeItem(at: url)
            sqlite3_open(url.path, &db)
        }
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA synchronous=NORMAL")
        exec("PRAGMA temp_store=MEMORY")
        exec("PRAGMA cache_size=-8000") // 8 Mo de cache, pas plus
        migrate()
    }

    // MARK: Schéma

    private func migrate() {
        let v = intValue("PRAGMA user_version") ?? 0
        if v < 1 {
            exec("""
            CREATE TABLE IF NOT EXISTS category(pid TEXT, type TEXT, cid TEXT, name TEXT, pos INTEGER, PRIMARY KEY(pid,type,cid));
            CREATE TABLE IF NOT EXISTS live(pid TEXT, sid TEXT, name TEXT, num INTEGER, icon TEXT, cid TEXT, epg TEXT, archive INTEGER, PRIMARY KEY(pid,sid));
            CREATE INDEX IF NOT EXISTS live_cat ON live(pid,cid,num);
            CREATE INDEX IF NOT EXISTS live_epg ON live(epg);
            CREATE TABLE IF NOT EXISTS vod(pid TEXT, sid TEXT, name TEXT, year INTEGER, icon TEXT, cid TEXT, ext TEXT, rating REAL, added INTEGER, tmdb TEXT, PRIMARY KEY(pid,sid));
            CREATE INDEX IF NOT EXISTS vod_cat ON vod(pid,cid,added);
            CREATE TABLE IF NOT EXISTS series(pid TEXT, sid TEXT, name TEXT, year INTEGER, cover TEXT, cid TEXT, plot TEXT, rating REAL, added INTEGER, tmdb TEXT, PRIMARY KEY(pid,sid));
            CREATE INDEX IF NOT EXISTS series_cat ON series(pid,cid,added);
            CREATE TABLE IF NOT EXISTS epg(ch TEXT, start INTEGER, stop INTEGER, title TEXT, descr TEXT);
            CREATE INDEX IF NOT EXISTS epg_ch ON epg(ch,start);
            PRAGMA user_version=1;
            """)
        }
        if v < 2 {
            exec("""
            CREATE TABLE IF NOT EXISTS fiche(kind TEXT, ckey TEXT, pid TEXT, sid TEXT, tmdb INTEGER, title TEXT, overview TEXT, poster TEXT, backdrop TEXT,
              genres TEXT, runtime INTEGER, vote REAL, year INTEGER, coll INTEGER, cast TEXT, wp TEXT, collname TEXT, PRIMARY KEY(kind,ckey));
            CREATE INDEX IF NOT EXISTS fiche_tmdb ON fiche(kind,tmdb);
            CREATE INDEX IF NOT EXISTS fiche_coll ON fiche(kind,coll);
            CREATE TABLE IF NOT EXISTS fmiss(kind TEXT, ckey TEXT, at INTEGER, PRIMARY KEY(kind,ckey));
            CREATE TABLE IF NOT EXISTS coll(id INTEGER PRIMARY KEY, name TEXT, parts TEXT);
            PRAGMA user_version=2;
            """)
        }
        if v < 3 {
            // 1.5.3 : pays, réalisateur, logo du titre et studios (colonnes ajoutées, les fiches existantes sont gardées
            // et complétées petit à petit en arrière-plan)
            exec("ALTER TABLE fiche ADD COLUMN country TEXT")
            exec("ALTER TABLE fiche ADD COLUMN director TEXT")
            exec("ALTER TABLE fiche ADD COLUMN logo TEXT")
            exec("ALTER TABLE fiche ADD COLUMN companies TEXT")
            exec("PRAGMA user_version=3")
        }
        if v < 4 {
            // 1.6 : classification d'âge française (TMDB) pour la limite d'âge des profils
            // (NULL = pas encore vérifiée ; '' = inconnue ; '0' = tous publics ; '10', '12', '16', '18')
            exec("ALTER TABLE fiche ADD COLUMN cert TEXT")
            exec("PRAGMA user_version=4")
        }
        if v < 5 {
            // 1.6 : genre de chaque programme du guide (catégorie XMLTV), pour la rangée « En ce moment »
            // (colonne ajoutée : le guide existant est gardé, le genre arrive à la prochaine mise à jour du guide)
            exec("ALTER TABLE epg ADD COLUMN cat TEXT")
            exec("PRAGMA user_version=5")
        }
        if v < 6 {
            // 1.6 : mots-clés TMDB des fiches (« marvel cinematic universe (mcu) », « space opera »…) pour « Dans le même
            // univers » confirmé par TMDB et pour « Mes goûts ». NULL = pas encore téléchargés (complétés en arrière-plan).
            exec("ALTER TABLE fiche ADD COLUMN keywords TEXT")
            exec("PRAGMA user_version=6")
        }
    }

    // MARK: Requêtes

    @discardableResult
    func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func intValue(_ sql: String, _ args: [Any?] = []) -> Int? {
        var out: Int?
        query(sql, args) { r in out = r.int(0) }
        return out
    }

    /// Exécute une requête et appelle `row` pour chaque ligne.
    /// nombre de requêtes lancées (mesures du simulateur de test)
    nonisolated(unsafe) static var queryCount = 0

    func query(_ sql: String, _ args: [Any?] = [], row: (Statement) -> Void) {
        Database.queryCount += 1
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, let st else { return }
        defer { sqlite3_finalize(st) }
        bind(st, args)
        let s = Statement(st)
        while sqlite3_step(st) == SQLITE_ROW { row(s) }
    }

    /// Insère beaucoup de lignes d'un coup (une seule transaction, une seule requête préparée).
    func insertMany(_ sql: String, _ rows: [[Any?]]) {
        guard !rows.isEmpty else { return }
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, let st else { return }
        defer { sqlite3_finalize(st) }
        exec("BEGIN")
        for r in rows {
            bind(st, r)
            sqlite3_step(st)
            sqlite3_reset(st)
            sqlite3_clear_bindings(st)
        }
        exec("COMMIT")
    }

    func run(_ sql: String, _ args: [Any?] = []) {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, let st else { return }
        defer { sqlite3_finalize(st) }
        bind(st, args)
        sqlite3_step(st)
    }

    private func bind(_ st: OpaquePointer, _ args: [Any?]) {
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case nil: sqlite3_bind_null(st, idx)
            case let v as Int: sqlite3_bind_int64(st, idx, Int64(v))
            case let v as Int64: sqlite3_bind_int64(st, idx, v)
            case let v as Double: sqlite3_bind_double(st, idx, v)
            case let v as Bool: sqlite3_bind_int64(st, idx, v ? 1 : 0)
            case let v as String: sqlite3_bind_text(st, idx, v, -1, Database.transient)
            default: sqlite3_bind_text(st, idx, "\(a!)", -1, Database.transient)
            }
        }
    }

    /// Lecture d'une ligne de résultat.
    struct Statement {
        let st: OpaquePointer
        init(_ st: OpaquePointer) { self.st = st }
        func str(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(st, i) else { return "" }
            return String(cString: c)
        }
        func int(_ i: Int32) -> Int { Int(sqlite3_column_int64(st, i)) }
        func double(_ i: Int32) -> Double { sqlite3_column_double(st, i) }
    }

    /// Exécute un bloc sur la file de la base, sans bloquer l'écran.
    func read<T>(_ work: @escaping (Database) -> T) async -> T {
        await withCheckedContinuation { cont in
            queue.async { cont.resume(returning: work(self)) }
        }
    }

    /// Taille du fichier de la base (réglages).
    var fileSize: Int64 {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var total: Int64 = 0
        for name in ["prisme.sqlite", "prisme.sqlite-wal"] {
            let p = dir.appendingPathComponent(name).path
            if let a = try? FileManager.default.attributesOfItem(atPath: p), let s = a[.size] as? NSNumber { total += s.int64Value }
        }
        return total
    }
}
