import Shimmer
import SwiftUI

extension View {
    func shimmer(active: Bool = true, duration: Double = 1.2, bounce: Bool = true) -> some View {
        shimmering(active: active, duration: duration, bounce: bounce)
    }
}
