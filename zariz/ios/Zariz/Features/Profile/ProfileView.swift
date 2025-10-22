import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 72)).foregroundStyle(.secondary)
            Text("Profile").font(.title2).bold()
            if session.isDemoMode {
                Text("Demo Mode is ON").foregroundStyle(.orange)
            }
            Button("Log Out") {
                KeychainTokenStore.clear()
                session.isAuthenticated = false
                session.isDemoMode = false
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(DS.Spacing.xl)
        .navigationTitle("Profile")
    }
}

