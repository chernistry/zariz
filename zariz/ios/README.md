# Zariz iOS

Scaffolded SwiftUI app with SwiftData and basic API client.

- App entry: `Zariz/App/ZarizApp.swift`
- SwiftData model: `Zariz/Data/Models/Order.swift`
- API client: `Zariz/Data/API/APIClient.swift`
- Config: `Zariz/Data/API/Config.swift`
- Assets: `Zariz/Resources/Assets.xcassets`
- Info: `Zariz/Supporting/Info.plist`
- Project config (XcodeGen): `project.yml`

Generate Xcode project:

```
brew install xcodegen
cd zariz/ios
xcodegen generate
open Zariz.xcodeproj
```

Targets:
- Zariz (iOS App)
- ZarizTests (Unit Tests)
- ZarizUITests (UI Tests)

Minimum iOS: 17.0; Swift: 6.0.

Auth & Orders
- Auth: `Features/Auth` implements real login (email/phone + password) calling `/v1/auth/login`; access token is kept in-memory; refresh token + metadata stored in Keychain with biometrics. Auto-refresh when expiry <2 minutes; logout calls `/v1/auth/logout` and clears session.
- Orders: `Features/Orders` has list/detail, syncing with backend and persisting with SwiftData. Claim and status actions call the API and refresh.

Background & Push
- Info.plist enables `remote-notification` and `fetch` background modes and permits BGTask identifier `app.zariz.orderUpdates`.
- `PushManager` registers for APNs and sends the device token to `/v1/devices/register`; on silent push, it triggers an orders sync.

Tests
- Unit: `ZarizTests/AuthServiceTests.swift` (mocked URLProtocol for login/refresh/logout).
- UI: `ZarizUITests/AuthFlowUITests.swift` for basic validation.
