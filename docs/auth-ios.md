# iOS Auth Flow — Zariz

Overview
- Real login using email/phone + password against `/v1/auth/login`.
- Access token held in memory; refresh token and metadata stored in Keychain with biometrics.
- Auto-refresh when access expiry < 2 minutes; background refresh on app activation.
- Logout calls `/v1/auth/logout`, clears session and stops sync.

Key Components
- `Zariz/Features/Auth/AuthService.swift` — login, refresh, logout, session bootstrap.
- `Zariz/Features/Auth/AuthModels.swift` — token/user models.
- `Zariz/Data/Security/AuthKeychainStore.swift` — Keychain storage (biometrics required).
- `Zariz/Features/Auth/AuthView.swift` — sign-in UI (email/phone + password).
- `Zariz/App/AppSession.swift` — current user + app auth state.
- `Zariz/Data/API/APIClient.swift` — attaches bearer and supports idempotency key.
- `Zariz/Features/Orders/OrdersService.swift` — uses bearer from session with auto-refresh.

Environment
- Base URL: `zariz/ios/Zariz/Data/API/Config.swift` → `AppConfig.baseURL` (defaults to `http://localhost:8000/v1`).
- Seed test users via TICKET-21 CLI (backend).

Local Run
1. Start backend with seeded admin/store/courier.
2. Open Xcode, run `Zariz` scheme on iOS 17+ simulator.
3. Sign in with test credentials; navigate Orders; background → foreground triggers refresh.
4. Logout from Profile.

Tests
- Unit: `xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing ZarizTests/AuthServiceTests`.
- UI: `xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing ZarizUITests/AuthFlowUITests`.

Security Notes
- Tokens never stored in UserDefaults; refresh token protected by biometrics (`biometryCurrentSet`).
- Logs redact secrets; auth events logged via `Telemetry.auth`.

