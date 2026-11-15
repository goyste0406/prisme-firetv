import Foundation
import Security

/// Mots de passe des fournisseurs dans le trousseau Apple de l'Apple TV (et plus dans les réglages ordinaires).
/// Un élément par fournisseur, retrouvé par son identifiant.
enum Keychain {
    private static let service = "prisme.provider"

    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    /// Enregistre (ou remplace) le mot de passe. Renvoie false si le trousseau refuse.
    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let data = Data(value.utf8)
        let q = base(account)
        let st = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if st == errSecSuccess { return true }
        if st != errSecItemNotFound { return false }
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: String) -> String? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func remove(_ account: String) {
        SecItemDelete(base(account) as CFDictionary)
    }
}
