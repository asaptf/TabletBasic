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

    func testFileNewClearsDocumentFromWelcome() throws {
        XCTAssertTrue(app.staticTexts["Welcome to"].waitForExistence(timeout: 5))

        app.tapMenuItem(menu: "File", item: "New...")

        XCTAssertFalse(app.staticTexts["Welcome to"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Untitled"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 3))
    }

    func testFileNewClearsLoadedProgram() throws {
        try dismissWelcome()

        app.tapMenuItem(menu: "File", item: "Open Sample Program...")
        let mathRow = app.staticTexts["MATH.BAS"]
        XCTAssertTrue(mathRow.waitForExistence(timeout: 5))
        mathRow.tap()

        let load = app.buttons["loadProgram"]
        XCTAssertTrue(load.waitForExistence(timeout: 3))
        load.tap()

        XCTAssertTrue(app.staticTexts["MATH.BAS"].waitForExistence(timeout: 3))
        app.tapMenuItem(menu: "File", item: "New...")
        XCTAssertTrue(app.staticTexts["Untitled"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 3))
    }

    func testEnabledMenuItemsRespond() throws {
        try dismissWelcome()

        app.tapMenuItem(menu: "Help", item: "About")
        XCTAssertTrue(app.buttons["aboutDismiss"].waitForExistence(timeout: 3))
        app.buttons["aboutDismiss"].tap()

        app.tapMenuItem(menu: "Run", item: "Start")
        XCTAssertTrue(app.staticTexts["programOutput"].waitForExistence(timeout: 8))

        app.tapMenuItem(menu: "View", item: "Return to Editor")
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 3))

        app.tapMenuItem(menu: "Edit", item: "Insert Line Numbers")
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 3))

        app.tapMenuItem(menu: "File", item: "Clear Output")
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 3))
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

    func testCaptureAppStoreScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        let outputURL = URL(
            fileURLWithPath: environment["APP_STORE_SCREENSHOT_DIR"] ?? defaultScreenshotDirectory(),
            isDirectory: true
        )
        let prefix = environment["APP_STORE_SCREENSHOT_PREFIX"] ?? screenshotPrefix()
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        XCTAssertTrue(app.staticTexts["Welcome to"].waitForExistence(timeout: 5))
        try saveScreenshot("01_\(prefix)_welcome", to: outputURL)

        relaunchForScreenshot(sample: "HELLO.BAS")
        XCTAssertTrue(app.textViews["sourceEditor"].waitForExistence(timeout: 5))
        try saveScreenshot("02_\(prefix)_editor", to: outputURL)

        app.tapMenuItem(menu: "File", item: "Open Sample Program...")
        XCTAssertTrue(app.navigationBars["Sample Programs"].waitForExistence(timeout: 5))
        try saveScreenshot("03_\(prefix)_samples", to: outputURL)

        relaunchForScreenshot(sample: "MOIRE.BAS")
        app.tapMenuItem(menu: "Run", item: "Start")
        XCTAssertTrue(app.staticTexts["programOutput"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["returnToEditor"].waitForExistence(timeout: 10))
        try saveScreenshot("04_\(prefix)_graphics", to: outputURL)

        relaunchForScreenshot(sample: nil)
        try dismissWelcome()
        app.tapMenuItem(menu: "Help", item: "Learning Guide")
        XCTAssertTrue(app.navigationBars["TabletBasic Learning Guide"].waitForExistence(timeout: 5))
        if app.staticTexts["Hello, World!"].waitForExistence(timeout: 2) {
            app.staticTexts["Hello, World!"].tap()
        }
        _ = app.buttons["Open in Editor"].waitForExistence(timeout: 3)
        try saveScreenshot("05_\(prefix)_lessons", to: outputURL)
    }

    private func dismissWelcome() throws {
        let dismiss = app.buttons["welcomeDismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertFalse(app.staticTexts["Welcome to"].waitForExistence(timeout: 2))
    }

    private func relaunchForScreenshot(sample filename: String?) {
        app.terminate()
        app.launchArguments = ["UI_TESTING"]
        if let filename {
            app.launchEnvironment = ["UI_TEST_SAMPLE": filename]
        } else {
            app.launchEnvironment = [:]
        }
        app.launch()
    }

    private func saveScreenshot(_ name: String, to outputURL: URL) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let fileURL = outputURL.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: fileURL)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func defaultScreenshotDirectory() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fastlane/screenshots/en-US")
            .path
    }

    private func screenshotPrefix() -> String {
        let frame = app.windows.firstMatch.frame
        if min(frame.width, frame.height) < 700 {
            return "IPHONE_69"
        }
        return "IPAD_PRO_3GEN_129"
    }
}
