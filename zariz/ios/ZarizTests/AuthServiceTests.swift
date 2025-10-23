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
        AuthSession.shared.clear()
    }

    func testLoginSuccess() async throws {
        let now = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let rnow = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))
        MockURLProtocol.requestHandler = { request in
            guard request.url?.absoluteString.hasSuffix("/auth/login") == true else { throw URLError(.badURL) }
            let json = """
            {"access_token":"a.b.c","refresh_token":"r1","expires_at":"\(now)","refresh_expires_at":"\(rnow)","role":"courier","user_id":"u1","store_ids":[1],"identifier":"c@example.com"}
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
            guard request.url?.absoluteString.hasSuffix("/auth/login") == true else { throw URLError(.badURL) }
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
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
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

