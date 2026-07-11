import XCTest
@testable import QBEngine
@testable import TabletBasic

final class TabletBasicTests: XCTestCase {
    @MainActor
    func testNewFileDismissesWelcomeAndClearsDocument() {
        let viewModel = IDEViewModel()
        XCTAssertTrue(viewModel.showWelcome)

        viewModel.handleShortcut(.newFile)

        XCTAssertFalse(viewModel.showWelcome)
        XCTAssertFalse(viewModel.showRunOutput)
        XCTAssertEqual(viewModel.documentName, "Untitled")
        XCTAssertEqual(viewModel.sourceCode, "")
        XCTAssertEqual(viewModel.cursorLine, 1)
        XCTAssertEqual(viewModel.cursorColumn, 1)
    }

    @MainActor
    func testNewFileClearsLoadedSampleProgram() {
        let viewModel = IDEViewModel()
        guard let math = SampleProgramLibrary.all.first(where: { $0.filename == "MATH.BAS" }) else {
            XCTFail("MATH.BAS missing")
            return
        }

        viewModel.loadSampleProgram(math)
        XCTAssertEqual(viewModel.documentName, "MATH.BAS")
        XCTAssertFalse(viewModel.sourceCode.isEmpty)

        viewModel.handleShortcut(.newFile)

        XCTAssertEqual(viewModel.documentName, "Untitled")
        XCTAssertEqual(viewModel.sourceCode, "")
        XCTAssertFalse(viewModel.showProgramLibrary)
    }

    @MainActor
    func testMenuActionsPresentEditor() async throws {
        let viewModel = IDEViewModel()
        guard let math = SampleProgramLibrary.all.first(where: { $0.filename == "MATH.BAS" }) else {
            XCTFail("MATH.BAS missing")
            return
        }

        viewModel.loadSampleProgram(math)
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.showRunOutput)

        viewModel.handleShortcut(.returnToEditor)
        XCTAssertFalse(viewModel.showRunOutput)

        viewModel.handleShortcut(.newFile)
        XCTAssertFalse(viewModel.showRunOutput)
        viewModel.sourceCode = "PRINT \"Menu test\""
        viewModel.handleShortcut(.insertLineNumber)
        XCTAssertFalse(viewModel.showRunOutput)
        XCTAssertTrue(viewModel.sourceCode.contains("10 PRINT"))
    }

    @MainActor
    func testInputPromptSuspendsUntilSubmit() async throws {
        let viewModel = IDEViewModel()
        viewModel.sourceCode = """
        INPUT "length"; L
        INPUT "breadth"; B
        A = L * B
        PRINT "area="; A
        """
        viewModel.runProgram()

        for _ in 0..<30 {
            if viewModel.showInputPrompt { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertTrue(viewModel.showInputPrompt)
        XCTAssertEqual(viewModel.inputPromptText, "length")

        viewModel.inputPromptValue = "5"
        viewModel.submitInputPrompt()

        for _ in 0..<30 {
            if viewModel.showInputPrompt { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertTrue(viewModel.showInputPrompt)
        XCTAssertEqual(viewModel.inputPromptText, "breadth")

        viewModel.inputPromptValue = "4"
        viewModel.submitInputPrompt()

        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.outputText.contains("area="))
        XCTAssertTrue(viewModel.outputText.contains("20"))
        XCTAssertFalse(viewModel.showInputPrompt)
    }

    @MainActor
    func testLoadMathBasAndRunThroughViewModel() async throws {
        let viewModel = IDEViewModel()
        guard let math = SampleProgramLibrary.all.first(where: { $0.filename == "MATH.BAS" }) else {
            XCTFail("MATH.BAS missing from library")
            return
        }

        viewModel.loadSampleProgram(math)
        XCTAssertEqual(viewModel.documentName, "MATH.BAS")

        viewModel.runProgram()
        for _ in 0..<30 {
            if !viewModel.isRunning { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.outputText.contains("Empty statement"))
        XCTAssertFalse(viewModel.outputText.contains("Syntax error"))
        XCTAssertTrue(viewModel.outputText.contains(math.smokeTestMarker))
    }

    @MainActor
    func testEverySampleProgramNormalizesAndParses() throws {
        var parser = ProgramParser()
        for program in SampleProgramLibrary.all {
            let normalized = BasicSourceNormalizer.normalize(program.code)
            XCTAssertNoThrow(try parser.parse(source: normalized), program.filename)
        }
    }

    func testSampleLibraryHasEightyPrograms() {
        XCTAssertEqual(SampleProgramLibrary.programCount, 81)
        XCTAssertEqual(SampleProgramLibrary.all.count, 81)
    }

    func testEveryLessonHasValidStarterCode() throws {
        var parser = ProgramParser()
        for lesson in LessonCatalog.all {
            let normalized = BasicSourceNormalizer.normalize(lesson.starterCode)
            XCTAssertNoThrow(
                try parser.parse(source: normalized),
                "Lesson \(lesson.id) starter code failed to parse"
            )
        }
    }

    func testLessonCatalogHasSixteenChapters() {
        let chapters = Set(LessonCatalog.all.map(\.chapter))
        XCTAssertEqual(chapters.count, 16)
    }

    func testSourceCursorTracksSelection() {
        let text = "ab\ncd"
        assertCursor(SourceCursor.position(in: text, location: 0), line: 1, column: 1)
        assertCursor(SourceCursor.position(in: text, location: 2), line: 1, column: 3)
        assertCursor(SourceCursor.position(in: text, location: 3), line: 2, column: 1)
        assertCursor(SourceCursor.position(in: text, location: 4), line: 2, column: 2)
        assertCursor(SourceCursor.position(in: "", location: 0), line: 1, column: 1)
    }

    private func assertCursor(_ position: (line: Int, column: Int), line: Int, column: Int) {
        XCTAssertEqual(position.line, line)
        XCTAssertEqual(position.column, column)
    }

    @MainActor
    func testOpenAndSaveBasicProgramFile() throws {
        let viewModel = IDEViewModel()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("RoundTrip-\(UUID().uuidString).bas")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let source = """
        PRINT "Files test"
        A = 2 ^ 8
        PRINT A
        """
        try source.write(to: fileURL, atomically: true, encoding: .utf8)

        viewModel.openExternalURL(fileURL)
        XCTAssertEqual(viewModel.documentName, fileURL.lastPathComponent)
        XCTAssertTrue(viewModel.sourceCode.contains("Files test"))
        XCTAssertTrue(viewModel.canSaveToCurrentFile)

        viewModel.sourceCode += "\nPRINT \"Saved\""
        viewModel.requestSaveFile()
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), viewModel.preparedSource)
    }

    @MainActor
    func testBasicProgramDocumentPreservesSource() {
        let original = "PRINT \"Hello\"\nA = 10"
        let document = BasicProgramDocument(text: original)
        XCTAssertEqual(document.text, original)

        let viewModel = IDEViewModel()
        viewModel.sourceCode = original
        XCTAssertEqual(viewModel.exportDocument.text, viewModel.preparedSource)
    }

    @MainActor
    func testSwitchingBetweenGraphicsAndTextProgramsClearsScreen() async throws {
        let viewModel = IDEViewModel()
        let graphics = try XCTUnwrap(
            SampleProgramLibrary.all.first(where: { $0.filename == "SHAPES.BAS" })
        )
        let text = try XCTUnwrap(
            SampleProgramLibrary.all.first(where: { $0.filename == "HELLO.BAS" })
        )

        viewModel.loadSampleProgram(graphics)
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.screen.isGraphicsMode)
        XCTAssertTrue(viewModel.outputText.contains(graphics.smokeTestMarker))

        viewModel.loadSampleProgram(text)
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertFalse(viewModel.screen.isGraphicsMode)
        XCTAssertTrue(viewModel.outputText.contains(text.smokeTestMarker))

        viewModel.loadSampleProgram(graphics)
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.screen.isGraphicsMode)
        XCTAssertTrue(viewModel.outputText.contains(graphics.smokeTestMarker))
    }

    @MainActor
    func testFindLocatesTextAndUpdatesCursor() {
        let viewModel = IDEViewModel()
        viewModel.sourceCode = """
        PRINT "Hello"
        PRINT "World"
        X = 1
        """
        viewModel.openFind()
        viewModel.findQuery = "World"
        viewModel.findNext()
        XCTAssertEqual(viewModel.cursorLine, 2)
        XCTAssertTrue(viewModel.findStatus.contains("Found"))

        viewModel.openFind()
        viewModel.findQuery = "Hello"
        viewModel.findReplaceText = "Hi"
        viewModel.replaceNext()
        XCTAssertTrue(viewModel.sourceCode.contains("Hi"))
        XCTAssertFalse(viewModel.sourceCode.contains("Hello"))
    }

    @MainActor
    func testStopAndBreakpointAPIs() async throws {
        let viewModel = IDEViewModel()
        viewModel.sourceCode = """
        DO
          SLEEP 0.05
        LOOP
        PRINT "NEVER"
        """
        viewModel.cursorLine = 2
        viewModel.toggleBreakpointAtCursor()
        XCTAssertTrue(viewModel.breakpoints.contains(2))
        viewModel.addWatch("X%")
        XCTAssertTrue(viewModel.watchList.contains("X%"))

        viewModel.runProgram()
        try await Task.sleep(nanoseconds: 80_000_000)
        viewModel.stopProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertFalse(viewModel.outputText.contains("NEVER"))
    }

    @MainActor
    private func waitForProgramFinish(_ viewModel: IDEViewModel) async throws {
        for _ in 0..<50 {
            if !viewModel.isRunning { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Program did not finish")
    }

    @MainActor
    func testEverySampleProgramRunsWithoutError() async throws {
        for program in SampleProgramLibrary.all {
            let viewModel = IDEViewModel()
            viewModel.loadSampleProgram(program)
            viewModel.runProgram()
            for _ in 0..<50 {
                if !viewModel.isRunning { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertFalse(viewModel.isRunning, program.filename)
            XCTAssertFalse(
                viewModel.outputText.contains("Empty statement"),
                "\(program.filename): \(viewModel.outputText)"
            )
            XCTAssertFalse(
                viewModel.outputText.contains("Syntax error"),
                "\(program.filename): \(viewModel.outputText)"
            )
            XCTAssertTrue(
                viewModel.outputText.contains(program.smokeTestMarker),
                "\(program.filename): expected '\(program.smokeTestMarker)' in output: \(viewModel.outputText)"
            )
        }
    }
}