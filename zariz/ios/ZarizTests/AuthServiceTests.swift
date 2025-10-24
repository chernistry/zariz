import XCTest
@testable import Zariz

final class AuthServiceTests: XCTestCase {
    override func setUp() async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        AuthKeychainStore.clear()
        await AuthSession.shared.clear()
    }

    func testLoginSuccess() async throws {
        let now = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let rnow = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))
        MockURLProtocol.requestHandler = { request in
            guard request.url?.absoluteString.contains("/auth/login_password") == true else { throw URLError(.badURL) }
            let token = Self.makeJWT(sub: "u1", role: "courier", exp: Int(Date().addingTimeInterval(3600).timeIntervalSince1970), storeIds: [1])
            let json = """
            {"access_token":"\(token)","refresh_token":"r1"}
            """.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, json)
        }
        let (_, user) = try await AuthService.shared.login(identifier: "c@example.com", password: "password123")
        XCTAssertEqual(user.userId, "u1")
        XCTAssertEqual(user.role, .courier)
    }

    func testLoginFailure401() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.absoluteString.contains("/auth/login_password") == true else { throw URLError(.badURL) }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        do {
            _ = try await AuthService.shared.login(identifier: "c@example.com", password: "bad")
            XCTFail("Expected error")
        } catch {
            // ok
        }
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static func makeJWT(sub: String, role: String, exp: Int, storeIds: [Int]?) -> String {
        func b64url(_ data: Data) -> String {
            data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = b64url(try! JSONSerialization.data(withJSONObject: ["alg": "HS256"]))
        var payloadDict: [String: Any] = ["sub": sub, "role": role, "exp": exp]
        if let s = storeIds { payloadDict["store_ids"] = s }
        let payload = b64url(try! JSONSerialization.data(withJSONObject: payloadDict))
        return "\(header).\(payload).sig"
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else { return }
        do {
            let (resp, data) = try handler(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
