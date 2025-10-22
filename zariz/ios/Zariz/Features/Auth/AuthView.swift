import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var session: AppSession

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack {
                Spacer()
                // Language switcher in auth screen (visible everywhere)
                Menu {
                    Button("HE") { session.languageCode = "he" }
                    Button("AR") { session.languageCode = "ar" }
                    Button("EN") { session.languageCode = "en" }
                    Button("RU") { session.languageCode = "ru" }
                } label: { Image(systemName: "globe") }
            }
            Text("welcome_title").font(.largeTitle).bold()
            TextField("phone_or_email", text: $vm.login)
                .textContentType(.username)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                .keyboardType(.emailAddress)
            Picker("role", selection: $vm.role) {
                Text("role_courier").tag("courier")
                Text("role_store").tag("store")
                Text("role_admin").tag("admin")
            }
            .pickerStyle(.segmented)
            Toggle("demo_mode", isOn: $session.isDemoMode)
            .tint(.blue)
            Button {
                Task {
                    if session.isDemoMode {
                        let input = vm.login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let allowed = ["courier", "store", "admin"]
                        guard allowed.contains(input) else {
                            vm.error = String(localized: "invalid_demo_login")
                            return
                        }
                        let fakeToken = "demo:\(input)"
                        do {
                            try KeychainTokenStore.save(token: fakeToken)
                            vm.isAuthenticated = true
                        } catch {
                            vm.error = (error as NSError).localizedDescription
                        }
                    } else {
                        await vm.signIn()
                    }
                }
            } label: { Text("sign_in").frame(maxWidth: .infinity) }
            .buttonStyle(PrimaryButtonStyle())
            if let err = vm.error { Text(err).foregroundStyle(.red) }
        }
        .padding(DS.Spacing.xl)
        .onChange(of: vm.isAuthenticated) { _, newValue in
            if newValue { session.isAuthenticated = true }
        }
    }
}
