import Foundation

enum TypeExtractor {
    /// Removes TYPE…END TYPE blocks while preserving original physical line numbers
    /// on remaining lines so breakpoints map to the editor.
    static func extract(from physicalLines: [String]) throws -> (remaining: [PhysicalLine], types: [TypeDef]) {
        var remaining: [PhysicalLine] = []
        var types: [TypeDef] = []
        var index = 0

        while index < physicalLines.count {
            let physicalLineNumber = index + 1
            let trimmed = physicalLines[index].trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("TYPE ") {
                let (typeDef, consumed) = try parseTypeBlock(physicalLines, start: index)
                types.append(typeDef)
                index += consumed
                continue
            }
            remaining.append(PhysicalLine(text: physicalLines[index], sourceLine: physicalLineNumber))
            index += 1
        }
        return (remaining, types)
    }

    private static func parseTypeBlock(_ lines: [String], start: Int) throws -> (TypeDef, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let tokens = tokenize(header)
        guard tokens.count >= 2, case .keyword(.type) = tokens[0].kind else {
            throw QBError.syntax("Expected TYPE at line \(start + 1)")
        }
        guard case .identifier(let rawName) = tokens[1].kind else {
            throw QBError.syntax("Expected type name at line \(start + 1)")
        }
        let (typeName, _) = splitTypeSuffix(rawName)
        var fields: [TypeField] = []
        var index = start + 1
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("END TYPE") || upper == "ENDTYPE" {
                index += 1
                break
            }
            if trimmed.isEmpty {
                index += 1
                continue
            }
            fields.append(try parseField(trimmed, sourceLine: index + 1))
            index += 1
        }
        return (TypeDef(name: typeName, fields: fields), index - start)
    }

    private static func parseField(_ line: String, sourceLine: Int) throws -> TypeField {
        let tokens = tokenize(line)
        guard !tokens.isEmpty, case .identifier(let rawName) = tokens[0].kind else {
            throw QBError.syntax("Expected field name at line \(sourceLine)")
        }
        let (name, suffixType) = splitTypeSuffix(rawName)
        var type = suffixType
        var pos = 1
        if pos < tokens.count, case .keyword(.as) = tokens[pos].kind {
            pos += 1
            guard pos < tokens.count else {
                throw QBError.syntax("Expected type after AS at line \(sourceLine)")
            }
            type = mapTypeToken(tokens[pos])
        }
        return TypeField(name: name, type: type)
    }

    private static func mapTypeToken(_ token: Token) -> QBType {
        switch token.kind {
        case .keyword(.integer): return .integer
        case .keyword(.long): return .long
        case .keyword(.single): return .single
        case .keyword(.double): return .double
        case .keyword(.string): return .string
        case .identifier(let raw):
            let (name, _) = splitTypeSuffix(raw)
            return .userType(name)
        default:
            return .variant
        }
    }

    private static func tokenize(_ source: String) -> [Token] {
        var lexer = Lexer(source: source)
        return lexer.tokenize().filter { token in
            if case .newline = token.kind { return false }
            if case .eof = token.kind { return false }
            return true
        }
    }
}
