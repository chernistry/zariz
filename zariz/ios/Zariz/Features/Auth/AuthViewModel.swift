import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var login: String = ""
    @Published var role: String = "courier" // or "store"
    @Published var error: String?
    @Published var isAuthenticated: Bool = false

    func signIn() async {
        do {
            let token = try await AuthService.shared.login(subject: login, role: role)
            try KeychainTokenStore.save(token: token)
            isAuthenticated = true
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

