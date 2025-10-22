import SwiftUI

enum DS {
    enum Color {
        static let background = SwiftUI.Color(UIColor.systemBackground)
        static let card = SwiftUI.Color(UIColor.secondarySystemBackground)
        static let primary = SwiftUI.Color("BrandPrimary", bundle: .main)
        static let accent = SwiftUI.Color.blue
        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
        static let statusNew = SwiftUI.Color.orange
        static let statusClaimed = SwiftUI.Color.blue
        static let statusPicked = SwiftUI.Color.purple
        static let statusDelivered = SwiftUI.Color.green
        static let statusCanceled = SwiftUI.Color.red
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(DS.Color.accent.cornerRadius(10))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: 12).fill(DS.Color.card))
    }
}

struct StatusBadge: View {
    let text: String
    let color: SwiftUI.Color
    var body: some View {
        Text(text.uppercased())
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

