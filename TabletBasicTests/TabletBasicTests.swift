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

    func testLessonCatalogHasSeventeenChapters() {
        let chapters = Set(LessonCatalog.all.map(\.chapter))
        XCTAssertEqual(chapters.count, 17)
        XCTAssertEqual(LessonCatalog.all.last?.id, "17-procedures")
        XCTAssertTrue(
            LessonCatalog.all.first(where: { $0.id == "04-if" })?.starterCode.contains("END IF") == true
        )
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
    func testUnsavedIndicatorAfterEdit() {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        XCTAssertFalse(viewModel.isDocumentDirty)
        XCTAssertEqual(viewModel.documentTitle, "Untitled")

        viewModel.sourceCode = "PRINT 1"
        XCTAssertTrue(viewModel.isDocumentDirty)
        XCTAssertEqual(viewModel.documentTitle, "Untitled*")
    }

    @MainActor
    func testUndoRedoRestoresSource() {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = "PRINT 1"
        viewModel.sourceCode = "PRINT 2"
        XCTAssertTrue(viewModel.canUndo)

        viewModel.handleShortcut(.undo)
        XCTAssertEqual(viewModel.sourceCode, "PRINT 1")
        viewModel.handleShortcut(.redo)
        XCTAssertEqual(viewModel.sourceCode, "PRINT 2")
    }

    func testSourceFindFindsAndWraps() {
        let text = "PRINT \"Hello\"\nPRINT \"World\""
        let first = SourceFind.find(in: text, query: "PRINT", startUTF16: 0)
        XCTAssertEqual(first?.line, 1)
        let afterFirst = (first?.utf16Range.location ?? 0) + 1
        let second = SourceFind.find(in: text, query: "PRINT", startUTF16: afterFirst)
        XCTAssertEqual(second?.line, 2)
        let wrapped = SourceFind.find(in: text, query: "Hello", startUTF16: (text as NSString).length)
        XCTAssertEqual(wrapped?.line, 1)
    }

    @MainActor
    func testFindNextMovesCursor() {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = "PRINT \"A\"\nPRINT \"B\""
        viewModel.findQuery = "PRINT"
        viewModel.cursorLine = 1
        viewModel.cursorColumn = 1
        viewModel.findNext(skipCurrent: false)
        XCTAssertEqual(viewModel.cursorLine, 1)
        viewModel.findNext()
        XCTAssertEqual(viewModel.cursorLine, 2)
    }

    @MainActor
    func testJumpToErrorUsesInterpreterLine() async throws {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = """
        PRINT "ok"
        THIS IS NOT VALID BASIC
        """
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertNotNil(viewModel.lastErrorLine)
        viewModel.handleShortcut(.jumpToError)
        XCTAssertEqual(viewModel.cursorLine, viewModel.lastErrorLine)
    }

    @MainActor
    func testImmediateModePreservesPriorProgramOutput() async throws {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = "PRINT \"ALPHA\""
        viewModel.runProgram()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.outputText.contains("ALPHA"), viewModel.outputText)

        viewModel.immediateInput = "PRINT \"BETA\""
        viewModel.runImmediate()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.outputText.contains("ALPHA"), viewModel.outputText)
        XCTAssertTrue(viewModel.outputText.contains("BETA"), viewModel.outputText)

        viewModel.immediateInput = "PRINT \"GAMMA\""
        viewModel.runImmediate()
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(viewModel.outputText.contains("ALPHA"), viewModel.outputText)
        XCTAssertTrue(viewModel.outputText.contains("BETA"), viewModel.outputText)
        XCTAssertTrue(viewModel.outputText.contains("GAMMA"), viewModel.outputText)
    }

    @MainActor
    func testStopCancelsRunningProgram() async throws {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = """
        DO
            SLEEP 10
        LOOP
        """
        viewModel.runProgram()
        for _ in 0..<20 {
            if viewModel.isRunning { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(viewModel.isRunning)
        viewModel.handleShortcut(.stop)
        try await waitForProgramFinish(viewModel)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.statusMessage, "Stopped")
    }

    @MainActor
    func testLiveOutputUpdatesWhileProgramRuns() async throws {
        let viewModel = IDEViewModel()
        viewModel.handleShortcut(.newFile)
        viewModel.sourceCode = """
        PRINT "FIRST"
        SLEEP 0.2
        PRINT "SECOND"
        """
        viewModel.runProgram()
        var sawFirstWhileRunning = false
        for _ in 0..<30 {
            if viewModel.isRunning && viewModel.outputText.contains("FIRST") {
                sawFirstWhileRunning = true
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try await waitForProgramFinish(viewModel)
        XCTAssertTrue(sawFirstWhileRunning, "output should refresh before the program ends: \(viewModel.outputText)")
        XCTAssertTrue(viewModel.outputText.contains("SECOND"))
    }

    func testLessonCheckerUsesShippedInterpreter() async throws {
        let lesson = try XCTUnwrap(LessonCatalog.all.first(where: { $0.id == "01-hello" }))
        let result = await LessonChecker.check(
            source: lesson.starterCode,
            expectedOutput: lesson.expectedOutput
        )
        XCTAssertTrue(result.passed, "\(result.error ?? "") \(result.output)")
        XCTAssertTrue(LessonChecker.matches(actual: result.output, expected: lesson.expectedOutput))
    }

    func testChapterFourUsesBlockIf() async throws {
        let lesson = try XCTUnwrap(LessonCatalog.all.first(where: { $0.id == "04-if" }))
        XCTAssertTrue(lesson.starterCode.contains("END IF"))
        XCTAssertFalse(lesson.starterCode.contains("GOTO"))
        let result = await LessonChecker.check(
            source: lesson.starterCode,
            expectedOutput: lesson.expectedOutput
        )
        XCTAssertTrue(result.passed, result.error ?? result.output)
        XCTAssertTrue(result.output.contains("Grade: B"), result.output)
    }

    func testChapterSeventeenProcedures() async throws {
        let lesson = try XCTUnwrap(LessonCatalog.all.first(where: { $0.id == "17-procedures" }))
        let result = await LessonChecker.check(
            source: lesson.starterCode,
            expectedOutput: lesson.expectedOutput
        )
        XCTAssertTrue(result.passed, result.error ?? result.output)
        XCTAssertTrue(result.output.contains("Add(3, 4) ="), result.output)
    }

    func testLessonProgressPersistsLocally() {
        let suite = "tabletbasic.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(LessonProgressStore.isComplete("01-hello", defaults: defaults))
        LessonProgressStore.markComplete("01-hello", defaults: defaults)
        XCTAssertTrue(LessonProgressStore.isComplete("01-hello", defaults: defaults))
        XCTAssertTrue(LessonProgressStore.completedIDs(defaults: defaults).contains("01-hello"))
    }

    func testLanguageGuideMentionsNewSurface() {
        let joined = BasicLanguageGuide.sections.map(\.content).joined(separator: "\n")
        XCTAssertFalse(joined.contains("80 built-in"))
        XCTAssertFalse(joined.contains("not supported yet"))
        XCTAssertTrue(joined.contains("81 built-in"))
        XCTAssertTrue(joined.contains("HEX$"))
        XCTAssertTrue(joined.contains("INKEY$"))
        XCTAssertTrue(joined.contains("LOOP WHILE"))
        XCTAssertTrue(joined.contains("FUNCTION"))
    }

    @MainActor
    func testCheckLessonHelperMarksExpectedOutput() async throws {
        let viewModel = IDEViewModel()
        let lesson = try XCTUnwrap(LessonCatalog.all.first(where: { $0.id == "01-hello" }))
        viewModel.loadLesson(lesson)
        let result = await viewModel.checkLesson(lesson)
        XCTAssertTrue(result.passed, result.error ?? result.output)
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