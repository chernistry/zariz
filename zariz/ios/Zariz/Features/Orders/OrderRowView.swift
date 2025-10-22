import SwiftUI

struct OrderRowView: View {
    let id: Int
    let status: String
    let pickup: String
    let delivery: String

    private func badge(for status: String) -> StatusBadge {
        switch status {
        case "new": return StatusBadge(text: "New", color: DS.Color.statusNew)
        case "claimed": return StatusBadge(text: "Claimed", color: DS.Color.statusClaimed)
        case "picked_up": return StatusBadge(text: "Picked", color: DS.Color.statusPicked)
        case "delivered": return StatusBadge(text: "Done", color: DS.Color.statusDelivered)
        case "canceled": return StatusBadge(text: "Canceled", color: DS.Color.statusCanceled)
        default: return StatusBadge(text: status, color: .gray)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("#\(id)").font(.headline)
                    badge(for: status)
                }
                Text("Pickup: \(pickup)").font(.subheadline).foregroundStyle(DS.Color.textSecondary)
                Text("Delivery: \(delivery)").font(.subheadline).foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}

