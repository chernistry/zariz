import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    profileCard
                    if session.isDemoMode { demoNotice }
                    logoutCard
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
            }
        }
        .navigationTitle("profile")
        .globalNavToolbar()
    }

    private var profileCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.lg) {
                    RemoteAvatarView(identifier: session.languageCode + (session.isDemoMode ? "-demo" : "-live"), size: 72)
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("profile_title")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text(session.isDemoMode ? String(localized: "profile_demo_role") : String(localized: "profile_real_role"))
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
                Text("profile_tagline")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var demoNotice: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(DS.Color.warning)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("demo_mode")
                        .font(DS.Font.body.weight(.semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("profile_demo_hint")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
    }

    private var logoutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("profile_logout_title")
                    .font(DS.Font.body.weight(.semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                Text("profile_logout_subtitle")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Button(String(localized: "logout")) {
                    Haptics.light()
                    Task {
                        await AuthService.shared.logout()
                        session.logout()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
