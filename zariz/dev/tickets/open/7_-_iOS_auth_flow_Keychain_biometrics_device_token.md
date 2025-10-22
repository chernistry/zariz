Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: iOS auth flow, Keychain (biometrics), device token

Objective
- Add login UI and API call returning JWT.
- Store token in Keychain with AccessControl (Face ID/Touch ID).
- Register APNs device token with backend.

Deliverables
- `AuthView` with phone/email and sign-in button.
- `AuthService` performing `POST /v1/auth/login`.
- Keychain storage bound to biometrics using SecAccessControl.
- APNs registration and `/v1/devices/register` call.

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Copy `Features/Authentication` components (face/touch validation and auth coordinator) into `zariz/ios/Zariz/Features/Auth/` and strip views you don’t need.
  - Copy `Dependencies/Persistence` Keychain wrapper and adapt it to store our JWT bound to biometrics; ensure `NSFaceIDUsageDescription` in Info.plist.
- From Swift-DeliveryApp:
  - Optional: reuse any lightweight sign-in screens for form styling.

Auth UI
```
// Zariz/Features/Auth/AuthView.swift
import SwiftUI

struct AuthView: View {
    @State private var login: String = ""
    @State private var token: String?
    var body: some View {
        VStack {
            TextField("Phone or Email", text: $login)
                .textContentType(.username)
                .textFieldStyle(.roundedBorder)
            Button("Sign In") { Task { try? await signIn() } }
        }.padding()
    }
    func signIn() async throws {
        let t = try await AuthService.shared.login(login: login)
        try Keychain.storeJWT(t)
        token = t
    }
}
```

AuthService
```
// Zariz/Features/Auth/AuthService.swift
import Foundation

final class AuthService {
    static let shared = AuthService()
    func login(login: String) async throws -> String {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/login"))
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: ["login": login])
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["access_token"] as! String
    }
}
```

Keychain storage (biometrics)
```
// Zariz/Data/Security/Keychain.swift
import Foundation
import Security

enum Keychain {
    static let service = "app.zariz.jwt"
    static func storeJWT(_ token: String) throws {
        let data = token.data(using: .utf8)!
        var error: Unmanaged<CFError>?
        let sac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryCurrentSet, &error)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "token",
            kSecAttrAccessControl as String: sac,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    static func readJWT() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return String(data: data, encoding: .utf8)
    }
}
```

APNs registration
- Add `UIApplication.shared.registerForRemoteNotifications()` after permission.
- Implement `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` to obtain token, send to `/v1/devices/register`.

Copy/Integrate
```
# Authentication feature & Keychain wrapper from DeliveryApp-iOS
mkdir -p zariz/ios/Zariz/Features/Auth
cp -R zariz/references/DeliveryApp-iOS/Features/Authentication/* zariz/ios/Zariz/Features/Auth/ || true
cp -R zariz/references/DeliveryApp-iOS/Dependencies/Persistence/* zariz/ios/Zariz/Modules/Persistence/ || true

# Review & rename types to avoid conflicts; align token storage key and AccessControl flags.
```

Info.plist
- Add `NSUserTrackingUsageDescription` if needed and `NSFaceIDUsageDescription` for biometrics prompt.

Verification
- Sign in; Keychain stores token and prompts Face ID when reading later.
- APNs token registered (stub okay without actual APNs in dev).

Next
- Orders UI and background sync in Ticket 8.
