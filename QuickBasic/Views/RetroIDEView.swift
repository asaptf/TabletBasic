import SwiftUI
import UniformTypeIdentifiers

struct RetroIDEView: View {
    @ObservedObject var viewModel: IDEViewModel
    @FocusState private var editorFocused: Bool
    @State private var isMenuOpen = false

    var body: some View {
        VStack(spacing: 0) {
            DOSMenuBar(viewModel: viewModel, isMenuOpen: $isMenuOpen)
                .zIndex(isMenuOpen ? 100 : 0)

            ZStack {
                QBTheme.background

                if viewModel.showWelcome {
                    WelcomeDialogView(
                        onEnter: { viewModel.handleShortcut(.dismissWelcomeToGuide) },
                        onEscape: { viewModel.handleShortcut(.dismissWelcome) }
                    )
                } else if viewModel.showRunOutput {
                    RunOutputView(viewModel: viewModel)
                } else {
                    CodeEditorView(
                        text: $viewModel.sourceCode,
                        cursorLine: $viewModel.cursorLine,
                        cursorColumn: $viewModel.cursorColumn
                    )
                    .focused($editorFocused)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isMenuOpen {
                    Color.black.opacity(0.001)
                        .onTapGesture { isMenuOpen = false }
                }
            }

            ImmediateWindowView(text: $viewModel.immediateInput) {
                viewModel.handleShortcut(.runImmediate)
            }

            StatusBarView(modeLabel: viewModel.showRunOutput ? "Output" : "Immediate")
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
}

private struct RunOutputView: View {
    @ObservedObject var viewModel: IDEViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var hasGraphics: Bool {
        viewModel.screen.width >= 320 && viewModel.screen.height >= 200
    }

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Text("Program Output")
                        .font(QBTheme.monoSmall)
                        .foregroundStyle(QBTheme.menuText)
                    Spacer()
                    if viewModel.isRunning {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    }
                    Button("Edit") {
                        viewModel.handleShortcut(.returnToEditor)
                    }
                    .font(QBTheme.monoSmall)
                    .foregroundStyle(QBTheme.menuText)
                    .accessibilityIdentifier("returnToEditor")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                if hasGraphics {
                    GraphicsCanvasView(screen: viewModel.screen, revision: viewModel.screenRevision)
                        .frame(
                            maxHeight: LayoutMetrics.graphicsMaxHeight(
                                compact: compactLayout,
                                totalHeight: geometry.size.height,
                                hasGraphics: true
                            ) ?? .infinity
                        )
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