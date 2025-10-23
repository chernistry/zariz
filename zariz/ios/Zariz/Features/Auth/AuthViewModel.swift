import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var password: String = ""
    @Published var error: String?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false

    func validate() -> String? {
        if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "auth_error_identifier_required")
        }
        if password.count < 8 {
            return String(localized: "auth_error_password_short")
        }
        return nil
    }

    func signIn(session: AppSession) async {
        if let v = validate() {
            self.error = v
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let (_, user) = try await AuthService.shared.login(identifier: identifier, password: password)
            session.applyLogin(user: user)
            self.isAuthenticated = true
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
