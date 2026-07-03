import XCTest

@MainActor
final class TabletBasicUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    func testWelcomeScreenAppears() {
        XCTAssertTrue(app.staticTexts["Welcome to"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["TabletBasic Version 1.0"].exists)
    }

    func testDismissWelcomeShowsEditor() throws {
        try dismissWelcome()
        XCTAssertTrue(app.staticTexts["Untitled"].exists)
        XCTAssertTrue(app.staticTexts["Immediate"].exists)
    }

    func testLoadMathBasAndRunFromSampleLibrary() throws {
        try dismissWelcome()

        app.tapMenuItem(menu: "File", item: "Open Sample Program...")

        let mathRow = app.staticTexts["MATH.BAS"]
        XCTAssertTrue(mathRow.waitForExistence(timeout: 5))
        mathRow.tap()

        let loadAndRun = app.buttons["loadAndRun"]
        XCTAssertTrue(loadAndRun.waitForExistence(timeout: 3))
        loadAndRun.tap()

        let output = app.staticTexts["programOutput"]
        XCTAssertTrue(output.waitForExistence(timeout: 8))

        let outputText = output.label
        XCTAssertFalse(outputText.contains("Empty statement"), "Got parse error: \(outputText)")
        XCTAssertFalse(outputText.contains("Syntax error"), "Got syntax error: \(outputText)")
        XCTAssertTrue(
            outputText.contains("4") || outputText.contains("256"),
            "Expected math output, got: \(outputText)"
        )
    }

    func testFileMenuDoesNotPushContentDown() throws {
        try dismissWelcome()

        let statusBar = app.staticTexts["Immediate"]
        XCTAssertTrue(statusBar.waitForExistence(timeout: 3))
        let yBefore = statusBar.frame.origin.y

        app.revealMainMenuIfNeeded()
        let menuFile = app.buttons["menuFile"]
        if menuFile.waitForExistence(timeout: 1) {
            menuFile.tap()
        }
        XCTAssertTrue(app.buttons["menuItem_File_Open Sample Program..."].waitForExistence(timeout: 2))

        let yDuringMenu = statusBar.frame.origin.y
        XCTAssertEqual(yBefore, yDuringMenu, accuracy: 1.0, "Status bar shifted when menu opened")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
    }

    func testCompactMenuItemsAreHittable() throws {
        try dismissWelcome()

        let overflow = app.buttons["menuOverflow"]
        guard overflow.waitForExistence(timeout: 2) else {
            throw XCTSkip("Regular menu layout — compact overflow not shown")
        }

        overflow.tap()
        let newFile = app.buttons["menuItem_File_New..."].firstMatch
        XCTAssertTrue(newFile.waitForExistence(timeout: 3))
        XCTAssertTrue(newFile.isHittable, "Menu items should be tappable above the document title")

        let about = app.buttons["menuItem_Help_About"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 3))
        XCTAssertTrue(about.isHittable, "All menu items should be visible without scrolling")

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Compact Menu Open"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func dismissWelcome() throws {
        let dismiss = app.buttons["welcomeDismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertFalse(app.staticTexts["Welcome to"].waitForExistence(timeout: 2))
    }
}