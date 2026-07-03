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
    @Published var documentName: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1

    private let interpreter = QBInterpreter()
    private let consoleOutput = ConsoleOutputHandler()

    var screen: ScreenBuffer { interpreter.screen }
    var hasGraphicsOutput: Bool { screen.width > 0 && screen.height > 0 }

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
        outputText = ""
        showRunOutput = false
        consoleOutput.clear()
    }

    func clearOutput() {
        outputText = ""
        consoleOutput.clear()
        interpreter.screen.cls()
        screenRevision += 1
        showRunOutput = false
    }

    var preparedSource: String {
        BasicSourceNormalizer.normalize(sourceCode)
    }

    func loadSampleProgram(_ program: SampleProgram) {
        sourceCode = BasicSourceNormalizer.normalize(program.code)
        documentName = program.filename
        showProgramLibrary = false
        showWelcome = false
        showRunOutput = false
    }

    func loadLesson(_ lesson: Lesson) {
        sourceCode = lesson.starterCode
        documentName = "LESSON.BAS"
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