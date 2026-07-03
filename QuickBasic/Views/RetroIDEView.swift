import SwiftUI

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
    }
}

private struct RunOutputView: View {
    @ObservedObject var viewModel: IDEViewModel

    var body: some View {
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

            if viewModel.screen.width >= 320 && viewModel.screen.height >= 200 {
                GraphicsCanvasView(screen: viewModel.screen, revision: viewModel.screenRevision)
                    .frame(maxHeight: .infinity)
            }

            ScrollView {
                Text(viewModel.outputText.isEmpty ? " " : viewModel.outputText)
                    .accessibilityIdentifier("programOutput")
                    .font(QBTheme.monoFont)
                    .foregroundStyle(QBTheme.editorText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: viewModel.screen.width >= 320 ? 120 : .infinity)
        }
        .background(QBTheme.background)
    }
}