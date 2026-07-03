import Foundation

enum ControlBlockFolder {
    static func foldIfBlock(_ lines: [String], start: Int) -> (String, Int) {
        foldIfBlockInternal(lines, start: start)
    }

    static func fold(_ lines: [String]) -> [String] {
        var result: [String] = []
        var index = 0

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(lines[index])
                index += 1
                continue
            }

            if isBlockIfStart(trimmed) {
                let (folded, consumed) = foldIfBlockInternal(lines, start: index)
                result.append(folded)
                index += consumed
                continue
            }

            result.append(lines[index])
            index += 1
        }

        return result
    }

    static func isBlockIfStart(_ line: String) -> Bool {
        let upper = line.uppercased()
        guard upper.hasPrefix("IF ") else { return false }
        guard let thenRange = upper.range(of: " THEN") else { return false }
        let afterThen = upper[thenRange.upperBound...]
            .trimmingCharacters(in: .whitespaces)
        if afterThen.isEmpty { return true }
        if afterThen.hasPrefix("'") { return true }
        return false
    }

    private static func foldIfBlockInternal(_ lines: [String], start: Int) -> (String, Int) {
        var parts: [String] = [lines[start].trimmingCharacters(in: .whitespaces)]
        var index = start + 1

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("END IF") || upper == "ENDIF" {
                index += 1
                break
            }

            if upper.hasPrefix("ELSEIF ") {
                parts.append(trimmed)
                index += 1
                continue
            }

            if upper == "ELSE" {
                parts.append("ELSE")
                index += 1
                continue
            }

            if upper.hasPrefix("ELSE ") {
                let afterElse = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                parts.append("ELSE")
                if !afterElse.isEmpty {
                    parts.append(String(afterElse))
                }
                index += 1
                continue
            }

            parts.append(trimmed)
            index += 1
        }

        return (parts.joined(separator: ": "), index - start)
    }

    static func isSelectCaseStart(_ line: String) -> Bool {
        line.uppercased().hasPrefix("SELECT CASE")
    }

    static func isEndSelect(_ line: String) -> Bool {
        let upper = line.uppercased().trimmingCharacters(in: .whitespaces)
        return upper.hasPrefix("END SELECT") || upper == "ENDSELECT"
    }
}