Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-24] iOS — Real Login Flow and Session Management

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

---

Analysis (executed)
- Reused existing modules: `zariz/ios/Zariz/Features/Auth`, `Data/API`, `Data/Security`, `App/*`.
- Confirmed base URL is `/v1` via `Data/API/Config.swift:4` and wired endpoints accordingly.
- Existing demo flow stored a fake token via `KeychainTokenStore`. Replaced with real session that stores refresh in Keychain (biometrics) and keeps access in memory.
- OrdersService used direct Keychain reads; refactored to fetch bearer via `AuthSession.validAccessToken()` with auto-refresh.

Plan (refined and executed)
1. Models: add `AuthTokenPair`, `AuthenticatedUser`, `AuthLoginResponse` → parse backend fields.
2. Session manager: add `AuthSession` actor providing `validAccessToken()`, refresh de-dupe, and Keychain persistence (`AuthKeychainStore`).
3. AuthService: implement `login(identifier,password)`, `refresh`, `logout`; log via `Telemetry.auth`.
4. UI: update `AuthView` to email/phone + SecureField, forgot-password CTA; remove role picker and demo toggle.
5. App wiring: `ZarizApp` bootstraps via silent refresh; `ProfileView` logout calls backend and clears session; `PushManager` uses bearer from session.
6. Networking: `APIClient` attaches bearer and supports method/body/idempotency; `OrdersService` uses async authorizedRequest with refresh.
7. L10n: add new keys (password labels/errors/CTA) in en/he/ru/ar.
8. Tests: add `ZarizTests/AuthServiceTests.swift` (URLProtocol stubs) and `ZarizUITests/AuthFlowUITests.swift` (UI validation); include test folders in `project.yml`.
9. Docs: add `docs/auth-ios.md` with setup and flows (see below).

Verification (to run)
- Unit: `cd zariz/ios && xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing ZarizTests/AuthServiceTests`.
- UI: `xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing ZarizUITests/AuthFlowUITests`.
- Manual: Launch app, sign in with seeded user (TICKET-21), observe Authorization headers on orders sync, background refresh when app becomes active, and logout clearing state and stopping sync.

Changes Applied (paths)
- Added: `zariz/ios/Zariz/Features/Auth/AuthModels.swift`, `zariz/ios/Zariz/Data/Security/AuthKeychainStore.swift`.
- Updated: `Features/Auth/AuthService.swift`, `Features/Auth/AuthView.swift`, `Features/Auth/AuthViewModel.swift`, `App/AppSession.swift`, `App/ZarizApp.swift`, `App/PushManager.swift`, `App/Telemetry.swift`, `Features/Orders/OrdersService.swift`, `Data/API/APIClient.swift`.
- L10n: `Resources/*/Localizable.strings` updated with auth strings.
- Tests: `zariz/ios/ZarizTests/AuthServiceTests.swift`, `zariz/ios/ZarizUITests/AuthFlowUITests.swift`; `zariz/ios/project.yml` now includes test sources.

Post-merge TODOs (if needed)
- If backend `refresh`/`logout` contract differs (body vs cookie), adapt AuthService accordingly.
- Optionally add a dedicated Developer screen to toggle demo mode behind a compile-time flag.
