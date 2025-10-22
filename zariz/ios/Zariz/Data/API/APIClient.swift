import Foundation

struct APIClient {
    var token: String?

    func request(_ path: String) async throws -> Data {
        let url = AppConfig.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        if let token {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

