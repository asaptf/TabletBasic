import SwiftUI

struct FindDialogView: View {
    @ObservedObject var viewModel: IDEViewModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showFindDialog = false
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Find")
                    .font(QBTheme.dialogFont)

                TextField("", text: $viewModel.findQuery)
                    .font(QBTheme.dialogFont)
                    .foregroundStyle(QBTheme.dialogText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 1))
                    .focused($fieldFocused)
                    .onSubmit {
                        viewModel.showFindDialog = false
                        viewModel.findNext(skipCurrent: false)
                    }
                    .accessibilityIdentifier("findField")

                HStack {
                    Button("Find") {
                        viewModel.showFindDialog = false
                        viewModel.findNext(skipCurrent: false)
                    }
                    .accessibilityIdentifier("findOK")
                    Button("Cancel") {
                        viewModel.showFindDialog = false
                    }
                }
                .font(QBTheme.dialogFont)
                .buttonStyle(.plain)
            }
            .foregroundStyle(QBTheme.dialogText)
            .padding(18)
            .frame(maxWidth: 360)
            .background(QBTheme.dialogBackground)
            .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 2))
        }
        .onAppear { fieldFocused = true }
    }
}

struct GoToLineDialogView: View {
    @ObservedObject var viewModel: IDEViewModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showGoToLineDialog = false
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Go to Line")
                    .font(QBTheme.dialogFont)

                TextField("", text: $viewModel.goToLineText)
                    .font(QBTheme.dialogFont)
                    .foregroundStyle(QBTheme.dialogText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 1))
                    .focused($fieldFocused)
                    .keyboardType(.numberPad)
                    .onSubmit(submit)
                    .accessibilityIdentifier("goToLineField")

                HStack {
                    Button("OK", action: submit)
                        .accessibilityIdentifier("goToLineOK")
                    Button("Cancel") {
                        viewModel.showGoToLineDialog = false
                    }
                }
                .font(QBTheme.dialogFont)
                .buttonStyle(.plain)
            }
            .foregroundStyle(QBTheme.dialogText)
            .padding(18)
            .frame(maxWidth: 280)
            .background(QBTheme.dialogBackground)
            .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 2))
        }
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        if let line = Int(viewModel.goToLineText.trimmingCharacters(in: .whitespaces)) {
            viewModel.jumpToLine(line)
        } else {
            viewModel.showGoToLineDialog = false
        }
    }
}
