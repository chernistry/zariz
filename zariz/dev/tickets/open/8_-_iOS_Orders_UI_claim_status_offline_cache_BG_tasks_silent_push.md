Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: iOS Orders UI, claim/status, offline cache, BG tasks + silent push

Objective
- Implement Orders list/detail screens, claim and status update calls.
- Sync with backend; persist in SwiftData for offline-first.
- Handle silent push + background refresh to update data.

Deliverables
- `OrdersListView` and `OrderDetailView` with actions.
- `OrdersService` to fetch/claim/update status.
- Background task registration and silent push handler.

Reference-driven accelerators (copy/adapt)
- From Swift-DeliveryApp:
  - Copy view patterns for lists/cards (e.g., `HomePageView`, item cells) and adapt to our Orders domain; place under `Zariz/Features/Orders/UI/`.
  - Copy lightweight models folder as a template for DTOs → convert to our `OrderDTO` (remove restaurant/product specifics).
- From DeliveryApp-iOS:
  - Use `Dependencies/DesignSystem` for typography/colors/spacings so screens look consistent. Import DS components into our Orders views.
  - Consider `Coordinator` for navigation if needed beyond simple NavigationStack.

UI
```
// Zariz/Features/Orders/OrdersListView.swift
import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    var body: some View {
        List(orders) { o in
            NavigationLink("#\(o.id) • \(o.status)", value: o.id)
        }
        .task { await OrdersService.shared.sync() }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationTitle("Orders")
    }
}
```

Detail
```
// Zariz/Features/Orders/OrderDetailView.swift
import SwiftUI
import SwiftData

struct OrderDetailView: View {
    let orderId: Int
    @Query(filter: #Predicate<OrderEntity> { $0.id == orderId }) var items: [OrderEntity]
    var body: some View {
        if let o = items.first {
            VStack(alignment: .leading, spacing: 12) {
                Text(o.pickupAddress)
                Text(o.deliveryAddress)
                HStack {
                    Button("Claim") { Task { try? await OrdersService.shared.claim(id: orderId) } }
                    Button("Picked up") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up") } }
                    Button("Delivered") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered") } }
                }
            }.padding()
        } else { Text("Loading...") }
    }
}
```

Service
```
// Zariz/Features/Orders/OrdersService.swift
import Foundation
import SwiftData

final class OrdersService {
    static let shared = OrdersService()
    private let client = APIClient(token: try? Keychain.readJWT())

    func sync() async {
        do {
            let data = try await client.request("orders")
            let list = try JSONDecoder().decode([OrderDTO].self, from: data)
            await MainActor.run {
                for o in list { upsert(o) }
            }
        } catch { print("sync error", error) }
    }

    func claim(id: Int) async throws {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("orders/\(id)/claim"))
        req.httpMethod = "POST"
        let _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    func updateStatus(id: Int, status: String) async throws {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("orders/\(id)/status"))
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    private func upsert(_ o: OrderDTO) {
        // map DTO to SwiftData entity
        // fetch or insert by id
    }
}

struct OrderDTO: Codable { let id: Int; let status: String; let pickup_address: String; let delivery_address: String }
```

Background updates and silent push
```
// In ZarizApp.swift
.backgroundTask(.appRefresh("orderUpdates")) {
    await OrdersService.shared.sync()
}
```
Handle APNs silent push in AppDelegate (SceneDelegate) to trigger the same sync.

Verification
- List displays backend orders; actions perform claim/status updates; UI refreshes.
- Background sync executes on push or scheduled refresh.

Copy/Integrate
```
# Ensure DesignSystem is available to Orders UI
ls zariz/ios/Zariz/Modules/DesignSystem || cp -R zariz/references/DeliveryApp-iOS/Dependencies/DesignSystem zariz/ios/Zariz/Modules/DesignSystem

# Bring additional SwiftUI views as needed from Swift-DeliveryApp
cp -R zariz/references/Swift-DeliveryApp/DeliveryApp/View/* zariz/ios/Zariz/Features/Orders/UI/ || true
```

Next
- Configure iOS CI/TestFlight in Ticket 9.
