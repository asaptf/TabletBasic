import XCTest
@testable import QBEngine

final class LanguageSurfaceTests: XCTestCase {
    func testHexAscOctSpaceAndConversions() async {
        let result = await run(
            """
            PRINT HEX$(255)
            PRINT HEX$(10)
            PRINT ASC("A")
            PRINT OCT$(8)
            PRINT "<"; SPACE$(3); ">"
            PRINT CINT(2.6)
            PRINT CSNG(3)
            PRINT CDBL(4)
            """
        )

        XCTAssertNil(result.error, result.error ?? "")
        let lines = result.output.split(whereSeparator: \.isNewline).map(String.init)
        XCTAssertTrue(lines.contains("FF"), result.output)
        XCTAssertTrue(lines.contains("A"), result.output)
        XCTAssertTrue(lines.contains("65"), result.output)
        XCTAssertTrue(lines.contains("10"), result.output)
        XCTAssertTrue(result.output.contains("<   >"), result.output)
        XCTAssertTrue(lines.contains("3"), result.output)
        XCTAssertTrue(lines.contains { $0 == "4" || $0.hasPrefix("4.") }, result.output)
    }

    func testTimerReturnsSecondsSinceMidnight() async {
        let result = await run("PRINT TIMER")
        XCTAssertNil(result.error, result.error ?? "")
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Double(trimmed)
        XCTAssertNotNil(value, "TIMER should print a number, got: \(result.output)")
        XCTAssertGreaterThanOrEqual(value ?? -1, 0)
        XCTAssertLessThan(value ?? 100_000, 86_400)
    }

    func testLocatePlacesPrintedText() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        CLS
        LOCATE 2, 4
        PRINT "Z";
        """)

        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        let index = (2 - 1) * interpreter.screen.textCols + (4 - 1)
        XCTAssertEqual(interpreter.screen.textCells[index], "Z")
        XCTAssertEqual(interpreter.screen.cursorRow, 2)
        XCTAssertEqual(interpreter.screen.cursorCol, 5)
    }

    func testBlockIfElseIf() async {
        let result = await run(
            """
            SCORE% = 85
            IF SCORE% >= 90 THEN
                PRINT "Grade: A"
            ELSEIF SCORE% >= 80 THEN
                PRINT "Grade: B"
            ELSE
                PRINT "Grade: C"
            END IF
            """
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("Grade: B"), result.output)
        XCTAssertFalse(result.output.contains("Grade: A"), result.output)
        XCTAssertFalse(result.output.contains("Grade: C"), result.output)
    }

    func testConstAssignment() async {
        let result = await run(
            """
            CONST PI = 3.14
            CONST A = 2, B = 5
            PRINT PI
            PRINT A * B
            """
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("3.14"), result.output)
        XCTAssertTrue(result.output.contains("10"), result.output)
    }

    func testOptionBaseZeroAllowsIndexZero() async {
        let result = await run(
            """
            OPTION BASE 0
            DIM A%(2)
            A%(0) = 7
            A%(2) = 9
            PRINT A%(0)
            PRINT A%(2)
            """
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("7"), result.output)
        XCTAssertTrue(result.output.contains("9"), result.output)
    }

    func testOptionBaseOneRejectsIndexZero() async {
        let result = await run(
            """
            OPTION BASE 1
            DIM A%(2)
            A%(0) = 1
            PRINT A%(0)
            """
        )
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.localizedCaseInsensitiveContains("range") == true, result.error ?? "")
    }

    func testBottomTestedLoopUntilAndWhile() async {
        let untilResult = await run(
            """
            N% = 0
            DO
                N% = N% + 1
            LOOP UNTIL N% = 3
            PRINT "until"; N%
            """
        )
        XCTAssertNil(untilResult.error, untilResult.error ?? "")
        XCTAssertTrue(untilResult.output.contains("until3"), untilResult.output)

        let whileResult = await run(
            """
            N% = 0
            DO
                N% = N% + 1
            LOOP WHILE N% < 2
            PRINT "while"; N%
            """
        )
        XCTAssertNil(whileResult.error, whileResult.error ?? "")
        XCTAssertTrue(whileResult.output.contains("while2"), whileResult.output)
    }

    func testInkeyReadsInjectedKeysFromShippedKeySource() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        let task = Task {
            await interpreter.run("""
            DO
                A$ = INKEY$
            LOOP WHILE A$ = ""
            B$ = INKEY$
            PRINT A$; B$
            """)
        }
        try? await Task.sleep(nanoseconds: 80_000_000)
        interpreter.injectKey("Q")
        interpreter.injectKey("B")
        await task.value

        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("QB"), output.buffer)
    }

    func testInkeyEmptyWithoutKeySource() async {
        let result = await run("""
        K$ = INKEY$
        IF K$ = "" THEN PRINT "none"
        """)
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("none"), result.output)
    }

    func testRequestStopCancelsSleepLoop() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        let task = Task {
            await interpreter.run("""
            DO
                SLEEP 10
            LOOP
            """)
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        interpreter.stop()
        await task.value

        XCTAssertEqual(interpreter.lastError, "Program stopped")
    }

    func testProgressFiresDuringPrintAndSleep() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        PRINT "A"
        SLEEP 0.05
        PRINT "B"
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("A"))
        XCTAssertTrue(output.buffer.contains("B"))
    }

    private func run(_ source: String) async -> (output: String, error: String?) {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(source)
        return (output.buffer, interpreter.lastError)
    }
}
