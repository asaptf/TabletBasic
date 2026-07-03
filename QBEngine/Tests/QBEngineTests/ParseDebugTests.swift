import XCTest
@testable import QBEngine

final class ParseDebugTests: XCTestCase {
    func testParseFunctionAssignment() throws {
        var parser = ProgramParser()
        let source = """
        RESULT% = Sum%(3, 4)
        END

        FUNCTION Sum% (A%, B%)
            Sum% = A% + B%
        END FUNCTION
        """
        XCTAssertNoThrow(try parser.parse(source: source))
    }
}