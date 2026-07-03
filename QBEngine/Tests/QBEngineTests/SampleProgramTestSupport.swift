import XCTest
@testable import QBEngine

enum SampleProgramTestSupport {
    static func runSampleProgram(_ program: SampleProgram) async -> (error: String?, output: String) {
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        let source = BasicSourceNormalizer.normalize(program.code)
        await interpreter.run(source)
        return (interpreter.lastError, output.buffer)
    }

    static func assertSampleRuns(
        _ filename: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        guard let program = SampleProgramLibrary.all.first(where: { $0.filename == filename }) else {
            XCTFail("Missing sample \(filename)", file: file, line: line)
            return
        }
        let result = await runSampleProgram(program)
        XCTAssertNil(result.error, "\(filename): \(result.error ?? "")", file: file, line: line)
    }
}