import XCTest
@testable import QBEngine

final class InterpreterTests: XCTestCase {
    func testPrintHello() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        PRINT "Hello, TabletBasic!"
        """)

        XCTAssertTrue(output.buffer.contains("Hello, TabletBasic!"))
    }

    func testForLoop() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        10 FOR I = 1 TO 3
        20 PRINT I
        30 NEXT I
        """)

        XCTAssertTrue(output.buffer.contains("1"))
        XCTAssertTrue(output.buffer.contains("2"))
        XCTAssertTrue(output.buffer.contains("3"))
    }

    func testGraphicsCircle() async throws {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        SCREEN 13
        CIRCLE (160, 100), 50, 4
        """)

        XCTAssertEqual(interpreter.screen.width, 320)
        XCTAssertEqual(interpreter.screen.height, 200)
        XCTAssertTrue(interpreter.screen.isGraphicsMode)
        XCTAssertNil(interpreter.lastError)
    }

    func testScreenResetsBetweenProgramRuns() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        SCREEN 13
        PSET (10, 10), 4
        """)
        XCTAssertTrue(interpreter.screen.isGraphicsMode)

        interpreter.screen.reset()

        await interpreter.run("""
        PRINT "Hello, World!"
        """)
        XCTAssertFalse(interpreter.screen.isGraphicsMode)
        XCTAssertEqual(interpreter.screen.width, 80)
        XCTAssertEqual(interpreter.screen.height, 25)
        XCTAssertTrue(output.buffer.contains("Hello, World!"))
    }

    func testIfThen() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        X = 10
        IF X > 5 THEN PRINT "YES"
        """)

        XCTAssertTrue(output.buffer.contains("YES"))
    }

    func testUndefinedVariablePrintsZero() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("PRINT TEST")

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("0"))
    }

    func testMultiDimensionalArray() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        DIM GRID%(3, 3)
        GRID%(2, 2) = 99
        PRINT GRID%(2, 2)
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("99"))
    }

    func testLoopUntilBottomTested() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        COUNT% = 0
        DO
            COUNT% = COUNT% + 1
            GUESS% = COUNT% * 3 MOD 7 + 1
            PRINT "Try"; COUNT%; ":"; GUESS%
        LOOP UNTIL GUESS% = 4
        PRINT "Found it on try"; COUNT%
        """)

        XCTAssertNil(interpreter.lastError, interpreter.lastError ?? "")
        XCTAssertTrue(output.buffer.contains("Try1:4"), output.buffer)
        XCTAssertTrue(output.buffer.contains("Found it on try1"), output.buffer)
    }

    func testLoopWhileBottomTested() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        N% = 0
        DO
            N% = N% + 1
            PRINT N%,
        LOOP WHILE N% < 3
        PRINT "done"
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("1"))
        XCTAssertTrue(output.buffer.contains("2"))
        XCTAssertTrue(output.buffer.contains("3"))
        XCTAssertTrue(output.buffer.contains("done"))
    }

    func testDoLoopSamplesStillRun() async {
        for filename in ["DOLOOP.BAS", "DOUNTIL.BAS", "DOWHILE.BAS", "EXITDO.BAS"] {
            await SampleProgramTestSupport.assertSampleRuns(filename)
        }
    }

    func testGosubReturn() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        10 GOSUB 100
        20 PRINT "DONE"
        30 END
        100 PRINT "SUB"
        110 RETURN
        """)

        XCTAssertTrue(output.buffer.contains("SUB"))
        XCTAssertTrue(output.buffer.contains("DONE"))
    }

    func testPrintTabWithColumn() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        PRINT "A"; TAB(10); "B"
        """)

        XCTAssertNil(interpreter.lastError)
        let line = output.buffer.trimmingCharacters(in: .newlines)
        XCTAssertTrue(line.hasPrefix("A"))
        XCTAssertTrue(line.hasSuffix("B"))
        XCTAssertGreaterThanOrEqual(line.count, 10)
        let bIndex = line.firstIndex(of: "B")!
        XCTAssertEqual(line.distance(from: line.startIndex, to: bIndex), 9)
    }

    func testRestoreToLineNumber() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        10 DATA 1, 2
        20 READ A
        30 DATA 3, 4
        40 READ B
        50 RESTORE 30
        60 READ C
        70 READ D
        80 PRINT A; B; C; D
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("1"))
        XCTAssertTrue(output.buffer.contains("3"))
        XCTAssertTrue(output.buffer.contains("3 4") || output.buffer.contains("3") && output.buffer.contains("4"))
    }

    func testImmediateModeQuestionPrint() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.runImmediate("? \"Quick\"")

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("Quick"))
    }

    func testMathFunctionsExpLogAtnFix() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        RANDOMIZE 1
        PRINT EXP(0)
        PRINT LOG(1)
        PRINT ATN(0)
        PRINT FIX(-2.7)
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("1"))
        XCTAssertTrue(output.buffer.contains("-2") || output.buffer.contains("-2.7"))
    }

    func testInkeyReturnsEmptyString() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        K$ = INKEY$
        IF K$ = "" THEN PRINT "empty"
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("empty"))
    }

    func testRndWithUpperBound() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        RANDOMIZE 42
        FOR I = 1 TO 20
            N = RND(6)
            IF N < 1 OR N > 6 THEN PRINT "bad"
        NEXT I
        PRINT "ok"
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("ok"))
        XCTAssertFalse(output.buffer.contains("bad"))
    }

    func testLineBoxedFillsRectangle() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        SCREEN 1
        LINE (10, 10)-(14, 14), 2, B
        """)

        XCTAssertNil(interpreter.lastError)
        let fillColor = interpreter.screen.colorAt(index: 2)
        let background = interpreter.screen.colorAt(index: 0)
        XCTAssertNotEqual(fillColor, background)
        for y in 10...14 {
            for x in 10...14 {
                let pixel = interpreter.screen.pixels[y * interpreter.screen.width + x]
                XCTAssertEqual(pixel, fillColor, "pixel at (\(x), \(y)) should be filled")
            }
        }
    }
}