import Foundation

public enum QBType: String, Sendable {
    case integer, long, single, double, string, variant
}

public indirect enum Expr: Sendable {
    case integer(Int)
    case float(Double)
    case string(String)
    case variable(String, QBType)
    case unary(UnaryOp, Expr)
    case binary(BinaryOp, Expr, Expr)
    case function(String, [Expr])
}

public enum UnaryOp: String, Sendable {
    case neg, not
}

public enum BinaryOp: String, Sendable {
    case add, sub, mul, div, intDiv, pow, mod
    case eq, ne, lt, le, gt, ge
    case and, or, xor, eqv, imp
}

public enum PrintItem: Sendable {
    case expression(Expr)
    case separator(Separator)
    case tab(Expr?)
    case spc(Int)
}

public enum Separator: Sendable {
    case semicolon, comma
}

public struct CaseClause: Sendable {
    public let values: [Expr]?
    public let isCompare: BinaryOp?
    public let compareValue: Expr?
    public let isElse: Bool
    public let statements: [Statement]

    public init(
        values: [Expr]? = nil,
        isCompare: BinaryOp? = nil,
        compareValue: Expr? = nil,
        isElse: Bool = false,
        statements: [Statement]
    ) {
        self.values = values
        self.isCompare = isCompare
        self.compareValue = compareValue
        self.isElse = isElse
        self.statements = statements
    }
}

public indirect enum Statement: Sendable {
    case rem(String)
    case print([PrintItem])
    case input([String], [Expr]?)
    case letStmt(Expr, Expr)
    case ifStmt(Expr, [Statement], [Statement]?)
    case forLoop(String, QBType, Expr, Expr, Expr?, [Statement])
    case next(String?)
    case whileLoop(Expr, [Statement])
    case wend
    case doLoop(DoMode, Expr?, [Statement])
    case loop(DoMode?)
    case exitFor, exitDo, exitWhile
    case goto(Int)
    case gosub(Int)
    case `return`
    case end, stop
    case dim(String, QBType, [Expr])
    case defType(QBType, String, String?)
    case data([Expr])
    case read([Expr])
    case restore(Expr?)
    case onGoto(Expr, [Int])
    case onGosub(Expr, [Int])
    case randomize(Expr?)
    case cls
    case screen(Expr, Expr?, Expr?)
    case color(Expr, Expr?, Expr?)
    case pset(Expr, Expr, Expr?)
    case preset(Expr, Expr, Expr?)
    case line(Expr, Expr, Expr?, Expr?, Expr?, Bool)
    case circle(Expr, Expr, Expr, Expr?, Expr?, Expr?)

    case beep
    case sleep(Expr)
    case assign(Expr, Expr)
    case selectCase(Expr, [CaseClause])
    case callProcedure(String, [Expr])
    case exitSub
    case exitFunction
}

public indirect enum DoMode: Sendable {
    case top, bottom
    case until(Expr)
    case `while`(Expr)
}

public struct ProgramLine: Sendable {
    public let lineNumber: Int?
    public let statements: [Statement]
    public let sourceLine: Int

    public init(lineNumber: Int?, statements: [Statement], sourceLine: Int) {
        self.lineNumber = lineNumber
        self.statements = statements
        self.sourceLine = sourceLine
    }
}

public struct ParsedProgram: Sendable {
    public let lines: [ProgramLine]
    public let lineIndex: [Int: Int]
    public let procedures: [String: ProcedureDef]

    public init(lines: [ProgramLine], procedures: [String: ProcedureDef] = [:]) {
        self.lines = lines
        self.procedures = procedures
        var index: [Int: Int] = [:]
        for (i, line) in lines.enumerated() {
            if let num = line.lineNumber {
                index[num] = i
            }
        }
        self.lineIndex = index
    }
}