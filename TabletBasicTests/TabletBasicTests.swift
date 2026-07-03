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
        XCTAssertTrue(viewModel.outputText.contains("4") || viewModel.outputText.contains("256"))
    }

    @MainActor
    func testEverySampleProgramNormalizesAndParses() throws {
        let parser = ProgramParser()
        for program in SampleProgramLibrary.all {
            let normalized = BasicSourceNormalizer.normalize(program.code)
            XCTAssertNoThrow(try parser.parse(source: normalized), program.filename)
        }
    }

    func testSampleLibraryHasTwentyPrograms() {
        XCTAssertEqual(SampleProgramLibrary.all.count, 20)
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
    func testEachSampleProgramByFilename() async throws {
        for filename in expectedFilenames {
            try await assertViewModelRuns(filename)
        }
    }

    // Individual tests for precise failure reporting in Xcode / CI.
    @MainActor func testHELLO_BAS() async throws { try await assertViewModelRuns("HELLO.BAS") }
    @MainActor func testVARS_BAS() async throws { try await assertViewModelRuns("VARS.BAS") }
    @MainActor func testMATH_BAS() async throws { try await assertViewModelRuns("MATH.BAS") }
    @MainActor func testCOMPARE_BAS() async throws { try await assertViewModelRuns("COMPARE.BAS") }
    @MainActor func testFORLOOP_BAS() async throws { try await assertViewModelRuns("FORLOOP.BAS") }
    @MainActor func testWHILE_BAS() async throws { try await assertViewModelRuns("WHILE.BAS") }
    @MainActor func testNESTED_BAS() async throws { try await assertViewModelRuns("NESTED.BAS") }
    @MainActor func testGOSUB_BAS() async throws { try await assertViewModelRuns("GOSUB.BAS") }
    @MainActor func testMENU_BAS() async throws { try await assertViewModelRuns("MENU.BAS") }
    @MainActor func testDATAREAD_BAS() async throws { try await assertViewModelRuns("DATAREAD.BAS") }
    @MainActor func testARRAY_BAS() async throws { try await assertViewModelRuns("ARRAY.BAS") }
    @MainActor func testDICE_BAS() async throws { try await assertViewModelRuns("DICE.BAS") }
    @MainActor func testFIBON_BAS() async throws { try await assertViewModelRuns("FIBON.BAS") }
    @MainActor func testTABLES_BAS() async throws { try await assertViewModelRuns("TABLES.BAS") }
    @MainActor func testSHAPES_BAS() async throws { try await assertViewModelRuns("SHAPES.BAS") }
    @MainActor func testBOXES_BAS() async throws { try await assertViewModelRuns("BOXES.BAS") }
    @MainActor func testSTARS_BAS() async throws { try await assertViewModelRuns("STARS.BAS") }
    @MainActor func testMOIRE_BAS() async throws { try await assertViewModelRuns("MOIRE.BAS") }
    @MainActor func testSINEWAVE_BAS() async throws { try await assertViewModelRuns("SINEWAVE.BAS") }
    @MainActor func testFLAG_BAS() async throws { try await assertViewModelRuns("FLAG.BAS") }

    @MainActor
    private func assertViewModelRuns(_ filename: String) async throws {
        let program = try XCTUnwrap(
            SampleProgramLibrary.all.first { $0.filename == filename },
            "Missing \(filename)"
        )
        let viewModel = IDEViewModel()
        viewModel.loadSampleProgram(program)
        viewModel.runProgram()
        for _ in 0..<50 {
            if !viewModel.isRunning { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(viewModel.isRunning, filename)
        XCTAssertFalse(viewModel.outputText.contains("Syntax error"), filename)
        XCTAssertFalse(viewModel.outputText.contains("Empty statement"), filename)
    }

    @MainActor
    func testEverySampleProgramRunsWithoutError() async throws {
        let viewModel = IDEViewModel()
        for program in SampleProgramLibrary.all {
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
        }
    }

    private let expectedFilenames = [
        "HELLO.BAS", "VARS.BAS", "MATH.BAS", "COMPARE.BAS",
        "FORLOOP.BAS", "WHILE.BAS", "NESTED.BAS", "GOSUB.BAS", "MENU.BAS",
        "DATAREAD.BAS", "ARRAY.BAS", "DICE.BAS", "FIBON.BAS", "TABLES.BAS",
        "SHAPES.BAS", "BOXES.BAS", "STARS.BAS", "MOIRE.BAS", "SINEWAVE.BAS", "FLAG.BAS"
    ]
}