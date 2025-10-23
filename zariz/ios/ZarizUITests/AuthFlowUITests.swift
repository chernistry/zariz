import XCTest

final class AuthFlowUITests: XCTestCase {
    func testAuthValidation() throws {
        let app = XCUIApplication()
        app.launch()

        // Expect sign-in screen
        let emailField = app.textFields[NSLocalizedString("phone_or_email", comment: "")]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("user@example.com")

        let signIn = app.buttons[NSLocalizedString("sign_in", comment: "")]
        signIn.tap()

        // Should show password short error
        let error = app.staticTexts[NSLocalizedString("auth_error_password_short", comment: "")]
        XCTAssertTrue(error.waitForExistence(timeout: 1))
    }
}

