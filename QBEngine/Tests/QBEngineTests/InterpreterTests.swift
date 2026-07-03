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
}