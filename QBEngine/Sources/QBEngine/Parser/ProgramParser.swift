import Foundation

public struct ProgramParser {
    private var activeProcedures: Set<String> = []
    private var activeFunctions: Set<String> = []

    public init() {}

    public mutating func parse(source: String) throws -> ParsedProgram {
        let rawLines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let (afterTypes, typeDefs) = try TypeExtractor.extract(from: rawLines)
        let (mainLines, procedureDefs) = try ProcedureExtractor.extract(from: afterTypes)
        let procedureMap = Dictionary(
            uniqueKeysWithValues: procedureDefs.map { ($0.name.uppercased(), $0) }
        )
        let typeMap = Dictionary(uniqueKeysWithValues: typeDefs.map { ($0.name.uppercased(), $0) })
        activeProcedures = Set(procedureMap.keys)
        activeFunctions = Set(
            procedureMap.values
                .filter { $0.kind == .function }
                .map(\.name)
        )
        // DECLARE lines are no-ops; still parse as statements when present in main
        let programLines = try parsePhysicalLines(mainLines)
        return ParsedProgram(lines: programLines, procedures: procedureMap, typeDefs: typeMap)
    }

    /// Parses lines that already carry original 1-based physical `sourceLine` values.
    mutating func parsePhysicalLines(
        _ physicalLines: [PhysicalLine],
        knownProcedures: Set<String>? = nil,
        knownFunctions: Set<String>? = nil
    ) throws -> [ProgramLine] {
        let savedProcedures = activeProcedures
        let savedFunctions = activeFunctions
        if let knownProcedures {
            activeProcedures = knownProcedures
        }
        if let knownFunctions {
            activeFunctions = knownFunctions
        }
        defer {
            activeProcedures = savedProcedures
            activeFunctions = savedFunctions
        }
        var programLines: [ProgramLine] = []
        var index = 0
        while index < physicalLines.count {
            let current = physicalLines[index]
            let trimmed = current.text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            if ControlBlockFolder.isSelectCaseStart(trimmed) {
                let (statement, consumed, sourceLine) = try parseSelectCaseBlock(
                    physicalLines,
                    start: index
                )
                programLines.append(
                    ProgramLine(lineNumber: nil, statements: [statement], sourceLine: sourceLine)
                )
                index += consumed
                continue
            }

            if ControlBlockFolder.isBlockIfStart(trimmed) {
                let (statement, consumed) = try parseIfBlock(physicalLines, start: index)
                programLines.append(
                    ProgramLine(lineNumber: nil, statements: [statement], sourceLine: current.sourceLine)
                )
                index += consumed
                continue
            }

            let foldedTrimmed = current.text.trimmingCharacters(in: .whitespaces)
            if foldedTrimmed.isEmpty {
                index += 1
                continue
            }

            var lexer = Lexer(source: current.text)
            let tokens = lexer.tokenize().filter { token in
                if case .newline = token.kind { return false }
                if case .eof = token.kind { return false }
                return true
            }

            if tokens.isEmpty {
                index += 1
                continue
            }

            var parser = LineParser(
                tokens: tokens,
                sourceLine: current.sourceLine,
                knownProcedures: activeProcedures,
                knownFunctions: activeFunctions
            )
            let line = try parser.parseLine()
            programLines.append(line)
            index += 1
        }

        return programLines
    }

    func parseIfBlock(_ lines: [PhysicalLine], start: Int) throws -> (Statement, Int) {
        let headerLine = lines[start]
        let header = headerLine.text.trimmingCharacters(in: .whitespaces)
        let headerTokens = tokenizeLine(header)
        var headerParser = LineParser(tokens: headerTokens, sourceLine: headerLine.sourceLine)
        let condition = try headerParser.parseIfHeaderCondition()

        var thenLines: [PhysicalLine] = []
        var elseLines: [PhysicalLine] = []
        var index = start + 1
        var inElse = false

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("END IF") || upper == "ENDIF" {
                index += 1
                break
            }

            if upper == "ELSE" || upper.hasPrefix("ELSE ") || upper.hasPrefix("ELSEIF ") {
                inElse = true
                if upper.hasPrefix("ELSE ") {
                    let afterElse = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if !afterElse.isEmpty {
                        elseLines.append(PhysicalLine(text: String(afterElse), sourceLine: line.sourceLine))
                    }
                } else if upper.hasPrefix("ELSEIF ") {
                    elseLines.append(PhysicalLine(text: trimmed, sourceLine: line.sourceLine))
                }
                index += 1
                continue
            }

            if inElse {
                elseLines.append(PhysicalLine(text: trimmed, sourceLine: line.sourceLine))
            } else {
                thenLines.append(PhysicalLine(text: trimmed, sourceLine: line.sourceLine))
            }
            index += 1
        }

        let thenStatements = try parseStatementPhysicalLines(thenLines)
        let elseStatements = elseLines.isEmpty ? nil : try parseStatementPhysicalLines(elseLines)
        return (.ifStmt(condition, thenStatements, elseStatements), index - start)
    }

    private func parseSelectCaseBlock(
        _ lines: [PhysicalLine],
        start: Int
    ) throws -> (Statement, Int, Int) {
        let headerLine = lines[start]
        let header = headerLine.text.trimmingCharacters(in: .whitespaces)
        let headerTokens = tokenizeLine(header)
        var headerParser = LineParser(tokens: headerTokens, sourceLine: headerLine.sourceLine)
        let selector = try headerParser.parseSelectCaseHeader()

        var clauses: [CaseClause] = []
        var index = start + 1
        var currentCaseLines: [PhysicalLine] = []
        var currentCaseHeader: String?
        var currentCaseSourceLine = headerLine.sourceLine

        func flushCase() throws {
            guard let headerText = currentCaseHeader else { return }
            let statements = try parseStatementPhysicalLines(currentCaseLines)
            clauses.append(try parseCaseClause(header: headerText, statements: statements))
            currentCaseHeader = nil
            currentCaseLines = []
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            if ControlBlockFolder.isEndSelect(trimmed) {
                try flushCase()
                index += 1
                break
            }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("CASE ") || upper == "CASE ELSE" {
                try flushCase()
                currentCaseHeader = trimmed
                currentCaseSourceLine = line.sourceLine
                index += 1
                continue
            }

            currentCaseLines.append(PhysicalLine(text: trimmed, sourceLine: line.sourceLine))
            index += 1
        }

        _ = currentCaseSourceLine
        return (.selectCase(selector, clauses), index - start, headerLine.sourceLine)
    }

    private func parseStatementPhysicalLines(_ lines: [PhysicalLine]) throws -> [Statement] {
        var statements: [Statement] = []
        for line in lines {
            let tokens = tokenizeLine(line.text)
            var parser = LineParser(
                tokens: tokens,
                sourceLine: line.sourceLine,
                knownProcedures: activeProcedures,
                knownFunctions: activeFunctions
            )
            repeat {
                statements.append(try parser.parseStatement())
            } while parser.takeColonIfPresent()
        }
        return statements
    }

    private func parseCaseClause(header: String, statements: [Statement]) throws -> CaseClause {
        let upper = header.uppercased().trimmingCharacters(in: .whitespaces)
        if upper == "CASE ELSE" {
            return CaseClause(isElse: true, statements: statements)
        }

        guard upper.hasPrefix("CASE ") else {
            throw QBError.syntax("Expected CASE clause, got '\(header)'")
        }

        let body = header.dropFirst(5).trimmingCharacters(in: .whitespaces)
        let bodyUpper = body.uppercased()
        if bodyUpper.hasPrefix("IS ") {
            let compareBody = body.dropFirst(3).trimmingCharacters(in: .whitespaces)
            let tokens = tokenizeLine(String(compareBody))
            var parser = ExpressionParser(tokens: tokens, knownFunctions: activeFunctions)
            let (op, rhs, consumed) = try parser.parseCaseIsComparison()
            if consumed < tokens.count {
                throw QBError.syntax("Unexpected tokens after CASE IS comparison")
            }
            return CaseClause(isCompare: op, compareValue: rhs, statements: statements)
        }

        let values = try parseCommaSeparatedExpressions(body)
        return CaseClause(values: values, statements: statements)
    }

    private func parseCommaSeparatedExpressions(_ source: String) throws -> [Expr] {
        let tokens = tokenizeLine(source)
        var parser = ExpressionParser(tokens: tokens, knownFunctions: activeFunctions)
        var values: [Expr] = []
        repeat {
            values.append(try parser.parseExpression())
        } while parser.takeCommaIfPresent()
        return values
    }

    private func tokenizeLine(_ source: String) -> [Token] {
        var lexer = Lexer(source: source)
        return lexer.tokenize().filter { token in
            if case .newline = token.kind { return false }
            if case .eof = token.kind { return false }
            return true
        }
    }
}

private struct LineParser {
    private var tokens: [Token]
    private var pos: Int = 0
    private let sourceLine: Int
    private let knownProcedures: Set<String>
    private let knownFunctions: Set<String>

    init(
        tokens: [Token],
        sourceLine: Int,
        knownProcedures: Set<String> = [],
        knownFunctions: Set<String> = []
    ) {
        self.tokens = tokens
        self.sourceLine = sourceLine
        self.knownProcedures = knownProcedures
        self.knownFunctions = knownFunctions
    }

    mutating func parseLine() throws -> ProgramLine {
        var lineNumber: Int?
        if let token = peek(), case .lineNumber(let num) = token.kind {
            lineNumber = num
            advance()
        } else if let token = peek(), case .integer(let num) = token.kind {
            if let next = tokens[safe: pos + 1], isStatementStart(next) {
                lineNumber = num
                advance()
            }
        }

        var statements: [Statement] = []
        repeat {
            statements.append(try parseStatement())
        } while match(.colon)

        return ProgramLine(lineNumber: lineNumber, statements: statements, sourceLine: sourceLine)
    }

    mutating func parseStatement() throws -> Statement {
        guard let token = peek() else {
            throw QBError.syntax("Empty statement at line \(sourceLine)")
        }

        if case .keyword(.rem) = token.kind {
            advance()
            let text = remainingText()
            return .rem(text)
        }

        if case .keyword(.let) = token.kind {
            advance()
            let target = try parseAssignable()
            try consumeEquals()
            let value = try parseExpression()
            return .letStmt(target, value)
        }

        if case .keyword(.print) = token.kind {
            advance()
            if matchKeyword(.using) {
                guard case .string(let format)? = peek()?.kind else {
                    throw QBError.syntax("Expected format string after PRINT USING")
                }
                advance()
                _ = match(.semicolon)
                var values: [Expr] = []
                if !isAtEnd() && !check(.colon) {
                    values.append(try parseExpression())
                    while match(.comma) {
                        values.append(try parseExpression())
                    }
                }
                return .printUsing(format, values)
            }
            // PRINT #n, ...
            if case .integer(let handle)? = peek()?.kind {
                advance()
                _ = match(.comma)
                return .printHash(handle, try parsePrintList())
            }
            return .print(try parsePrintList())
        }

        if case .keyword(.input) = token.kind {
            advance()
            // INPUT #n, varlist
            if case .integer(let handle)? = peek()?.kind {
                advance()
                _ = match(.comma)
                return .inputHash(handle, try parseVariableList())
            }
            return try parseInput()
        }

        // LINE INPUT #n, var
        if case .keyword(.line) = token.kind,
           let next = tokens[safe: pos + 1], case .keyword(.input) = next.kind,
           let third = tokens[safe: pos + 2], case .integer(let handle) = third.kind {
            advance() // LINE
            advance() // INPUT
            advance() // handle
            _ = match(.comma)
            let target = try parseAssignable()
            return .lineInputHash(handle, target)
        }

        if case .keyword(.line) = token.kind {
            // LINE INPUT or LINE graphics
            if let next = tokens[safe: pos + 1], case .keyword(.input) = next.kind {
                advance() // LINE
                advance() // INPUT
                var prompt: String?
                if case .string(let p)? = peek()?.kind {
                    advance()
                    prompt = p
                    _ = match(.semicolon)
                }
                let target = try parseAssignable()
                return .lineInput(prompt, target)
            }
        }

        if case .keyword(.if) = token.kind {
            return try parseIf()
        }

        if case .keyword(.for) = token.kind {
            return try parseFor()
        }

        if case .keyword(.next) = token.kind {
            advance()
            if case .identifier(let rawName)? = peek()?.kind {
                advance()
                let (name, _) = splitTypeSuffix(rawName)
                return .next(name)
            }
            return .next(nil)
        }

        if case .keyword(.while) = token.kind {
            advance()
            let condition = try parseExpression()
            return .whileLoop(condition, [])
        }

        if case .keyword(.wend) = token.kind {
            advance()
            return .wend
        }

        if case .keyword(.do) = token.kind {
            return try parseDo()
        }

        if case .keyword(.loop) = token.kind {
            advance()
            if matchKeyword(.while) {
                return .loop(.while(try parseExpression()))
            }
            if matchKeyword(.until) {
                return .loop(.until(try parseExpression()))
            }
            return .loop(nil)
        }

        if case .keyword(.exit) = token.kind {
            advance()
            if matchKeyword(.for) { return .exitFor }
            if matchKeyword(.do) { return .exitDo }
            if matchKeyword(.while) { return .exitWhile }
            if matchKeyword(.sub) { return .exitSub }
            if matchKeyword(.function) { return .exitFunction }
            throw QBError.syntax("EXIT must be followed by FOR, DO, WHILE, SUB, or FUNCTION")
        }

        if case .keyword(.call) = token.kind {
            advance()
            return try parseProcedureCall()
        }

        if case .keyword(.goto) = token.kind {
            advance()
            return .goto(try parseJumpTarget())
        }

        if case .keyword(.gosub) = token.kind {
            advance()
            return .gosub(try parseJumpTarget())
        }

        if case .keyword(.return) = token.kind {
            advance()
            return .return
        }

        if case .keyword(.end) = token.kind {
            advance()
            return .end
        }

        if case .keyword(.stop) = token.kind {
            advance()
            return .stop
        }

        if case .keyword(.dim) = token.kind {
            return try parseDim()
        }

        if case .keyword(.const) = token.kind {
            return try parseConst()
        }

        if case .keyword(.swap) = token.kind {
            advance()
            let a = try parseAssignable()
            try consume(.comma, message: "Expected ',' in SWAP")
            let b = try parseAssignable()
            return .swap(a, b)
        }

        if case .keyword(.option) = token.kind {
            advance()
            // OPTION BASE n
            if case .identifier(let raw)? = peek()?.kind, raw.uppercased() == "BASE" {
                advance()
            } else if case .keyword = peek()?.kind {
                // ignore
            }
            let base = try parseExpression()
            if case .integer(let n) = base {
                return .optionBase(n)
            }
            throw QBError.syntax("OPTION BASE requires integer")
        }

        if case .keyword(.locate) = token.kind {
            advance()
            let row = try parseExpression()
            var col: Expr?
            if match(.comma) {
                col = try parseExpression()
            }
            return .locate(row, col)
        }

        if case .keyword(.open) = token.kind {
            return try parseOpen()
        }

        if case .keyword(.close) = token.kind {
            advance()
            if isAtEnd() || check(.colon) {
                return .close(nil)
            }
            var handles: [Int] = []
            repeat {
                if case .integer(let n)? = peek()?.kind {
                    advance()
                    handles.append(n)
                } else if case .identifier(let raw)? = peek()?.kind, raw.hasPrefix("#"),
                          let n = Int(raw.dropFirst()) {
                    advance()
                    handles.append(n)
                } else {
                    break
                }
            } while match(.comma)
            return .close(handles.isEmpty ? nil : handles)
        }

        if case .keyword(.paint) = token.kind {
            advance()
            try consume(.lparen, message: "Expected '(' after PAINT")
            let x = try parseExpression()
            try consume(.comma, message: "Expected ','")
            let y = try parseExpression()
            try consume(.rparen, message: "Expected ')'")
            var paintColor: Expr?
            var border: Expr?
            if match(.comma) {
                paintColor = try parseExpression()
                if match(.comma) {
                    border = try parseExpression()
                }
            }
            return .paint(x, y, paintColor, border)
        }

        if case .keyword(.draw) = token.kind {
            advance()
            return .draw(try parseExpression())
        }

        if case .keyword(.get) = token.kind {
            advance()
            try consume(.lparen, message: "Expected '(' after GET")
            let x1 = try parseExpression()
            try consume(.comma, message: "Expected ','")
            let y1 = try parseExpression()
            try consume(.rparen, message: "Expected ')'")
            try consume(.minus, message: "Expected '-' in GET")
            try consume(.lparen, message: "Expected '('")
            let x2 = try parseExpression()
            try consume(.comma, message: "Expected ','")
            let y2 = try parseExpression()
            try consume(.rparen, message: "Expected ')'")
            try consume(.comma, message: "Expected ',' before array name")
            guard case .identifier(let rawName)? = peek()?.kind else {
                throw QBError.syntax("Expected sprite name in GET")
            }
            advance()
            let (name, _) = splitTypeSuffix(rawName)
            return .getSprite(x1, y1, x2, y2, name)
        }

        if case .keyword(.put) = token.kind {
            advance()
            try consume(.lparen, message: "Expected '(' after PUT")
            let x = try parseExpression()
            try consume(.comma, message: "Expected ','")
            let y = try parseExpression()
            try consume(.rparen, message: "Expected ')'")
            try consume(.comma, message: "Expected ',' before array name")
            guard case .identifier(let rawName)? = peek()?.kind else {
                throw QBError.syntax("Expected sprite name in PUT")
            }
            advance()
            let (name, _) = splitTypeSuffix(rawName)
            return .putSprite(x, y, name)
        }

        if case .keyword(.shared) = token.kind {
            advance()
            return .shared(try parseNameList())
        }

        if case .keyword(.static) = token.kind {
            advance()
            return .static(try parseNameList())
        }

        if case .keyword(.declare) = token.kind {
            advance()
            let kind: ProcedureKind
            if matchKeyword(.sub) {
                kind = .sub
            } else if matchKeyword(.function) {
                kind = .function
            } else {
                throw QBError.syntax("Expected SUB or FUNCTION after DECLARE")
            }
            guard case .identifier(let rawName)? = peek()?.kind else {
                throw QBError.syntax("Expected procedure name after DECLARE")
            }
            advance()
            let (name, _) = splitTypeSuffix(rawName)
            // Skip rest of declare line
            while !isAtEnd() && !check(.colon) { advance() }
            return .declare(name, kind)
        }

        if case .keyword(.mid) = token.kind {
            return try parseMidAssign()
        }
        // MID$ as identifier (dollar-suffix form)
        if case .identifier(let rawMid) = token.kind {
            let upperMid = rawMid.uppercased()
            if upperMid == "MID" || upperMid == "MID$" {
                // Only statement form if followed by '(' and later '='
                if tokens[safe: pos + 1]?.kind == .lparen {
                    return try parseMidAssign()
                }
            }
        }

        if case .keyword(.defint) = token.kind { return try parseDefType(.integer) }
        if case .keyword(.deflng) = token.kind { return try parseDefType(.long) }
        if case .keyword(.defsng) = token.kind { return try parseDefType(.single) }
        if case .keyword(.defdbl) = token.kind { return try parseDefType(.double) }
        if case .keyword(.defstr) = token.kind { return try parseDefType(.string) }

        if case .keyword(.data) = token.kind {
            advance()
            return .data(try parseDataList())
        }

        if case .keyword(.read) = token.kind {
            advance()
            return .read(try parseVariableList())
        }

        if case .keyword(.restore) = token.kind {
            advance()
            if isAtEnd() {
                return .restore(nil)
            }
            return .restore(try parseExpression())
        }

        if case .keyword(.on) = token.kind {
            return try parseOn()
        }

        if case .keyword(.randomize) = token.kind {
            advance()
            if isAtEnd() || check(.colon) {
                return .randomize(nil)
            }
            return .randomize(try parseExpression())
        }

        if case .keyword(.cls) = token.kind {
            advance()
            return .cls
        }

        if case .keyword(.screen) = token.kind {
            advance()
            let mode = try parseExpression()
            var color: Expr?
            var ap: Expr?
            if match(.comma) {
                color = try parseExpression()
                if match(.comma) {
                    ap = try parseExpression()
                }
            }
            return .screen(mode, color, ap)
        }

        if case .keyword(.color) = token.kind {
            advance()
            let fg = try parseExpression()
            var bg: Expr?
            if match(.comma) {
                bg = try parseExpression()
            }
            return .color(fg, bg, nil)
        }

        if case .keyword(.pset) = token.kind {
            advance()
            return try parsePointStatement(preset: false)
        }

        if case .keyword(.preset) = token.kind {
            advance()
            return try parsePointStatement(preset: true)
        }

        if case .keyword(.line) = token.kind {
            advance()
            return try parseLineStatement()
        }

        if case .keyword(.circle) = token.kind {
            advance()
            return try parseCircle()
        }

        if case .keyword(.beep) = token.kind {
            advance()
            return .beep
        }

        if case .keyword(.sleep) = token.kind {
            advance()
            return .sleep(try parseExpression())
        }

        if case .identifier(let rawName) = token.kind {
            let (name, _) = splitTypeSuffix(rawName)
            // Named label: Foo:
            if tokens[safe: pos + 1]?.kind == .colon {
                advance()
                advance() // colon
                return .label(name)
            }
            if knownProcedures.contains(name),
               !knownFunctions.contains(name),
               !check(.equals) {
                advance()
                let args = try parseProcedureArguments()
                return .callProcedure(name, args)
            }
        }

        // PRINT #n, ... / INPUT #n, ... when print/input already handled —
        // handle bare assignment including field access
        let target = try parseAssignable()
        try consumeEquals()
        let value = try parseExpression()
        return .assign(target, value)
    }

    private mutating func parseIf() throws -> Statement {
        advance()
        let condition = try parseExpression()
        try consumeKeyword(.then)

        var thenStatements: [Statement] = []
        var elseStatements: [Statement]?

        if let target = try tryOptionalJumpTarget() {
            thenStatements = [.goto(target)]
        } else {
            thenStatements.append(try parseStatement())
            while !isAtEnd() && !isElseClause() {
                guard match(.colon) else { break }
                if isElseClause() { break }
                thenStatements.append(try parseStatement())
            }
        }

        if isElseClause() {
            if matchKeyword(.elseif) {
                return .ifStmt(condition, thenStatements, [.ifStmt(try parseExpressionAfterElseIf(), [], nil)])
            }
            consumeElseKeyword()
            var elseBody: [Statement] = []
            if let target = try tryOptionalJumpTarget() {
                elseBody = [.goto(target)]
            } else {
                elseBody.append(try parseStatement())
                while !isAtEnd() && !isStatementBoundary() {
                    guard match(.colon) else { break }
                    if isStatementBoundary() { break }
                    elseBody.append(try parseStatement())
                }
            }
            elseStatements = elseBody
        }

        return .ifStmt(condition, thenStatements, elseStatements)
    }

    private mutating func parseExpressionAfterElseIf() throws -> Expr {
        let condition = try parseExpression()
        try consumeKeyword(.then)
        _ = try parseStatement()
        return condition
    }

    private mutating func parseFor() throws -> Statement {
        advance()
        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected variable after FOR")
        }
        advance()
        let (name, qbType) = splitTypeSuffix(rawName)
        try consumeEquals()
        let start = try parseExpression()
        try consumeKeyword(.to)
        let end = try parseExpression()
        var step: Expr?
        if matchKeyword(.step) {
            step = try parseExpression()
        }
        return .forLoop(name, qbType, start, end, step, [])
    }

    private mutating func parseDo() throws -> Statement {
        advance()
        if matchKeyword(.while) {
            return .doLoop(.while(try parseExpression()), nil, [])
        }
        if matchKeyword(.until) {
            return .doLoop(.until(try parseExpression()), nil, [])
        }
        return .doLoop(.top, nil, [])
    }

    private mutating func parseDim() throws -> Statement {
        advance()
        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected name in DIM")
        }
        advance()
        let (name, suffixType) = splitTypeSuffix(rawName)
        var bounds: [Expr] = []
        if match(.lparen) {
            repeat {
                let first = try parseExpression()
                if matchKeyword(.to) {
                    let upper = try parseExpression()
                    bounds.append(.function("__BOUNDS__", [first, upper]))
                } else {
                    bounds.append(first)
                }
            } while match(.comma)
            try consume(.rparen, message: "Expected ')' after DIM bounds")
        }
        var qbType = suffixType
        if matchKeyword(.as) {
            qbType = try parseTypeName()
            if bounds.isEmpty {
                return .dimAs(name, qbType, [])
            }
            return .dimAs(name, qbType, bounds)
        }
        if bounds.isEmpty {
            return .dimAs(name, qbType == .variant ? .variant : qbType, [])
        }
        return .dim(name, qbType, bounds)
    }

    private mutating func parseTypeName() throws -> QBType {
        if matchKeyword(.integer) { return .integer }
        if matchKeyword(.long) { return .long }
        if matchKeyword(.single) { return .single }
        if matchKeyword(.double) { return .double }
        if matchKeyword(.string) { return .string }
        if case .identifier(let raw)? = peek()?.kind {
            advance()
            let (name, _) = splitTypeSuffix(raw)
            return .userType(name)
        }
        throw QBError.syntax("Expected type name after AS")
    }

    private mutating func parseMidAssign() throws -> Statement {
        advance() // MID / MID$
        try consume(.lparen, message: "Expected '(' after MID$")
        let target = try parseAssignable()
        try consume(.comma, message: "Expected ','")
        let start = try parseExpression()
        var len: Expr?
        if match(.comma) {
            len = try parseExpression()
        }
        try consume(.rparen, message: "Expected ')'")
        try consumeEquals()
        let value = try parseExpression()
        return .midAssign(target, start, len, value)
    }

    private mutating func parseConst() throws -> Statement {
        advance()
        var items: [(String, QBType, Expr)] = []
        repeat {
            guard case .identifier(let rawName)? = peek()?.kind else {
                throw QBError.syntax("Expected constant name")
            }
            advance()
            let (name, type) = splitTypeSuffix(rawName)
            try consumeEquals()
            let value = try parseExpression()
            items.append((name, type, value))
        } while match(.comma)
        return .constDecl(items)
    }

    private mutating func parseOpen() throws -> Statement {
        advance()
        guard case .string(let path)? = peek()?.kind else {
            throw QBError.syntax("Expected filename string in OPEN")
        }
        advance()
        try consumeKeyword(.for)
        let mode: FileMode
        if matchKeyword(.input) {
            mode = .input
        } else if matchKeyword(.output) {
            mode = .output
        } else if matchKeyword(.append) {
            mode = .append
        } else if matchKeyword(.random) {
            mode = .random
        } else {
            throw QBError.syntax("Expected INPUT, OUTPUT, APPEND, or RANDOM after FOR")
        }
        try consumeKeyword(.as)
        // AS #1 or AS 1
        if case .integer(let n)? = peek()?.kind {
            advance()
            return .open(path, mode, n)
        }
        if case .identifier(let raw)? = peek()?.kind, raw.hasPrefix("#"), let n = Int(raw.dropFirst()) {
            advance()
            return .open(path, mode, n)
        }
        // AS # with separate tokens - lexer may give identifier "#" then integer? Unlikely.
        // Also handle keyword-less: sometimes # is not tokenized — try expression
        let handleExpr = try parseExpression()
        if case .integer(let n) = handleExpr {
            return .open(path, mode, n)
        }
        throw QBError.syntax("Expected file number after AS")
    }

    private mutating func parseNameList() throws -> [String] {
        var names: [String] = []
        repeat {
            guard case .identifier(let raw)? = peek()?.kind else {
                throw QBError.syntax("Expected variable name")
            }
            advance()
            let (name, _) = splitTypeSuffix(raw)
            names.append(name)
        } while match(.comma)
        return names
    }

    private mutating func parseDefType(_ type: QBType) throws -> Statement {
        advance()
        guard case .identifier(let start)? = peek()?.kind else {
            throw QBError.syntax("Expected letter range in DEF type")
        }
        advance()
        var endLetter: String?
        if match(.minus) {
            guard case .identifier(let end)? = peek()?.kind else {
                throw QBError.syntax("Expected end letter in DEF type range")
            }
            advance()
            endLetter = end.uppercased()
        }
        return .defType(type, start.uppercased(), endLetter)
    }

    private mutating func parseOn() throws -> Statement {
        advance()
        let expr = try parseExpression()
        if matchKeyword(.goto) {
            return .onGoto(expr, try parseJumpTargetList())
        }
        if matchKeyword(.gosub) {
            return .onGosub(expr, try parseJumpTargetList())
        }
        throw QBError.syntax("Expected GOTO or GOSUB after ON")
    }

    private mutating func parseJumpTargetList() throws -> [JumpTarget] {
        var targets: [JumpTarget] = []
        repeat {
            targets.append(try parseJumpTarget())
        } while match(.comma)
        return targets
    }

    private mutating func parseInput() throws -> Statement {
        var prompts: [String] = []
        if case .string(let prompt)? = peek()?.kind {
            advance()
            prompts.append(prompt)
            try consume(.semicolon, message: "Expected ';' after INPUT prompt")
        }
        if match(.comma) {
            return .input(prompts, try parseVariableList())
        }
        guard case .identifier = peek()?.kind else {
            throw QBError.syntax("Expected variable after INPUT")
        }
        let vars = try parseVariableList()
        return .input(prompts, vars)
    }

    mutating func parseIfHeaderCondition() throws -> Expr {
        try consumeKeyword(.if)
        let condition = try parseExpression()
        try consumeKeyword(.then)
        return condition
    }

    mutating func parseSelectCaseHeader() throws -> Expr {
        try consumeKeyword(.select)
        try consumeKeyword(.case)
        return try parseExpression()
    }

    mutating func takeColonIfPresent() -> Bool {
        match(.colon)
    }

    private mutating func parsePrintList() throws -> [PrintItem] {
        if isAtEnd() || check(.colon) || isStatementBoundary() {
            return [.expression(.string(""))]
        }

        var items: [PrintItem] = []
        while !isAtEnd() && !check(.colon) && !isStatementBoundary() {
            if match(.semicolon) {
                items.append(.separator(.semicolon))
                if isAtEnd() || check(.colon) { break }
                continue
            }
            if match(.comma) {
                items.append(.separator(.comma))
                if isAtEnd() || check(.colon) { break }
                continue
            }
            if matchKeyword(.tab) {
                if match(.lparen) {
                    let arg = try parseExpression()
                    try consume(.rparen, message: "Expected ')' after TAB")
                    items.append(.tab(arg))
                } else {
                    items.append(.tab(nil))
                }
                continue
            }
            if matchKeyword(.spc) {
                try consume(.lparen, message: "Expected '(' after SPC")
                let count = try parseExpression()
                try consume(.rparen, message: "Expected ')' after SPC")
                if case .integer(let n) = count {
                    items.append(.spc(n))
                } else {
                    items.append(.spc(1))
                }
                continue
            }
            items.append(.expression(try parseExpression()))
        }

        return items
    }

    private mutating func parseDataList() throws -> [Expr] {
        var values: [Expr] = []
        repeat {
            values.append(try parseExpression())
        } while match(.comma)
        return values
    }

    private mutating func parseVariableList() throws -> [Expr] {
        var vars: [Expr] = []
        repeat {
            vars.append(try parseAssignable())
        } while match(.comma)
        return vars
    }

    private mutating func parseProcedureCall() throws -> Statement {
        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected procedure name after CALL at line \(sourceLine)")
        }
        advance()
        let (name, _) = splitTypeSuffix(rawName)
        let args = try parseProcedureArguments()
        return .callProcedure(name, args)
    }

    private mutating func parseProcedureArguments() throws -> [Expr] {
        var args: [Expr] = []
        if match(.lparen) {
            if !check(.rparen) {
                repeat {
                    args.append(try parseExpression())
                } while match(.comma)
            }
            try consume(.rparen, message: "Expected ')' after arguments")
        } else if !isAtEnd() && !check(.colon) {
            repeat {
                args.append(try parseExpression())
            } while match(.comma)
        }
        return args
    }

    private mutating func parseAssignable() throws -> Expr {
        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected variable name at line \(sourceLine)")
        }
        advance()
        let (name, qbType) = splitTypeSuffix(rawName)
        var expr: Expr = .variable(name, qbType)
        if match(.lparen) {
            var indices: [Expr] = []
            if !check(.rparen) {
                repeat {
                    indices.append(try parseExpression())
                } while match(.comma)
            }
            try consume(.rparen, message: "Expected ')' after array index")
            for index in indices {
                expr = .function("INDEX", [expr, index])
            }
        }
        while match(.dot) {
            guard case .identifier(let fieldRaw)? = peek()?.kind else {
                throw QBError.syntax("Expected field name after '.'")
            }
            advance()
            let (field, _) = splitTypeSuffix(fieldRaw)
            expr = .fieldAccess(expr, field)
        }
        return expr
    }

    private mutating func parsePointStatement(preset: Bool) throws -> Statement {
        try consume(.lparen, message: "Expected '(' after PSET/PRESET")
        let x = try parseExpression()
        try consume(.comma, message: "Expected ','")
        let y = try parseExpression()
        try consume(.rparen, message: "Expected ')' after coordinates")
        var color: Expr?
        if match(.comma) {
            color = try parseExpression()
        }
        return preset ? .preset(x, y, color) : .pset(x, y, color)
    }

    private mutating func parseLineStatement() throws -> Statement {
        var style: LineBoxStyle = .none
        let parenStart = match(.lparen)
        let x1 = try parseExpression()
        try consume(.comma, message: "Expected ',' in LINE")
        let y1 = try parseExpression()
        if parenStart {
            try consume(.rparen, message: "Expected ')' after LINE start point")
        }
        var x2: Expr?
        var y2: Expr?
        var color: Expr?
        if match(.minus) || matchKeyword(.to) {
            if match(.lparen) {
                x2 = try parseExpression()
                try consume(.comma, message: "Expected ','")
                y2 = try parseExpression()
                try consume(.rparen, message: "Expected ')'")
            } else {
                x2 = try parseExpression()
                try consume(.comma, message: "Expected ','")
                y2 = try parseExpression()
            }
        }
        if match(.comma) {
            if let token = peek(), case .identifier(let rawName) = token.kind {
                let flag = rawName.uppercased()
                if flag == "BF" {
                    advance()
                    style = .filled
                } else if flag == "B" {
                    advance()
                    style = .box
                } else {
                    color = try parseExpression()
                    if match(.comma),
                       let next = peek(), case .identifier(let boxName) = next.kind {
                        let boxFlag = boxName.uppercased()
                        if boxFlag == "BF" {
                            advance()
                            style = .filled
                        } else if boxFlag == "B" {
                            advance()
                            style = .box
                        }
                    }
                }
            } else {
                color = try parseExpression()
                if match(.comma),
                   let next = peek(), case .identifier(let boxName) = next.kind {
                    let boxFlag = boxName.uppercased()
                    if boxFlag == "BF" {
                        advance()
                        style = .filled
                    } else if boxFlag == "B" {
                        advance()
                        style = .box
                    }
                }
            }
        }
        return .line(x1, y1, x2, y2, color, style)
    }

    private mutating func parseCircle() throws -> Statement {
        try consume(.lparen, message: "Expected '(' after CIRCLE")
        let x = try parseExpression()
        try consume(.comma, message: "Expected ','")
        let y = try parseExpression()
        try consume(.rparen, message: "Expected ')' after coordinates")
        try consume(.comma, message: "Expected ',' before radius")
        let radius = try parseExpression()
        var color: Expr?
        var start: Expr?
        var end: Expr?
        if match(.comma) {
            color = try parseExpression()
            if match(.comma) {
                start = try parseExpression()
                if match(.comma) {
                    end = try parseExpression()
                }
            }
        }
        return .circle(x, y, radius, color, start, end)
    }

    private mutating func parseJumpTarget() throws -> JumpTarget {
        guard let token = peek() else {
            throw QBError.syntax("Expected line number or label")
        }
        if case .lineNumber(let num) = token.kind {
            advance()
            return .lineNumber(num)
        }
        if case .integer(let num) = token.kind {
            advance()
            return .lineNumber(num)
        }
        if case .identifier(let raw) = token.kind {
            advance()
            let (name, _) = splitTypeSuffix(raw)
            return .label(name)
        }
        throw QBError.syntax("Expected line number or label, got \(token.kind)")
    }

    private mutating func tryOptionalJumpTarget() throws -> JumpTarget? {
        guard let token = peek() else { return nil }
        switch token.kind {
        case .lineNumber(let num):
            advance()
            return .lineNumber(num)
        case .integer(let num):
            if let next = tokens[safe: pos + 1], !isStatementStart(next) {
                return nil
            }
            advance()
            return .lineNumber(num)
        default:
            // Identifiers are statements (PRINT, etc.), not optional THEN targets
            return nil
        }
    }

    private mutating func parseExpression() throws -> Expr {
        var parser = ExpressionParser(
            tokens: Array(tokens.dropFirst(pos)),
            knownFunctions: knownFunctions
        )
        let expr = try parser.parseExpression()
        let consumed = parser.consumedCount
        pos += consumed
        return expr
    }

    private mutating func consumeTypeSuffix(default defaultType: QBType) throws -> QBType {
        guard let token = peek() else { return defaultType }
        if case .identifier(let name) = token.kind, let _ = TypeSuffix(rawValue: name) {
            advance()
            switch name {
            case "%": return .integer
            case "&": return .long
            case "!": return .single
            case "#": return .double
            case "$": return .string
            default: return defaultType
            }
        }
        return defaultType
    }

    private mutating func consumeEquals() throws {
        try consume(.equals, message: "Expected '='")
    }

    private func remainingText() -> String {
        guard pos < tokens.count else { return "" }
        return tokens[pos...].compactMap { token -> String? in
            switch token.kind {
            case .identifier(let s): return s
            case .integer(let n): return String(n)
            case .string(let s): return s
            default: return nil
            }
        }.joined(separator: " ")
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

    private mutating func matchKeyword(_ keyword: Keyword) -> Bool {
        guard let token = peek(), case .keyword(keyword) = token.kind else { return false }
        advance()
        return true
    }

    private mutating func consume(_ kind: TokenKind, message: String) throws {
        guard match(kind) else {
            throw QBError.syntax("\(message) at line \(sourceLine)")
        }
    }

    private mutating func consumeKeyword(_ keyword: Keyword) throws {
        guard matchKeyword(keyword) else {
            throw QBError.syntax("Expected \(keyword.rawValue.uppercased()) at line \(sourceLine)")
        }
    }

    private func check(_ kind: TokenKind) -> Bool {
        peek()?.kind == kind
    }

    private func isAtEnd() -> Bool {
        pos >= tokens.count
    }

    private func previous() -> Token? {
        guard pos > 0 else { return nil }
        return tokens[pos - 1]
    }

    private func isElseClause() -> Bool {
        guard let token = peek(), case .keyword(let kw) = token.kind else { return false }
        return kw == .else || kw == .elseif
    }

    private mutating func consumeElseKeyword() {
        if matchKeyword(.elseif) { return }
        _ = matchKeyword(.else)
    }

    private func isStatementBoundary() -> Bool {
        guard let token = peek(), case .keyword(let kw) = token.kind else { return false }
        return [.next, .wend, .loop, .else, .elseif, .end, .return, .case].contains(kw)
    }
}

extension ExpressionParser {
    var consumedCount: Int { pos }
}

private func isStatementStart(_ token: Token) -> Bool {
    if case .keyword = token.kind { return true }
    if case .identifier = token.kind { return true }
    return false
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

func splitTypeSuffix(_ rawName: String) -> (String, QBType) {
    guard let last = rawName.last, let suffix = TypeSuffix(rawValue: String(last)) else {
        return (rawName.uppercased(), .variant)
    }
    let base = String(rawName.dropLast()).uppercased()
    let type: QBType
    switch suffix {
    case .integer: type = .integer
    case .long: type = .long
    case .single: type = .single
    case .double: type = .double
    case .string: type = .string
    }
    return (base, type)
}