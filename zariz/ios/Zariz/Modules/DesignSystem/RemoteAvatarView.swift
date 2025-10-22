import SwiftUI

public struct RemoteAvatarView: View {
    let identifier: String
    var size: CGFloat = 56

    public init(identifier: String, size: CGFloat = 56) {
        self.identifier = identifier
        self.size = size
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
            .fill(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .stroke(DS.Color.brandPrimary.opacity(0.12), lineWidth: 1)
            )
            .overlay(iconOverlay)
            .frame(width: size, height: size)
            .shadow(color: DS.Color.brandPrimary.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var backgroundGradient: LinearGradient {
        let palette: [Color] = [
            Color(red: 0.93, green: 0.46, blue: 0.24),
            Color(red: 0.26, green: 0.62, blue: 0.94),
            Color(red: 0.31, green: 0.75, blue: 0.51),
            Color(red: 0.56, green: 0.41, blue: 0.89),
            Color(red: 0.94, green: 0.36, blue: 0.38)
        ]
        let hash = abs(identifier.hashValue)
        let first = palette[hash % palette.count]
        let second = palette[(hash / palette.count) % palette.count]
        return LinearGradient(colors: [first, second.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var iconOverlay: some View {
        VStack(spacing: size * 0.08) {
            Image("BoxIcon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size * 0.48, height: size * 0.48)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: size * 0.08, x: 0, y: size * 0.05)
            Text(monogram)
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var monogram: String {
        let allowed = identifier.filter { $0.isLetter || $0.isNumber }
        guard let first = allowed.first else { return "#" }
        return String(first).uppercased()
    }
}
