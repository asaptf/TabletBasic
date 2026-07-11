import Foundation

public final class QBInterpreter: @unchecked Sendable {
    private var parser = ProgramParser()
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

    public var isRunning: Bool = false
    public var isPaused: Bool { executor.isPaused }
    public var currentSourceLine: Int { executor.currentSourceLine }
    public var breakpoints: Set<Int> {
        get { executor.breakpoints }
        set { executor.breakpoints = newValue }
    }
    public var watches: [String] {
        get { executor.watches }
        set { executor.watches = newValue }
    }
    public var stepMode: Bool {
        get { executor.stepMode }
        set { executor.stepMode = newValue }
    }
    public var debugEnabled: Bool {
        get { executor.debugEnabled }
        set { executor.debugEnabled = newValue }
    }

    public init() {}

    public func parse(_ source: String) throws -> ParsedProgram {
        try parser.parse(source: source)
    }

    public func run(_ source: String) async {
        do {
            lastError = nil
            isRunning = true
            defer { isRunning = false }
            environmentResetForRun()
            let program = try parser.parse(source: source)
            try await executor.execute(program: program)
        } catch QBError.programStopped {
            lastError = "Program stopped"
            executor.output?.writeLine("Program stopped")
        } catch {
            lastError = error.localizedDescription
            executor.output?.writeLine(error.localizedDescription)
        }
    }

    public func runImmediate(_ source: String) async {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String
        if trimmed.first == "?" {
            let rest = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            normalized = rest.isEmpty ? "PRINT" : "PRINT \(rest)"
        } else {
            normalized = trimmed
        }
        let wrapped = "10 \(normalized)\n20 END\n"
        await run(wrapped)
    }

    public func stop() {
        executor.requestStop()
    }

    public func injectKey(_ key: String) {
        executor.injectKey(key)
    }

    public func toggleBreakpoint(line: Int) {
        if breakpoints.contains(line) {
            breakpoints.remove(line)
        } else {
            breakpoints.insert(line)
        }
    }

    public func resumeStep() {
        executor.resumeStep()
    }

    public func continueRunning() {
        executor.continueRunning()
    }

    public func watchSnapshot() -> [String: String] {
        executor.watchSnapshot()
    }

    public func setFileBaseDirectory(_ url: URL) {
        executor.environment.fileStore.setBaseDirectory(url)
    }

    public var fileStore: FileStore {
        executor.environment.fileStore
    }

    private func environmentResetForRun() {
        // Preserve sandboxed file base directory across runs.
        let baseDir = executor.environment.fileStore.baseDirectory
        executor.environment.resetSession()
        executor.environment.fileStore.setBaseDirectory(baseDir)
        // Clear sticky resumeRequested / parked continuations from a prior stop.
        executor.resetDebugControlState()
    }
}
