import XCTest

final class NavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNavigateAllTabs() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")

        // HOME (default)
        XCTAssertTrue(app.staticTexts["Fitnesswispr"].waitForExistence(timeout: 5), "Home title visible")
        snapshot(app, "01-Home")

        // RECORD
        tabBar.buttons["Record"].tap()
        sleep(2)
        snapshot(app, "02-Record")

        // CALENDAR
        tabBar.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5), "Calendar screen visible")
        sleep(2)
        snapshot(app, "03-Calendar")

        // HISTORY
        tabBar.buttons["History"].tap()
        sleep(2)
        snapshot(app, "04-History")

        // SETTINGS
        tabBar.buttons["Settings"].tap()
        sleep(2)
        snapshot(app, "05-Settings")

        // Back to Home
        tabBar.buttons["Home"].tap()
        sleep(1)
        snapshot(app, "06-Home-Return")
    }
}
