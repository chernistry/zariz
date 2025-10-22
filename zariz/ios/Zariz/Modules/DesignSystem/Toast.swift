import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    struct Item: Identifiable {
        enum Style { case info, success, error }
        let id = UUID()
        let text: LocalizedStringKey
        let style: Style
        let icon: String?
    }

    @Published var current: Item?

    func show(_ text: LocalizedStringKey, style: Item.Style = .info, icon: String? = nil, duration: TimeInterval = 1.6) {
        current = Item(text: text, style: style, icon: icon)

        let delay = UInt64(max(duration, 0) * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.current = nil }
        }
    }
}

private struct ToastView: View {
    let item: ToastCenter.Item
    var body: some View {
        HStack(spacing: 10) {
            if let icon = item.icon { Image(systemName: icon) }
            Text(item.text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 2, x: 0, y: 1)
    }
}

struct ToastHost: ViewModifier {
    @EnvironmentObject var toast: ToastCenter
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let item = toast.current {
                ToastView(item: item)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }
}
