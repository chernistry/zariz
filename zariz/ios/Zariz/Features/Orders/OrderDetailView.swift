import Kingfisher
import SwiftData
import SwiftUI

struct OrderDetailView: View {
    let orderId: Int
    @Environment(\.modelContext) private var ctx
    @Query private var items: [OrderEntity]
    @EnvironmentObject private var toast: ToastCenter

    private let heroURL = URL(string: "https://images.unsplash.com/photo-1506617420156-8e4536971650?auto=format&fit=crop&w=1600&q=80")

    init(orderId: Int) {
        self.orderId = orderId
        _items = Query(filter: #Predicate<OrderEntity> { $0.id == orderId })
    }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()
            content
        }
        .globalNavToolbar()
        .safeAreaInset(edge: .bottom) { bottomActionBar }
    }

    @ViewBuilder
    private var content: some View {
        if let order = items.first {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    headerSection(order: order)
                    locationsSection(order: order)
                    statusTimeline(order: order)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
            }
        } else {
            ProgressView()
                .task {
                    await MainActor.run { ModelContextHolder.shared.context = ctx }
                    await OrdersService.shared.sync()
                }
        }
    }
}

extension OrderDetailView {
    @ViewBuilder
    fileprivate var bottomActionBar: some View {
        if let order = items.first {
            let (title, action, enabled): (LocalizedStringKey, () -> Void, Bool) = {
                switch order.status {
                case "new":
                    return (LocalizedStringKey("claim"), { performClaim(orderId: orderId) }, true)
                case "claimed":
                    return (LocalizedStringKey("picked_up"), { performStatusUpdate("picked_up") }, true)
                case "picked_up":
                    return (LocalizedStringKey("delivered"), { performStatusUpdate("delivered") }, true)
                default:
                    return (LocalizedStringKey("delivered"), {}, false)
                }
            }()

            VStack(spacing: 0) {
                Divider().background(DS.Color.divider)
                Button(title) { action() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!enabled)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Color.background)
            }
            .background(DS.Color.background)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
        }
    }

    private func performClaim(orderId: Int) {
        Task {
            do {
                try await OrdersService.shared.claim(id: orderId)
                await MainActor.run {
                    Haptics.success()
                    toast.show("toast_claimed", style: .success)
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    toast.show("toast_generic_error", style: .error)
                }
            }
        }
    }

    private func performStatusUpdate(_ status: String) {
        Task {
            do {
                try await OrdersService.shared.updateStatus(id: orderId, status: status)
                await MainActor.run {
                    Haptics.success()
                    switch status {
                    case "picked_up": toast.show("toast_picked_up", style: .success)
                    case "delivered": toast.show("toast_delivered", style: .success)
                    default: break
                    }
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    toast.show("toast_generic_error", style: .error)
                }
            }
        }
    }
}

private extension OrderDetailView {
    @ViewBuilder
    func headerSection(order: OrderEntity) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("\(String(localized: "order")) #\(order.id)")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text(order.status.localizedStatus)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: order.status.localizedStatus.uppercased(), color: order.status.statusColor)
                }
                KFImage(heroURL)
                    .placeholder { heroPlaceholder }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
            }
        }
    }

    @ViewBuilder
    func locationsSection(order: OrderEntity) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionRow(titleKey: "pickup", value: order.pickupAddress, icon: "shippingbox")
                Divider().background(DS.Color.divider)
                SectionRow(titleKey: "delivery", value: order.deliveryAddress, icon: "location")
            }
        }
    }

    @ViewBuilder
    func statusTimeline(order: OrderEntity) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("order_status_header")
                    .font(DS.Font.body.weight(.semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(OrderStatusStep.allCases, id: \.self) { step in
                        TimelineRow(
                            title: step.localizedTitle,
                            isCompleted: step.isCompleted(for: order.status),
                            isCurrent: step.isCurrent(for: order.status)
                        )
                    }
                }
            }
        }
    }

    var heroPlaceholder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.medium)
            .fill(DS.Color.surfaceElevated)
            .frame(height: 180)
            .shimmer()
    }
}

private struct SectionRow: View {
    let titleKey: LocalizedStringKey
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DS.Color.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(titleKey)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(value)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textPrimary)
            }
        }
    }
}

private enum OrderStatusStep: CaseIterable {
    case new, claimed, picked, delivered

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .new: return "status_new"
        case .claimed: return "status_claimed"
        case .picked: return "status_picked_up"
        case .delivered: return "status_delivered"
        }
    }

    func isCompleted(for status: String) -> Bool {
        guard let statusIndex = Self.sequence.firstIndex(of: status) else { return false }
        guard let current = Self.allCases.firstIndex(of: self) else { return false }
        return current < statusIndex
    }

    func isCurrent(for status: String) -> Bool {
        guard let statusIndex = Self.sequence.firstIndex(of: status) else { return self == .new }
        guard let current = Self.allCases.firstIndex(of: self) else { return false }
        return current == statusIndex
    }

    private static let sequence: [String] = ["new", "claimed", "picked_up", "delivered"]
}

private struct TimelineRow: View {
    let title: LocalizedStringKey
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .strokeBorder(isCurrent ? DS.Color.brandPrimary : DS.Color.brandPrimary.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.success)
                } else if isCurrent {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(DS.Color.brandPrimary)
                        .font(.system(size: 10))
                }
            }
            Text(title)
                .font(isCurrent ? DS.Font.body.weight(.semibold) : DS.Font.body)
                .foregroundStyle(isCurrent ? DS.Color.textPrimary : DS.Color.textSecondary)
            Spacer()
        }
    }
}

private extension String {
    var localizedStatus: String {
        switch self {
        case "new": return String(localized: "status_new")
        case "claimed": return String(localized: "status_claimed")
        case "picked_up": return String(localized: "status_picked_up")
        case "delivered": return String(localized: "status_delivered")
        case "canceled": return String(localized: "status_canceled")
        default: return self
        }
    }

    var statusColor: Color {
        switch self {
        case "new": return DS.Color.statusNew
        case "claimed": return DS.Color.statusClaimed
        case "picked_up": return DS.Color.statusPicked
        case "delivered": return DS.Color.statusDelivered
        case "canceled": return DS.Color.statusCanceled
        default: return DS.Color.textSecondary
        }
    }
}
