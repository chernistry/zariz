import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 72)).foregroundStyle(.secondary)
            Text(String(localized: "profile")).font(.title2).bold()
            if session.isDemoMode {
                Text(String(localized: "demo_mode")).foregroundStyle(.orange)
            }
            Button(String(localized: "logout")) {
                KeychainTokenStore.clear()
                session.isAuthenticated = false
                session.isDemoMode = false
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(DS.Spacing.xl)
        .navigationTitle("profile")
        .globalNavToolbar()
    }
}
