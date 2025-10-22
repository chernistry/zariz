import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.45), .clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .mask(content)
                .opacity(0.8)
                .offset(x: phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 180
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

