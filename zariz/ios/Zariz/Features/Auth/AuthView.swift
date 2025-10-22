import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var session: AppSession

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Welcome to Zariz").font(.largeTitle).bold()
            TextField("Phone or Email (subject)", text: $vm.login)
                .textContentType(.username)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                .keyboardType(.emailAddress)
            Picker("Role", selection: $vm.role) {
                Text("Courier").tag("courier")
                Text("Store").tag("store")
                Text("Admin").tag("admin")
            }
            .pickerStyle(.segmented)
            Toggle("Demo Mode", isOn: $session.isDemoMode)
            .tint(.blue)
            Button {
                Task {
                    if session.isDemoMode {
                        let input = vm.login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let allowed = ["courier", "store", "admin"]
                        guard allowed.contains(input) else {
                            vm.error = "In demo mode, enter: courier, store, or admin"
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
            } label: { Text("Sign In").frame(maxWidth: .infinity) }
            .buttonStyle(PrimaryButtonStyle())
            if let err = vm.error { Text(err).foregroundStyle(.red) }
        }
        .padding(DS.Spacing.xl)
        .onChange(of: vm.isAuthenticated) { _, newValue in
            if newValue { session.isAuthenticated = true }
        }
    }
}
