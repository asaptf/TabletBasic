import Foundation
import QBEngine
import SwiftUI

@MainActor
final class IDEViewModel: ObservableObject {
    @Published var sourceCode: String = ""
    @Published var outputText: String = ""
    @Published var immediateInput: String = ""
    @Published var statusMessage: String = ""
    @Published var screenRevision: Int = 0
    @Published var isRunning: Bool = false
    @Published var showWelcome: Bool = true
    @Published var showHelp: Bool = false
    @Published var showSurvivalGuide: Bool = false
    @Published var showProgramLibrary: Bool = false
    @Published var showAbout: Bool = false
    @Published var showRunOutput: Bool = false
    @Published var showOpenFilePicker: Bool = false
    @Published var showSaveFilePicker: Bool = false
    @Published var documentName: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var showInputPrompt: Bool = false
    @Published var inputPromptText: String = ""
    @Published var inputPromptValue: String = ""
    @Published var findQuery: String = ""
    @Published var findReplaceText: String = ""
    @Published var showFindPanel: Bool = false
    @Published var findStatus: String = ""
    @Published var breakpoints: Set<Int> = []
    @Published var watchList: [String] = []
    @Published var watchValues: [String: String] = [:]
    @Published var isPaused: Bool = false
    @Published var debugEnabled: Bool = false
    @Published var stepMode: Bool = false

    private let interpreter = QBInterpreter()
    private var inputContinuation: CheckedContinuation<String, Never>?
    private let consoleOutput = ConsoleOutputHandler()
    private var documentBookmark: Data?
    private var findCursor: String.Index?

    var screen: ScreenBuffer { interpreter.screen }
    var hasGraphicsOutput: Bool { screen.isGraphicsMode }

    init() {
        interpreter.output = consoleOutput
        interpreter.input = self

        if ProcessInfo.processInfo.arguments.contains("UI_TESTING"),
           let filename = ProcessInfo.processInfo.environment["UI_TEST_SAMPLE"],
           let program = SampleProgramLibrary.all.first(where: { $0.filename == filename }) {
            showWelcome = false
            sourceCode = BasicSourceNormalizer.normalize(program.code)
            documentName = program.filename
        }
    }

    func dismissWelcome(openSurvivalGuide: Bool) {
        showWelcome = false
        if openSurvivalGuide {
            showSurvivalGuide = true
        }
    }

    func runProgram() {
        guard !isRunning else { return }
        cancelPendingInput()
        isRunning = true
        isPaused = false
        showRunOutput = true
        showWelcome = false
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1
        interpreter.breakpoints = breakpoints
        interpreter.watches = watchList
        interpreter.debugEnabled = debugEnabled || stepMode || !breakpoints.isEmpty
        interpreter.stepMode = stepMode

        Task {
            // Poll pause state for UI while running
            let poll = Task { @MainActor in
                while isRunning {
                    isPaused = interpreter.isPaused
                    if interpreter.isPaused {
                        watchValues = interpreter.watchSnapshot()
                        statusMessage = "Paused at line \(interpreter.currentSourceLine)"
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            await interpreter.run(preparedSource)
            poll.cancel()
            outputText = consoleOutput.buffer
            screenRevision += 1
            isRunning = false
            isPaused = false
            watchValues = interpreter.watchSnapshot()
            if let error = interpreter.lastError {
                statusMessage = error
            } else {
                statusMessage = "Ready"
            }
        }
    }

    func stopProgram() {
        interpreter.stop()
        cancelPendingInput()
        statusMessage = "Stopping…"
    }

    func stepProgram() {
        if isRunning && isPaused {
            interpreter.stepMode = true
            interpreter.resumeStep()
            return
        }
        stepMode = true
        debugEnabled = true
        runProgram()
    }

    func continueProgram() {
        if isRunning && isPaused {
            interpreter.continueRunning()
            statusMessage = "Continuing…"
        }
    }

    func toggleBreakpointAtCursor() {
        let line = cursorLine
        if breakpoints.contains(line) {
            breakpoints.remove(line)
            statusMessage = "Breakpoint cleared at \(line)"
        } else {
            breakpoints.insert(line)
            statusMessage = "Breakpoint set at \(line)"
        }
        interpreter.breakpoints = breakpoints
    }

    func addWatch(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.uppercased()
        if !watchList.contains(where: { $0.uppercased() == key }) {
            watchList.append(trimmed)
        }
        interpreter.watches = watchList
        watchValues = interpreter.watchSnapshot()
    }

    func injectKey(_ key: String) {
        interpreter.injectKey(key)
    }

    // MARK: - Find / Replace

    func openFind() {
        showFindPanel = true
        findStatus = ""
        findCursor = nil
    }

    func findNext() {
        let query = findQuery
        guard !query.isEmpty else {
            findStatus = "Enter search text"
            return
        }
        let source = sourceCode
        let start = findCursor ?? source.startIndex
        let searchRange = start..<source.endIndex
        if let range = source.range(of: query, options: [.caseInsensitive], range: searchRange) {
            findCursor = range.upperBound
            updateCursorFromIndex(range.lowerBound, in: source)
            findStatus = "Found at line \(cursorLine)"
            return
        }
        // Wrap
        if let range = source.range(of: query, options: [.caseInsensitive]) {
            findCursor = range.upperBound
            updateCursorFromIndex(range.lowerBound, in: source)
            findStatus = "Found at line \(cursorLine) (wrapped)"
            return
        }
        findStatus = "Not found"
    }

    func replaceNext() {
        let query = findQuery
        guard !query.isEmpty else { return }
        let source = sourceCode
        let start = findCursor ?? source.startIndex
        if let range = source.range(of: query, options: [.caseInsensitive], range: start..<source.endIndex)
            ?? source.range(of: query, options: [.caseInsensitive]) {
            sourceCode.replaceSubrange(range, with: findReplaceText)
            findCursor = sourceCode.index(range.lowerBound, offsetBy: findReplaceText.count, limitedBy: sourceCode.endIndex)
            findStatus = "Replaced"
            findNext()
        } else {
            findStatus = "Not found"
        }
    }

    private func updateCursorFromIndex(_ index: String.Index, in source: String) {
        let prefix = source[..<index]
        let lines = prefix.split(separator: "\n", omittingEmptySubsequences: false)
        cursorLine = max(1, lines.count)
        cursorColumn = (lines.last?.count ?? 0) + 1
    }

    func runImmediate() {
        let command = immediateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isRunning else { return }
        immediateInput = ""
        showRunOutput = true
        showWelcome = false

        Task {
            isRunning = true
            await interpreter.runImmediate(BasicSourceNormalizer.normalize(command))
            if !consoleOutput.buffer.isEmpty {
                if !outputText.isEmpty { outputText += "\n" }
                outputText += consoleOutput.buffer
            }
            screenRevision += 1
            isRunning = false
            consoleOutput.clear()
        }
    }

    func returnToEditor() {
        presentEditor()
    }

    func newFile() {
        dismissModalSheets()
        presentEditor()
        sourceCode = ""
        documentName = "Untitled"
        documentBookmark = nil
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1
        cursorLine = 1
        cursorColumn = 1
        statusMessage = ""
    }

    var exportDocument: BasicProgramDocument {
        BasicProgramDocument(text: preparedSource)
    }

    var defaultSaveFilename: String {
        let base = documentName == "Untitled" ? "Untitled" : documentName
        let lower = base.lowercased()
        if lower.hasSuffix(".bas") { return base }
        return "\(base).bas"
    }

    var canSaveToCurrentFile: Bool {
        documentBookmark != nil
    }

    func requestOpenFile() {
        presentEditor()
        showOpenFilePicker = true
    }

    func requestSaveFile() {
        if canSaveToCurrentFile {
            saveToBookmarkedFile()
        } else {
            showSaveFilePicker = true
        }
    }

    func requestSaveAsFile() {
        showSaveFilePicker = true
    }

    func handleImportedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            openExternalURL(url)
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }

    func handleExportedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try BasicProgramFileStore.writeText(preparedSource, to: url)
                documentName = url.lastPathComponent
                documentBookmark = try BasicProgramFileStore.makeBookmark(for: url)
                statusMessage = "Saved \(url.lastPathComponent)"
            } catch {
                statusMessage = error.localizedDescription
            }
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }

    func openExternalURL(_ url: URL) {
        do {
            let text = try BasicProgramFileStore.readText(from: url)
            sourceCode = BasicSourceNormalizer.normalize(text)
            documentName = url.lastPathComponent
            documentBookmark = try BasicProgramFileStore.makeBookmark(for: url)
            showWelcome = false
            showRunOutput = false
            statusMessage = "Opened \(url.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveToBookmarkedFile() {
        guard let bookmark = documentBookmark else {
            showSaveFilePicker = true
            return
        }
        do {
            let url = try BasicProgramFileStore.resolveURL(from: bookmark)
            try BasicProgramFileStore.writeText(preparedSource, to: url)
            statusMessage = "Saved \(url.lastPathComponent)"
        } catch {
            documentBookmark = nil
            statusMessage = error.localizedDescription
            showSaveFilePicker = true
        }
    }

    private func clearDocumentReference() {
        documentBookmark = nil
    }

    func clearOutput() {
        cancelPendingInput()
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1
        showRunOutput = false
    }

    func submitInputPrompt() {
        let value = inputPromptValue
        inputPromptValue = ""
        inputPromptText = ""
        showInputPrompt = false
        statusMessage = ""
        inputContinuation?.resume(returning: value)
        inputContinuation = nil
    }

    private func cancelPendingInput(returning value: String = "") {
        guard inputContinuation != nil else { return }
        inputPromptValue = ""
        inputPromptText = ""
        showInputPrompt = false
        inputContinuation?.resume(returning: value)
        inputContinuation = nil
    }



    var preparedSource: String {
        BasicSourceNormalizer.normalize(sourceCode)
    }

    func loadSampleProgram(_ program: SampleProgram) {
        sourceCode = BasicSourceNormalizer.normalize(program.code)
        documentName = program.filename
        clearDocumentReference()
        showProgramLibrary = false
        showWelcome = false
        showRunOutput = false
    }

    func loadLesson(_ lesson: Lesson) {
        sourceCode = lesson.starterCode
        documentName = "LESSON.BAS"
        clearDocumentReference()
        showSurvivalGuide = false
        showWelcome = false
        showRunOutput = false
    }

    func handleShortcut(_ action: IDEAction) {
        switch action {
        case .run:
            stepMode = false
            runProgram()
        case .runImmediate:
            runImmediate()
        case .stop:
            stopProgram()
        case .step:
            stepProgram()
        case .continueRun:
            continueProgram()
        case .toggleBreakpoint:
            toggleBreakpointAtCursor()
        case .find:
            openFind()
        case .findNext:
            findNext()
        case .help:
            showHelp = true
        case .survivalGuide:
            showSurvivalGuide = true
        case .clear:
            clearOutput()
        case .newFile:
            newFile()
        case .openFile:
            requestOpenFile()
        case .saveFile:
            requestSaveFile()
        case .saveAsFile:
            requestSaveAsFile()
        case .insertLineNumber:
            insertLineNumbers()
        case .openSamples:
            presentEditor()
            showProgramLibrary = true
        case .returnToEditor:
            returnToEditor()
        case .dismissWelcome:
            dismissWelcome(openSurvivalGuide: false)
        case .dismissWelcomeToGuide:
            dismissWelcome(openSurvivalGuide: true)
        case .about:
            showAbout = true
        }
    }

    private func presentEditor() {
        showWelcome = false
        showRunOutput = false
    }

    private func dismissModalSheets() {
        showHelp = false
        showSurvivalGuide = false
        showProgramLibrary = false
        showAbout = false
    }

    private func insertLineNumbers() {
        presentEditor()
        let lines = sourceCode.split(separator: "\n", omittingEmptySubsequences: false)
        var numbered: [String] = []
        var lineNum = 10
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                numbered.append("")
                continue
            }
            if trimmed.first?.isNumber == true {
                numbered.append(String(line))
            } else {
                numbered.append("\(lineNum) \(line)")
                lineNum += 10
            }
        }
        sourceCode = numbered.joined(separator: "\n")
    }
}

enum IDEAction: String {
    case run
    case runImmediate
    case stop
    case step
    case continueRun
    case toggleBreakpoint
    case find
    case findNext
    case help
    case survivalGuide
    case clear
    case newFile
    case openFile
    case saveFile
    case saveAsFile
    case insertLineNumber
    case openSamples
    case returnToEditor
    case dismissWelcome
    case dismissWelcomeToGuide
    case about
}

extension IDEViewModel: QBInputHandler {
    nonisolated func prompt(_ text: String) async throws -> String {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.inputContinuation = continuation
                self.inputPromptText = text
                self.inputPromptValue = ""
                self.showInputPrompt = true
                self.showRunOutput = true
                self.statusMessage = "INPUT: \(text)"
            }
        }
    }
}