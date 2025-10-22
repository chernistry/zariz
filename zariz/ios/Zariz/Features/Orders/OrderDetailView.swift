import SwiftUI
import SwiftData

struct OrderDetailView: View {
    let orderId: Int
    @Environment(\.modelContext) private var ctx
    @Query private var items: [OrderEntity]
    @EnvironmentObject private var toast: ToastCenter

    init(orderId: Int) {
        self.orderId = orderId
        _items = Query(filter: #Predicate<OrderEntity> { $0.id == orderId })
    }

    var body: some View {
        content
            .globalNavToolbar()
            .safeAreaInset(edge: .bottom) { bottomActionBar }
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

extension OrderDetailView {
    @ViewBuilder
    fileprivate var bottomActionBar: some View {
        if let o = items.first {
            let (title, action, enabled): (LocalizedStringKey, () -> Void, Bool) = {
                switch o.status {
                case "new":
                    return (LocalizedStringKey("claim"), {
                        Task {
                            try? await OrdersService.shared.claim(id: orderId)
                            await MainActor.run {
                                Haptics.success()
                                toast.show("toast_claimed", style: .success, icon: "checkmark.circle")
                            }
                        }
                    }, true)
                case "claimed":
                    return (LocalizedStringKey("picked_up"), {
                        Task {
                            try? await OrdersService.shared.updateStatus(id: orderId, status: "picked_up")
                            await MainActor.run {
                                Haptics.success()
                                toast.show("toast_picked_up", style: .success, icon: "checkmark.circle")
                            }
                        }
                    }, true)
                case "picked_up":
                    return (LocalizedStringKey("delivered"), {
                        Task {
                            try? await OrdersService.shared.updateStatus(id: orderId, status: "delivered")
                            await MainActor.run {
                                Haptics.success()
                                toast.show("toast_delivered", style: .success, icon: "checkmark.circle")
                            }
                        }
                    }, true)
                default:
                    return (LocalizedStringKey("delivered"), {}, false)
                }
            }()

            VStack(spacing: 0) {
                Divider()
                Button(title) { action() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!enabled)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                    .background(.ultraThinMaterial)
            }
        }
    }
}
