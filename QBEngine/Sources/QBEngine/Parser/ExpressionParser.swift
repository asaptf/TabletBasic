import Foundation

public struct ExpressionParser {
    private var tokens: [Token]
    var pos: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens.filter { token in
            if case .newline = token.kind { return false }
            return true
        }
    }

    public mutating func parseExpression() throws -> Expr {
        try parseImp()
    }

    private mutating func parseImp() throws -> Expr {
        var left = try parseEqv()
        while matchKeyword(.imp) {
            let right = try parseEqv()
            left = .binary(.imp, left, right)
        }
        return left
    }

    private mutating func parseEqv() throws -> Expr {
        var left = try parseXor()
        while matchKeyword(.xor) || matchKeyword(.eqv) {
            let op: BinaryOp = previousKeyword() == .eqv ? .eqv : .xor
            let right = try parseXor()
            left = .binary(op, left, right)
        }
        return left
    }

    private mutating func parseXor() throws -> Expr {
        var left = try parseOr()
        while matchKeyword(.xor) {
            let right = try parseOr()
            left = .binary(.xor, left, right)
        }
        return left
    }

    private mutating func parseOr() throws -> Expr {
        var left = try parseAnd()
        while matchKeyword(.or) {
            let right = try parseAnd()
            left = .binary(.or, left, right)
        }
        return left
    }

    private mutating func parseAnd() throws -> Expr {
        var left = try parseNot()
        while matchKeyword(.and) {
            let right = try parseNot()
            left = .binary(.and, left, right)
        }
        return left
    }

    private mutating func parseNot() throws -> Expr {
        if matchKeyword(.not) {
            return .unary(.not, try parseNot())
        }
        return try parseComparison()
    }

    private mutating func parseComparison() throws -> Expr {
        var left = try parseAddSub()
        while true {
            if match(.equals) {
                left = .binary(.eq, left, try parseAddSub())
            } else if match(.notEquals) {
                left = .binary(.ne, left, try parseAddSub())
            } else if match(.less) {
                left = .binary(.lt, left, try parseAddSub())
            } else if match(.lessEquals) {
                left = .binary(.le, left, try parseAddSub())
            } else if match(.greater) {
                left = .binary(.gt, left, try parseAddSub())
            } else if match(.greaterEquals) {
                left = .binary(.ge, left, try parseAddSub())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseAddSub() throws -> Expr {
        var left = try parseMulDiv()
        while true {
            if match(.plus) {
                left = .binary(.add, left, try parseMulDiv())
            } else if match(.minus) {
                left = .binary(.sub, left, try parseMulDiv())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseMulDiv() throws -> Expr {
        var left = try parsePower()
        while true {
            if match(.asterisk) {
                left = .binary(.mul, left, try parsePower())
            } else if match(.slash) {
                left = .binary(.div, left, try parsePower())
            } else if match(.backslash) {
                left = .binary(.intDiv, left, try parsePower())
            } else if matchKeyword(.mod) {
                left = .binary(.mod, left, try parsePower())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parsePower() throws -> Expr {
        var left = try parseUnary()
        if match(.caret) {
            let right = try parsePower()
            left = .binary(.pow, left, right)
        }
        return left
    }

    private mutating func parseUnary() throws -> Expr {
        if match(.plus) {
            return try parseUnary()
        }
        if match(.minus) {
            return .unary(.neg, try parseUnary())
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> Expr {
        if match(.lparen) {
            let expr = try parseExpression()
            try consume(.rparen, message: "Expected ')'")
            return expr
        }

        if let token = peek() {
            switch token.kind {
            case .integer(let value):
                advance()
                return .integer(value)
            case .float(let value):
                advance()
                return .float(value)
            case .string(let value):
                advance()
                return .string(value)
            case .identifier(let rawName):
                advance()
                let (name, qbType) = splitTypeSuffix(rawName)
                if match(.lparen) {
                    if qbType != .variant && !Self.builtinFunctions.contains(name.uppercased()) {
                        return try parseArrayAccess(name: name, type: qbType)
                    }
                    return .function(name, try parseArgumentList())
                }
                return .variable(name, qbType)
            case .keyword(let keyword):
                advance()
                if match(.lparen) {
                    return .function(keyword.rawValue.uppercased(), try parseArgumentList())
                }
                if Self.zeroArgFunctions.contains(keyword) {
                    return .function(keyword.rawValue.uppercased(), [])
                }
                throw QBError.syntax("Unexpected keyword '\(keyword.rawValue)' in expression at \(currentPosition())")
            default:
                break
            }
        }

        throw QBError.syntax("Unexpected token in expression at \(currentPosition())")
    }

    private mutating func parseArrayAccess(name: String, type: QBType) throws -> Expr {
        var indices: [Expr] = []
        if !check(.rparen) {
            repeat {
                indices.append(try parseExpression())
            } while match(.comma)
        }
        try consume(.rparen, message: "Expected ')' after array index")
        var expr: Expr = .variable(name, type)
        for index in indices {
            expr = .function("INDEX", [expr, index])
        }
        return expr
    }

    private mutating func parseArgumentList() throws -> [Expr] {
        var args: [Expr] = []
        if !check(.rparen) {
            repeat {
                args.append(try parseExpression())
            } while match(.comma)
        }
        try consume(.rparen, message: "Expected ')' after arguments")
        return args
    }

    private static let zeroArgFunctions: Set<Keyword> = [
        .rnd, .inkey
    ]

    private static let builtinFunctions: Set<String> = [
        "ABS", "ASC", "ATN", "CHR", "CHR$", "CINT", "CDBL", "CSNG", "CLNG",
        "COS", "EXP", "FIX", "HEX$", "INKEY$", "INSTR", "INT", "LCASE", "LCASE$",
        "LEFT", "LEFT$", "LEN", "LOG", "MID", "MID$", "OCT$", "RIGHT", "RIGHT$",
        "RND", "SGN", "SIN", "SQR", "STR", "STR$", "STRING", "STRING$",
        "TAN", "UCASE", "UCASE$", "VAL"
    ]

    mutating func takeCommaIfPresent() -> Bool {
        match(.comma)
    }

    mutating func parseCaseIsComparison() throws -> (BinaryOp, Expr, Int) {
        let startPos = pos
        if match(.less) {
            if match(.equals) {
                return (.le, try parseExpression(), pos)
            }
            if match(.greater) {
                return (.ne, try parseExpression(), pos)
            }
            return (.lt, try parseExpression(), pos)
        }
        if match(.greater) {
            if match(.equals) {
                return (.ge, try parseExpression(), pos)
            }
            return (.gt, try parseExpression(), pos)
        }
        if match(.equals) {
            return (.eq, try parseExpression(), pos)
        }
        if matchKeyword(.not) {
            if match(.less) {
                if match(.greater) {
                    return (.ne, try parseExpression(), pos)
                }
            }
        }
        pos = startPos
        throw QBError.syntax("Expected comparison operator after CASE IS")
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

    private func peek() -> Token? {
        guard pos < tokens.count else { return nil }
        return tokens[pos]
    }

    private mutating func advance() {
        if pos < tokens.count { pos += 1 }
    }

    private mutating func match(_ kind: (Token) -> Bool) -> Bool {
        guard let token = peek(), kind(token) else { return false }
        advance()
        return true
    }

    private mutating func match(_ expected: (TokenKind) -> Bool) -> Bool {
        guard let token = peek(), expected(token.kind) else { return false }
        advance()
        return true
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
            throw QBError.syntax("\(message) at \(currentPosition())")
        }
    }

    private func check(_ kind: TokenKind) -> Bool {
        peek()?.kind == kind
    }

    private var lastKeyword: Keyword?
    private func previousKeyword() -> Keyword { lastKeyword ?? .and }

    private func currentPosition() -> String {
        if let token = peek() {
            return "line \(token.line), column \(token.column)"
        }
        return "end of input"
    }
}