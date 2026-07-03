import XCTest
@testable import QBEngine

final class BasicSourceNormalizerTests: XCTestCase {
    func testDedentMultilineStringIndentation() {
        let source = """
            A = 1
            PRINT A
            """
        let normalized = BasicSourceNormalizer.normalize(source)
        XCTAssertEqual(normalized, "A = 1\nPRINT A")
    }

    func testCommentOnlyIndentedLineIsSkippedByParser() async {
        let source = """
            ' comment line
            PRINT "ok"
            """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(BasicSourceNormalizer.normalize(source))
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("ok"))
    }

    func testMathBasIndentedLikeApp() async {
        let source = """
            ' MATH.BAS - Expressions and functions
            A = 16
            PRINT "Square root of"; A; "is"; SQR(A)
            PRINT "2 to the power 8:"; 2 ^ 8
            PRINT "10 MOD 3 ="; 10 MOD 3
            """
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(BasicSourceNormalizer.normalize(source))
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("4"))
        XCTAssertTrue(output.buffer.contains("256"))
    }
}