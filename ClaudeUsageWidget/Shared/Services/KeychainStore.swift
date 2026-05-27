import Foundation
import Security

enum KeychainError: Error, Equatable {
    case notFound
    case unexpectedData
    case unhandledError(OSStatus)
}

struct KeychainStore {
    private let service: String
    private let accessGroup: String?

    // Production init — uses the shared access group so both the app and widget extension can read credentials
    init() {
        // Must match the Keychain Sharing entitlement in both targets
        self.service = "io.github.sergei-matheson.claudeusagewidget.session"
        // $(AppIdentifierPrefix) expands to TeamID + "." at build time, so the runtime value is HR4LVL7TKY.io.github.sergei-matheson.claudeusagewidget
        self.accessGroup = "HR4LVL7TKY.io.github.sergei-matheson.claudeusagewidget"
    }

    // Internal init for testing — pass a unique service name and omit the access group so tests run in the sandbox
    init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func save(_ credentials: SessionCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData: data] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery()
            addQuery[kSecValueData] = data
            // kSecAttrAccessibleAfterFirstUnlock allows the extension to read even before user unlock
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledError(updateStatus)
        }
    }

    func load() throws -> SessionCredentials {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
        guard let data = item as? Data else { throw KeychainError.unexpectedData }

        return try JSONDecoder().decode(SessionCredentials.self, from: data)
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    private func baseQuery() -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        return query
    }
}
