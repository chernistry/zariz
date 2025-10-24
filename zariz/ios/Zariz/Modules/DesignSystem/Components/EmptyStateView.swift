import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(DS.Color.textSecondary)
            
            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                
                Text(message)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
            }
        }
        .padding(DS.Spacing.xl)
    }
}
