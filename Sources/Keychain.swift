import Foundation
import Security

/// Guarda a credencial do slskd no Keychain do aparelho.
enum Keychain {
    private static let service = "com.samflix.sonda.slskd"

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func set(_ value: String, for account: String) {
        let data = Data(value.utf8)
        var base = query(account)
        base[kSecValueData as String] = data
        base[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemDelete(query(account) as CFDictionary)
        SecItemAdd(base as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        var base = query(account)
        base[kSecReturnData as String] = true
        base[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(base as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
