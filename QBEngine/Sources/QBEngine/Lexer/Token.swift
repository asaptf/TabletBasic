import Foundation

public enum TokenKind: Equatable, Sendable {
    case integer(Int)
    case float(Double)
    case string(String)
    case identifier(String)
    case keyword(Keyword)
    case lineNumber(Int)
    case typeSuffix(TypeSuffix)
    case plus, minus, asterisk, slash, backslash, caret
    case assign
    case lparen, rparen, comma, colon, semicolon, dot
    case equals, notEquals, less, greater, lessEquals, greaterEquals
    case newline
    case eof
    case error(String)
}

public enum TypeSuffix: String, Sendable {
    case integer = "%"
    case long = "&"
    case single = "!"
    case double = "#"
    case string = "$"
}

public struct Keyword: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let abs = Keyword(rawValue: "abs")
    public static let and = Keyword(rawValue: "and")
    public static let append = Keyword(rawValue: "append")
    public static let `as` = Keyword(rawValue: "as")
    public static let beep = Keyword(rawValue: "beep")
    public static let bload = Keyword(rawValue: "bload")
    public static let bsave = Keyword(rawValue: "bsave")
    public static let call = Keyword(rawValue: "call")
    public static let `case` = Keyword(rawValue: "case")
    public static let cdate = Keyword(rawValue: "cdate")
    public static let chr = Keyword(rawValue: "chr")
    public static let circle = Keyword(rawValue: "circle")
    public static let cls = Keyword(rawValue: "cls")
    public static let color = Keyword(rawValue: "color")
    public static let const = Keyword(rawValue: "const")
    public static let cos = Keyword(rawValue: "cos")
    public static let data = Keyword(rawValue: "data")
    public static let date = Keyword(rawValue: "date")
    public static let declare = Keyword(rawValue: "declare")
    public static let def = Keyword(rawValue: "def")
    public static let defdbl = Keyword(rawValue: "defdbl")
    public static let defint = Keyword(rawValue: "defint")
    public static let deflng = Keyword(rawValue: "deflng")
    public static let defsng = Keyword(rawValue: "defsng")
    public static let defstr = Keyword(rawValue: "defstr")
    public static let dim = Keyword(rawValue: "dim")
    public static let `do` = Keyword(rawValue: "do")
    public static let double = Keyword(rawValue: "double")
    public static let draw = Keyword(rawValue: "draw")
    public static let `else` = Keyword(rawValue: "else")
    public static let elseif = Keyword(rawValue: "elseif")
    public static let end = Keyword(rawValue: "end")
    public static let eqv = Keyword(rawValue: "eqv")
    public static let erase = Keyword(rawValue: "erase")
    public static let exit = Keyword(rawValue: "exit")
    public static let exp = Keyword(rawValue: "exp")
    public static let field = Keyword(rawValue: "field")
    public static let `for` = Keyword(rawValue: "for")
    public static let function = Keyword(rawValue: "function")
    public static let get = Keyword(rawValue: "get")
    public static let gosub = Keyword(rawValue: "gosub")
    public static let goto = Keyword(rawValue: "goto")
    public static let `if` = Keyword(rawValue: "if")
    public static let imp = Keyword(rawValue: "imp")
    public static let inkey = Keyword(rawValue: "inkey")
    public static let input = Keyword(rawValue: "input")
    public static let instr = Keyword(rawValue: "instr")
    public static let int = Keyword(rawValue: "int")
    public static let integer = Keyword(rawValue: "integer")
    public static let left = Keyword(rawValue: "left")
    public static let len = Keyword(rawValue: "len")
    public static let `let` = Keyword(rawValue: "let")
    public static let line = Keyword(rawValue: "line")
    public static let loc = Keyword(rawValue: "loc")
    public static let log = Keyword(rawValue: "log")
    public static let long = Keyword(rawValue: "long")
    public static let loop = Keyword(rawValue: "loop")
    public static let lset = Keyword(rawValue: "lset")
    public static let mid = Keyword(rawValue: "mid")
    public static let mod = Keyword(rawValue: "mod")
    public static let next = Keyword(rawValue: "next")
    public static let not = Keyword(rawValue: "not")
    public static let on = Keyword(rawValue: "on")
    public static let open = Keyword(rawValue: "open")
    public static let option = Keyword(rawValue: "option")
    public static let or = Keyword(rawValue: "or")
    public static let paint = Keyword(rawValue: "paint")
    public static let pcopy = Keyword(rawValue: "pcopy")
    public static let peek = Keyword(rawValue: "peek")
    public static let poke = Keyword(rawValue: "poke")
    public static let preset = Keyword(rawValue: "preset")
    public static let print = Keyword(rawValue: "print")
    public static let pset = Keyword(rawValue: "pset")
    public static let put = Keyword(rawValue: "put")
    public static let randomize = Keyword(rawValue: "randomize")
    public static let read = Keyword(rawValue: "read")
    public static let redim = Keyword(rawValue: "redim")
    public static let rem = Keyword(rawValue: "rem")
    public static let restore = Keyword(rawValue: "restore")
    public static let `return` = Keyword(rawValue: "return")
    public static let right = Keyword(rawValue: "right")
    public static let rset = Keyword(rawValue: "rset")
    public static let rnd = Keyword(rawValue: "rnd")
    public static let select = Keyword(rawValue: "select")
    public static let screen = Keyword(rawValue: "screen")
    public static let lcase = Keyword(rawValue: "lcase")
    public static let seek = Keyword(rawValue: "seek")
    public static let sgn = Keyword(rawValue: "sgn")
    public static let shared = Keyword(rawValue: "shared")
    public static let sin = Keyword(rawValue: "sin")
    public static let single = Keyword(rawValue: "single")
    public static let sleep = Keyword(rawValue: "sleep")
    public static let sng = Keyword(rawValue: "sng")
    public static let sound = Keyword(rawValue: "sound")
    public static let space = Keyword(rawValue: "space")
    public static let spc = Keyword(rawValue: "spc")
    public static let sqr = Keyword(rawValue: "sqr")
    public static let `static` = Keyword(rawValue: "static")
    public static let step = Keyword(rawValue: "step")
    public static let stop = Keyword(rawValue: "stop")
    public static let str = Keyword(rawValue: "str")
    public static let string = Keyword(rawValue: "string")
    public static let sub = Keyword(rawValue: "sub")
    public static let swap = Keyword(rawValue: "swap")
    public static let tab = Keyword(rawValue: "tab")
    public static let tan = Keyword(rawValue: "tan")
    public static let then = Keyword(rawValue: "then")
    public static let time = Keyword(rawValue: "time")
    public static let to = Keyword(rawValue: "to")
    public static let ubound = Keyword(rawValue: "ubound")
    public static let ucase = Keyword(rawValue: "ucase")
    public static let until = Keyword(rawValue: "until")
    public static let val = Keyword(rawValue: "val")
    public static let varptr = Keyword(rawValue: "varptr")
    public static let view = Keyword(rawValue: "view")
    public static let wend = Keyword(rawValue: "wend")
    public static let `while` = Keyword(rawValue: "while")
    public static let width = Keyword(rawValue: "width")
    public static let write = Keyword(rawValue: "write")
    public static let xor = Keyword(rawValue: "xor")

    public static let all: [Keyword] = [
        .abs, .and, .append, .as, .beep, .bload, .bsave, .call, .case, .cdate, .chr, .circle,
        .cls, .color, .const, .cos, .data, .date, .declare, .def, .defdbl, .defint, .deflng,
        .defsng, .defstr, .dim, .do, .double, .draw, .else, .elseif, .end, .eqv, .erase,
        .exit, .exp, .field, .for, .function, .get, .gosub, .goto, .if, .imp, .inkey, .input,
        .instr, .int, .integer, .left, .len, .let, .line, .loc, .log, .long, .loop, .lset,
        .mid, .mod, .next, .not, .on, .open, .option, .or, .paint, .pcopy, .peek, .poke,
        .preset, .print, .pset, .put, .randomize, .read, .redim, .rem, .restore, .return,
        .right, .rset, .rnd, .select, .screen, .seek, .sgn, .shared, .sin, .single, .sleep, .sng,
        .sound, .space, .spc, .sqr, .static, .step, .stop, .str, .string, .sub, .swap,
        .tab, .tan, .then, .time, .to, .ubound, .ucase, .lcase, .until, .val, .varptr, .view,
        .wend, .while, .width, .write, .xor
    ]

    public static let lookup: [String: Keyword] = {
        var map: [String: Keyword] = [:]
        for kw in all {
            map[kw.rawValue] = kw
        }
        return map
    }()
}

public struct Token: Equatable, Sendable {
    public let kind: TokenKind
    public let line: Int
    public let column: Int

    public init(kind: TokenKind, line: Int, column: Int) {
        self.kind = kind
        self.line = line
        self.column = column
    }
}