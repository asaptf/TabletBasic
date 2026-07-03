import Foundation
import QBEngine

struct SchoolCase {
    let name: String
    let source: String
    let inputs: [String]
    let mustContain: [String]
    let mustNotContain: [String]
}

@MainActor
func runSchoolProbe() async {
    let cases: [SchoolCase] = [
        SchoolCase(
            name: "PRINT undefined variable",
            source: "PRINT TEST",
            inputs: [],
            mustContain: ["0"],
            mustNotContain: ["error", "Error"]
        ),
        SchoolCase(
            name: "PRINT string literal",
            source: "PRINT \"TEST\"",
            inputs: [],
            mustContain: ["TEST"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "Rectangle area",
            source: """
            INPUT "length"; L
            INPUT "breadth"; B
            A = L * B
            PRINT "area="; A
            """,
            inputs: ["5", "4"],
            mustContain: ["area=", "20"],
            mustNotContain: ["error", "Error", "Syntax"]
        ),
        SchoolCase(
            name: "Sum and product",
            source: """
            A = 12
            B = 8
            PRINT "sum="; A + B
            PRINT "product="; A * B
            """,
            inputs: [],
            mustContain: ["sum=", "20", "product=", "96"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "IF positive",
            source: """
            N = 5
            IF N > 0 THEN PRINT "positive"
            """,
            inputs: [],
            mustContain: ["positive"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "IF block with ENDIF",
            source: """
            N = -3
            IF N > 0 THEN
                PRINT "positive"
            ELSE
                PRINT "negative"
            END IF
            """,
            inputs: [],
            mustContain: ["negative"],
            mustNotContain: ["Syntax", "error"]
        ),
        SchoolCase(
            name: "FOR 1 to 5",
            source: """
            FOR I = 1 TO 5
                PRINT I;
            NEXT I
            """,
            inputs: [],
            mustContain: ["1", "2", "3", "4", "5"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "WHILE loop",
            source: """
            I = 1
            WHILE I <= 3
                PRINT I;
                I = I + 1
            WEND
            """,
            inputs: [],
            mustContain: ["1", "2", "3"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "Simple interest",
            source: """
            P = 1000
            R = 5
            T = 2
            I = P * T * R / 100
            PRINT "interest="; I
            """,
            inputs: [],
            mustContain: ["interest=", "100"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "MOD even/odd",
            source: """
            N = 7
            IF N MOD 2 = 0 THEN PRINT "even" ELSE PRINT "odd"
            """,
            inputs: [],
            mustContain: ["odd"],
            mustNotContain: []
        ),
        SchoolCase(
            name: "SELECT CASE",
            source: """
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
            inputs: [],
            mustContain: ["two"],
            mustNotContain: ["Syntax", "error"]
        ),
        SchoolCase(
            name: "UCASE$",
            source: """
            A$ = "hello"
            PRINT UCASE$(A$)
            """,
            inputs: [],
            mustContain: ["HELLO"],
            mustNotContain: ["Unknown function", "error"]
        ),
        SchoolCase(
            name: "Circle area 22/7",
            source: """
            R = 7
            C = 22 / 7 * R ^ 2
            PRINT "circle="; C
            """,
            inputs: [],
            mustContain: ["circle=", "154"],
            mustNotContain: []
        ),
    ]

    var failures = 0
    for testCase in cases {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        let inputIndex = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        inputIndex.initialize(to: 0)
        interpreter.input = MockInputHandler(inputs: testCase.inputs, index: inputIndex)
        let source = BasicSourceNormalizer.normalize(testCase.source)
        await interpreter.run(source)

        var failed = false
        if let error = interpreter.lastError {
            print("FAIL [\(testCase.name)] runtime: \(error)")
            failed = true
        }
        for needle in testCase.mustContain where !output.buffer.contains(needle) {
            print("FAIL [\(testCase.name)] missing '\(needle)' in: \(output.buffer.debugDescription)")
            failed = true
        }
        for needle in testCase.mustNotContain where output.buffer.localizedCaseInsensitiveContains(needle) {
            print("FAIL [\(testCase.name)] unwanted '\(needle)' in: \(output.buffer.debugDescription)")
            failed = true
        }
        if failed {
            failures += 1
        } else {
            print("OK   [\(testCase.name)]")
        }
    }

    print(failures == 0 ? "All school probes passed." : "\(failures) school probe(s) failed.")
    exit(failures == 0 ? 0 : 1)
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