import SwiftUI

struct SkeletonOrderRow: View {
    var body: some View {
        Card {
            HStack(spacing: DS.Spacing.lg) {
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(DS.Color.surfaceElevated)
                    .frame(width: 60, height: 60)
                    .shimmer()
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.Color.surfaceElevated)
                        .frame(width: 120, height: 16)
                        .shimmer()
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.Color.surfaceElevated)
                        .frame(width: 220, height: 14)
                        .shimmer()
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.Color.surfaceElevated)
                        .frame(width: 180, height: 14)
                        .shimmer()
                }
            }
        }
    }
}
