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
        content
            .globalNavToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if let o = items.first {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("\(String(localized: "order")) #\(o.id)").font(.title2).bold()
                    Spacer()
                    StatusBadge(text: o.status, color: .gray)
                }
                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(alignment: .top) {
                            Image(systemName: "shippingbox")
                            Text("\(String(localized: "pickup")): \(o.pickupAddress)").font(.subheadline)
                        }
                        Divider()
                        HStack(alignment: .top) {
                            Image(systemName: "location")
                            Text("\(String(localized: "delivery")): \(o.deliveryAddress)").font(.subheadline)
                        }
                    }
                }
                VStack(spacing: DS.Spacing.md) {
                    Button(String(localized: "claim")) { Task { try? await OrdersService.shared.claim(id: orderId) } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(o.status != "new")
                    Button(String(localized: "picked_up")) { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up") } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(o.status != "claimed")
                    Button(String(localized: "delivered")) { Task { try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered") } }
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

