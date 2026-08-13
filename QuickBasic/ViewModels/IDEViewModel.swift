import Foundation
import QBEngine
import SwiftUI

@MainActor
final class IDEViewModel: ObservableObject {
    @Published var sourceCode: String = "" {
        didSet { recordEdit(from: oldValue) }
    }
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
    @Published var showFindDialog: Bool = false
    @Published var showGoToLineDialog: Bool = false
    @Published var findQuery: String = ""
    @Published var goToLineText: String = ""
    @Published var editorCommand: EditorCommand = .idle
    @Published var documentName: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var showInputPrompt: Bool = false
    @Published var inputPromptText: String = ""
    @Published var inputPromptValue: String = ""
    @Published var lastErrorLine: Int?
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
    private var runTask: Task<Void, Never>?
    private var savedSnapshot: String = ""
    private var isApplyingHistory = false
    private var undoStack: [String] = []
    private var redoStack: [String] = []

    var screen: ScreenBuffer { interpreter.screen }
    var hasGraphicsOutput: Bool { screen.isGraphicsMode }
    var isDocumentDirty: Bool { sourceCode != savedSnapshot }
    var documentTitle: String { isDocumentDirty ? "\(documentName)*" : documentName }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var canJumpToError: Bool { lastErrorLine != nil }

    init() {
        interpreter.output = consoleOutput
        interpreter.input = self

        if ProcessInfo.processInfo.arguments.contains("UI_TESTING"),
           let filename = ProcessInfo.processInfo.environment["UI_TEST_SAMPLE"],
           let program = SampleProgramLibrary.all.first(where: { $0.filename == filename }) {
            showWelcome = false
            replaceSource(BasicSourceNormalizer.normalize(program.code), markSaved: true, clearHistory: true)
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
        lastErrorLine = nil
        statusMessage = ""
        interpreter.breakpoints = breakpoints
        interpreter.watches = watchList
        interpreter.debugEnabled = debugEnabled || stepMode || !breakpoints.isEmpty
        interpreter.stepMode = stepMode

        runTask = Task {
            let poll = Task { @MainActor in
                while isRunning {
                    isPaused = interpreter.isPaused
                    outputText = consoleOutput.buffer
                    screenRevision += 1
                    if interpreter.isPaused {
                        watchValues = interpreter.watchSnapshot()
                        statusMessage = "Paused at line \(interpreter.currentSourceLine)"
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            await interpreter.run(preparedSource)
            poll.cancel()
            isPaused = false
            watchValues = interpreter.watchSnapshot()
            finishRun()
            if interpreter.lastError == nil, statusMessage.isEmpty || statusMessage == "Stopped" {
                statusMessage = "Ready"
            }
        }
    }

    func stopProgram() {
        interpreter.stop()
        cancelPendingInput()
        statusMessage = "Stopped"
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

    func openFind() {
        showFindPanel = true
        showFindDialog = true
        findStatus = ""
        findCursor = nil
    }

    func runImmediate() {
        let command = immediateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isRunning else { return }
        immediateInput = ""
        showRunOutput = true
        showWelcome = false
        isRunning = true

        runTask = Task {
            await interpreter.runImmediate(BasicSourceNormalizer.normalize(command))
            finishRun()
        }
    }

    func enqueueRuntimeKey(_ key: String) {
        guard isRunning, !key.isEmpty else { return }
        interpreter.injectKey(key)
    }

    func returnToEditor() {
        presentEditor()
    }

    func newFile() {
        dismissModalSheets()
        presentEditor()
        replaceSource("", markSaved: true, clearHistory: true)
        documentName = "Untitled"
        documentBookmark = nil
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1
        cursorLine = 1
        cursorColumn = 1
        statusMessage = ""
        lastErrorLine = nil
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
                savedSnapshot = sourceCode
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
            replaceSource(BasicSourceNormalizer.normalize(text), markSaved: true, clearHistory: true)
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
            savedSnapshot = sourceCode
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
        replaceSource(BasicSourceNormalizer.normalize(program.code), markSaved: true, clearHistory: true)
        documentName = program.filename
        clearDocumentReference()
        showProgramLibrary = false
        showWelcome = false
        showRunOutput = false
    }

    func loadLesson(_ lesson: Lesson) {
        replaceSource(lesson.starterCode, markSaved: true, clearHistory: true)
        documentName = "LESSON.BAS"
        clearDocumentReference()
        showSurvivalGuide = false
        showWelcome = false
        showRunOutput = false
    }

    func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        isApplyingHistory = true
        redoStack.append(sourceCode)
        sourceCode = previous
        isApplyingHistory = false
    }

    func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        isApplyingHistory = true
        undoStack.append(sourceCode)
        sourceCode = next
        isApplyingHistory = false
    }

    func requestFind() {
        showFindDialog = true
        showGoToLineDialog = false
    }

    func findNext(skipCurrent: Bool = true) {
        guard !findQuery.isEmpty else {
            findStatus = "Enter search text"
            return
        }
        var start = SourceFind.utf16Offset(line: cursorLine, column: cursorColumn, in: sourceCode)
        if skipCurrent {
            start += 1
        }
        guard let match = SourceFind.find(in: sourceCode, query: findQuery, startUTF16: start) else {
            findStatus = "Not found"
            statusMessage = "Not found"
            return
        }
        cursorLine = match.line
        cursorColumn = match.column
        editorCommand = .select(match.utf16Range)
        findStatus = "Found at line \(match.line)"
        statusMessage = ""
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
            findNext(skipCurrent: false)
        } else {
            findStatus = "Not found"
        }
    }

    func requestGoToLine() {
        goToLineText = "\(cursorLine)"
        showGoToLineDialog = true
        showFindDialog = false
    }

    func jumpToLine(_ line: Int) {
        let target = max(1, line)
        cursorLine = target
        cursorColumn = 1
        editorCommand = .goToLine(target)
        showGoToLineDialog = false
    }

    func jumpToError() {
        guard let line = lastErrorLine else { return }
        jumpToLine(line)
    }

    func checkLesson(_ lesson: Lesson) async -> LessonCheckResult {
        let source = documentName == "LESSON.BAS" && !sourceCode.isEmpty ? sourceCode : lesson.starterCode
        return await LessonChecker.check(source: source, expectedOutput: lesson.expectedOutput)
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
            requestFind()
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
        case .undo:
            undoEdit()
        case .redo:
            redoEdit()
        case .goToLine:
            requestGoToLine()
        case .jumpToError:
            jumpToError()
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

    private func finishRun() {
        outputText = consoleOutput.buffer
        screenRevision += 1
        isRunning = false
        lastErrorLine = interpreter.lastErrorLine
        if let error = interpreter.lastError {
            statusMessage = error == "Program stopped" ? "Stopped" : error
        }
        runTask = nil
    }

    private func refreshLiveOutput() {
        outputText = consoleOutput.buffer
        screenRevision += 1
    }

    private func recordEdit(from oldValue: String) {
        guard !isApplyingHistory, oldValue != sourceCode else { return }
        undoStack.append(oldValue)
        if undoStack.count > 200 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    private func replaceSource(_ text: String, markSaved: Bool, clearHistory: Bool) {
        isApplyingHistory = true
        sourceCode = text
        isApplyingHistory = false
        if clearHistory {
            undoStack.removeAll()
            redoStack.removeAll()
        }
        if markSaved {
            savedSnapshot = sourceCode
        }
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
    case stop
    case runImmediate
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
    case undo
    case redo
    case goToLine
    case jumpToError
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