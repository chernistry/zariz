import SwiftUI
import UIKit

enum DS {
    enum Color {
        static let brandPrimary = SwiftUI.Color("BrandPrimary", bundle: .main)
        static let brandSecondary = SwiftUI.Color(red: 0.20, green: 0.60, blue: 0.98)
        static let accent = SwiftUI.Color(red: 0.99, green: 0.54, blue: 0.30)
        static let background = SwiftUI.Color.dynamic(
            light: .init(red: 0.96, green: 0.97, blue: 1.0, alpha: 1.0),
            dark: .init(red: 0.09, green: 0.11, blue: 0.18, alpha: 1.0)
        )
        static let surface = SwiftUI.Color.dynamic(
            light: .init(red: 1, green: 1, blue: 1, alpha: 1),
            dark: .init(red: 0.14, green: 0.16, blue: 0.23, alpha: 1)
        )
        static let surfaceElevated = SwiftUI.Color.dynamic(
            light: .init(red: 0.93, green: 0.95, blue: 1.0, alpha: 1),
            dark: .init(red: 0.18, green: 0.21, blue: 0.30, alpha: 1)
        )
        static let textPrimary = SwiftUI.Color.dynamic(
            light: .init(red: 0.10, green: 0.12, blue: 0.23, alpha: 1),
            dark: .init(red: 0.91, green: 0.94, blue: 1.0, alpha: 1)
        )
        static let textSecondary = SwiftUI.Color.dynamic(
            light: .init(red: 0.47, green: 0.53, blue: 0.66, alpha: 1),
            dark: .init(red: 0.63, green: 0.70, blue: 0.87, alpha: 1)
        )
        static let success = SwiftUI.Color(red: 0.30, green: 0.73, blue: 0.42)
        static let warning = SwiftUI.Color(red: 0.99, green: 0.75, blue: 0.18)
        static let error = SwiftUI.Color(red: 0.92, green: 0.32, blue: 0.32)
        static let divider = SwiftUI.Color.white.opacity(0.12)

        static let statusNew = SwiftUI.Color(red: 0.96, green: 0.58, blue: 0.25)
        static let statusAccepted = SwiftUI.Color(red: 0.25, green: 0.64, blue: 0.96)
        static let statusPicked = SwiftUI.Color(red: 0.53, green: 0.37, blue: 0.94)
        static let statusDelivered = SwiftUI.Color(red: 0.30, green: 0.73, blue: 0.42)
        static let statusCanceled = SwiftUI.Color(red: 0.92, green: 0.32, blue: 0.32)
    }

    enum Gradient {
        static let primary = LinearGradient(colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let accent = LinearGradient(colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        static let skeleton = LinearGradient(colors: [SwiftUI.Color.white.opacity(0.15), SwiftUI.Color.white.opacity(0.6), SwiftUI.Color.white.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 36, weight: .bold, design: .rounded)
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 17, weight: .regular, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)

        static func numeric(weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: 18, weight: weight, design: .monospaced)
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
    }

    enum Shadow {
        static let subtle = ShadowStyle(color: SwiftUI.Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        static let elevated = ShadowStyle(color: SwiftUI.Color.black.opacity(0.14), radius: 30, x: 0, y: 16)
    }

    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0.24)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)
    }
}

struct ShadowStyle {
    let color: SwiftUI.Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                DS.Gradient.accent
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
            )
            .shadow(color: DS.Color.brandPrimary.opacity(configuration.isPressed ? 0.16 : 0.28), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 4 : 10)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.body)
            .foregroundStyle(DS.Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .strokeBorder(DS.Color.brandPrimary.opacity(configuration.isPressed ? 0.9 : 0.4), lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .fill(DS.Color.brandPrimary.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct LoadingButtonStyle: ButtonStyle {
    @Binding var isLoading: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .font(DS.Font.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            DS.Gradient.accent
                .opacity(configuration.isPressed || isLoading ? 0.8 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .disabled(isLoading)
    }
}

extension ButtonStyle where Self == LoadingButtonStyle {
    static func loading(isLoading: Binding<Bool>) -> LoadingButtonStyle {
        LoadingButtonStyle(isLoading: isLoading)
    }
}

struct Card<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .fill(DS.Color.surface)
                    .modifier(ShadowModifier(style: DS.Shadow.subtle))
            )
    }
}

struct StatusBadge: View {
    let text: String
    let color: SwiftUI.Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(DS.Font.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(color.opacity(0.16))
        )
        .foregroundStyle(color)
    }
}

private struct ShadowModifier: ViewModifier {
    let style: ShadowStyle
    func body(content: Content) -> some View {
        content.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

private extension SwiftUI.Color {
    static func dynamic(light: UIColor, dark: UIColor) -> SwiftUI.Color {
        SwiftUI.Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}
