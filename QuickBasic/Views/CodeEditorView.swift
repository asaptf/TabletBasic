import SwiftUI
import UIKit

enum SourceCursor {
    static func position(in text: String, location: Int) -> (line: Int, column: Int) {
        let safeLocation = min(max(0, location), text.count)
        guard safeLocation > 0 else { return (1, 1) }

        var line = 1
        var column = 1
        for character in text.prefix(safeLocation) {
            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return (line, column)
    }
}

struct CodeEditorView: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var editorScrollOffset: CGFloat = 0

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    private var editorFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: compactLayout ? 13 : 15, weight: .regular)
    }

    var body: some View {
        HStack(spacing: 0) {
            LineNumberGutter(
                text: text,
                activeLine: cursorLine,
                compact: compactLayout,
                scrollOffset: editorScrollOffset
            )
            .frame(width: LayoutMetrics.lineNumberGutterWidth(compact: compactLayout))

            Rectangle()
                .fill(QBTheme.menuText.opacity(0.25))
                .frame(width: 1)

            BasicTextEditor(
                text: $text,
                font: editorFont,
                textColor: UIColor(QBTheme.editorText),
                backgroundColor: UIColor(QBTheme.editorBackground),
                onSelectionChange: updateCursor,
                onScroll: { editorScrollOffset = $0 }
            )
        }
        .background(QBTheme.editorBackground)
    }

    private func updateCursor(line: Int, column: Int) {
        cursorLine = line
        cursorColumn = column
    }
}

private struct BasicTextEditor: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor
    let onSelectionChange: (Int, Int) -> Void
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.tintColor = textColor
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.text = text
        context.coordinator.attach(to: textView)
        context.coordinator.reportSelection(in: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
        if textView.backgroundColor != backgroundColor {
            textView.backgroundColor = backgroundColor
        }

        guard textView.text != text else { return }

        textView.text = text
        textView.selectedRange = NSRange(location: 0, length: 0)
        context.coordinator.reportSelection(in: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BasicTextEditor
        private weak var textView: UITextView?
        private var scrollObservation: NSKeyValueObservation?

        init(parent: BasicTextEditor) {
            self.parent = parent
        }

        func attach(to textView: UITextView) {
            self.textView = textView
            scrollObservation = textView.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
                self?.parent.onScroll(view.contentOffset.y)
            }
        }

        func reportSelection(in textView: UITextView) {
            let location = textView.selectedRange.location
            let (line, column) = SourceCursor.position(in: textView.text, location: location)
            parent.onSelectionChange(line, column)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            reportSelection(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportSelection(in: textView)
        }
    }
}

private struct LineNumberGutter: View {
    let text: String
    let activeLine: Int
    let compact: Bool
    let scrollOffset: CGFloat

    private var lineCount: Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { line in
                    Text("\(line)")
                        .font(compact ? QBTheme.monoSmall : QBTheme.monoFont)
                        .foregroundStyle(line == activeLine ? QBTheme.menuText : QBTheme.lineNumberText)
                        .frame(height: LayoutMetrics.editorLineHeight, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .background(line == activeLine ? QBTheme.selectionHighlight : Color.clear)
                }
            }
            .padding(.trailing, 6)
            .padding(.top, 8)
            .offset(y: -scrollOffset)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .background(QBTheme.editorBackground)
    }
}