import SwiftUI

struct NavigationRow<Content: View>: View {
    let selectable: Bool
    let content: Content
    let action: () -> Void
    
    init(selectable: Bool = true, @ViewBuilder content: () -> Content, action: @escaping () -> Void) {
        self.selectable = selectable
        self.content = content()
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                content
                Spacer()
                if selectable {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(!selectable)
        .buttonStyle(.plain)
    }
}

#Preview("Navigation Rows") {
    VStack(spacing: 0) {
        NavigationRow(content: {
            Text("Simple Row")
        }, action: {})
        
        Divider()
        
        NavigationRow(content: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.body)
                Text("Subtitle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }, action: {})
        
        Divider()
        
        NavigationRow(selectable: false, content: {
            Text("Non-selectable")
                .foregroundStyle(.secondary)
        }, action: {})
    }
}
