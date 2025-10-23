import Foundation
import Network

actor AuthSession {
    static let shared = AuthSession()

    private var accessToken: String?
    private var accessTokenExp: Date?
    private(set) var currentUser: AuthenticatedUser?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "auth.session.monitor")
    private var refreshingTask: Task<String, Error>?

    init() {
        monitor.start(queue: queue)
    }

    func configure(pair: AuthTokenPair, user: AuthenticatedUser) throws {
        self.accessToken = pair.accessToken
        self.accessTokenExp = pair.expiresAt
        self.currentUser = user
        try AuthKeychainStore.save(pair: pair, user: user)
    }

    func clear() {
        accessToken = nil
        accessTokenExp = nil
        currentUser = nil
        AuthKeychainStore.clear()
    }

    private func isNearExpiry(_ date: Date?) -> Bool {
        guard let date else { return true }
        return date.timeIntervalSinceNow < 120 // <2 minutes
    }

    func validAccessToken() async throws -> String {
        if let token = accessToken, !isNearExpiry(accessTokenExp) {
            return token
        }
        if let task = refreshingTask { return try await task.value }
        let task = Task<String, Error> {
            let pair = try await AuthService.shared.refresh()
            self.accessToken = pair.accessToken
            self.accessTokenExp = pair.expiresAt
            return pair.accessToken
        }
        refreshingTask = task
        defer { refreshingTask = nil }
        return try await task.value
    }
}

actor AuthService {
    static let shared = AuthService()

    func login(identifier: String, password: String) async throws -> (AuthTokenPair, AuthenticatedUser) {
        guard NetworkMonitor.isOnline else { throw URLError(.notConnectedToInternet) }
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/login"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let start = Date()
        let body: [String: Any] = ["identifier": identifier, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let latency = Int((Date().timeIntervalSince(start) * 1000).rounded())
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            Telemetry.auth.error("auth.login.failure code=\(http.statusCode) latency_ms=\(latency)")
            throw NSError(
                domain: "Auth",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Login failed (\(http.statusCode))"]
            )
        }
        let respDTO = try JSONDecoder().decode(AuthLoginResponse.self, from: data)
        let (pair, user) = try respDTO.toPairAndUser()
        try await AuthSession.shared.configure(pair: pair, user: user)
        Telemetry.auth.info("auth.login.success latency_ms=\(latency, privacy: .public)")
        return (pair, user)
    }

    func refresh() async throws -> AuthTokenPair {
        guard NetworkMonitor.isOnline else { throw URLError(.notConnectedToInternet) }
        guard let stored = try AuthKeychainStore.load(prompt: "Authenticate to refresh session") else {
            throw NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "No stored session"])
        }
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/refresh"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["refresh_token": stored.refreshToken]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            Telemetry.auth.error("auth.refresh.failure code=\(http.statusCode)")
            throw NSError(domain: "Auth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Refresh failed"])
        }
        let dto = try JSONDecoder().decode(AuthLoginResponse.self, from: data)
        let (pair, user) = try dto.toPairAndUser()
        try await AuthSession.shared.configure(pair: pair, user: user)
        return pair
    }

    func logout() async {
        // Best-effort: call backend, then clear
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/logout"))
        req.httpMethod = "POST"
        if let token = try? await AuthSession.shared.validAccessToken() {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        _ = try? await URLSession.shared.data(for: req)
        await MainActor.run {
            OrdersSyncManager.shared.stopForegroundLoop()
        }
        await AuthSession.shared.clear()
    }
}

enum NetworkMonitor { static var isOnline: Bool { true } }
