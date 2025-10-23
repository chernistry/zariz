import Foundation
import LocalAuthentication
import Security

/// Stores refresh token and related metadata. Access requires biometrics.
enum AuthKeychainStore {
    private static let service = "app.zariz.auth"
    private static let account = "session"

    struct StoredSession: Codable {
        let refreshToken: String
        let userId: String
        let role: String
        let storeIds: [Int]
        let identifier: String?
    }

    static func save(refreshToken: String, user: AuthenticatedUser) throws {
        let payload = StoredSession(
            refreshToken: refreshToken,
            userId: user.userId,
            role: user.role.rawValue,
            storeIds: user.storeIds,
            identifier: user.identifier
        )
        let data = try JSONEncoder().encode(payload)

        var error: Unmanaged<CFError>?
        guard let sac = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: sac,
            kSecValueData as String: data
        ]
        SecItemDelete(addQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func load(prompt: String = "Authenticate to access session") throws -> StoredSession? {
        let context = LAContext()
        context.localizedReason = prompt
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return try JSONDecoder().decode(StoredSession.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
