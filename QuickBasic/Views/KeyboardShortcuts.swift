import SwiftUI

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var viewModel: IDEViewModel

    func body(content: Content) -> some View {
        content
            .onKeyPress(.init("\r"), phases: .down) { press in
                if viewModel.showWelcome {
                    viewModel.handleShortcut(.dismissWelcomeToGuide)
                    return .handled
                }
                if !viewModel.immediateInput.isEmpty {
                    viewModel.handleShortcut(.runImmediate)
                    return .handled
                }
                viewModel.handleShortcut(.run)
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                if viewModel.showWelcome {
                    viewModel.handleShortcut(.dismissWelcome)
                } else if viewModel.showRunOutput {
                    viewModel.handleShortcut(.returnToEditor)
                } else {
                    viewModel.handleShortcut(.clear)
                }
                return .handled
            }
            .onKeyPress(.init("1"), phases: .down) { press in
                guard press.modifiers.contains(.function) else { return .ignored }
                viewModel.handleShortcut(.help)
                return .handled
            }
            .onKeyPress(.init("5"), phases: .down) { press in
                guard press.modifiers.contains(.function) else { return .ignored }
                viewModel.handleShortcut(.run)
                return .handled
            }
    }
}

extension View {
    func qbKeyboardShortcuts(viewModel: IDEViewModel) -> some View {
        modifier(KeyboardShortcutsModifier(viewModel: viewModel))
    }
}