Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: iOS bootstrap (SwiftUI, modules, SwiftData models)

Objective
- Create SwiftUI project “Zariz” with modular folders and SwiftData models.
- Add networking layer (URLSession + simple client) and config.

Deliverables
- Xcode project with targets: Zariz (App), ZarizTests, ZarizUITests.
- Folder structure and SwiftData @Model entities for Order.
- Basic API client placeholder and config management.

Implementation Summary
- App entry: `zariz/ios/Zariz/App/ZarizApp.swift` using `.modelContainer(for: [OrderEntity.self])`.
- SwiftData model: `zariz/ios/Zariz/Data/Models/Order.swift`.
- API client/config: `zariz/ios/Zariz/Data/API/APIClient.swift`, `zariz/ios/Zariz/Data/API/Config.swift`.
- Assets scaffold: `zariz/ios/Zariz/Resources/Assets.xcassets`.
- Info: `zariz/ios/Zariz/Supporting/Info.plist`.
- XcodeGen config: `zariz/ios/project.yml` for Zariz, ZarizTests, ZarizUITests targets (iOS 17, Swift 6).
- README with generation instructions: `zariz/ios/README.md`.

How to Verify
- `brew install xcodegen`
- `cd zariz/ios && xcodegen generate && open Zariz.xcodeproj`
- Build and run: see "Zariz MVP" text; SwiftData compiles for iOS 17+.

Notes
- Modules directory `zariz/ios/Zariz/Modules` reserved for future imports from `DeliveryApp-iOS/Dependencies/*`.
- UI components from `Swift-DeliveryApp` can be copied into `Features/Orders/UI` in later tickets.

