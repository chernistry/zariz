import Foundation

struct TokenResponse: Decodable {
    let access_token: String
}

final class AuthService {
    static let shared = AuthService()

    func login(subject: String, role: String) async throws -> String {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/login"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["subject": subject, "role": role]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "Auth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Login failed ("](http.statusCode)")])
        }
        let tok = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tok.access_token
    }
}

