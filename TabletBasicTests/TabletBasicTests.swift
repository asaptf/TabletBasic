import XCTest
@testable import QBEngine
@testable import TabletBasic

final class TabletBasicTests: XCTestCase {
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
        let parser = ProgramParser()
        for program in SampleProgramLibrary.all {
            let normalized = BasicSourceNormalizer.normalize(program.code)
            XCTAssertNoThrow(try parser.parse(source: normalized), program.filename)
        }
    }

    func testSampleLibraryHasEightyPrograms() {
        XCTAssertEqual(SampleProgramLibrary.programCount, 80)
        XCTAssertEqual(SampleProgramLibrary.all.count, 80)
    }

    func testEveryLessonHasValidStarterCode() throws {
        let parser = ProgramParser()
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