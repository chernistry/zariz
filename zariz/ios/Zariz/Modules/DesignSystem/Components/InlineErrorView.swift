import SwiftUI

struct InlineErrorView: View {
    let message: String
    var dismissAction: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DS.Color.error)
            
            Text(message)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textPrimary)
            
            Spacer()
            
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
    }
}
