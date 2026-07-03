import Foundation

public final class QBInterpreter: @unchecked Sendable {
    private let parser = ProgramParser()
    public let executor = Executor()
    public private(set) var lastError: String?

    public var output: QBOutputHandler? {
        get { executor.output }
        set { executor.output = newValue }
    }

    public var input: QBInputHandler? {
        get { executor.input }
        set { executor.input = newValue }
    }

    public var screen: ScreenBuffer { executor.screen }

    public init() {}

    public func parse(_ source: String) throws -> ParsedProgram {
        try parser.parse(source: source)
    }

    public func run(_ source: String) async {
        do {
            lastError = nil
            let program = try parser.parse(source: source)
            try await executor.execute(program: program)
        } catch {
            lastError = error.localizedDescription
            executor.output?.writeLine(error.localizedDescription)
        }
    }

    public func runImmediate(_ source: String) async {
        let wrapped = "10 \(source)\n20 END\n"
        await run(wrapped)
    }
}