import Foundation
import QBEngine

let parser = ProgramParser()
var failures = 0

print("Validating \(SampleProgramLibrary.all.count) sample programs...")

for (index, program) in SampleProgramLibrary.all.enumerated() {
    let source = BasicSourceNormalizer.normalize(program.code)
    do {
        _ = try parser.parse(source: source)
    } catch {
        print("[\(index + 1)/\(SampleProgramLibrary.all.count)] PARSE FAIL \(program.filename): \(error)")
        failures += 1
        continue
    }

    let interpreter = QBInterpreter()
    let output = ConsoleOutputHandler()
    interpreter.output = output
    await interpreter.run(source)

    if let error = interpreter.lastError {
        print("[\(index + 1)/\(SampleProgramLibrary.all.count)] RUN FAIL \(program.filename): \(error)")
        failures += 1
        continue
    }

    if !output.buffer.contains(program.smokeTestMarker) {
        print(
            "[\(index + 1)/\(SampleProgramLibrary.all.count)] MARKER FAIL \(program.filename): " +
            "expected '\(program.smokeTestMarker)' in output"
        )
        failures += 1
        continue
    }

    print("[\(index + 1)/\(SampleProgramLibrary.all.count)] OK \(program.filename)")
}

if failures == 0 {
    print("All \(SampleProgramLibrary.all.count) programs passed.")
    exit(0)
} else {
    print("\(failures) program(s) failed validation.")
    exit(1)
}