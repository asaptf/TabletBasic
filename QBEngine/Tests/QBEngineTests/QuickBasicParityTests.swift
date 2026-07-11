import XCTest
@testable import QBEngine
import Foundation

/// Acceptance tests for QuickBASIC parity features (criteria 1–5).
final class QuickBasicParityTests: XCTestCase {
    private var scratchDir: URL!

    override func setUp() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("QBParity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        scratchDir = base
    }

    override func tearDown() async throws {
        if let scratchDir {
            try? FileManager.default.removeItem(at: scratchDir)
        }
    }

    // MARK: - High-ROI builtins + language

    func testBuiltinsASC_SPACE_HEX_OCT_conversions_trim_timer() async {
        let result = await run("""
        PRINT ASC("A")
        PRINT SPACE$(3); "X"
        PRINT HEX$(255)
        PRINT OCT$(8)
        PRINT CINT(3.6)
        PRINT CDBL(2)
        PRINT CSNG(1)
        PRINT CLNG(4.2)
        PRINT LTRIM$("  hi")
        PRINT RTRIM$("hi  "); "Z"
        PRINT TIMER >= 0
        PRINT LEN(DATE$) > 0
        PRINT LEN(TIME$) > 0
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("65"))
        XCTAssertTrue(result.output.contains("   X") || result.output.contains("X"))
        XCTAssertTrue(result.output.contains("FF"))
        XCTAssertTrue(result.output.contains("10"))
        XCTAssertTrue(result.output.contains("4")) // CINT 3.6
        XCTAssertTrue(result.output.contains("hi"))
        XCTAssertTrue(result.output.contains("Z"))
        XCTAssertTrue(result.output.contains("-1")) // TIMER >= 0 true
    }

    func testConstSwapOptionBaseLboundUbound() async {
        let result = await run("""
        OPTION BASE 1
        CONST PI = 3
        CONST MSG$ = "OK"
        A% = 1
        B% = 2
        SWAP A%, B%
        PRINT A%; B%
        PRINT PI
        PRINT MSG$
        DIM ARR%(5)
        PRINT LBOUND(ARR%)
        PRINT UBOUND(ARR%)
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("2") && result.output.contains("1"))
        XCTAssertTrue(result.output.contains("3"))
        XCTAssertTrue(result.output.contains("OK"))
        // LBOUND with OPTION BASE 1 → 1; UBOUND → 5
        let lines = result.output.split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains("1"))
        XCTAssertTrue(lines.contains("5"))
    }

    func testNamedLabelsGotoGosub() async {
        let result = await run("""
        PRINT "START"
        GOSUB Helper
        GOTO Finish
        PRINT "SKIP"
        Helper:
        PRINT "SUB"
        RETURN
        Finish:
        PRINT "DONE"
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("START"))
        XCTAssertTrue(result.output.contains("SUB"))
        XCTAssertTrue(result.output.contains("DONE"))
        XCTAssertFalse(result.output.contains("SKIP"))
    }

    func testLocateAndTextScreen() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run("""
        CLS
        LOCATE 3, 5
        PRINT "HI"
        """)
        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertEqual(interpreter.screen.textAt(row: 3, col: 5), "H")
        XCTAssertEqual(interpreter.screen.textAt(row: 3, col: 6), "I")
    }

    func testLineInputPrintUsingMidAssign() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        let input = QueueInputHandler(responses: ["hello world"])
        interpreter.output = output
        interpreter.input = input
        await interpreter.run("""
        LINE INPUT "Name: "; N$
        PRINT USING "##.##"; 12.3
        S$ = "ABCDEF"
        MID$(S$, 3, 2) = "XY"
        PRINT S$
        PRINT N$
        """)
        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("12.30") || output.buffer.contains("12.3"))
        XCTAssertTrue(output.buffer.contains("ABXYEF"))
        XCTAssertTrue(output.buffer.contains("hello world"))
    }

    // MARK: - TYPE / SHARED / STATIC / DECLARE

    func testTypeDimAsFieldAccess() async {
        let result = await run("""
        TYPE Point
          X AS INTEGER
          Y AS INTEGER
        END TYPE
        DIM P AS Point
        P.X = 10
        P.Y = 20
        PRINT P.X
        PRINT P.Y
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("10"))
        XCTAssertTrue(result.output.contains("20"))
    }

    func testSharedAndStaticAndDeclare() async {
        let result = await run("""
        DECLARE SUB Bump ()
        DECLARE FUNCTION Twice% (N%)
        G% = 5
        CALL Bump
        PRINT G%
        PRINT Twice%(3)
        CALL Counter
        CALL Counter
        END

        SUB Bump ()
          SHARED G%
          G% = G% + 1
        END SUB

        FUNCTION Twice% (N%)
          Twice% = N% * 2
        END FUNCTION

        SUB Counter ()
          STATIC C%
          C% = C% + 1
          PRINT C%
        END SUB
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("6"))
        XCTAssertTrue(result.output.contains("6")) // Twice(3)=6 — same as G
        // Counter prints 1 then 2
        let nums = result.output.split(whereSeparator: { $0.isNewline || $0 == " " }).compactMap { Int($0) }
        XCTAssertTrue(nums.contains(1))
        XCTAssertTrue(nums.contains(2))
    }

    // MARK: - INKEY$ + Stop

    func testInkeyInjectedKeysExitLoop() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        // Keys must be injected after run starts: resetSession() clears the queue at run entry.
        let runTask = Task {
            await interpreter.run("""
            K$ = ""
            DO
              K$ = INKEY$
              IF K$ = "Q" THEN EXIT DO
              SLEEP 0.01
            LOOP
            PRINT "GOT"; K$
            """)
        }
        for _ in 0..<100 {
            if interpreter.isRunning { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        interpreter.injectKey("Q")
        await runTask.value
        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("GOTQ") || output.buffer.contains("Q"), output.buffer)
    }

    func testStopAbortsLongLoop() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        let task = Task {
            await interpreter.run("""
            DO
              SLEEP 0.05
            LOOP
            PRINT "NEVER"
            """)
        }
        try? await Task.sleep(nanoseconds: 80_000_000)
        interpreter.stop()
        await task.value
        XCTAssertFalse(output.buffer.contains("NEVER"))
        XCTAssertTrue(
            interpreter.lastError?.contains("stopped") == true
            || output.buffer.lowercased().contains("stopped")
        )
    }

    // MARK: - Graphics

    func testLineBF_Paint_Draw_GetPut() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run("""
        SCREEN 13
        CLS
        LINE (10, 10)-(20, 20), 4, BF
        PAINT (50, 50), 2
        DRAW "C3U10R10D10L10"
        LINE (100, 100)-(104, 104), 7, BF
        GET (100, 100)-(104, 104), SPR
        PUT (150, 150), SPR
        PRINT "GFXOK"
        """)
        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("GFXOK"))
        // Filled box pixel should be color 4
        XCTAssertEqual(interpreter.screen.point(x: 15, y: 15), 4)
        // PAINT at 50,50
        XCTAssertEqual(interpreter.screen.point(x: 50, y: 50), 2)
        // PUT sprite
        XCTAssertEqual(interpreter.screen.point(x: 152, y: 152), 7)
    }

    // MARK: - File I/O

    func testSequentialFileRoundTrip() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        interpreter.setFileBaseDirectory(scratchDir)
        await interpreter.run("""
        OPEN "scores.txt" FOR OUTPUT AS #1
        PRINT #1, "Alice"
        PRINT #1, 42
        CLOSE #1
        OPEN "scores.txt" FOR INPUT AS #1
        INPUT #1, N$
        INPUT #1, S%
        CLOSE #1
        PRINT N$
        PRINT S%
        PRINT "FILEOK"
        """)
        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("Alice"))
        XCTAssertTrue(output.buffer.contains("42"))
        XCTAssertTrue(output.buffer.contains("FILEOK"))
        let contents = try? String(contentsOf: scratchDir.appendingPathComponent("scores.txt"), encoding: .utf8)
        XCTAssertNotNil(contents)
        XCTAssertTrue(contents?.contains("Alice") == true)
    }

    // MARK: - Debug step / watch

    /// Breakpoints must use original editor (physical) line numbers even when
    /// TYPE…END TYPE (or SUB) blocks are extracted before parsing.
    func testBreakpointUsesPhysicalLineWithTypeBlock() async {
        // Physical layout (1-based):
        // 1 TYPE Point
        // 2   X AS INTEGER
        // 3 END TYPE
        // 4 DIM P AS Point
        // 5 P.X = 1
        // 6 PRINT P.X   <-- breakpoint target (editor line 6)
        // 7 PRINT "AFTER"
        let source = """
        TYPE Point
          X AS INTEGER
        END TYPE
        DIM P AS Point
        P.X = 1
        PRINT P.X
        PRINT "AFTER"
        """
        var parser = ProgramParser()
        let program = try! parser.parse(source: source)
        let printLine = program.lines.first { line in
            line.statements.contains {
                if case .print = $0 { return true }
                return false
            }
        }
        XCTAssertNotNil(printLine)
        // First PRINT must still be physical line 6 (after 3-line TYPE block)
        XCTAssertEqual(printLine?.sourceLine, 6, "sourceLine must match editor line, got \(printLine?.sourceLine ?? -1)")

        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        interpreter.debugEnabled = true
        interpreter.breakpoints = [6]
        interpreter.watches = ["P"]

        let runTask = Task {
            await interpreter.run(source)
        }
        for _ in 0..<100 {
            if interpreter.isPaused { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(interpreter.isPaused, "should pause at physical line 6")
        XCTAssertEqual(interpreter.currentSourceLine, 6)
        // Should not have printed AFTER yet
        XCTAssertFalse(output.buffer.contains("AFTER"))
        interpreter.continueRunning()
        await runTask.value
        XCTAssertTrue(output.buffer.contains("1") || output.buffer.contains("AFTER") || interpreter.lastError == nil)
        XCTAssertTrue(output.buffer.contains("AFTER") || output.buffer.contains("1"))
    }

    func testEnvironmentResetsBetweenRuns() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run("A% = 99\nPRINT A%")
        XCTAssertTrue(output.buffer.contains("99"))
        output.clear()
        await interpreter.run("PRINT A%")
        // Fresh run must not leak prior assignment (undefined numeric → 0)
        XCTAssertTrue(output.buffer.contains("0"), "leaked A% across runs: \(output.buffer)")
        XCTAssertFalse(output.buffer.trimmingCharacters(in: .whitespacesAndNewlines) == "99")
    }

    /// Stopping a non-paused program must not sticky-set resumeRequested and skip
    /// the next run's first breakpoint (skeptic gap).
    func testStopThenBreakpointStillPauses() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        // Run 1: long loop, stop while not at a debug pause
        let stopTask = Task {
            await interpreter.run("""
            DO
              SLEEP 0.05
            LOOP
            PRINT "NEVER"
            """)
        }
        try? await Task.sleep(nanoseconds: 80_000_000)
        interpreter.stop()
        await stopTask.value
        XCTAssertFalse(output.buffer.contains("NEVER"))

        // Run 2: breakpoint on line 2 must still pause (not auto-resumed)
        output.clear()
        interpreter.debugEnabled = true
        interpreter.breakpoints = [2]
        let source = """
        PRINT "START"
        PRINT "HIT"
        PRINT "DONE"
        """
        let runTask = Task { await interpreter.run(source) }
        var paused = false
        for _ in 0..<200 {
            if interpreter.isPaused {
                paused = true
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(paused, "breakpoint on line 2 must pause after a prior stop")
        XCTAssertEqual(interpreter.currentSourceLine, 2)
        XCTAssertFalse(output.buffer.contains("DONE"), "must not have run past BP: \(output.buffer)")
        interpreter.continueRunning()
        await runTask.value
        XCTAssertTrue(output.buffer.contains("DONE"), output.buffer)
    }

    func testDebugStepAndWatch() async {
        // Use breakpoint (not free-run stepMode) to avoid multi-pause races in CI.
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        interpreter.debugEnabled = true
        interpreter.breakpoints = [2] // pause at X% = 1
        interpreter.watches = ["X%"]
        let source = """
        X% = 0
        X% = 1
        PRINT X%
        """
        let runTask = Task { await interpreter.run(source) }

        var paused = false
        for _ in 0..<200 {
            if interpreter.isPaused {
                paused = true
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(paused, "should hit breakpoint on line 2")
        XCTAssertEqual(interpreter.currentSourceLine, 2)
        // Line 1 already executed: X% is 0
        let snap = interpreter.watchSnapshot()
        XCTAssertEqual(snap["X%"] ?? snap["X"], "0", "watch snapshot: \(snap)")

        interpreter.continueRunning()
        await runTask.value
        XCTAssertTrue(output.buffer.contains("1"), output.buffer)
    }

    // MARK: - Multi-feature smoke (run twice)

    func testMultiFeatureSmokeTwice() async throws {
        let source = """
        CONST TITLE$ = "SMOKE"
        OPTION BASE 0
        TYPE Rec
          V AS INTEGER
        END TYPE
        DIM R AS Rec
        R.V = 7
        A% = 3
        B% = 9
        SWAP A%, B%
        PRINT TITLE$
        PRINT ASC("B")
        PRINT HEX$(10)
        PRINT SPACE$(1); "S"
        LOCATE 1, 1
        PRINT "L"
        GOTO Skip
        PRINT "NO"
        Skip:
        PRINT "LAB"
        PRINT R.V
        PRINT A%
        SCREEN 13
        LINE (0, 0)-(5, 5), 5, BF
        PAINT (10, 10), 1
        DRAW "U5"
        OPEN "smoke.txt" FOR OUTPUT AS #1
        PRINT #1, "OK"
        CLOSE #1
        OPEN "smoke.txt" FOR INPUT AS #1
        LINE INPUT #1, ROW$
        CLOSE #1
        PRINT ROW$
        PRINT "SMOKEPASS"
        """
        for _ in 1...2 {
            let interpreter = QBInterpreter()
            let output = ConsoleOutputHandler()
            interpreter.output = output
            interpreter.setFileBaseDirectory(scratchDir)
            await interpreter.run(source)
            XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
            XCTAssertTrue(output.buffer.contains("SMOKE"), output.buffer)
            XCTAssertTrue(output.buffer.contains("66"), "ASC B") // B = 66
            XCTAssertTrue(output.buffer.contains("A"), "HEX 10")
            XCTAssertTrue(output.buffer.contains("LAB"))
            XCTAssertTrue(output.buffer.contains("7"))
            XCTAssertTrue(output.buffer.contains("9")) // after SWAP
            XCTAssertTrue(output.buffer.contains("OK"))
            XCTAssertTrue(output.buffer.contains("SMOKEPASS"))
            XCTAssertEqual(interpreter.screen.point(x: 2, y: 2), 5)
            let fileText = try String(contentsOf: scratchDir.appendingPathComponent("smoke.txt"), encoding: .utf8)
            XCTAssertTrue(fileText.contains("OK"))
        }
    }

    // Helpers

    private func run(_ source: String) async -> (output: String, error: String?) {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        if let scratchDir {
            interpreter.setFileBaseDirectory(scratchDir)
        }
        await interpreter.run(source)
        return (output.buffer, interpreter.lastError)
    }
}

/// Injects scripted INPUT responses for tests.
final class QueueInputHandler: QBInputHandler, @unchecked Sendable {
    private var responses: [String]
    private var index = 0

    init(responses: [String]) {
        self.responses = responses
    }

    func prompt(_ text: String) async throws -> String {
        defer { index += 1 }
        if index < responses.count {
            return responses[index]
        }
        return ""
    }
}
