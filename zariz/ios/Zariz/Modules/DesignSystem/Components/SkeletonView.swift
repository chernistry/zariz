import SwiftUI

struct SkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.small)
            .fill(DS.Color.surfaceElevated)
            .shimmer()
    }
}
