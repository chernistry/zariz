import XCTest
@testable import Zariz

final class KeychainAuthStoreTests: XCTestCase {
    override func setUp() async throws {
        AuthKeychainStore.clear()
    }

    override func tearDown() async throws {
        AuthKeychainStore.clear()
    }

    func testSaveLoadClearSession() throws {
        let user = AuthenticatedUser(userId: "u42", role: .courier, storeIds: [1,2], identifier: "courier")
        try AuthKeychainStore.save(refreshToken: "refresh-token-xyz", user: user)

        // Silent load (no UI)
        let loaded = try AuthKeychainStore.load(prompt: nil)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.refreshToken, "refresh-token-xyz")
        XCTAssertEqual(loaded?.userId, "u42")

        AuthKeychainStore.clear()
        let afterClear = try AuthKeychainStore.load(prompt: nil)
        XCTAssertNil(afterClear)
    }
}

