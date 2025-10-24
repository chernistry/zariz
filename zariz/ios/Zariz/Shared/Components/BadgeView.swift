import SwiftUI

struct BadgeView: View {
    enum BadgeType: Equatable, Sendable {
        case new
        case tip
        case customText(String)
        
        var title: String {
            switch self {
            case .new:
                return String(localized: "badge_new")
            case .tip:
                return String(localized: "badge_tip")
            case .customText(let text):
                return text
            }
        }
    }
    
    enum BackgroundShape: Sendable {
        case roundedRectangle(cornerRadius: CGFloat)
        case circle
        
        static var defaultShape: BackgroundShape {
            .roundedRectangle(cornerRadius: 8)
        }
    }
    
    struct Customizations: Sendable {
        let textColor: Color
        let backgroundColor: Color
        
        init(textColor: Color = .white, backgroundColor: Color = .blue) {
            self.textColor = textColor
            self.backgroundColor = backgroundColor
        }
    }
    
    private let type: BadgeType
    private let customizations: Customizations
    private let backgroundShape: BackgroundShape
    
    init(type: BadgeType) {
        self.type = type
        self.customizations = .init()
        self.backgroundShape = .defaultShape
    }
    
    init(text: String, customizations: Customizations = .init(), backgroundShape: BackgroundShape = .defaultShape) {
        self.type = .customText(text)
        self.customizations = customizations
        self.backgroundShape = backgroundShape
    }
    
    var body: some View {
        Text(type.title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(customizations.textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(backgroundView())
    }
    
    @ViewBuilder
    private func backgroundView() -> some View {
        switch backgroundShape {
        case .circle:
            Circle()
                .fill(customizations.backgroundColor)
                .stroke(.white, lineWidth: 1)
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(customizations.backgroundColor)
                .stroke(.white, lineWidth: 1)
        }
    }
}

#Preview("Badge Types") {
    VStack(spacing: 16) {
        BadgeView(type: .new)
        BadgeView(type: .tip)
        BadgeView(text: "VIP")
        BadgeView(text: "Custom", customizations: .init(textColor: .black, backgroundColor: .yellow))
    }
    .padding()
}
