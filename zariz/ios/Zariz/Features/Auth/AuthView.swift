import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var session: AppSession

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign In").font(.title).bold()
            TextField("Phone or Email (subject)", text: $vm.login)
                .textContentType(.username)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
            Picker("Role", selection: $vm.role) {
                Text("Courier").tag("courier")
                Text("Store").tag("store")
                Text("Admin").tag("admin")
            }
            .pickerStyle(.segmented)
            Button {
                Task { await vm.signIn() }
            } label: {
                Text("Sign In").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            if let err = vm.error { Text(err).foregroundStyle(.red) }
        }
        .padding()
        .onChange(of: vm.isAuthenticated) { _, newValue in
            if newValue { session.isAuthenticated = true }
        }
    }
}
