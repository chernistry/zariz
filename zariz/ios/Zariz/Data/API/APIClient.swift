import Foundation

struct APIClient {
    func request(_ path: String, method: String = "GET", body: Data? = nil, idempotencyKey: String? = nil) async throws -> (Data, URLResponse) {
        let url = AppConfig.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let idempotencyKey { req.addValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        if let token = try? await AuthSession.shared.validAccessToken() {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await URLSession.shared.data(for: req)
    }
}
