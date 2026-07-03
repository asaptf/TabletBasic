import SwiftUI

struct ImmediateWindowView: View {
    @Binding var text: String
    let onExecute: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(">")
                .font(QBTheme.monoFont)
                .foregroundStyle(QBTheme.immediateText)
                .padding(.leading, 6)

            TextField("", text: $text)
                .font(QBTheme.monoFont)
                .foregroundStyle(QBTheme.immediateText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onSubmit(onExecute)
        }
        .frame(height: 28)
        .background(QBTheme.immediateBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QBTheme.menuText.opacity(0.35))
                .frame(height: 1)
        }
    }
}