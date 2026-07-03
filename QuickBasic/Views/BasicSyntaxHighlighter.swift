import SwiftUI
import UIKit
import QBEngine

struct SyntaxColors {
    let plain: UIColor
    let keyword: UIColor
    let string: UIColor
    let comment: UIColor
    let number: UIColor
    let lineNumber: UIColor
    let `operator`: UIColor
    let typeSuffix: UIColor

    static let dosBlue = SyntaxColors(
        plain: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        keyword: UIColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1.0),
        string: UIColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1.0),
        comment: UIColor(red: 0.55, green: 0.95, blue: 0.65, alpha: 1.0),
        number: UIColor(red: 1.0, green: 0.75, blue: 0.55, alpha: 1.0),
        lineNumber: UIColor(red: 1.0, green: 0.65, blue: 0.85, alpha: 1.0),
        operator: UIColor(red: 0.85, green: 0.85, blue: 1.0, alpha: 1.0),
        typeSuffix: UIColor(red: 0.75, green: 0.9, blue: 1.0, alpha: 1.0)
    )
}

enum BasicSyntaxHighlighter {
    private static let operatorCharacters: Set<Character> = [
        "+", "-", "*", "/", "\\", "^", "=", "<", ">", "(", ")", ",", ":", ";"
    ]

    private static let typeSuffixes: Set<Character> = ["%", "&", "!", "#", "$"]

    static func attributedString(
        from text: String,
        font: UIFont,
        lineHeight: CGFloat,
        colors: SyntaxColors = .dosBlue
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight

        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: colors.plain,
            .paragraphStyle: paragraphStyle
        ]

        guard !text.isEmpty else {
            return NSAttributedString(string: "", attributes: defaultAttributes)
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: defaultAttributes))
            }
            highlightLine(
                String(line),
                into: result,
                font: font,
                paragraphStyle: paragraphStyle,
                colors: colors
            )
        }

        return result
    }

    private static func highlightLine(
        _ line: String,
        into result: NSMutableAttributedString,
        font: UIFont,
        paragraphStyle: NSParagraphStyle,
        colors: SyntaxColors
    ) {
        var index = line.startIndex
        var onlyWhitespaceSoFar = true

        func append(_ text: String, color: UIColor) {
            guard !text.isEmpty else { return }
            result.append(
                NSAttributedString(
                    string: text,
                    attributes: [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraphStyle
                    ]
                )
            )
        }

        while index < line.endIndex {
            let character = line[index]

            if character == "'" {
                append(String(line[index...]), color: colors.comment)
                return
            }

            if character == "\"" {
                var end = line.index(after: index)
                while end < line.endIndex {
                    if line[end] == "\"" {
                        let next = line.index(after: end)
                        if next < line.endIndex, line[next] == "\"" {
                            end = line.index(after: next)
                            continue
                        }
                        end = line.index(after: end)
                        break
                    }
                    end = line.index(after: end)
                }
                append(String(line[index..<end]), color: colors.string)
                index = end
                onlyWhitespaceSoFar = false
                continue
            }

            if character.isWhitespace {
                append(String(character), color: colors.plain)
                index = line.index(after: index)
                continue
            }

            if onlyWhitespaceSoFar, character.isNumber {
                let start = index
                var end = index
                while end < line.endIndex, line[end].isNumber {
                    end = line.index(after: end)
                }
                var probe = end
                while probe < line.endIndex, line[probe].isWhitespace {
                    probe = line.index(after: probe)
                }
                if probe < line.endIndex, line[probe].isLetter || line[probe] == "_" {
                    append(String(line[start..<end]), color: colors.lineNumber)
                    index = end
                    onlyWhitespaceSoFar = false
                    continue
                }
            }

            if character.isNumber || (character == "." && nextCharacter(in: line, after: index)?.isNumber == true) {
                let start = index
                var end = index
                var sawDot = character == "."
                while end < line.endIndex {
                    let current = line[end]
                    if current.isNumber {
                        end = line.index(after: end)
                    } else if current == ".", !sawDot, nextCharacter(in: line, after: end)?.isNumber == true {
                        sawDot = true
                        end = line.index(after: end)
                    } else {
                        break
                    }
                }
                append(String(line[start..<end]), color: colors.number)
                index = end
                onlyWhitespaceSoFar = false
                continue
            }

            if character.isLetter || character == "_" {
                let start = index
                var end = index
                while end < line.endIndex {
                    let current = line[end]
                    if current.isLetter || current.isNumber || current == "_" {
                        end = line.index(after: end)
                    } else {
                        break
                    }
                }

                let word = String(line[start..<end]).lowercased()
                if Keyword.lookup[word] != nil {
                    var tokenEnd = end
                    if tokenEnd < line.endIndex, typeSuffixes.contains(line[tokenEnd]) {
                        tokenEnd = line.index(after: tokenEnd)
                        append(String(line[start..<tokenEnd]), color: colors.keyword)
                    } else if word == "rem" {
                        append(String(line[start...]), color: colors.comment)
                        return
                    } else {
                        append(String(line[start..<end]), color: colors.keyword)
                    }
                    index = tokenEnd
                } else {
                    var tokenEnd = end
                    if tokenEnd < line.endIndex, typeSuffixes.contains(line[tokenEnd]) {
                        tokenEnd = line.index(after: tokenEnd)
                        append(String(line[start..<end]), color: colors.plain)
                        append(String(line[end..<tokenEnd]), color: colors.typeSuffix)
                    } else {
                        append(String(line[start..<end]), color: colors.plain)
                    }
                    index = tokenEnd
                }
                onlyWhitespaceSoFar = false
                continue
            }

            if operatorCharacters.contains(character) {
                var end = index
                if character == "<" || character == ">" {
                    let next = nextCharacter(in: line, after: end)
                    if next == "=" || (character == "<" && next == ">") {
                        end = line.index(after: end)
                        end = line.index(after: end)
                    } else {
                        end = line.index(after: end)
                    }
                } else {
                    end = line.index(after: end)
                }
                append(String(line[index..<end]), color: colors.operator)
                index = end
                onlyWhitespaceSoFar = false
                continue
            }

            append(String(character), color: colors.plain)
            index = line.index(after: index)
            onlyWhitespaceSoFar = false
        }
    }

    private static func nextCharacter(in line: String, after index: String.Index) -> Character? {
        let next = line.index(after: index)
        guard next < line.endIndex else { return nil }
        return line[next]
    }
}

struct BasicCodePreview: View {
    let code: String
    var fontSize: CGFloat = 14

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(attributedCode)
                .font(.system(size: fontSize, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(minHeight: 160, maxHeight: 320)
        .padding(12)
        .background(QBTheme.editorBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QBTheme.menuText.opacity(0.22), lineWidth: 1)
        )
    }

    private var attributedCode: AttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = EditorTypography.lineHeight(for: font)
        let highlighted = BasicSyntaxHighlighter.attributedString(
            from: code,
            font: font,
            lineHeight: lineHeight
        )
        return AttributedString(highlighted)
    }
}