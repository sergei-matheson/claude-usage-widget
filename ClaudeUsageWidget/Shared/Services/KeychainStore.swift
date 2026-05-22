import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case unexpectedData
    case unhandledError(OSStatus)
}

struct KeychainStore {
    // Must match the Keychain Sharing entitlement in both targets
    private let service = "com.yourorg.claudeusagewidget.session"
    private let accessGroup = "com.yourorg.claudeusagewidget"

    func save(_ credentials: SessionCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, [kSecValueData: data] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccessGroup: accessGroup,
                kSecValueData: data,
                // kSecAttrAccessibleAfterFirstUnlock allows the extension to read even before user unlock
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledError(updateStatus)
        }
    }

    func load() throws -> SessionCredentials {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
        guard let data = item as? Data else { throw KeychainError.unexpectedData }

        return try JSONDecoder().decode(SessionCredentials.self, from: data)
    }

    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
}
