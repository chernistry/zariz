import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var session: AppSession
    @FocusState private var isLoginFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            DS.Color.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    header
                    heroCard
                    formCard
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.xl * 1.2)
                .padding(.bottom, 80)
            }
        }
        .onTapGesture { isLoginFocused = false }
        .onChange(of: vm.isAuthenticated) { _, newValue in
            if newValue { session.isAuthenticated = true }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("welcome_title")
                    .font(DS.Font.largeTitle)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("welcome_tagline")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
            LanguageMenuButton()
        }
    }

    private var heroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("auth_hero_title")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("auth_hero_subtitle")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                }
                Image("AuthHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text("auth_hero_badge")
                            .font(DS.Font.caption)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(DS.Color.brandPrimary.opacity(0.85))
                            )
                            .foregroundStyle(.white)
                            .padding(DS.Spacing.sm)
                    }
            }
        }
    }

    private var formCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("auth_login_label")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.horizontal, 2)
                    TextField("phone_or_email", text: $vm.identifier)
                        .focused($isLoginFocused)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .padding(.vertical, 14)
                        .padding(.horizontal, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .fill(DS.Color.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .stroke(DS.Color.brandPrimary.opacity(0.2), lineWidth: 1.2)
                        )
                        .submitLabel(.done)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("auth_password_label")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.horizontal, 2)
                    SecureField("password_placeholder", text: $vm.password)
                        .textContentType(.password)
                        .padding(.vertical, 14)
                        .padding(.horizontal, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .fill(DS.Color.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .stroke(DS.Color.brandPrimary.opacity(0.2), lineWidth: 1.2)
                        )
                        .submitLabel(.go)
                }

                Button(action: signInTapped) {
                    Text("sign_in")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(vm.isLoading)

                Button(action: { openSupport() }) {
                    Text("forgot_password_cta")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                if let err = vm.error {
                    Text(err)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.error)
                        .padding(.top, DS.Spacing.xs)
                }
            }
        }
    }

    private func signInTapped() {
        Task {
            await vm.signIn(session: session)
            if vm.isAuthenticated { Haptics.success() } else { Haptics.error() }
        }
    }

    private func openSupport() {
        guard let url = URL(string: "mailto:ops@zariz") else { return }
        UIApplication.shared.open(url)
    }
}
