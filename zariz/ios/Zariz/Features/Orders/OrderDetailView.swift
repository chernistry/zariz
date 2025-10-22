import SwiftUI
import SwiftData

struct OrderDetailView: View {
    let orderId: Int
    @Environment(\.modelContext) private var ctx
    @Query private var items: [OrderEntity]

    init(orderId: Int) {
        self.orderId = orderId
        _items = Query(filter: #Predicate<OrderEntity> { $0.id == orderId })
    }

    var body: some View {
        if let o = items.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("Order #\(o.id)").font(.title2).bold()
                Text("Pickup: \(o.pickupAddress)")
                Text("Delivery: \(o.deliveryAddress)")
                HStack {
                    Button("Claim") { Task { try? await OrdersService.shared.claim(id: orderId, context: ctx) } }
                        .disabled(o.status != "new")
                    Button("Picked up") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up", context: ctx) } }
                        .disabled(o.status != "claimed")
                    Button("Delivered") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered", context: ctx) } }
                        .disabled(o.status != "picked_up")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        } else {
            ProgressView().task { await OrdersService.shared.sync(context: ctx) }
        }
    }
}

