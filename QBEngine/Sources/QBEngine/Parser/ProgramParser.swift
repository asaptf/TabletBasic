import Foundation

public struct ProgramParser {
    public init() {}

    public func parse(source: String) throws -> ParsedProgram {
        let physicalLines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var programLines: [ProgramLine] = []
        var index = 0
        while index < physicalLines.count {
            let trimmed = physicalLines[index].trimmingCharacters(in: .whitespaces)
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
                    ProgramLine(lineNumber: nil, statements: [statement], sourceLine: index + 1)
                )
                index += consumed
                continue
            }

            let physicalLine = physicalLines[index]
            let foldedTrimmed = physicalLine.trimmingCharacters(in: .whitespaces)
            if foldedTrimmed.isEmpty {
                index += 1
                continue
            }

            var lexer = Lexer(source: physicalLine)
            let tokens = lexer.tokenize().filter { token in
                if case .newline = token.kind { return false }
                if case .eof = token.kind { return false }
                return true
            }

            if tokens.isEmpty {
                index += 1
                continue
            }

            var parser = LineParser(tokens: tokens, sourceLine: index + 1)
            let line = try parser.parseLine()
            programLines.append(line)
            index += 1
        }

        return ParsedProgram(lines: programLines)
    }

    private func parseIfBlock(_ lines: [String], start: Int) throws -> (Statement, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let headerTokens = tokenizeLine(header)
        var headerParser = LineParser(tokens: headerTokens, sourceLine: start + 1)
        let condition = try headerParser.parseIfHeaderCondition()

        var thenLines: [String] = []
        var elseLines: [String] = []
        var index = start + 1
        var inElse = false

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

            if upper == "ELSE" || upper.hasPrefix("ELSE ") || upper.hasPrefix("ELSEIF ") {
                inElse = true
                if upper.hasPrefix("ELSE ") {
                    let afterElse = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if !afterElse.isEmpty {
                        elseLines.append(String(afterElse))
                    }
                } else if upper.hasPrefix("ELSEIF ") {
                    elseLines.append(trimmed)
                }
                index += 1
                continue
            }

            if inElse {
                elseLines.append(trimmed)
            } else {
                thenLines.append(trimmed)
            }
            index += 1
        }

        let thenStatements = try parseStatementLines(thenLines, sourceLine: start + 2)
        let elseStatements = elseLines.isEmpty ? nil : try parseStatementLines(elseLines, sourceLine: start + 2)
        return (.ifStmt(condition, thenStatements, elseStatements), index - start)
    }

    private func parseSelectCaseBlock(
        _ lines: [String],
        start: Int
    ) throws -> (Statement, Int, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let headerTokens = tokenizeLine(header)
        var headerParser = LineParser(tokens: headerTokens, sourceLine: start + 1)
        let selector = try headerParser.parseSelectCaseHeader()

        var clauses: [CaseClause] = []
        var index = start + 1
        var currentCaseLines: [String] = []
        var currentCaseHeader: String?

        func flushCase() throws {
            guard let headerLine = currentCaseHeader else { return }
            let statements = try parseStatementLines(currentCaseLines, sourceLine: index)
            clauses.append(try parseCaseClause(header: headerLine, statements: statements))
            currentCaseHeader = nil
            currentCaseLines = []
        }

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
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
                index += 1
                continue
            }

            currentCaseLines.append(trimmed)
            index += 1
        }

        return (.selectCase(selector, clauses), index - start, start + 1)
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
            var parser = ExpressionParser(tokens: tokens)
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
        var parser = ExpressionParser(tokens: tokens)
        var values: [Expr] = []
        repeat {
            values.append(try parser.parseExpression())
        } while parser.takeCommaIfPresent()
        return values
    }

    private func parseStatementLines(_ lines: [String], sourceLine: Int) throws -> [Statement] {
        var statements: [Statement] = []
        for (offset, line) in lines.enumerated() {
            let tokens = tokenizeLine(line)
            var parser = LineParser(tokens: tokens, sourceLine: sourceLine + offset)
            repeat {
                statements.append(try parser.parseStatement())
            } while parser.takeColonIfPresent()
        }
        return statements
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

    init(tokens: [Token], sourceLine: Int) {
        self.tokens = tokens
        self.sourceLine = sourceLine
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
            return .print(try parsePrintList())
        }

        if case .keyword(.input) = token.kind {
            advance()
            return try parseInput()
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
            return .loop
        }

        if case .keyword(.exit) = token.kind {
            advance()
            if matchKeyword(.for) { return .exitFor }
            if matchKeyword(.do) { return .exitDo }
            if matchKeyword(.while) { return .exitWhile }
            throw QBError.syntax("EXIT must be followed by FOR, DO, or WHILE")
        }

        if case .keyword(.goto) = token.kind {
            advance()
            let target = try parseLineTarget()
            return .goto(target)
        }

        if case .keyword(.gosub) = token.kind {
            advance()
            let target = try parseLineTarget()
            return .gosub(target)
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

        if let lineNum = try tryOptionalLineTarget() {
            thenStatements = [.goto(lineNum)]
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
            if let lineNum = try tryOptionalLineTarget() {
                elseBody = [.goto(lineNum)]
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
            throw QBError.syntax("Expected array name in DIM")
        }
        advance()
        let (name, qbType) = splitTypeSuffix(rawName)
        try consume(.lparen, message: "Expected '(' after array name")
        var bounds: [Expr] = []
        repeat {
            bounds.append(try parseExpression())
        } while match(.comma)
        try consume(.rparen, message: "Expected ')' after DIM bounds")
        return .dim(name, qbType, bounds)
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
            return .onGoto(expr, try parseLineList())
        }
        if matchKeyword(.gosub) {
            return .onGosub(expr, try parseLineList())
        }
        throw QBError.syntax("Expected GOTO or GOSUB after ON")
    }

    private mutating func parseLineList() throws -> [Int] {
        var lines: [Int] = []
        repeat {
            lines.append(try parseLineTarget())
        } while match(.comma)
        return lines
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
                    items.append(.tab(nil))
                    _ = arg
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

    private mutating func parseAssignable() throws -> Expr {
        guard case .identifier(let rawName)? = peek()?.kind else {
            throw QBError.syntax("Expected variable name at line \(sourceLine)")
        }
        advance()
        let (name, qbType) = splitTypeSuffix(rawName)
        if match(.lparen) {
            var indices: [Expr] = []
            if !check(.rparen) {
                repeat {
                    indices.append(try parseExpression())
                } while match(.comma)
            }
            try consume(.rparen, message: "Expected ')' after array index")
            var expr: Expr = .variable(name, qbType)
            for index in indices {
                expr = .function("INDEX", [expr, index])
            }
            return expr
        }
        return .variable(name, qbType)
    }

    private mutating func parsePointStatement(preset: Bool) throws -> Statement {
        try consume(.lparen, message: "Expected '(' after PSET/PRESET")
        let x = try parseExpression()
        try consume(.comma, message: "Expected ','")
        let y = try parseExpression()
        var color: Expr?
        if match(.comma) {
            color = try parseExpression()
        }
        try consume(.rparen, message: "Expected ')'")
        return preset ? .preset(x, y, color) : .pset(x, y, color)
    }

    private mutating func parseLineStatement() throws -> Statement {
        var boxed = false
        if match(.lparen) {
            boxed = true
        }
        let x1 = try parseExpression()
        try consume(.comma, message: "Expected ',' in LINE")
        let y1 = try parseExpression()
        var x2: Expr?
        var y2: Expr?
        var color: Expr?
        if match(.minus) || matchKeyword(.to) {
            if !matchKeyword(.to) && !check(.lparen) {
                // handled minus
            }
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
            color = try parseExpression()
        }
        return .line(x1, y1, x2, y2, color, boxed)
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

    private mutating func parseLineTarget() throws -> Int {
        guard let token = peek() else {
            throw QBError.syntax("Expected line number")
        }
        if case .lineNumber(let num) = token.kind {
            advance()
            return num
        }
        if case .integer(let num) = token.kind {
            advance()
            return num
        }
        throw QBError.syntax("Expected line number, got \(token.kind)")
    }

    private mutating func tryOptionalLineTarget() throws -> Int? {
        guard let token = peek() else { return nil }
        switch token.kind {
        case .lineNumber(let num), .integer(let num):
            if case .integer = token.kind {
                if let next = tokens[safe: pos + 1], !isStatementStart(next) {
                    return nil
                }
            }
            advance()
            return num
        default:
            return nil
        }
    }

    private mutating func parseExpression() throws -> Expr {
        var parser = ExpressionParser(tokens: Array(tokens.dropFirst(pos)))
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

private func splitTypeSuffix(_ rawName: String) -> (String, QBType) {
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