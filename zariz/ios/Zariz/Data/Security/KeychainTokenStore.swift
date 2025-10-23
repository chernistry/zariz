import Foundation
import LocalAuthentication
import Security

enum KeychainTokenStore {
    private static let service = "app.zariz.jwt"
    private static let account = "token"

    static func save(token: String) throws {
        let data = Data(token.utf8)
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        if let sac = makeAccessControl() {
            addQuery[kSecAttrAccessControl as String] = sac
        } else {
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        // Replace if exists
        SecItemDelete(addQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func load(prompt: String = "Authenticate to access") throws -> String? {
        var baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let context = LAContext()
        context.localizedReason = prompt
        let canAuth = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ||
                      context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        context.interactionNotAllowed = !canAuth
        baseQuery[kSecUseAuthenticationContext as String] = context
        var item: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled:
            return nil
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
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
            Telemetry.auth.error("auth.keychain.token_access_control_fallback error=\(lastError.localizedDescription, privacy: .public)")
        }
        return nil
    }
}
