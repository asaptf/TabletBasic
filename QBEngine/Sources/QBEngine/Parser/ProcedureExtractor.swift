import Foundation

enum ProcedureExtractor {
    static func extract(from physicalLines: [String]) throws -> (
        mainLines: [String],
        procedures: [ProcedureDef]
    ) {
        let procedureInfo = collectProcedureInfo(from: physicalLines)
        let knownProcedures = procedureInfo.all
        let knownFunctions = procedureInfo.functions
        var mainLines: [String] = []
        var procedures: [ProcedureDef] = []
        var index = 0

        while index < physicalLines.count {
            let trimmed = physicalLines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                mainLines.append(physicalLines[index])
                index += 1
                continue
            }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("SUB ") || upper.hasPrefix("FUNCTION ") {
                let (procedure, consumed) = try parseProcedureBlock(
                    physicalLines,
                    start: index,
                    knownProcedures: knownProcedures,
                    knownFunctions: knownFunctions
                )
                procedures.append(procedure)
                index += consumed
                continue
            }

            mainLines.append(physicalLines[index])
            index += 1
        }

        return (mainLines, procedures)
    }

    private static func collectProcedureInfo(from lines: [String]) -> (all: Set<String>, functions: Set<String>) {
        var all = Set<String>()
        var functions = Set<String>()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            guard upper.hasPrefix("SUB ") || upper.hasPrefix("FUNCTION ") else { continue }
            let tokens = tokenize(trimmed)
            guard tokens.count >= 2 else { continue }
            if case .identifier(let rawName) = tokens[1].kind {
                let (name, _) = splitTypeSuffix(rawName)
                all.insert(name)
                if upper.hasPrefix("FUNCTION ") {
                    functions.insert(name)
                }
            }
        }
        return (all, functions)
    }

    private static func parseProcedureBlock(
        _ lines: [String],
        start: Int,
        knownProcedures: Set<String>,
        knownFunctions: Set<String>
    ) throws -> (ProcedureDef, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let headerTokens = tokenize(header)
        var parser = ProcedureHeaderParser(tokens: headerTokens, sourceLine: start + 1)
        let headerInfo = try parser.parse()

        var bodySourceLines: [String] = []
        var index = start + 1

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                bodySourceLines.append(lines[index])
                index += 1
                continue
            }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("END SUB") || upper == "ENDSUB" {
                index += 1
                break
            }
            if upper.hasPrefix("END FUNCTION") || upper == "ENDFUNCTION" {
                index += 1
                break
            }

            bodySourceLines.append(lines[index])
            index += 1
        }

        var bodyParser = ProgramParser()
        let body = try bodyParser.parsePhysicalLines(
            bodySourceLines,
            lineOffset: start + 1,
            knownProcedures: knownProcedures,
            knownFunctions: knownFunctions
        )
        let procedure = ProcedureDef(
            name: headerInfo.name,
            kind: headerInfo.kind,
            params: headerInfo.params,
            returnType: headerInfo.returnType,
            body: body,
            sourceLine: start + 1
        )
        return (procedure, index - start)
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

private struct ProcedureHeaderInfo {
    let name: String
    let kind: ProcedureKind
    let params: [ProcedureParam]
    let returnType: QBType
}

private struct ProcedureHeaderParser {
    private var tokens: [Token]
    private let sourceLine: Int
    private var pos = 0

    init(tokens: [Token], sourceLine: Int) {
        self.tokens = tokens
        self.sourceLine = sourceLine
    }

    mutating func parse() throws -> ProcedureHeaderInfo {
        guard let token = peek() else {
            throw QBError.syntax("Expected SUB or FUNCTION at line \(sourceLine)")
        }

        let kind: ProcedureKind
        if case .keyword(.sub) = token.kind {
            kind = .sub
            advance()
        } else if case .keyword(.function) = token.kind {
            kind = .function
            advance()
        } else {
            throw QBError.syntax("Expected SUB or FUNCTION at line \(sourceLine)")
        }

        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected procedure name at line \(sourceLine)")
        }
        advance()
        let (name, returnType) = splitTypeSuffix(rawName)

        var params: [ProcedureParam] = []
        if match(.lparen) {
            if !check(.rparen) {
                repeat {
                    guard case .identifier(let rawParam)? = peek()?.kind else {
                        throw QBError.syntax("Expected parameter name at line \(sourceLine)")
                    }
                    advance()
                    let (paramName, paramType) = splitTypeSuffix(rawParam)
                    params.append(ProcedureParam(name: paramName, type: paramType))
                } while match(.comma)
            }
            try consume(.rparen, message: "Expected ')' after parameter list")
        }

        return ProcedureHeaderInfo(
            name: name,
            kind: kind,
            params: params,
            returnType: kind == .function ? returnType : .variant
        )
    }

    private func peek() -> Token? {
        guard pos < tokens.count else { return nil }
        return tokens[pos]
    }

    private mutating func advance() {
        if pos < tokens.count { pos += 1 }
    }

    private mutating func match(_ kind: TokenKind) -> Bool {
        guard let token = peek(), token.kind == kind else { return false }
        advance()
        return true
    }

    private mutating func check(_ kind: TokenKind) -> Bool {
        peek()?.kind == kind
    }

    private mutating func consume(_ kind: TokenKind, message: String) throws {
        guard match(kind) else {
            throw QBError.syntax("\(message) at line \(sourceLine)")
        }
    }
}

