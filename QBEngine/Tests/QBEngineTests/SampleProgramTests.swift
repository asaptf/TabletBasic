import XCTest
@testable import QBEngine

final class SampleProgramTests: XCTestCase {
    func testMathBas() async {
        let code = """
        A = 16
        PRINT "Square root of"; A; "is"; SQR(A)
        PRINT "Sine of 90 degrees:"; SIN(1.5708)
        PRINT "2 to the power 8:"; 2 ^ 8
        PRINT "10 MOD 3 ="; 10 MOD 3
        """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("4"))
        XCTAssertTrue(output.buffer.contains("256"))
    }

    func testPrintTrailingComma() async {
        let code = """
        FOR I% = 1 TO 3
            PRINT I%,
        NEXT I%
        """
        let interpreter = QBInterpreter()
        interpreter.output = ConsoleOutputHandler()
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
    }

    func testRndWithoutParens() async {
        let code = """
        RANDOMIZE 1
        PRINT INT(RND * 6) + 1
        """
        let interpreter = QBInterpreter()
        interpreter.output = ConsoleOutputHandler()
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
    }

    func testDataBeforeRead() async {
        let code = """
        READ NAME$
        PRINT NAME$
        DATA "TabletBasic"
        """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("TabletBasic"))
    }

    func testArrayAccess() async {
        let code = """
        DIM SCORES%(5)
        FOR I% = 1 TO 3
            SCORES%(I%) = I% * 10
        NEXT I%
        PRINT SCORES%(2)
        """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("20"))
    }

    func testOnGosubInForLoop() async {
        let code = """
        FOR CHOICE% = 1 TO 2
            ON CHOICE% GOSUB 100, 200
        NEXT CHOICE%
        END
        100 PRINT "A"
        110 RETURN
        200 PRINT "B"
        210 RETURN
        """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(code)
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("A"))
        XCTAssertTrue(output.buffer.contains("B"))
    }
}