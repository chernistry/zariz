import Foundation

struct AuthTokenPair: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let refreshExpiresAt: Date
}

struct AuthenticatedUser: Codable, Sendable {
    let userId: String
    let role: UserRole
    let storeIds: [Int]
    let identifier: String?
}

struct AuthLoginResponse: Codable, Sendable {
    let access_token: String
    let refresh_token: String
    let expires_at: String
    let refresh_expires_at: String
    let role: String
    let user_id: String
    let store_ids: [Int]
    let identifier: String?

    func toPairAndUser() throws -> (AuthTokenPair, AuthenticatedUser) {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let exp = df.date(from: expires_at),
              let rexp = df.date(from: refresh_expires_at) else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid token expiry dates"])
        }
        let pair = AuthTokenPair(accessToken: access_token, refreshToken: refresh_token, expiresAt: exp, refreshExpiresAt: rexp)
        let user = AuthenticatedUser(userId: user_id, role: UserRole(rawValue: role) ?? .courier, storeIds: store_ids, identifier: identifier)
        return (pair, user)
    }
}

