import XCTest

/// UI smoke tests: every bundled sample program runs in the app without errors.
@MainActor
final class SampleProgramsUITests: XCTestCase {
    private var app: XCUIApplication!

    private struct SampleExpectation {
        let filename: String
        let outputContains: String
    }

    private static let allPrograms: [SampleExpectation] = [
        SampleExpectation(filename: "HELLO.BAS", outputContains: "Hello, World!"),
        SampleExpectation(filename: "VARS.BAS", outputContains: "TabletBasic"),
        SampleExpectation(filename: "MATH.BAS", outputContains: "256"),
        SampleExpectation(filename: "COMPARE.BAS", outputContains: "Grade: B"),
        SampleExpectation(filename: "FORLOOP.BAS", outputContains: "Done!"),
        SampleExpectation(filename: "WHILE.BAS", outputContains: "128"),
        SampleExpectation(filename: "NESTED.BAS", outputContains: "25"),
        SampleExpectation(filename: "GOSUB.BAS", outputContains: "Main program ending"),
        SampleExpectation(filename: "MENU.BAS", outputContains: "Option 3 selected"),
        SampleExpectation(filename: "DATAREAD.BAS", outputContains: "Planet data:"),
        SampleExpectation(filename: "ARRAY.BAS", outputContains: "Test scores:"),
        SampleExpectation(filename: "DICE.BAS", outputContains: "Rolling dice"),
        SampleExpectation(filename: "FIBON.BAS", outputContains: "Fibonacci"),
        SampleExpectation(filename: "TABLES.BAS", outputContains: "----+"),
        SampleExpectation(filename: "SHAPES.BAS", outputContains: "Shapes drawn!"),
        SampleExpectation(filename: "BOXES.BAS", outputContains: "Nested boxes"),
        SampleExpectation(filename: "STARS.BAS", outputContains: "Starfield complete"),
        SampleExpectation(filename: "MOIRE.BAS", outputContains: "Moire pattern"),
        SampleExpectation(filename: "SINEWAVE.BAS", outputContains: "Sine wave plotted"),
        SampleExpectation(filename: "FLAG.BAS", outputContains: "Flag drawn!")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
    }

    func testLibraryListsAllTwentySamplePrograms() throws {
        launchApp(sample: nil)
        try openSampleLibrary()

        for program in Self.allPrograms {
            filterSampleList(to: program.filename)
            let row = app.descendants(matching: .any)["sample_\(program.filename)"].firstMatch
            XCTAssertTrue(
                row.waitForExistence(timeout: 5),
                "Sample row \(program.filename) not found in library"
            )
        }
    }

    func testEverySampleProgramRunsFromEditor() throws {
        for program in Self.allPrograms {
            try XCTContext.runActivity(named: program.filename) { _ in
                relaunchApp(sample: program.filename)
                try runFromRunMenu()
                assertOutput(program.filename, contains: program.outputContains)
            }
        }
    }

    func testEverySampleProgramLoadsAndRunsFromLibrary() throws {
        try runEverySampleProgramFromLibrary()
    }

    /// Backward-compatible alias for older CI commands and scripts.
    func testEverySampleProgramLoadsAndRuns() throws {
        try runEverySampleProgramFromLibrary()
    }

    private func runEverySampleProgramFromLibrary() throws {
        launchApp(sample: nil)
        try dismissWelcomeIfNeeded()

        for program in Self.allPrograms {
            try XCTContext.runActivity(named: program.filename) { _ in
                try loadAndRunFromLibrary(program.filename, expect: program.outputContains)
                returnToEditor()
            }
        }
    }

    // Individual tests for precise failure reporting in Xcode / CI.
    func testHELLO_BAS() throws { try runSingle("HELLO.BAS", expect: "Hello, World!") }
    func testVARS_BAS() throws { try runSingle("VARS.BAS", expect: "TabletBasic") }
    func testMATH_BAS() throws { try runSingle("MATH.BAS", expect: "256") }
    func testCOMPARE_BAS() throws { try runSingle("COMPARE.BAS", expect: "Grade: B") }
    func testFORLOOP_BAS() throws { try runSingle("FORLOOP.BAS", expect: "Done!") }
    func testWHILE_BAS() throws { try runSingle("WHILE.BAS", expect: "128") }
    func testNESTED_BAS() throws { try runSingle("NESTED.BAS", expect: "25") }
    func testGOSUB_BAS() throws { try runSingle("GOSUB.BAS", expect: "Main program ending") }
    func testMENU_BAS() throws { try runSingle("MENU.BAS", expect: "Option 3 selected") }
    func testDATAREAD_BAS() throws { try runSingle("DATAREAD.BAS", expect: "Planet data:") }

    /// Backward-compatible alias for older CI commands and scripts.
    func testLoadAndRunDATAREAD_BAS() throws { try runSingle("DATAREAD.BAS", expect: "Planet data:") }
    func testARRAY_BAS() throws { try runSingle("ARRAY.BAS", expect: "Test scores:") }
    func testDICE_BAS() throws { try runSingle("DICE.BAS", expect: "Rolling dice") }
    func testFIBON_BAS() throws { try runSingle("FIBON.BAS", expect: "Fibonacci") }
    func testTABLES_BAS() throws { try runSingle("TABLES.BAS", expect: "----+") }
    func testSHAPES_BAS() throws { try runSingle("SHAPES.BAS", expect: "Shapes drawn!") }
    func testBOXES_BAS() throws { try runSingle("BOXES.BAS", expect: "Nested boxes") }
    func testSTARS_BAS() throws { try runSingle("STARS.BAS", expect: "Starfield complete") }
    func testMOIRE_BAS() throws { try runSingle("MOIRE.BAS", expect: "Moire pattern") }
    func testSINEWAVE_BAS() throws { try runSingle("SINEWAVE.BAS", expect: "Sine wave plotted") }
    func testFLAG_BAS() throws { try runSingle("FLAG.BAS", expect: "Flag drawn!") }

    // MARK: - Helpers

    private func runSingle(_ filename: String, expect expected: String) throws {
        launchApp(sample: filename)
        try runFromRunMenu()
        assertOutput(filename, contains: expected)
    }

    private func launchApp(sample filename: String?) {
        if let filename {
            app.launchEnvironment = ["UI_TEST_SAMPLE": filename]
        } else {
            app.launchEnvironment = [:]
        }
        app.launch()
    }

    private func relaunchApp(sample filename: String) {
        app.terminate()
        launchApp(sample: filename)
    }

    private func dismissWelcomeIfNeeded() throws {
        let dismiss = app.buttons["welcomeDismiss"]
        if dismiss.waitForExistence(timeout: 3) {
            dismiss.tap()
            XCTAssertFalse(app.staticTexts["Welcome to"].waitForExistence(timeout: 2))
        }
    }

    private func runFromRunMenu() throws {
        try dismissWelcomeIfNeeded()
        app.buttons["menuRun"].tap()
        let start = app.buttons["menuItem_Run_Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
    }

    private func openSampleLibrary() throws {
        try dismissWelcomeIfNeeded()
        app.buttons["menuFile"].tap()
        let openSamples = app.buttons["menuItem_File_Open Sample Program..."]
        XCTAssertTrue(openSamples.waitForExistence(timeout: 3))
        openSamples.tap()
        XCTAssertTrue(app.navigationBars["Sample Programs"].waitForExistence(timeout: 5))
    }

    private func filterSampleList(to filename: String) {
        let query = filename.replacingOccurrences(of: ".BAS", with: "")
        guard let search = activateSampleSearchField() else { return }
        search.typeFilteredQuery(query)
    }

    private func activateSampleSearchField() -> XCUIElement? {
        let byPrompt = app.searchFields["Filter samples"]
        if byPrompt.waitForExistence(timeout: 3) {
            byPrompt.tap()
            byPrompt.clearText()
            return byPrompt
        }

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 2) {
            search.tap()
            search.clearText()
            return search
        }

        let searchButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Search")
        ).firstMatch
        guard searchButton.waitForExistence(timeout: 2) else { return nil }
        searchButton.tap()
        guard search.waitForExistence(timeout: 3) else { return nil }
        search.tap()
        search.clearText()
        return search
    }

    private func tapSampleRow(_ filename: String) {
        filterSampleList(to: filename)
        let row = app.descendants(matching: .any)["sample_\(filename)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Sample row \(filename) not found")

        if row.isHittable {
            row.tap()
        } else {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func loadAndRunFromLibrary(_ filename: String, expect expected: String) throws {
        try openSampleLibrary()
        tapSampleRow(filename)

        let loadAndRun = app.buttons["loadAndRun"]
        XCTAssertTrue(loadAndRun.waitForExistence(timeout: 3))
        loadAndRun.tap()

        assertOutput(filename, contains: expected)
    }

    private func assertOutput(_ filename: String, contains expected: String) {
        let output = app.staticTexts["programOutput"]
        XCTAssertTrue(output.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["returnToEditor"].waitForExistence(timeout: 5))

        let text = waitForProgramOutput(containing: expected, element: output, timeout: 25)
        XCTAssertFalse(text.contains("Syntax error"), "\(filename): \(text)")
        XCTAssertFalse(text.contains("Empty statement"), "\(filename): \(text)")
        XCTAssertTrue(
            text.contains(expected),
            "\(filename): expected '\(expected)' in output: \(text)"
        )
    }

    private func waitForProgramOutput(
        containing expected: String,
        element: XCUIElement,
        timeout: TimeInterval
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var text = element.label
        while Date() < deadline {
            if app.progressIndicators.firstMatch.exists {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                text = element.label
                continue
            }
            text = element.label
            if text.contains(expected) { return text }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.label
    }

    private func returnToEditor() {
        let edit = app.buttons["returnToEditor"]
        if edit.waitForExistence(timeout: 2) {
            edit.tap()
        }
    }
}

private extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String, !stringValue.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }

    func typeFilteredQuery(_ query: String) {
        typeText(query)
    }
}