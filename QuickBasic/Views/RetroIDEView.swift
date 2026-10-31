import SwiftUI
import UniformTypeIdentifiers

struct RetroIDEView: View {
    @ObservedObject var viewModel: IDEViewModel
    @FocusState private var editorFocused: Bool
    @State private var isMenuOpen = false

    var body: some View {
        GeometryReader { container in
            VStack(spacing: 0) {
                DOSMenuBar(viewModel: viewModel, isMenuOpen: $isMenuOpen, containerSize: container.size)
                    .zIndex(isMenuOpen ? 100 : 0)

                ZStack {
                    QBTheme.background

                    if viewModel.showWelcome {
                        WelcomeDialogView(
                            onEnter: { viewModel.handleShortcut(.dismissWelcomeToGuide) },
                            onEscape: { viewModel.handleShortcut(.dismissWelcome) }
                        )
                    } else {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                CodeEditorView(
                                    text: $viewModel.sourceCode,
                                    cursorLine: $viewModel.cursorLine,
                                    cursorColumn: $viewModel.cursorColumn,
                                    command: $viewModel.editorCommand
                                )
                                .focused($editorFocused)
                                .frame(maxHeight: .infinity)

                                outputSplitBar

                                RunOutputView(viewModel: viewModel)
                                    .frame(height: outputPaneHeight(in: geometry.size.height))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if isMenuOpen {
                        Color.black.opacity(0.001)
                            .onTapGesture { isMenuOpen = false }
                    }
                }
                .overlay {
                    if viewModel.showFindDialog {
                        FindDialogView(viewModel: viewModel)
                    } else if viewModel.showGoToLineDialog {
                        GoToLineDialogView(viewModel: viewModel)
                    }
                }

                ImmediateWindowView(text: $viewModel.immediateInput) {
                    viewModel.handleShortcut(.runImmediate)
                }

                StatusBarView(
                    modeLabel: viewModel.isRunning ? "Running" : "Immediate",
                    statusMessage: viewModel.statusMessage,
                    onStatusTap: viewModel.canJumpToError ? { viewModel.jumpToError() } : nil
                )
            }
            .overlay {
                if viewModel.showInputPrompt {
                    InputPromptOverlay(viewModel: viewModel)
                }
            }
        }
        .background(QBTheme.background)
        .onAppear { editorFocused = true }
        .qbKeyboardShortcuts(viewModel: viewModel)
        .sheet(isPresented: $viewModel.showHelp) {
            HelpView()
        }
        .sheet(isPresented: $viewModel.showSurvivalGuide) {
            LearningView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showProgramLibrary) {
            ProgramLibraryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAbout) {
            AboutView()
        }
        .sheet(isPresented: $viewModel.showFindPanel) {
            FindPanelView(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: $viewModel.showOpenFilePicker,
            allowedContentTypes: [.basicProgram, .plainText],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImportedFiles(result)
        }
        .fileExporter(
            isPresented: $viewModel.showSaveFilePicker,
            document: viewModel.exportDocument,
            contentTypes: [.basicProgram, .plainText],
            defaultFilename: viewModel.defaultSaveFilename
        ) { result in
            viewModel.handleExportedFile(result)
        }
    }

    private var outputSplitBar: some View {
        HStack(spacing: 8) {
            Text("OUTPUT")
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.menuText)
            if viewModel.isRunning {
                Text("Running...")
                    .font(QBTheme.monoSmall)
                    .foregroundStyle(QBTheme.statusSecondaryText)
            }
            Spacer(minLength: 0)
            Button("Edit") {
                viewModel.handleShortcut(.returnToEditor)
            }
            .font(QBTheme.monoSmall)
            .foregroundStyle(QBTheme.menuText)
            .buttonStyle(.plain)
            .accessibilityIdentifier("returnToEditor")
            if viewModel.isRunning {
                Button("Stop") {
                    viewModel.handleShortcut(.stop)
                }
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.menuText)
                .buttonStyle(.plain)
                .accessibilityIdentifier("stopProgram")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(QBTheme.menuBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QBTheme.menuText.opacity(0.45))
                .frame(height: 1)
        }
    }

    private func outputPaneHeight(in totalHeight: CGFloat) -> CGFloat {
        LayoutMetrics.outputPaneHeight(totalHeight: totalHeight, hasGraphics: viewModel.hasGraphicsOutput)
    }
}

private struct RunOutputView: View {
    @ObservedObject var viewModel: IDEViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var hasGraphics: Bool {
        viewModel.screen.isGraphicsMode
    }

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if hasGraphics {
                    GraphicsCanvasView(screen: viewModel.screen, revision: viewModel.screenRevision)
                        .layoutPriority(1)
                        .padding(.horizontal, 8)
                }

                ScrollView {
                    Text(viewModel.outputText.isEmpty ? " " : viewModel.outputText)
                        .accessibilityIdentifier("programOutput")
                        .font(compactLayout ? QBTheme.monoSmall : QBTheme.monoFont)
                        .foregroundStyle(QBTheme.editorText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(
                    maxHeight: LayoutMetrics.outputTextMaxHeight(
                        compact: compactLayout,
                        totalHeight: geometry.size.height,
                        hasGraphics: hasGraphics
                    )
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(QBTheme.background)
    }
}

private struct InputPromptOverlay: View {
    @ObservedObject var viewModel: IDEViewModel
    @FocusState private var fieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(viewModel.inputPromptText)
                    .font(QBTheme.dialogFont)
                    .accessibilityIdentifier("inputPrompt")

                TextField("", text: $viewModel.inputPromptValue)
                    .font(QBTheme.dialogFont)
                    .foregroundStyle(QBTheme.dialogText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(QBTheme.dialogBorder, lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($fieldFocused)
                    .accessibilityIdentifier("inputPromptField")
                    .onSubmit { viewModel.submitInputPrompt() }

                HStack(spacing: 24) {
                    Button("Stop") {
                        viewModel.stopProgram()
                    }
                    .accessibilityIdentifier("inputPromptStop")

                    Button("OK") {
                        viewModel.submitInputPrompt()
                    }
                    .accessibilityIdentifier("inputPromptOK")
                }
                .font(QBTheme.dialogFont)
                .buttonStyle(.plain)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(QBTheme.dialogText)
            .padding(.horizontal, compactLayout ? 16 : 24)
            .padding(.vertical, compactLayout ? 14 : 18)
            .background(QBTheme.dialogBackground)
            .overlay(
                Rectangle()
                    .stroke(QBTheme.dialogBorder, lineWidth: 2)
            )
            .frame(maxWidth: LayoutMetrics.welcomeMaxWidth(compact: compactLayout))
            .padding(.horizontal, compactLayout ? 12 : 24)
        }
        .onAppear { fieldFocused = true }
    }
}

private struct FindPanelView: View {
    @ObservedObject var viewModel: IDEViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Find") {
                    TextField("Find", text: $viewModel.findQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("findQuery")
                    TextField("Replace with", text: $viewModel.findReplaceText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if !viewModel.findStatus.isEmpty {
                    Text(viewModel.findStatus)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Find")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Find Next") { viewModel.findNext() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Replace") { viewModel.replaceNext() }
                }
            }
        }
    }
}
