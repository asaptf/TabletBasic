import XCTest
@testable import QBEngine

final class SubFunctionTests: XCTestCase {
    func testSubWithCall() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        CALL Hello("World")
        END

        SUB Hello (MSG$)
            PRINT "Hello,"; MSG$
        END SUB
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("Hello,World"))
    }

    func testBareSubCall() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        Greet "TabletBasic"
        END

        SUB Greet (NAME$)
            PRINT "Hi"; NAME$
        END SUB
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("HiTabletBasic"))
    }

    func testFunctionReturn() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        RESULT% = Add%(3, 4)
        PRINT RESULT%
        END

        FUNCTION Add% (A%, B%)
            Add% = A% + B%
        END FUNCTION
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("7"))
    }

    func testByRefParameter() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        X% = 1
        Bump X%
        PRINT X%
        END

        SUB Bump (N%)
            N% = N% + 1
        END SUB
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("2"))
    }

    func testExitSub() async {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output

        await interpreter.run("""
        CALL Early
        PRINT "Done"
        END

        SUB Early ()
            PRINT "Start"
            EXIT SUB
            PRINT "Hidden"
        END SUB
        """)

        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("Start"))
        XCTAssertTrue(output.buffer.contains("Done"))
        XCTAssertFalse(output.buffer.contains("Hidden"))
    }
}