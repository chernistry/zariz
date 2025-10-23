import Foundation
import LocalAuthentication
import Security

/// Stores refresh token and related metadata. Access can require biometrics/passcode based on availability.
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

        let accessControl = makeAccessControl()
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        if let accessControl {
            addQuery[kSecAttrAccessControl as String] = accessControl
        } else {
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        SecItemDelete(addQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func makeAccessControl() -> SecAccessControl? {
        let candidates: [SecAccessControlCreateFlags] = [
            [.biometryCurrentSet],
            [.biometryAny],
            [.userPresence]
        ]
        var lastError: Error?
        for flags in candidates {
            var error: Unmanaged<CFError>?
            if let sac = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                flags,
                &error
            ) {
                return sac
            }
            if let err = error?.takeRetainedValue() {
                lastError = err as Error
            }
        }
        if let lastError {
            Telemetry.auth.error("auth.keychain.access_control_fallback error=\(lastError.localizedDescription, privacy: .public)")
        }
        return nil
    }

    /// Load session from Keychain.
    /// - Parameter prompt: If provided, allows authentication UI with this message. If nil, skips UI.
    static func load(prompt: String? = nil) throws -> StoredSession? {
        var baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let prompt {
            let context = LAContext()
            context.localizedReason = prompt
            baseQuery[kSecUseAuthenticationContext as String] = context
        } else {
            baseQuery[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            return try JSONDecoder().decode(StoredSession.self, from: data)
        case errSecItemNotFound:
            return nil
        case errSecAuthFailed:
            if prompt == nil { return nil }
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        case errSecUserCanceled:
            return nil
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func makeLAContext(prompt: String?) -> LAContext {
        let ctx = LAContext()
        if let reason = prompt {
            ctx.localizedReason = reason
            ctx.interactionNotAllowed = false
        } else {
            ctx.interactionNotAllowed = true
        }
        return ctx
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
