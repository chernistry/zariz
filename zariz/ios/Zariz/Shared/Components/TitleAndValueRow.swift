import SwiftUI

struct TitleAndValueRow: View {
    enum SelectionStyle: Sendable {
        case none
        case disclosure
        case highlight
    }
    
    enum Value: Sendable {
        case text(String)
        case placeholder
        case icon(Image)
    }
    
    private let title: String
    private let titleSuffixIcon: (image: Image, color: Color)?
    private let value: Value
    private let valueAlignment: TextAlignment
    private let bold: Bool
    private let selectionStyle: SelectionStyle
    private let isLoading: Bool
    private let isMultiline: Bool
    private let action: () -> Void
    
    init(
        title: String,
        titleSuffixIcon: (image: Image, color: Color)? = nil,
        value: Value,
        valueAlignment: TextAlignment = .trailing,
        bold: Bool = false,
        selectionStyle: SelectionStyle = .none,
        isLoading: Bool = false,
        isMultiline: Bool = true,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titleSuffixIcon = titleSuffixIcon
        self.value = value
        self.valueAlignment = valueAlignment
        self.bold = bold
        self.selectionStyle = selectionStyle
        self.isLoading = isLoading
        self.isMultiline = isMultiline
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(bold ? .body.weight(.semibold) : .body)
                        .foregroundStyle(selectionStyle == .highlight ? Color.blue : Color.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let icon = titleSuffixIcon {
                        icon.image
                            .foregroundStyle(icon.color)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    valueView
                    
                    if selectionStyle == .disclosure {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(selectionStyle == .none)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var valueView: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(valueAlignment)
                .lineLimit(isMultiline ? nil : 1)
        case .placeholder:
            Text("—")
                .font(.body)
                .foregroundStyle(.tertiary)
        case .icon(let image):
            image
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Title and Value Rows") {
    VStack(spacing: 0) {
        TitleAndValueRow(
            title: "Name",
            value: .text("John Doe")
        )
        
        Divider()
        
        TitleAndValueRow(
            title: "Email",
            value: .text("john@example.com"),
            selectionStyle: .disclosure,
            action: {}
        )
        
        Divider()
        
        TitleAndValueRow(
            title: "Phone",
            value: .placeholder
        )
        
        Divider()
        
        TitleAndValueRow(
            title: "Loading",
            value: .text(""),
            isLoading: true
        )
        
        Divider()
        
        TitleAndValueRow(
            title: "Highlighted",
            value: .text("Tap me"),
            selectionStyle: .highlight,
            action: {}
        )
    }
}
