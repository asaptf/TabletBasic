import XCTest
@testable import QBEngine

/// Every bundled sample program must parse and run without errors.
/// Source of truth: SampleProgramLibrary (same data the app ships).
final class AllSampleProgramsTests: XCTestCase {
    func testLibraryContainsTwentyPrograms() {
        XCTAssertEqual(SampleProgramLibrary.all.count, 20)
    }

    func testEverySampleProgramParses() throws {
        let parser = ProgramParser()
        for program in SampleProgramLibrary.all {
            let source = BasicSourceNormalizer.normalize(program.code)
            XCTAssertNoThrow(try parser.parse(source: source), program.filename)
        }
    }

    func testEverySampleProgramRuns() async {
        for program in SampleProgramLibrary.all {
            let interpreter = QBInterpreter()
            interpreter.output = ConsoleOutputHandler()
            let source = BasicSourceNormalizer.normalize(program.code)
            await interpreter.run(source)
            XCTAssertNil(
                interpreter.lastError,
                "\(program.filename) failed: \(interpreter.lastError ?? "")"
            )
        }
    }

    // Individual tests for precise failure reporting in Xcode / CI.
    func testHELLO_BAS() async { await assertRuns("HELLO.BAS") }
    func testVARS_BAS() async { await assertRuns("VARS.BAS") }
    func testMATH_BAS() async { await assertRuns("MATH.BAS") }
    func testCOMPARE_BAS() async { await assertRuns("COMPARE.BAS") }
    func testFORLOOP_BAS() async { await assertRuns("FORLOOP.BAS") }
    func testWHILE_BAS() async { await assertRuns("WHILE.BAS") }
    func testNESTED_BAS() async { await assertRuns("NESTED.BAS") }
    func testGOSUB_BAS() async { await assertRuns("GOSUB.BAS") }
    func testMENU_BAS() async { await assertRuns("MENU.BAS") }
    func testDATAREAD_BAS() async { await assertRuns("DATAREAD.BAS") }
    func testARRAY_BAS() async { await assertRuns("ARRAY.BAS") }
    func testDICE_BAS() async { await assertRuns("DICE.BAS") }
    func testFIBON_BAS() async { await assertRuns("FIBON.BAS") }
    func testTABLES_BAS() async { await assertRuns("TABLES.BAS") }
    func testSHAPES_BAS() async { await assertRuns("SHAPES.BAS") }
    func testBOXES_BAS() async { await assertRuns("BOXES.BAS") }
    func testSTARS_BAS() async { await assertRuns("STARS.BAS") }
    func testMOIRE_BAS() async { await assertRuns("MOIRE.BAS") }
    func testSINEWAVE_BAS() async { await assertRuns("SINEWAVE.BAS") }
    func testFLAG_BAS() async { await assertRuns("FLAG.BAS") }

    func testCOMPARE_BASPrintsGradeB() async {
        guard let program = SampleProgramLibrary.all.first(where: { $0.filename == "COMPARE.BAS" }) else {
            XCTFail("Missing COMPARE.BAS")
            return
        }
        let interpreter = QBInterpreter()
        let output = ConsoleOutputHandler()
        interpreter.output = output
        await interpreter.run(BasicSourceNormalizer.normalize(program.code))
        XCTAssertNil(interpreter.lastError)
        XCTAssertTrue(output.buffer.contains("Grade: B"), output.buffer)
    }

    private func assertRuns(_ filename: String) async {
        guard let program = SampleProgramLibrary.all.first(where: { $0.filename == filename }) else {
            XCTFail("Missing sample \(filename)")
            return
        }
        let interpreter = QBInterpreter()
        interpreter.output = ConsoleOutputHandler()
        await interpreter.run(BasicSourceNormalizer.normalize(program.code))
        XCTAssertNil(interpreter.lastError, "\(filename): \(interpreter.lastError ?? "")")
    }
}