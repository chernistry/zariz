Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-22] iOS — Real Login Flow and Session Management

Goal
- Replace the demo-only login with a secure email/phone + password flow backed by TICKET-21 APIs, persisting tokens safely and enforcing role-based routing inside the app.

Context
- `AuthView` currently accepts any `subject`/`role` pair (or demo toggle) and saves a fake token. API calls succeed without Authorization headers. Users cannot log out or recover sessions, making production onboarding impossible.
- Backend will expose `POST /v1/auth/login`, `/refresh`, `/logout` with JWT + refresh tokens.

Scope
1) UI/UX updates
   - Add secure `SecureField` for password, inline validation (non-empty, ≥8 chars), and localized error states.
   - Provide login identifier text field accepting email or phone; show network activity indicator + disable button during requests.
   - Present forgot-password CTA (links to mailto:ops@zariz); hide demo toggle behind `Settings > Developer`.
2) Networking & services
   - Replace `AuthService.login(subject:role:)` with `login(identifier: String, password: String)` returning `AuthTokenPair` (access, refresh, expiresAt, refreshExpiresAt, role, userId, storeIds).
   - Implement `refresh()` to call `/auth/refresh` when access token expires; integrate with `APIClient` request pipeline using async interceptor and NWPathMonitor fail-fast.
   - Store tokens in Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), track expiry in `AppSession`.
3) Session state
   - Extend `AppSession` with `currentUser` model (id, role, storeIds, email/phone) and `isAuthenticated` derived from token presence; add logout method to clear tokens and call backend `/auth/logout`.
   - Ensure onboarding flow revalidates session on launch (silent refresh) and handles revoked tokens by presenting login screen.
4) Security & observability
   - Redact passwords in logs, use OSLog category `auth`.
   - Add `Telemetry.log` events (`auth.login.success/failure`, latency).
5) Tests & docs
   - XCTest: `AuthServiceTests` mocking URLProtocol for success, 401, refresh, logout.
   - UI tests: `AuthFlowUITests` verifying login screen handles invalid credentials, success transitions to orders list.
   - Update `README-ios.md` (if missing add) with login instructions and environment setup.

Plan
1. Update models (`AuthTokenPair`, `AuthenticatedUser`) in `AuthService`.
2. Refactor `APIClient` to inject `AuthSessionProvider` that attaches bearer token and triggers refresh with jittered retry (max 3 attempts, 2s timeout).
3. Rewrite `AuthViewModel` to validate inputs, call new service, emit detailed errors; update `AuthView` UI and localization keys.
4. Add background refresh task (`Task.detached`) invoked when app becomes active and token expiry <5 min.
5. Implement logout button in profile/global toolbar; ensure `OrdersSyncManager` stops on logout.
6. Write unit tests using stubbed `URLProtocol`; add UI test scenario with mocked backend (via launch arguments toggling stub server).
7. Update localization strings for new labels/errors in `Localizable.strings` (en/he/ru/ar).
8. Document new flow in `docs/auth-ios.md`, including how to seed test users from TICKET-21 CLI.

Verification
- `xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing ZarizTests/AuthServiceTests`.
- Run `AuthFlowUITests` to ensure login screen handles invalid password and success path.
- Manual: launch app, login with seeded user, observe Authorization header on orders sync (charles proxy), logout removes tokens and shows login screen.

File references / Changes
- `zariz/ios/Zariz/Features/Auth/AuthService.swift`, `AuthView.swift`, `AuthViewModel.swift`
- `zariz/ios/Zariz/App/AppSession.swift`, `PushManager.swift` (logout integration), `OrdersSyncManager.swift`
- `zariz/ios/Zariz/Networking/APIClient.swift` (or equivalent)
- `zariz/ios/Zariz/Resources/Localizable.strings` (all locales)
- `zariz/ios/ZarizTests/AuthServiceTests.swift`, `zariz/ios/ZarizUITests/AuthFlowUITests.swift`
- `docs/auth-ios.md` (new)

Notes
- Ensure biometrics unlock reuses Keychain token (optional follow-up for stored sessions).
- Coordinate release toggle with backend deployment; keep demo mode behind compile-time flag for internal builds only.
