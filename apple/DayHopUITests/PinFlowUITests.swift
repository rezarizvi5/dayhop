import XCTest

final class PinFlowUITests: XCTestCase {
    func testOnePinEntryOpensParent() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let preview = app.buttons["Preview Maya's morning"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10), app.debugDescription)
        if !preview.isHittable { app.swipeUp() }
        preview.tap()

        let prompt = app.staticTexts["Parent PIN"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Enter the PIN again"].exists)
        XCTAssertFalse(app.staticTexts["Choose a parent PIN"].exists)

        enter(app, "2580")

        let house = app.staticTexts["Maya's house"]
        XCTAssertTrue(house.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Parent PIN"].exists)
        XCTAssertFalse(app.staticTexts["Enter the PIN again"].exists)
        XCTAssertFalse(app.staticTexts["Choose a parent PIN"].exists)
    }

    private func enter(_ app: XCUIApplication, _ pin: String) {
        for digit in pin {
            let key = app.buttons[String(digit)].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 3), "Missing \(digit)\n\(app.debugDescription)")
            key.tap()
        }
    }
}
