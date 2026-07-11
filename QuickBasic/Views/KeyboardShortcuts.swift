import SwiftUI

private enum FunctionKey {
    static let f1 = "\u{F704}"
    static let f5 = "\u{F708}"
    static let f8 = "\u{F70B}"
    static let f9 = "\u{F70C}"
}

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var viewModel: IDEViewModel

    func body(content: Content) -> some View {
        content
            .onKeyPress(phases: .down) { press in
                // Forward printable keys to INKEY$ while a program is running
                if viewModel.isRunning, !viewModel.showInputPrompt {
                    let chars = press.characters
                    if !chars.isEmpty && chars.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value < 127 }) {
                        viewModel.injectKey(chars)
                        return .handled
                    }
                }
                switch press.characters {
                case FunctionKey.f1:
                    viewModel.handleShortcut(.help)
                    return .handled
                case FunctionKey.f5:
                    if viewModel.isPaused {
                        viewModel.handleShortcut(.continueRun)
                    } else {
                        viewModel.handleShortcut(.run)
                    }
                    return .handled
                case FunctionKey.f8:
                    viewModel.handleShortcut(.step)
                    return .handled
                case FunctionKey.f9:
                    viewModel.handleShortcut(.toggleBreakpoint)
                    return .handled
                default:
                    break
                }
                if press.modifiers.contains(.command) || press.modifiers.contains(.control) {
                    if press.characters.lowercased() == "f" {
                        viewModel.handleShortcut(.find)
                        return .handled
                    }
                    if press.characters.lowercased() == "g" {
                        viewModel.handleShortcut(.findNext)
                        return .handled
                    }
                    if press.characters.lowercased() == "." || press.characters == "c" && press.modifiers.contains(.control) {
                        // Ctrl+C / Cmd+. style stop
                        if viewModel.isRunning {
                            viewModel.handleShortcut(.stop)
                            return .handled
                        }
                    }
                }
                return .ignored
            }
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