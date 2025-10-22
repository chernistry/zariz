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
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("Order #\(o.id)").font(.title2).bold()
                    Spacer()
                    StatusBadge(text: o.status, color: .gray)
                }
                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(alignment: .top) {
                            Image(systemName: "shippingbox")
                            Text("Pickup: \(o.pickupAddress)").font(.subheadline)
                        }
                        Divider()
                        HStack(alignment: .top) {
                            Image(systemName: "location")
                            Text("Delivery: \(o.deliveryAddress)").font(.subheadline)
                        }
                    }
                }
                VStack(spacing: DS.Spacing.md) {
                    Button("Claim") { Task { try? await OrdersService.shared.claim(id: orderId) } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(o.status != "new")
                    Button("Picked Up") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up") } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(o.status != "claimed")
                    Button("Delivered") { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered") } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(o.status != "picked_up")
                }
                Spacer()
            }
            .padding(DS.Spacing.lg)
        } else {
            ProgressView().task {
                await MainActor.run { ModelContextHolder.shared.context = ctx }
                await OrdersService.shared.sync()
            }
        }
    }
}
