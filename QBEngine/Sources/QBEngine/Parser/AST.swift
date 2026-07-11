import Foundation

public enum QBType: Sendable, Equatable, Hashable {
    case integer, long, single, double, string, variant
    case userType(String)
}

public enum JumpTarget: Sendable, Equatable {
    case lineNumber(Int)
    case label(String)
}

public indirect enum Expr: Sendable {
    case integer(Int)
    case float(Double)
    case string(String)
    case variable(String, QBType)
    case fieldAccess(Expr, String)
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
    case using(format: String, values: [Expr])
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

public struct TypeField: Sendable, Equatable {
    public let name: String
    public let type: QBType

    public init(name: String, type: QBType) {
        self.name = name.uppercased()
        self.type = type
    }
}

public struct TypeDef: Sendable, Equatable {
    public let name: String
    public let fields: [TypeField]

    public init(name: String, fields: [TypeField]) {
        self.name = name.uppercased()
        self.fields = fields
    }
}

public enum LineBoxStyle: Sendable, Equatable {
    case none
    case box
    case filled
}

public enum FileMode: String, Sendable {
    case input, output, append, random
}

public indirect enum Statement: Sendable {
    case rem(String)
    case print([PrintItem])
    case printUsing(String, [Expr])
    case input([String], [Expr]?)
    case lineInput(String?, Expr)
    case letStmt(Expr, Expr)
    case ifStmt(Expr, [Statement], [Statement]?)
    case forLoop(String, QBType, Expr, Expr, Expr?, [Statement])
    case next(String?)
    case whileLoop(Expr, [Statement])
    case wend
    case doLoop(DoMode, Expr?, [Statement])
    case loop(DoMode?)
    case exitFor, exitDo, exitWhile
    case goto(JumpTarget)
    case gosub(JumpTarget)
    case `return`
    case end, stop
    case dim(String, QBType, [Expr])
    case dimAs(String, QBType, [Expr])
    case defType(QBType, String, String?)
    case data([Expr])
    case read([Expr])
    case restore(Expr?)
    case onGoto(Expr, [JumpTarget])
    case onGosub(Expr, [JumpTarget])
    case randomize(Expr?)
    case cls
    case screen(Expr, Expr?, Expr?)
    case color(Expr, Expr?, Expr?)
    case locate(Expr, Expr?)
    case pset(Expr, Expr, Expr?)
    case preset(Expr, Expr, Expr?)
    case line(Expr, Expr, Expr?, Expr?, Expr?, LineBoxStyle)
    case circle(Expr, Expr, Expr, Expr?, Expr?, Expr?)
    case paint(Expr, Expr, Expr?, Expr?)
    case draw(Expr)
    case getSprite(Expr, Expr, Expr, Expr, String)
    case putSprite(Expr, Expr, String)
    case constDecl([(String, QBType, Expr)])
    case swap(Expr, Expr)
    case optionBase(Int)
    case label(String)
    case midAssign(Expr, Expr, Expr?, Expr)
    case open(String, FileMode, Int)
    case close([Int]?)
    case printHash(Int, [PrintItem])
    case inputHash(Int, [Expr])
    case lineInputHash(Int, Expr)
    case shared([String])
    case `static`([String])
    case declare(String, ProcedureKind)
    case typeDef(TypeDef)
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
    public let labelIndex: [String: Int]
    public let procedures: [String: ProcedureDef]
    public let typeDefs: [String: TypeDef]

    public init(
        lines: [ProgramLine],
        procedures: [String: ProcedureDef] = [:],
        typeDefs: [String: TypeDef] = [:]
    ) {
        self.lines = lines
        self.procedures = procedures
        self.typeDefs = typeDefs
        var index: [Int: Int] = [:]
        var labels: [String: Int] = [:]
        for (i, line) in lines.enumerated() {
            if let num = line.lineNumber {
                index[num] = i
            }
            for statement in line.statements {
                if case .label(let name) = statement {
                    labels[name.uppercased()] = i
                }
            }
        }
        self.lineIndex = index
        self.labelIndex = labels
    }
}
