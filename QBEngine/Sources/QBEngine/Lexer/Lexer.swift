import Foundation

public struct Lexer: Sendable {
    private static let dollarSuffixFunctions: Set<String> = [
        "ucase", "lcase", "left", "right", "mid", "chr", "str", "string",
        "hex", "oct", "space", "ltrim", "rtrim", "date", "time", "inkey",
        "input"
    ]
    private let source: String
    private let chars: [Character]
    private var index: Int = 0
    private var line: Int = 1
    private var column: Int = 1

    public init(source: String) {
        self.source = source
        self.chars = Array(source)
    }

    public mutating func tokenize() -> [Token] {
        var tokens: [Token] = []
        while true {
            let token = nextToken()
            tokens.append(token)
            if case .eof = token.kind { break }
        }
        return tokens
    }

    public mutating func nextToken() -> Token {
        skipWhitespaceAndContinuations()

        let startLine = line
        let startColumn = column

        guard index < chars.count else {
            return Token(kind: .eof, line: startLine, column: startColumn)
        }

        let ch = chars[index]

        if ch == "\n" {
            advance()
            return Token(kind: .newline, line: startLine, column: startColumn)
        }

        if ch == "'" {
            skipComment()
            return nextToken()
        }

        if ch == "\"" {
            return readString(startLine: startLine, startColumn: startColumn)
        }

        if ch.isNumber || (ch == "." && peekNext().map(\.isNumber) == true) {
            return readNumber(startLine: startLine, startColumn: startColumn)
        }

        if ch.isLetter || ch == "_" {
            return readIdentifierOrKeyword(startLine: startLine, startColumn: startColumn)
        }

        // File-number prefix: #1 → integer 1
        if ch == "#", let next = peekNext(), next.isNumber {
            advance()
            return readNumber(startLine: startLine, startColumn: startColumn)
        }

        switch ch {
        case "+": advance(); return Token(kind: .plus, line: startLine, column: startColumn)
        case "-": advance(); return Token(kind: .minus, line: startLine, column: startColumn)
        case "*": advance(); return Token(kind: .asterisk, line: startLine, column: startColumn)
        case "/": advance(); return Token(kind: .slash, line: startLine, column: startColumn)
        case "\\": advance(); return Token(kind: .backslash, line: startLine, column: startColumn)
        case "^": advance(); return Token(kind: .caret, line: startLine, column: startColumn)
        case "(": advance(); return Token(kind: .lparen, line: startLine, column: startColumn)
        case ")": advance(); return Token(kind: .rparen, line: startLine, column: startColumn)
        case ",": advance(); return Token(kind: .comma, line: startLine, column: startColumn)
        case ":": advance(); return Token(kind: .colon, line: startLine, column: startColumn)
        case ";": advance(); return Token(kind: .semicolon, line: startLine, column: startColumn)
        case ".": advance(); return Token(kind: .dot, line: startLine, column: startColumn)
        case "=":
            advance()
            return Token(kind: .equals, line: startLine, column: startColumn)
        case "<":
            advance()
            if match(">") {
                return Token(kind: .notEquals, line: startLine, column: startColumn)
            }
            if match("=") {
                return Token(kind: .lessEquals, line: startLine, column: startColumn)
            }
            return Token(kind: .less, line: startLine, column: startColumn)
        case ">":
            advance()
            if match("=") {
                return Token(kind: .greaterEquals, line: startLine, column: startColumn)
            }
            return Token(kind: .greater, line: startLine, column: startColumn)
        default:
            let message = "Unexpected character '\(ch)'"
            advance()
            return Token(kind: .error(message), line: startLine, column: startColumn)
        }
    }

    private mutating func skipWhitespaceAndContinuations() {
        while index < chars.count {
            let ch = chars[index]
            if ch == " " || ch == "\t" || ch == "\r" {
                advance()
                continue
            }
            if ch == "_" && peekNext() == "\n" {
                advance()
                if index < chars.count && chars[index] == "\n" {
                    advance()
                }
                continue
            }
            break
        }
    }

    private mutating func skipComment() {
        advance()
        while index < chars.count && chars[index] != "\n" {
            advance()
        }
    }

    private mutating func readString(startLine: Int, startColumn: Int) -> Token {
        advance()
        var value = ""
        while index < chars.count {
            let ch = chars[index]
            if ch == "\"" {
                if peekNext() == "\"" {
                    advance()
                    advance()
                    value.append("\"")
                    continue
                }
                advance()
                break
            }
            if ch == "\n" {
                return Token(kind: .error("Unterminated string"), line: startLine, column: startColumn)
            }
            value.append(ch)
            advance()
        }
        return Token(kind: .string(value), line: startLine, column: startColumn)
    }

    private mutating func readNumber(startLine: Int, startColumn: Int) -> Token {
        var hasDot = false
        var text = ""

        while index < chars.count {
            let ch = chars[index]
            if ch.isNumber {
                text.append(ch)
                advance()
            } else if ch == "." && !hasDot && peekNext().map(\.isNumber) == true {
                hasDot = true
                text.append(ch)
                advance()
            } else {
                break
            }
        }

        if hasDot {
            if let value = Double(text) {
                return Token(kind: .float(value), line: startLine, column: startColumn)
            }
        } else if let value = Int(text) {
            if index < chars.count && chars[index].isLetter {
                return Token(kind: .lineNumber(value), line: startLine, column: startColumn)
            }
            return Token(kind: .integer(value), line: startLine, column: startColumn)
        }

        return Token(kind: .error("Invalid number '\(text)'"), line: startLine, column: startColumn)
    }

    private mutating func readIdentifierOrKeyword(startLine: Int, startColumn: Int) -> Token {
        var text = ""
        while index < chars.count {
            let ch = chars[index]
            if ch.isLetter || ch.isNumber || ch == "_" {
                text.append(ch)
                advance()
            } else {
                break
            }
        }

        let lower = text.lowercased()
        if let keyword = Keyword.lookup[lower] {
            if Self.dollarSuffixFunctions.contains(lower),
               index < chars.count, chars[index] == "$" {
                text.append("$")
                advance()
                return Token(kind: .identifier(text), line: startLine, column: startColumn)
            }
            return Token(kind: .keyword(keyword), line: startLine, column: startColumn)
        }

        if index < chars.count {
            let suffixChar = chars[index]
            if TypeSuffix(rawValue: String(suffixChar)) != nil {
                text.append(suffixChar)
                advance()
            }
        }

        return Token(kind: .identifier(text), line: startLine, column: startColumn)
    }

    private mutating func advance() {
        guard index < chars.count else { return }
        if chars[index] == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        index += 1
    }

    private func peekNext() -> Character? {
        let next = index + 1
        guard next < chars.count else { return nil }
        return chars[next]
    }

    private mutating func match(_ expected: Character) -> Bool {
        guard index < chars.count, chars[index] == expected else { return false }
        advance()
        return true
    }
}