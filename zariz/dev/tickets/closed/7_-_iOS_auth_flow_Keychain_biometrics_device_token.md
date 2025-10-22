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

Implementation Summary
- Keychain store: `zariz/ios/Zariz/Data/Security/KeychainTokenStore.swift` (SecAccessControl `.biometryCurrentSet`, WhenUnlockedThisDeviceOnly).
- Auth service/UI: `zariz/ios/Zariz/Features/Auth/AuthService.swift`, `Zariz/ios/Zariz/Features/Auth/AuthViewModel.swift`, `Zariz/ios/Zariz/Features/Auth/AuthView.swift`.
- App/session/push: `zariz/ios/Zariz/App/AppSession.swift`, `zariz/ios/Zariz/App/PushManager.swift`; wired in `zariz/ios/Zariz/App/ZarizApp.swift` with `@UIApplicationDelegateAdaptor`.
- Info.plist: added `NSFaceIDUsageDescription` message.

How to Verify
- `cd zariz/ios && xcodegen generate && open Zariz.xcodeproj`
- Run app (simulator/device). Enter subject (e.g. `1`) and role (`courier`), tap Sign In; token is stored in Keychain.
- When PushManager registers device, it POSTs `/v1/devices/register` with `{platform:"ios", token}` and Authorization header if JWT available.
- Reading token from Keychain prompts Face ID/Touch ID.

Notes
- APNs requires enabling Push Notifications capability and proper provisioning profiles; the code safely no-ops without real APNs on simulator.
- Do not log sensitive tokens. Adjust Keychain access control flags if UX requires userPresence instead of strict biometry set.

