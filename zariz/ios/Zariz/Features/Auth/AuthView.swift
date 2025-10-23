import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var session: AppSession
    @FocusState private var isLoginFocused: Bool
    @State private var animateGradient = false

    var body: some View {
        ZStack(alignment: .top) {
            // Animated gradient background
            LinearGradient(
                colors: [
                    DS.Color.brandPrimary.opacity(0.15),
                    DS.Color.background,
                    DS.Color.background
                ],
                startPoint: animateGradient ? .topLeading : .topTrailing,
                endPoint: animateGradient ? .bottomTrailing : .bottomLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    header
                    logoSection
                    formCard
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.xl * 1.5)
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
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("welcome_title")
                    .font(DS.Font.largeTitle.weight(.bold))
                    .foregroundStyle(DS.Color.textPrimary)
                Text("welcome_tagline")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
            LanguageMenuButton()
        }
    }

    private var logoSection: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                // Modern glassmorphic logo container
                ZStack {
                    Circle()
                        .fill(DS.Color.brandPrimary.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 90, height: 90)
                        .overlay {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(DS.Color.brandPrimary)
                        }
                        .shadow(color: DS.Color.brandPrimary.opacity(0.3), radius: 20, y: 10)
                }
                
                Text("Zariz")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.textPrimary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.lg)
    }

    private var formCard: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Modern glassmorphic card
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Label("phone_or_email", systemImage: "person.circle.fill")
                        .font(DS.Font.caption.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                    
                    TextField("", text: $vm.identifier, prompt: Text("Enter your email or phone").foregroundStyle(DS.Color.textSecondary.opacity(0.5)))
                        .focused($isLoginFocused)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(.vertical, 16)
                        .padding(.horizontal, DS.Spacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                                .stroke(DS.Color.brandPrimary.opacity(isLoginFocused ? 0.5 : 0.2), lineWidth: 1.5)
                        }
                        .submitLabel(.next)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Label("password_placeholder", systemImage: "lock.circle.fill")
                        .font(DS.Font.caption.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                    
                    SecureField("", text: $vm.password, prompt: Text("Enter your password").foregroundStyle(DS.Color.textSecondary.opacity(0.5)))
                        .textContentType(.password)
                        .padding(.vertical, 16)
                        .padding(.horizontal, DS.Spacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                                .stroke(DS.Color.brandPrimary.opacity(0.2), lineWidth: 1.5)
                        }
                        .submitLabel(.go)
                        .onSubmit { signInTapped() }
                }

                Button(action: signInTapped) {
                    HStack {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("sign_in")
                                .font(DS.Font.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
                .shadow(color: DS.Color.brandPrimary.opacity(0.4), radius: 15, y: 8)
                .disabled(vm.isLoading)

                if let err = vm.error {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                            .font(DS.Font.caption)
                    }
                    .foregroundStyle(DS.Color.error)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Color.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
                }
            }
            .padding(DS.Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 30, y: 15)
            
            Button(action: { openSupport() }) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "questionmark.circle.fill")
                    Text("forgot_password_cta")
                }
                .font(DS.Font.caption.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
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
