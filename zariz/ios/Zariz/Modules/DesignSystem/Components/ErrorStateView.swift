import SwiftUI

struct ErrorStateView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.error)
            
            VStack(spacing: DS.Spacing.xs) {
                Text("Something Went Wrong")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                
                Text(error.localizedDescription)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: retryAction) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.primary)
            .frame(maxWidth: 280)
        }
        .padding(DS.Spacing.xl)
    }
}
