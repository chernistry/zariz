import SwiftUI

struct SkeletonOrderRow: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(width: 80, height: 16)
                    .shimmer()
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(width: 200, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(width: 180, height: 14)
                    .shimmer()
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.md)
    }
}

