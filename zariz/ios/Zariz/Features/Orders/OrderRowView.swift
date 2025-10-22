import SwiftUI

struct OrderRowView: View {
    let id: Int
    let status: String
    let pickup: String
    let delivery: String

    private func badge(for status: String) -> StatusBadge {
        switch status {
        case "new": return StatusBadge(text: String(localized: "status_new"), color: DS.Color.statusNew)
        case "claimed": return StatusBadge(text: String(localized: "status_claimed"), color: DS.Color.statusClaimed)
        case "picked_up": return StatusBadge(text: String(localized: "status_picked_up"), color: DS.Color.statusPicked)
        case "delivered": return StatusBadge(text: String(localized: "status_delivered"), color: DS.Color.statusDelivered)
        case "canceled": return StatusBadge(text: String(localized: "status_canceled"), color: DS.Color.statusCanceled)
        default: return StatusBadge(text: status, color: .gray)
        }
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                RemoteAvatarView(identifier: "order-\(id)-\(pickup)")
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text("#\(id)")
                            .font(DS.Font.numeric())
                            .foregroundStyle(DS.Color.textPrimary)
                        badge(for: status)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label {
                            Text(pickup)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Color.textPrimary)
                        } icon: {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(DS.Color.statusNew)
                        }
                        Label {
                            Text(delivery)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Color.textPrimary)
                        } icon: {
                            Image(systemName: "location")
                                .foregroundStyle(DS.Color.statusClaimed)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
