# TICKET-27: iOS login crash after recent auth+concurrency changes; orders not appearing post-login; Keychain/biometrics + delegate isolation suspects

Priority: P0 (Blocker)

Owners: iOS (auth + concurrency), Backend (auth refresh contracts), QA

Labels: ios, auth, keychain, concurrency, swift6, push, sse, backend-sync, critical

## Problem Summary

- After recent auth/concurrency refactors, the iOS app crashes immediately after pressing “Login”. When the app is launched fresh, it sometimes opens the main screen with a previously cached session, but no orders are loaded. After logout, attempting to log back in causes a crash (Task 5: EXC_BREAKPOINT).
- We introduced changes in PushManager delegate isolation, SSE client sendability, and Keychain access control. We suspect either Swift 6 concurrency isolation violations (delegate closures) or Keychain LAContext/access-control edge-cases on simulator are causing the crash. Orders not appearing suggests post-login sync/session token flow may also be broken despite HTTP 200 responses in logs.

## Environment

- iOS target: 17+, Swift 6 concurrency checks enabled.
- Simulator devices: iPhone 17 Pro (iOS 26.0.1), others similar.
- Backend: FastAPI 3.12+, dev stack running on Docker; Gorush added for APNs.
- AppConfig baseURL currently points to `http://192.168.3.47:8000/v1`.

## Repro Steps

1) Launch app (clean run). If a session exists, app opens into the main (courier) screen but shows zero orders.
2) Tap logout in Profile.
3) Enter `courier` / `12345678`, tap Login.
4) App crashes with: `Task 5: EXC_BREAKPOINT (code=1, subcode=0x...)`.

Additional logs observed around sessions/networking (on device/sim console):

- `nw_socket_set_connection_idle [C*:2] setsockopt SO_CONNECTION_IDLE failed [42: Protocol not available]` (noise)
- `orders.sync.request path=orders` then `orders.sync.http code=200 bytes=327` then `orders.sync.parsed count=1 ids=12` (so HTTP is OK and JSON parsed)
- Orders still not present in UI after successful sync.

Backend quick check (works):
```
TOKEN=$(curl -sS -X POST http://localhost:8000/v1/auth/login_password -H 'Content-Type: application/json' -d '{"identifier":"courier","password":"12345678"}' | jq -r .access_token)
curl -sS http://localhost:8000/v1/orders -H "Authorization: Bearer $TOKEN" | jq
[
  { "id": 12, "store_id": 1, "courier_id": 5, "status": "assigned", ... }
]
```

## Recent Changes (likely correlated)

1) PushManager delegate isolation
   - We iterated between `@MainActor` on the type vs. `nonisolated` delegate methods.
   - We changed completion handlers to avoid capturing across isolation, then later reverted to immediate calls:
   ```swift
   extension PushManager: UNUserNotificationCenterDelegate, UIApplicationDelegate {
       nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
           completionHandler([.banner, .sound])
       }

       nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
           completionHandler(.noData)
           Task { await OrdersService.shared.sync() }
       }
   }
   ```
   - Earlier variants used `Task { @MainActor in ... }` or `await MainActor.run { completionHandler(...) }`, which the compiler warned could cause data races.

2) SSEClient sendability
   - We temporarily rewrote `SSEClient` with `UnsafeMutablePointer` and `@unchecked Sendable`, then reverted back to a simple class with a mutable `URLSessionDataTask?` and parsing queue:
   ```swift
   final class SSEClient: NSObject, @preconcurrency URLSessionDataDelegate {
       private var task: URLSessionDataTask?
       private var buffer = Data()
       private let url: URL
       private let onEvent: (Any) -> Void
       private let parseQueue = DispatchQueue(label: "sse.client.parse")
       // start/stop + parse implementation ...
   }
   ```

3) Keychain & biometrics fallbacks
   - We added a `makeAccessControl()` fallback cascade `.biometryCurrentSet` → `.biometryAny` → `.userPresence`; if none available (simulators), we store with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
   - We changed load() to always set `LAContext` + `interactionNotAllowed` (to avoid deprecated `kSecUseAuthenticationUIFail`).
   - We previously also attempted a secondary, context-free fallback for `errSecAuthFailed`; that was removed (could impact reading older items saved with stricter access control).

4) Auth flow and tokens
   - iOS client now performs real login via `/auth/login_password` and stores refresh in Keychain; access token in-memory.
   - Refresh uses `/auth/refresh` with refresh_token in body (not cookies).
   - App preloads session from Keychain on start (if present) and flips UI into authenticated state.

5) SwiftData migration
   - Earlier crash on migration (mandatory fields) fixed by making fields optional and suggesting one-time reinstall. App deletion recommended once.

## Current iOS Code Snippets (relevant)

AuthService (iOS):
```swift
actor AuthService {
    static let shared = AuthService()

    func login(identifier: String, password: String) async throws -> (AuthTokenPair, AuthenticatedUser) {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/login_password"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["identifier": identifier, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        // ... parse access/refresh, decode claims, compute exp ...
        try await AuthSession.shared.configure(pair: pair, user: user)
        return (pair, user)
    }

    func refresh() async throws -> AuthTokenPair {
        guard let stored = try AuthKeychainStore.load(prompt: "Authenticate to refresh session") else {
            throw NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "No stored session"])
        }
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/refresh"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": stored.refreshToken])
        // ... update session via AuthSession.configure ...
        return pair
    }
}
```

AuthSession (iOS):
```swift
actor AuthSession {
    static let shared = AuthSession()
    private var accessToken: String?
    private var accessTokenExp: Date?
    private(set) var currentUser: AuthenticatedUser?
    private var refreshingTask: Task<String, Error>?

    func configure(pair: AuthTokenPair, user: AuthenticatedUser) throws {
        self.accessToken = pair.accessToken
        self.accessTokenExp = pair.expiresAt
        self.currentUser = user
        try AuthKeychainStore.save(refreshToken: pair.refreshToken, user: user)
        NotificationCenter.default.post(name: .authSessionConfigured, object: user)
    }

    func validAccessToken() async throws -> String {
        if let token = accessToken, /* not near expiry */ { return token }
        if let task = refreshingTask { return try await task.value }
        let task = Task<String, Error> {
            let pair = try await AuthService.shared.refresh()
            self.accessToken = pair.accessToken
            self.accessTokenExp = pair.expiresAt
            return pair.accessToken
        }
        refreshingTask = task
        defer { refreshingTask = nil }
        return try await task.value
    }
}
```

OrdersService (iOS) excerpt:
```swift
private func authorizedRequest(path: String, method: String = "GET", body: Data? = nil, idempotencyKey: String? = nil) async -> URLRequest {
    var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent(path))
    req.httpMethod = method
    if let body { req.httpBody = body; req.addValue("application/json", forHTTPHeaderField: "Content-Type") }
    if let tok = await authToken() { req.addValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
    if let idk = idempotencyKey { req.addValue(idk, forHTTPHeaderField: "Idempotency-Key") }
    req.timeoutInterval = 20
    return req
}

private func authToken() async -> String? { try? await AuthSession.shared.validAccessToken() }
```

App startup session bootstrap:
```swift
@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager
    @StateObject private var session = AppSession()
    var body: some Scene {
        WindowGroup {
            Group { session.isAuthenticated ? MainTabs() : AuthView() }
                .onAppear {
                    if let s = try? AuthKeychainStore.load() {
                        let user = AuthenticatedUser(userId: s.userId, role: UserRole(rawValue: s.role) ?? .courier, storeIds: s.storeIds, identifier: s.identifier)
                        session.applyLogin(user: user)
                    }
                    pushManager.registerForPush()
                }
        }
    }
}
```

## Backend Context (auth endpoints)

FastAPI `/auth/login_password` returns `{ access_token, refresh_token }`.

FastAPI `/auth/refresh` expects body `{ refresh_token }` and returns a new pair; revokes the previous refresh session, issues a new one.

Note: Earlier logs showed bcrypt backend version warnings in passlib (not fatal) and some 401s on `/v1/auth/refresh`; ensure refresh flow is consistent.

## Observed Compiler/Runtime Diagnostics on iOS

- Build-time (addressed):
  - Using non-Sendable `completionHandler` across actors in PushManager delegate methods.
  - Stored property mutability warning for Sendable SSE client (resolved by reverting to simple, non-Sendable class and marking delegate as `@preconcurrency`).
- Runtime:
  - `Task 5: EXC_BREAKPOINT (code=1, ...)` right after pressing Login.
  - UI loads authenticated state from Keychain occasionally, but orders are not rendered despite successful `/orders` response and parse logs.

## Hypotheses (ranked)

1) Delegate isolation regression on Swift 6: mixing `@MainActor` class with `nonisolated` delegate methods and capturing closures previously triggered data-race warnings; although we now call handlers immediately, the `@UIApplicationDelegateAdaptor` lifecycle + `ObservableObject` state in `PushManager` might still cross isolation (e.g., `@Published deviceToken`) at awkward times.

2) Keychain LAContext mismatch: previously saved items used strict access control; new load path always sets `LAContext` with `interactionNotAllowed`, and we removed a fallback read. On login, `AuthSession.configure` saves refresh; a failure or inconsistent saved state could throw and bubble into a precondition somewhere, producing EXC_BREAKPOINT.

3) Session/auth refresh path immediately after login: `OrdersService.sync()` requests may hit `validAccessToken()` → `refresh()` and get a 401 or JSON mismatch, leaving app in inconsistent state (e.g., `currentUser` set but no orders and a crash).

4) SwiftData context availability: `OrdersListView` sets `ModelContextHolder.shared.context` in `.task`/`.onAppear`, but if an early sync happens before that, fetch/save could be nil-guarded; however code guards nil and logs errors — unlikely to crash.

## What We Tried (not resolved)

- Reworked PushManager to avoid capturing completion handlers across isolation boundaries; tried both `@MainActor` type and `nonisolated` delegate methods. Warnings resolved, but crash persists.
- Reverted SSEClient back to a simple, non-Sendable class to remove unsafe pointer usage.
- Implemented Keychain access-control fallbacks and `LAContext.interactionNotAllowed` use to avoid deprecated APIs.
- Confirmed backend `/auth/login_password` and `/orders` work via curl; the app logs show 200/parsed results, but UI remains empty.

## Ask (for AI assistant with web search)

Please provide a concrete, step-by-step resolution plan and code-level guidance for Swift 6 + FastAPI:

1) Concurrency-safe delegates
   - Exact recommended pattern for `UIApplicationDelegate` and `UNUserNotificationCenterDelegate` under Swift 6 sendability.
   - How to structure `PushManager` so `@Published` state stays main-thread-only while delegate methods remain `nonisolated` without triggering data races or runtime crashes.
   - Provide fully compiled signatures and minimal sample implementation, avoiding “sending completionHandler risks causing data races”.

2) Keychain + LAContext
   - Provide robust save/load patterns that work on simulator and device:
     - Access control choice when biometrics are unavailable.
     - How to read items saved previously with `.biometryCurrentSet` when biometrics are not configured.
     - Whether to keep a context-free fallback path; how to set `interactionNotAllowed` correctly.
     - Error handling strategy: ensure failures never crash login; surface actionable error to UI instead.
   - Provide tested sample code for both a token string and a JSON-encoded session payload.

3) Auth/refresh flow hardening
   - Recommend token lifecycle: when to call refresh post-login; handling 401/expired refresh; idempotency of refresh; retry/backoff.
   - Ensure `validAccessToken()` avoids concurrent refresh storms (our `refreshingTask` gate) and does not deadlock or crash.
   - Propose minimal telemetry we should log to pinpoint failures (e.g., labeled OSLog points for save/load/refresh paths, error codes, and decisions).

4) Orders not appearing
   - Given `/orders` returns 200 with entries and logs show parsed ids, propose where to add assertions/instrumentation in SwiftData pipeline to confirm upsert/save/fetch actually happen, and the list/filter pipeline shows them.
   - Suggest race-free ordering between setting `ModelContextHolder.shared.context` and the first `sync()` after login.

5) Diagnostics: reproduce & test
   - How to catch the `EXC_BREAKPOINT` reliably: recommended breakpoints (Swift error / exceptions / concurrency), and typical stacks for this pattern.
   - Propose minimal XCTest cases:
     - `AuthServiceTests` using `URLProtocol` stubs for login/refresh.
     - `KeychainStoreTests` verifying save/load roundtrip when LAContext can/can’t evaluate biometrics.

6) Backend contract sanity (brief)
   - Validate our login/refresh JSON contracts vs. secure cookie flow; confirm we’re aligned and won’t hit 401s for refresh right after login.
   - Recommend test vectors for `/auth/refresh` verifying revoke/rotate flow and 401s.

## Acceptance Criteria

- No crash after tapping Login (simulator + device).
- Orders appear in the list after login and refresh cycles (both immediate and periodic sync).
- No Swift 6 sendability warnings in PushManager or SSE client; no “sending completionHandler” warnings.
- Keychain works on simulator w/o biometrics and on device with biometrics on/off; login/logout/login repeatedly without crash.
- Telemetry shows:
  - `auth.login.success` with latency; `auth.refresh.success/failure` with codes.
  - `orders.sync.request/http/parsed` with counts; any SwiftData errors are logged with messages.

## Constraints / Non-Goals

- Keep change surface minimal; do not introduce third-party Keychain wrappers.
- No APNs delivery debugging required here (Gorush integration exists; separate ticket for push delivery).
- Do not rely on accessing our private repo; include code patterns inline (as above).

---

If you need more context, assume Swift 6 concurrency rules, iOS 17+, SwiftUI app lifecycle, FastAPI backend with JWT access + rotating refresh in body (not cookies). Provide code and explanations inline; no external file references.

