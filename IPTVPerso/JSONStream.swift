import Foundation

/// Lecture « au fil de l'eau » des grandes listes des fournisseurs (films, séries, chaînes).
///
/// Avant (1.7) : la liste entière (parfois 60 Mo et plus) était gardée en mémoire puis transformée d'un coup en
/// centaines de milliers d'objets, deux fois de suite (vérification puis import) : avec un très gros fournisseur,
/// tvOS pouvait fermer l'appli faute de mémoire.
/// Maintenant : la réponse est enregistrée dans un fichier, puis lue titre par titre ; seule une ligne à la fois
/// est transformée en objet. La mémoire reste stable, quelle que soit la taille du catalogue.
enum JSONStream {
    enum Outcome: Equatable {
        /// liste lue en entier (nombre d'objets)
        case complete(Int)
        /// réponse coupée avant la fin (nombre d'objets lus avant la coupure) : à ne pas utiliser pour remplacer un catalogue
        case truncated(Int)
        /// la réponse n'est pas une liste (erreur du serveur, page HTML…)
        case notList
    }

    /// Appelle `body` pour chaque objet du tableau JSON du fichier. Un tableau d'objets imbriqué dans un objet
    /// (« { "1": {...}, "2": {...} } », que renvoient quelques serveurs) est lu de la même façon.
    static func forEachObject(file: URL, _ body: ([String: Any]) -> Void) -> Outcome {
        guard let data = try? Data(contentsOf: file, options: .alwaysMapped), !data.isEmpty else { return .notList }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Outcome in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return .notList }
            let n = raw.count
            var i = 0
            func skipSpace() { while i < n, base[i] == 0x20 || base[i] == 0x0A || base[i] == 0x0D || base[i] == 0x09 { i += 1 } }
            skipSpace()
            if i < n, base[i] == 0xEF, i + 2 < n { i += 3; skipSpace() }   // marque UTF-8 en tête
            guard i < n else { return .notList }
            let open = base[i]
            guard open == UInt8(ascii: "[") || open == UInt8(ascii: "{") else { return .notList }
            let isDict = open == UInt8(ascii: "{")
            i += 1
            var count = 0
            while true {
                skipSpace()
                guard i < n else { return .truncated(count) }
                let c = base[i]
                if c == UInt8(ascii: ",") { i += 1; continue }
                if (!isDict && c == UInt8(ascii: "]")) || (isDict && c == UInt8(ascii: "}")) { return .complete(count) }
                if isDict {
                    // « "clé" : » puis la valeur
                    guard c == UInt8(ascii: "\"") else { return count == 0 ? .notList : .truncated(count) }
                    guard let e = endOfString(base, n, i) else { return .truncated(count) }
                    i = e + 1; skipSpace()
                    guard i < n, base[i] == UInt8(ascii: ":") else { return .truncated(count) }
                    i += 1; skipSpace()
                    guard i < n else { return .truncated(count) }
                }
                guard let end = endOfValue(base, n, i) else { return .truncated(count) }
                if base[i] == UInt8(ascii: "{") {
                    let slice = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: base + i), count: end - i + 1, deallocator: .none)
                    autoreleasepool {
                        if let o = (try? JSONSerialization.jsonObject(with: slice)) as? [String: Any] { body(o); count += 1 }
                    }
                } else if isDict && count == 0 && base[i] != UInt8(ascii: "{") {
                    // objet qui n'est pas une liste d'objets (message d'erreur du serveur)
                    return .notList
                }
                i = end + 1
            }
        }
    }

    /// Fin d'une chaîne qui commence à `start` (guillemet ouvrant) : position du guillemet fermant.
    private static func endOfString(_ b: UnsafePointer<UInt8>, _ n: Int, _ start: Int) -> Int? {
        var j = start + 1
        while j < n {
            let c = b[j]
            if c == UInt8(ascii: "\\") { j += 2; continue }
            if c == UInt8(ascii: "\"") { return j }
            j += 1
        }
        return nil
    }

    /// Fin d'une valeur JSON qui commence à `start` : objet, tableau, chaîne ou valeur simple.
    private static func endOfValue(_ b: UnsafePointer<UInt8>, _ n: Int, _ start: Int) -> Int? {
        let c = b[start]
        if c == UInt8(ascii: "\"") { return endOfString(b, n, start) }
        if c == UInt8(ascii: "{") || c == UInt8(ascii: "[") {
            var depth = 0, j = start
            while j < n {
                let x = b[j]
                if x == UInt8(ascii: "\"") { guard let e = endOfString(b, n, j) else { return nil }; j = e + 1; continue }
                if x == UInt8(ascii: "{") || x == UInt8(ascii: "[") { depth += 1 }
                else if x == UInt8(ascii: "}") || x == UInt8(ascii: "]") { depth -= 1; if depth == 0 { return j } }
                j += 1
            }
            return nil
        }
        // nombre, true, false, null : jusqu'à la virgule ou la fin du tableau
        var j = start
        while j < n, b[j] != UInt8(ascii: ","), b[j] != UInt8(ascii: "]"), b[j] != UInt8(ascii: "}") { j += 1 }
        return j < n ? j - 1 : nil
    }
}

/// Listes d'un fournisseur enregistrées dans des fichiers : téléchargées une fois à la vérification d'un nouveau
/// fournisseur, réutilisées par l'import qui suit (au lieu de tout retélécharger). Effacées après l'import,
/// et de toute façon au bout d'une heure.
enum ListFiles {
    static var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("import", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// nom de fichier propre au compte (serveur + identifiant) et à la liste demandée
    static func file(account: XtreamAccount, action: String) -> URL {
        var h: UInt64 = 1469598103934665603
        for b in (account.baseURL + "|" + account.username + "|" + action).utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return dir.appendingPathComponent(String(h, radix: 36) + ".json")
    }

    /// fichier encore valable (moins d'une heure) laissé par la vérification
    static func fresh(account: XtreamAccount, action: String) -> URL? {
        let f = file(account: account, action: action)
        guard let a = try? FileManager.default.attributesOfItem(atPath: f.path), let d = a[.modificationDate] as? Date,
              Date().timeIntervalSince(d) < 3600, ((a[.size] as? NSNumber)?.intValue ?? 0) > 0 else { return nil }
        return f
    }

    /// Télécharge la liste dans son fichier (jamais en mémoire). Une coupure réseau : une seule nouvelle tentative.
    static func download(_ url: URL, to dest: URL, timeout: Double = 180) async throws {
        var lastError: Error = XtreamError.badURL
        for attempt in 0..<2 {
            do {
                var r = URLRequest(url: url); r.timeoutInterval = timeout
                let (tmp, resp) = try await URLSession.shared.download(for: r)
                if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
                    try? FileManager.default.removeItem(at: tmp)
                    throw XtreamError.badStatus(h.statusCode)
                }
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                return
            } catch let e as XtreamError {
                throw e   // réponse claire du serveur : inutile de réessayer
            } catch {
                lastError = error
                if attempt == 0 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
            }
        }
        throw lastError
    }

    /// ménage : fichiers de plus d'une heure
    static func purgeOld() {
        guard let L = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for f in L {
            let d = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(d) > 3600 { try? FileManager.default.removeItem(at: f) }
        }
    }
}
