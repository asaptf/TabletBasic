import XCTest
@testable import QBEngine

/// Every bundled sample program must parse and run without errors.
/// Source of truth: SampleProgramLibrary (same data the app ships).
final class AllSampleProgramsTests: XCTestCase {
    func testLibraryContainsEightyPrograms() {
        XCTAssertEqual(SampleProgramLibrary.programCount, 81)
        XCTAssertEqual(SampleProgramLibrary.all.count, 81)
    }

    func testSampleProgramFilenamesAreUnique() {
        let filenames = SampleProgramLibrary.all.map(\.filename)
        XCTAssertEqual(Set(filenames).count, filenames.count)
    }

    func testEverySampleProgramHasSmokeMarker() {
        for program in SampleProgramLibrary.all {
            XCTAssertFalse(
                program.smokeTestMarker.isEmpty,
                "\(program.filename) is missing smokeTestMarker"
            )
        }

        let markers = SampleProgramLibrary.all.map(\.smokeTestMarker)
        XCTAssertEqual(Set(markers).count, markers.count, "smokeTestMarker values must be unique")
    }

    func testEverySampleProgramParses() throws {
        var parser = ProgramParser()
        for program in SampleProgramLibrary.all {
            let source = BasicSourceNormalizer.normalize(program.code)
            XCTAssertNoThrow(try parser.parse(source: source), program.filename)
        }
    }

    func testEverySampleProgramRuns() async {
        for program in SampleProgramLibrary.all {
            let result = await SampleProgramTestSupport.runSampleProgram(program)
            XCTAssertNil(
                result.error,
                "\(program.filename) failed: \(result.error ?? "")"
            )
        }
    }

    func testEverySampleProgramProducesSmokeMarker() async {
        for program in SampleProgramLibrary.all {
            let result = await SampleProgramTestSupport.runSampleProgram(program)
            XCTAssertNil(result.error, "\(program.filename): \(result.error ?? "")")
            XCTAssertTrue(
                result.output.contains(program.smokeTestMarker),
                "\(program.filename): expected '\(program.smokeTestMarker)' in output: \(result.output)"
            )
        }
    }

    func testCOMPARE_BASPrintsGradeB() async {
        guard let program = SampleProgramLibrary.all.first(where: { $0.filename == "COMPARE.BAS" }) else {
            XCTFail("Missing COMPARE.BAS")
            return
        }
        let result = await SampleProgramTestSupport.runSampleProgram(program)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains(program.smokeTestMarker), result.output)
    }
}