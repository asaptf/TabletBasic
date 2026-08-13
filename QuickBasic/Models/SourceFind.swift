import Foundation

enum SourceFind {
    struct Match: Equatable {
        let line: Int
        let column: Int
        let utf16Range: NSRange
    }

    static func find(in text: String, query: String, startUTF16: Int) -> Match? {
        let needle = query
        guard !needle.isEmpty else { return nil }
        let nsText = text as NSString
        let length = nsText.length
        let start = min(max(0, startUTF16), length)
        let tail = NSRange(location: start, length: length - start)
        let found = nsText.range(of: needle, options: [.caseInsensitive], range: tail)
        if found.location != NSNotFound {
            return match(in: text, range: found)
        }
        if start > 0 {
            let head = NSRange(location: 0, length: start)
            let wrapped = nsText.range(of: needle, options: [.caseInsensitive], range: head)
            if wrapped.location != NSNotFound {
                return match(in: text, range: wrapped)
            }
        }
        return nil
    }

    static func utf16Range(ofLine line: Int, in text: String) -> NSRange {
        let nsText = text as NSString
        var currentLine = 1
        var index = 0
        let target = max(1, line)
        while index < nsText.length {
            if currentLine == target {
                return NSRange(location: index, length: 0)
            }
            if nsText.character(at: index) == 10 {
                currentLine += 1
            }
            index += 1
        }
        return NSRange(location: nsText.length, length: 0)
    }

    static func utf16Offset(line: Int, column: Int, in text: String) -> Int {
        let lineStart = utf16Range(ofLine: line, in: text).location
        return lineStart + max(0, column - 1)
    }

    private static func match(in text: String, range: NSRange) -> Match {
        let position = SourceCursor.position(in: text, location: range.location)
        return Match(line: position.line, column: position.column, utf16Range: range)
    }
}

enum EditorCommand: Equatable {
    case idle
    case select(NSRange)
    case goToLine(Int)
}
