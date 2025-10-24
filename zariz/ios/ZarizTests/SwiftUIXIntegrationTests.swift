import XCTest
import SwiftUIX
@testable import Zariz

final class SwiftUIXIntegrationTests: XCTestCase {
    func testSwiftUIXImport() {
        // Verify library is accessible
        XCTAssertNotNil(CocoaTextField.self)
    }
    
    func testSwiftUIXComponentsAvailable() {
        // Verify key components are available
        XCTAssertNotNil(CocoaButton.self)
        XCTAssertNotNil(ActivityIndicator.self)
    }
}
