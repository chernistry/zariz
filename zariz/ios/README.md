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

