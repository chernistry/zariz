import Foundation
import Network

struct AuthTokenPair: Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct AuthenticatedUser: Sendable {
    let userId: String
    let role: UserRole
    let storeIds: [Int]
    let identifier: String?
}

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

    func configure(pair: AuthTokenPair, user: AuthenticatedUser) {
        self.accessToken = pair.accessToken
        self.accessTokenExp = pair.expiresAt
        self.currentUser = user
        do {
            try AuthKeychainStore.save(refreshToken: pair.refreshToken, user: user)
        } catch {
            Telemetry.auth.error("auth.keychain.save_failure msg=\(error.localizedDescription)")
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .authSessionConfigured, object: user)
        }
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
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/login_password"))
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
        // Response: { access_token, refresh_token }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = obj?["access_token"] as? String, let refresh = obj?["refresh_token"] as? String else {
            throw NSError(domain: "Auth", code: -3, userInfo: [NSLocalizedDescriptionKey: "Malformed response"])
        }
        let claims = try Self.decodeClaims(fromJWT: access)
        let exp = Date(timeIntervalSince1970: TimeInterval(claims.exp))
        let pair = AuthTokenPair(accessToken: access, refreshToken: refresh, expiresAt: exp)
        let user = AuthenticatedUser(userId: claims.sub, role: UserRole(rawValue: claims.role) ?? .courier, storeIds: claims.store_ids ?? [], identifier: identifier)
        await AuthSession.shared.configure(pair: pair, user: user)
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
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = obj?["access_token"] as? String, let refresh = obj?["refresh_token"] as? String else {
            throw NSError(domain: "Auth", code: -4, userInfo: [NSLocalizedDescriptionKey: "Malformed refresh response"])
        }
        let claims = try Self.decodeClaims(fromJWT: access)
        let exp = Date(timeIntervalSince1970: TimeInterval(claims.exp))
        let pair = AuthTokenPair(accessToken: access, refreshToken: refresh, expiresAt: exp)
        let user = AuthenticatedUser(userId: claims.sub, role: UserRole(rawValue: claims.role) ?? .courier, storeIds: claims.store_ids ?? [], identifier: stored.identifier)
        await AuthSession.shared.configure(pair: pair, user: user)
        return pair
    }

    func logout() async {
        // Best-effort: call backend, then clear
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("auth/logout"))
        req.httpMethod = "POST"
        do {
            if let stored = try? AuthKeychainStore.load(prompt: "Authenticate to logout") {
                req.addValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["refresh_token": stored.refreshToken]
                req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                _ = try? await URLSession.shared.data(for: req)
            }
        } catch {
            // Ignore keychain errors on logout
        }
        await MainActor.run {
            OrdersSyncManager.shared.stopForegroundLoop()
        }
        await AuthSession.shared.clear()
    }

    private struct JWTClaims: Decodable {
        let sub: String
        let role: String
        let exp: Int
        let store_ids: [Int]?
    }

    private static func decodeClaims(fromJWT jwt: String) throws -> JWTClaims {
        let parts = jwt.split(separator: ".").map(String.init)
        if parts.count < 2 { throw NSError(domain: "Auth", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid token"]) }
        func base64urlToData(_ s: String) -> Data? {
            var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let pad = 4 - (b.count % 4)
            if pad < 4 { b.append(String(repeating: "=", count: pad)) }
            return Data(base64Encoded: b)
        }
        guard let data = base64urlToData(parts[1]) else {
            throw NSError(domain: "Auth", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid payload"])
        }
        return try JSONDecoder().decode(JWTClaims.self, from: data)
    }
}

enum NetworkMonitor { static var isOnline: Bool { true } }
