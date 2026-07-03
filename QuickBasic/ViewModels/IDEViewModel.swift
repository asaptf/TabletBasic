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

    private let interpreter = QBInterpreter()
    private let consoleOutput = ConsoleOutputHandler()
    private var documentBookmark: Data?

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
        isRunning = true
        showRunOutput = true
        showWelcome = false
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1

        Task {
            await interpreter.run(preparedSource)
            outputText = consoleOutput.buffer
            screenRevision += 1
            isRunning = false
            if let error = interpreter.lastError {
                statusMessage = error
            }
        }
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
        showRunOutput = false
    }

    func newFile() {
        sourceCode = ""
        documentName = "Untitled"
        documentBookmark = nil
        outputText = ""
        showRunOutput = false
        consoleOutput.clear()
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
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.reset()
        screenRevision += 1
        showRunOutput = false
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
            runProgram()
        case .runImmediate:
            runImmediate()
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

    private func insertLineNumbers() {
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
        await MainActor.run { self.statusMessage = "INPUT: \(text)" }
        return ""
    }
}