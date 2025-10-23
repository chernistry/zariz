import XCTest
@testable import Zariz

final class AuthSessionConcurrencyTests: XCTestCase {
    override func setUp() async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
        AuthKeychainStore.clear()
        await AuthSession.shared.clear()
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        AuthKeychainStore.clear()
        await AuthSession.shared.clear()
    }

    func testValidAccessTokenSingleFlightRefresh() async throws {
        // Arrange: store a session and set an expired access token to force refresh
        let user = AuthenticatedUser(userId: "u1", role: .courier, storeIds: [1], identifier: "courier")
        try AuthKeychainStore.save(refreshToken: "r0", user: user)
        let expired = Date().addingTimeInterval(-3600)
        let initialPair = AuthTokenPair(accessToken: "expired", refreshToken: "r0", expiresAt: expired)
        await AuthSession.shared.configure(pair: initialPair, user: user)

        // Mock refresh endpoint returning a new token
        var refreshCallCount = 0
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url?.absoluteString, url.contains("/auth/refresh") else {
                throw URLError(.badURL)
            }
            refreshCallCount += 1
            let token = MockURLProtocol.makeJWT(sub: "u1", role: "courier", exp: Int(Date().addingTimeInterval(3600).timeIntervalSince1970), storeIds: [1])
            let json = "{" + "\"access_token\":\"\(token)\",\"refresh_token\":\"r1\"}".data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, json)
        }

        // Act: concurrently request validAccessToken several times
        async let t1 = AuthSession.shared.validAccessToken()
        async let t2 = AuthSession.shared.validAccessToken()
        async let t3 = AuthSession.shared.validAccessToken()
        async let t4 = AuthSession.shared.validAccessToken()
        let results = try await [t1, t2, t3, t4]

        // Assert: all tokens equal and refresh called once
        XCTAssertEqual(Set(results).count, 1, "All calls should return the same token")
        XCTAssertEqual(refreshCallCount, 1, "Refresh endpoint should be called once (single-flight)")
    }
}
