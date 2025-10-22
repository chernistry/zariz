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

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Copy module scaffolds from `Dependencies/*` into `zariz/ios/Zariz/Modules/` (as Swift PM local packages or groups):
    - `DesignSystem`, `Core`, `Networking`, `Persistence`, `Coordinator`, `Analytics`, `TestUtils`.
    - Remove or stub anything not needed for MVP (e.g., advanced analytics hooks) but keep structure for growth.
  - Copy `Features/Authentication` to inform our auth flow (actual integration in Ticket 7), and `DeliveryApp/Coordinator` to bootstrap a Coordinator if desired alongside SwiftUI NavigationStack.
- From Swift-DeliveryApp:
  - Reuse SwiftUI view patterns (lists/cards/layouts) for early Orders list and details. Copy selected files from `DeliveryApp/View/*` into `Zariz/Features/Orders/UI/` and rename to match our domain (no restaurant/product wording).

Project structure (inside `zariz/ios/Zariz`)
```
Zariz/
  App/
    ZarizApp.swift
  Features/
    Auth/
    Orders/
  Data/
    Models/
      Order.swift
    API/
      APIClient.swift
      Config.swift
  Resources/
    Assets.xcassets
```

SwiftData model
```
// Zariz/Data/Models/Order.swift
import SwiftData

@Model
final class OrderEntity {
    @Attribute(.unique) var id: Int
    var status: String
    var pickupAddress: String
    var deliveryAddress: String

    init(id: Int, status: String, pickupAddress: String, deliveryAddress: String) {
        self.id = id
        self.status = status
        self.pickupAddress = pickupAddress
        self.deliveryAddress = deliveryAddress
    }
}
```

App entry
```
// Zariz/App/ZarizApp.swift
import SwiftUI
import SwiftData

@main
struct ZarizApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Zariz MVP")
        }
        .modelContainer(for: [OrderEntity.self])
    }
}
```

API Client (placeholder)
```
// Zariz/Data/API/Config.swift
enum AppConfig {
    static let baseURL = URL(string: "http://localhost:8000/v1")!
}

// Zariz/Data/API/APIClient.swift
import Foundation

struct APIClient {
    var token: String?

    func request(_ path: String) async throws -> Data {
        let url = AppConfig.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        if let token { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}
```

Verification
- Build and run in Xcode; app shows placeholder text.
- Confirm SwiftData compiles with iOS 17+ target.

Copy/Integrate
```
# Create modules directory
mkdir -p zariz/ios/Zariz/Modules
cp -R zariz/references/DeliveryApp-iOS/Dependencies/* zariz/ios/Zariz/Modules/ || true

# Bring in selected SwiftUI components as starting points for Orders UI
mkdir -p zariz/ios/Zariz/Features/Orders/UI
cp -R zariz/references/Swift-DeliveryApp/DeliveryApp/View/* zariz/ios/Zariz/Features/Orders/UI/ || true
```

Next
- Implement auth with Keychain in Ticket 7.
