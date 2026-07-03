import SwiftUI

struct CodeEditorView: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    var body: some View {
        HStack(spacing: 0) {
            LineNumberGutter(text: text, activeLine: cursorLine, compact: compactLayout)
                .frame(width: LayoutMetrics.lineNumberGutterWidth(compact: compactLayout))

            Rectangle()
                .fill(QBTheme.menuText.opacity(0.25))
                .frame(width: 1)

            TextEditor(text: $text)
                .font(compactLayout ? QBTheme.monoSmall : QBTheme.monoFont)
                .foregroundStyle(QBTheme.editorText)
                .scrollContentBackground(.hidden)
                .background(QBTheme.editorBackground)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: text) { _, newValue in
                    updateCursor(from: newValue)
                }
        }
        .background(QBTheme.editorBackground)
    }

    private func updateCursor(from text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        cursorLine = max(1, lines.count)
        if let last = lines.last {
            cursorColumn = last.count + 1
        } else {
            cursorColumn = 1
        }
    }
}

private struct LineNumberGutter: View {
    let text: String
    let activeLine: Int
    let compact: Bool

    private var lineCount: Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { line in
                    Text("\(line)")
                        .font(compact ? QBTheme.monoSmall : QBTheme.monoFont)
                        .foregroundStyle(line == activeLine ? QBTheme.menuText : QBTheme.lineNumberText)
                        .frame(height: 22, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .background(line == activeLine ? QBTheme.selectionHighlight : Color.clear)
                }
            }
            .padding(.trailing, 6)
            .padding(.top, 8)
        }
        .background(QBTheme.editorBackground)
    }
}