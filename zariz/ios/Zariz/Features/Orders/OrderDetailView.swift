import SwiftUI
import SwiftData

struct OrderDetailView: View {
    let orderId: Int
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var session: AppSession
    @Query private var items: [OrderEntity]

    init(orderId: Int) {
        self.orderId = orderId
        _items = Query(filter: #Predicate<OrderEntity> { $0.id == orderId })
    }

    var body: some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if session.isDemoMode {
                        Button("Home") {
                            KeychainTokenStore.clear()
                            session.isAuthenticated = false
                        }
                    }
                    Button("Logout") {
                        KeychainTokenStore.clear()
                        session.isAuthenticated = false
                        session.isDemoMode = false
                    }
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if let o = items.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("Order #\(o.id)").font(.title2).bold()
                Text("Pickup: \(o.pickupAddress)")
                Text("Delivery: \(o.deliveryAddress)")
                HStack {
                    Button("Claim") { Task { try? await OrdersService.shared.claim(id: orderId) } }
                        .disabled(o.status != "new")
                    Button("Picked up") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up") } }
                        .disabled(o.status != "claimed")
                    Button("Delivered") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered") } }
                        .disabled(o.status != "picked_up")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        } else {
            ProgressView().task {
                await MainActor.run { ModelContextHolder.shared.context = ctx }
                await OrdersService.shared.sync()
            }
        }
    }
}
