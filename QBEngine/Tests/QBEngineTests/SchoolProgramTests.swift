import XCTest
@testable import QBEngine

/// Classic school-level QBasic programs (sources adapted from public tutorials).
/// Each test acts as an arbiter: expected QuickBasic semantics vs interpreter output.
final class SchoolProgramTests: XCTestCase {
    func testPrintUndefinedVariableDefaultsToZero() async {
        let result = await run(
            "PRINT TEST",
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("0"), "Undefined numeric vars default to 0 in QB")
        XCTAssertFalse(result.output.lowercased().contains("error"))
    }

    func testPrintStringLiteralShowsText() async {
        let result = await run("PRINT \"TEST\"", inputs: [])
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("TEST"))
        XCTAssertFalse(result.output.contains("0\n"))
    }

    func testRectangleAreaWithInput() async {
        let result = await run(
            """
            INPUT "length"; L
            INPUT "breadth"; B
            A = L * B
            PRINT "area="; A
            """,
            inputs: ["5", "4"]
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("area="))
        XCTAssertTrue(result.output.contains("20"))
    }

    func testSumAndProduct() async {
        let result = await run(
            """
            A = 12
            B = 8
            PRINT "sum="; A + B
            PRINT "product="; A * B
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("sum="))
        XCTAssertTrue(result.output.contains("20"))
        XCTAssertTrue(result.output.contains("product="))
        XCTAssertTrue(result.output.contains("96"))
    }

    func testSimpleInterest() async {
        let result = await run(
            """
            P = 1000
            R = 5
            T = 2
            I = P * T * R / 100
            PRINT "interest="; I
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("interest="))
        XCTAssertTrue(result.output.contains("100"))
    }

    func testCircleAreaWithPiApproximation() async {
        let result = await run(
            """
            R = 7
            C = 22 / 7 * R ^ 2
            PRINT "circle="; C
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("circle="))
        XCTAssertTrue(result.output.contains("154"))
    }

    func testIfThenSingleLine() async {
        let result = await run(
            """
            X = 10
            IF X > 5 THEN PRINT "YES"
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("YES"))
    }

    func testIfBlockWithEndIf() async {
        let result = await run(
            """
            N = -3
            IF N > 0 THEN
                PRINT "positive"
            ELSE
                PRINT "negative"
            END IF
            """,
            inputs: []
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("negative"))
        XCTAssertFalse(result.output.contains("positive"))
    }

    func testIfThenElseOnOneLine() async {
        let result = await run(
            """
            N = 7
            IF N MOD 2 = 0 THEN PRINT "even" ELSE PRINT "odd"
            """,
            inputs: []
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("odd"))
    }

    func testForLoopCounts() async {
        let result = await run(
            """
            FOR I = 1 TO 5
                PRINT I;
            NEXT I
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        for expected in ["1", "2", "3", "4", "5"] {
            XCTAssertTrue(result.output.contains(expected), "missing \(expected)")
        }
    }

    func testWhileLoopCounts() async {
        let result = await run(
            """
            I = 1
            WHILE I <= 3
                PRINT I;
                I = I + 1
            WEND
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("1"))
        XCTAssertTrue(result.output.contains("2"))
        XCTAssertTrue(result.output.contains("3"))
    }

    func testSelectCaseBranches() async {
        let result = await run(
            """
            N = 2
            SELECT CASE N
            CASE 1
                PRINT "one"
            CASE 2
                PRINT "two"
            CASE ELSE
                PRINT "other"
            END SELECT
            """,
            inputs: []
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("two"))
    }

    func testUcaseFunction() async {
        let result = await run(
            """
            A$ = "hello"
            PRINT UCASE$(A$)
            """,
            inputs: []
        )
        XCTAssertNil(result.error, result.error ?? "")
        XCTAssertTrue(result.output.contains("HELLO"))
    }

    func testTriangleArea() async {
        let result = await run(
            """
            B = 10
            H = 6
            T = 1 / 2 * B * H
            PRINT "triangle="; T
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("triangle="))
        XCTAssertTrue(result.output.contains("30"))
    }

    func testAverageOfThreeNumbers() async {
        let result = await run(
            """
            A = 10
            B = 20
            C = 30
            AVG = (A + B + C) / 3
            PRINT "avg="; AVG
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("avg="))
        XCTAssertTrue(result.output.contains("20"))
    }

    func testForLoopOddNumbersStep2() async {
        let result = await run(
            """
            FOR I = 1 TO 5 STEP 2
                PRINT I;
            NEXT I
            """,
            inputs: []
        )
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains("1"))
        XCTAssertTrue(result.output.contains("3"))
        XCTAssertTrue(result.output.contains("5"))
        XCTAssertFalse(result.output.contains("2"))
    }

    // MARK: - Helpers

    private func run(_ source: String, inputs: [String]) async -> (error: String?, output: String) {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        let index = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        index.initialize(to: 0)
        defer {
            index.deinitialize(count: 1)
            index.deallocate()
        }
        interpreter.input = MockInputHandler(inputs: inputs, index: index)
        let normalized = BasicSourceNormalizer.normalize(source)
        await interpreter.run(normalized)
        return (interpreter.lastError, output.buffer)
    }
}

private final class MockInputHandler: QBInputHandler, @unchecked Sendable {
    private let inputs: [String]
    private let index: UnsafeMutablePointer<Int>

    init(inputs: [String], index: UnsafeMutablePointer<Int>) {
        self.inputs = inputs
        self.index = index
    }

    func prompt(_ text: String) async throws -> String {
        let i = index.pointee
        index.pointee += 1
        return i < inputs.count ? inputs[i] : ""
    }
}