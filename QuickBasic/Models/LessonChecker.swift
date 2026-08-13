import Foundation
import QBEngine

struct LessonCheckResult: Equatable {
    let passed: Bool
    let output: String
    let error: String?
}

enum LessonChecker {
    static func matches(actual: String, expected: String?) -> Bool {
        guard let expected, !expected.isEmpty else { return true }
        return actual.contains(expected)
    }

    static func check(source: String, expectedOutput: String?) async -> LessonCheckResult {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(BasicSourceNormalizer.normalize(source))
        if let error = interpreter.lastError {
            return LessonCheckResult(passed: false, output: output.buffer, error: error)
        }
        let passed = matches(actual: output.buffer, expected: expectedOutput)
        return LessonCheckResult(passed: passed, output: output.buffer, error: nil)
    }
}
