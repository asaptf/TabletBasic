import Foundation

public enum BasicSourceNormalizer {
    /// Strips the common leading indentation produced by Swift multiline string literals.
    public static func normalize(_ source: String) -> String {
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let indents = lines.compactMap { line -> Int? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return line.prefix(while: { $0 == " " || $0 == "\t" }).count
        }

        guard let minIndent = indents.min(), minIndent > 0 else {
            return source
        }

        let dedented = lines.map { line -> String in
            if line.trimmingCharacters(in: .whitespaces).isEmpty { return "" }
            if line.count <= minIndent { return line.trimmingCharacters(in: .whitespaces) }
            return String(line.dropFirst(minIndent))
        }

        return dedented.joined(separator: "\n")
    }
}