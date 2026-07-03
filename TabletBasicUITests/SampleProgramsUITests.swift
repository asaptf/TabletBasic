import XCTest
import QBEngine

/// UI smoke tests: every bundled sample program runs in the app without errors.
@MainActor
final class SampleProgramsUITests: XCTestCase {
    private var app: XCUIApplication!

    private struct SampleExpectation {
        let filename: String
        let outputContains: String
    }

    private static let allPrograms: [SampleExpectation] = SampleProgramLibrary.all.map { program in
        SampleExpectation(filename: program.filename, outputContains: program.smokeTestMarker)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
    }

    func testLibraryListsAllSamplePrograms() throws {
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

    // MARK: - Helpers

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
        let quickRun = app.buttons["quickRun"]
        if quickRun.waitForExistence(timeout: 1) {
            quickRun.tap()
        } else {
            app.tapMenuItem(menu: "Run", item: "Start")
        }
    }

    private func openSampleLibrary() throws {
        try dismissWelcomeIfNeeded()
        app.tapMenuItem(menu: "File", item: "Open Sample Program...")
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
        XCTAssertTrue(output.waitForExistence(timeout: 10))
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