import SwiftUI
import UIKit

enum SourceCursor {
    static func position(in text: String, location: Int) -> (line: Int, column: Int) {
        let nsText = text as NSString
        let safeLocation = min(max(0, location), nsText.length)
        guard safeLocation > 0 else { return (1, 1) }

        var line = 1
        for index in 0..<safeLocation where nsText.character(at: index) == unichar(0x000A) {
            line += 1
        }

        let lineStart = nsText.lineRange(for: NSRange(location: safeLocation, length: 0)).location
        let column = safeLocation - lineStart + 1
        return (line, column)
    }
}

enum EditorTypography {
    static func lineHeight(for font: UIFont) -> CGFloat {
        ceil(font.lineHeight)
    }

    static func attributedString(
        from text: String,
        font: UIFont,
        textColor: UIColor,
        lineHeight: CGFloat
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
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

    private var lineHeight: CGFloat {
        EditorTypography.lineHeight(for: editorFont)
    }

    var body: some View {
        HStack(spacing: 0) {
            LineNumberGutter(
                text: text,
                activeLine: cursorLine,
                compact: compactLayout,
                lineHeight: lineHeight,
                scrollOffset: editorScrollOffset
            )
            .frame(width: LayoutMetrics.lineNumberGutterWidth(compact: compactLayout))

            Rectangle()
                .fill(QBTheme.menuText.opacity(0.25))
                .frame(width: 1)

            BasicTextEditor(
                text: $text,
                font: editorFont,
                lineHeight: lineHeight,
                textColor: UIColor(QBTheme.editorText),
                backgroundColor: UIColor(QBTheme.editorBackground),
                onSelectionChange: updateCursor,
                onScroll: { editorScrollOffset = $0 }
            )
            .accessibilityIdentifier("sourceEditor")
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
    let lineHeight: CGFloat
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
        textView.accessibilityIdentifier = "sourceEditor"
        context.coordinator.applyStyledText(to: textView, text: text, selection: NSRange(location: 0, length: 0))
        context.coordinator.attach(to: textView)
        context.coordinator.reportSelection(in: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.backgroundColor != backgroundColor {
            textView.backgroundColor = backgroundColor
        }
        if textView.tintColor != textColor {
            textView.tintColor = textColor
        }

        let currentText = textView.text ?? ""
        guard currentText != text else { return }

        let selection = text.isEmpty
            ? NSRange(location: 0, length: 0)
            : textView.selectedRange
        context.coordinator.applyStyledText(
            to: textView,
            text: text,
            selection: selection
        )
        context.coordinator.reportSelection(in: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BasicTextEditor
        private var scrollObservation: NSKeyValueObservation?

        init(parent: BasicTextEditor) {
            self.parent = parent
        }

        func attach(to textView: UITextView) {
            scrollObservation = textView.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
                self?.parent.onScroll(view.contentOffset.y)
            }
        }

        func applyStyledText(to textView: UITextView, text: String, selection: NSRange) {
            let attributes = BasicSyntaxHighlighter.attributedString(
                from: text,
                font: parent.font,
                lineHeight: parent.lineHeight
            )
            textView.attributedText = attributes
            if attributes.length > 0 {
                textView.typingAttributes = attributes.attributes(at: 0, effectiveRange: nil)
            }

            let length = (text as NSString).length
            let location = min(selection.location, length)
            let maxLength = max(0, length - location)
            textView.selectedRange = NSRange(location: location, length: min(selection.length, maxLength))
        }

        func reportSelection(in textView: UITextView) {
            let text = textView.text ?? ""
            let location = textView.selectedRange.location
            let (line, column) = SourceCursor.position(in: text, location: location)
            parent.onSelectionChange(line, column)
        }

        func textViewDidChange(_ textView: UITextView) {
            let selection = textView.selectedRange
            let plainText = textView.text ?? ""
            parent.text = plainText
            applyStyledText(to: textView, text: plainText, selection: selection)
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
    let lineHeight: CGFloat
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
                        .frame(height: lineHeight, alignment: .trailing)
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