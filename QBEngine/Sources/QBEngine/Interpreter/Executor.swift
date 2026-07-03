import Foundation

public final class Executor: @unchecked Sendable {
    private let environment = Environment()
    public let screen = ScreenBuffer()
    public weak var output: QBOutputHandler?
    public var input: QBInputHandler?

    private var returnStack: [Int] = []
    private var forStack: [ForFrame] = []
    private var whileStack: [Int] = []
    private var doStack: [DoFrame] = []
    private var procedures: [String: ProcedureDef] = [:]
    private var activeFunctionName: String?
    private var functionReturnValue: QBValue?

    public init() {}

    public func execute(program: ParsedProgram) async throws {
        procedures = program.procedures
        try await preloadData(from: program)
        var pc = 0
        while pc < program.lines.count {
            let line = program.lines[pc]
            do {
                let jump = try await executeLine(line, program: program, at: pc)
                if let jump {
                    if jump == -1 { return }
                    if let nextPC = resolveJump(jump, in: program) {
                        pc = nextPC
                        continue
                    }
                    throw QBError.runtime("Line \(jump) not found")
                }
                pc += 1
            } catch QBError.endProgram, QBError.stopProgram {
                return
            } catch QBError.breakLoop {
                pc = try skipToNext(program: program, from: pc, keyword: .next)
            } catch QBError.breakDo {
                pc = try skipToNext(program: program, from: pc, keyword: .loop)
            } catch QBError.breakWhile {
                pc = try skipToNext(program: program, from: pc, keyword: .wend)
            }
        }
    }

    private func executeLine(_ line: ProgramLine, program: ParsedProgram, at pc: Int) async throws -> Int? {
        for statement in line.statements {
            if let jump = try await executeStatement(statement, program: program, at: pc) {
                return jump
            }
        }
        return nil
    }

    private func executeStatement(_ statement: Statement, program: ParsedProgram, at pc: Int) async throws -> Int? {
        switch statement {
        case .rem:
            return nil
        case .print(let items):
            try await executePrint(items)
        case .input(let prompts, let vars):
            try await executeInput(prompts: prompts, variables: vars)
        case .letStmt(let target, let value), .assign(let target, let value):
            try await assign(target, value: try await evaluate(value))
        case .ifStmt(let condition, let thenBranch, let elseBranch):
            if try await evaluate(condition).asBool {
                return try await executeBlock(thenBranch, program: program, at: pc)
            } else if let elseBranch {
                return try await executeBlock(elseBranch, program: program, at: pc)
            }
        case .forLoop(let name, let type, let start, let end, let step, _):
            let startVal = try await evaluate(start).asDouble
            let endVal = try await evaluate(end).asDouble
            let stepVal: Double
            if let step {
                stepVal = try await evaluate(step).asDouble
            } else {
                stepVal = 1
            }
            try environment.setVariable(name, value: QBValue.from(startVal, type: type), type: type)
            forStack.append(ForFrame(name: name, type: type, end: endVal, step: stepVal, linePC: pc))
        case .next(let name):
            guard var frame = forStack.popLast() else {
                throw QBError.runtime("NEXT without FOR")
            }
            if let name, name != frame.name {
                forStack.append(frame)
                throw QBError.runtime("NEXT variable mismatch")
            }
            let current = try environment.getVariable(frame.name).asDouble
            let next = current + frame.step
            let shouldContinue = frame.step > 0 ? next <= frame.end : next >= frame.end
            if shouldContinue {
                try environment.setVariable(frame.name, value: QBValue.from(next, type: frame.type), type: frame.type)
                forStack.append(frame)
                let nextPC = frame.linePC + 1
                if nextPC < program.lines.count {
                    return program.lines[nextPC].lineNumber ?? nextPC
                }
            }
        case .whileLoop(let condition, _):
            if try await evaluate(condition).asBool {
                whileStack.append(pc)
            } else {
                return try skipWhileEnd(program: program, from: pc)
            }
        case .wend:
            guard let startPC = whileStack.popLast() else {
                throw QBError.runtime("WEND without WHILE")
            }
            let startLine = program.lines[startPC]
            if case .whileLoop(let condition, _) = startLine.statements.first {
                if try await evaluate(condition).asBool {
                    whileStack.append(startPC)
                    return startLine.lineNumber ?? startPC
                }
            }
        case .doLoop(let mode, _, _):
            doStack.append(DoFrame(mode: mode, linePC: pc))
            if case .until(let expr) = mode {
                if try await evaluate(expr).asBool {
                    return try skipToNext(program: program, from: pc, keyword: .loop)
                }
            }
            if case .while(let expr) = mode {
                let whileReady = try await evaluate(expr).asBool
                if !whileReady {
                    return try skipToNext(program: program, from: pc, keyword: .loop)
                }
            }
        case .loop(let bottomMode):
            guard let frame = doStack.popLast() else {
                throw QBError.runtime("LOOP without DO")
            }
            let startLine = program.lines[frame.linePC]
            let startTarget = startLine.lineNumber ?? frame.linePC
            let continueLoop: Bool
            if let bottomMode {
                switch bottomMode {
                case .until(let expr):
                    continueLoop = !(try await evaluate(expr).asBool)
                case .while(let expr):
                    continueLoop = try await evaluate(expr).asBool
                case .top, .bottom:
                    continueLoop = true
                }
            } else if case .doLoop(let doMode, _, _) = startLine.statements.first {
                switch doMode {
                case .until(let expr):
                    continueLoop = !(try await evaluate(expr).asBool)
                case .while(let expr):
                    continueLoop = try await evaluate(expr).asBool
                case .top, .bottom:
                    continueLoop = true
                }
            } else {
                continueLoop = true
            }
            if continueLoop {
                doStack.append(frame)
                return startTarget
            }
        case .exitFor:
            throw QBError.breakLoop
        case .exitDo:
            _ = doStack.popLast()
            throw QBError.breakDo
        case .exitWhile:
            _ = whileStack.popLast()
            throw QBError.breakWhile
        case .goto(let line):
            return line
        case .gosub(let line):
            returnStack.append(pc + 1)
            return line
        case .return:
            guard let returnPC = returnStack.popLast() else {
                throw QBError.runtime("RETURN without GOSUB")
            }
            if returnPC < program.lines.count {
                return program.lines[returnPC].lineNumber ?? returnPC
            }
        case .end:
            throw QBError.endProgram
        case .stop:
            throw QBError.stopProgram
        case .dim(let name, let type, let bounds):
            var parsedBounds: [Int] = []
            for bound in bounds {
                let upper = try await evaluate(bound).asInt
                parsedBounds.append(1)
                parsedBounds.append(upper)
            }
            try environment.dimension(name, type: type, bounds: parsedBounds)
        case .defType(let type, let start, let end):
            let startChar = Character(start)
            let endChar = Character(end ?? start)
            environment.setDefaultType(type, from: startChar, to: endChar)
        case .data:
            return nil
        case .read(let vars):
            for variable in vars {
                let value = try environment.readNext()
                try await assign(variable, value: value)
            }
        case .restore(let line):
            if let line {
                environment.restoreToLine(try await evaluate(line).asInt)
            } else {
                environment.restore(pointer: 0)
            }
        case .onGoto(let expr, let lines):
            let index = try await evaluate(expr).asInt
            if index >= 1 && index <= lines.count {
                return lines[index - 1]
            }
        case .onGosub(let expr, let lines):
            let index = try await evaluate(expr).asInt
            if index >= 1 && index <= lines.count {
                returnStack.append(pc + 1)
                return lines[index - 1]
            }
        case .randomize(let seed):
            if let seed {
                environment.seedRandom(try await evaluate(seed).asInt)
            } else {
                environment.seedRandom()
            }
        case .cls:
            screen.cls()
        case .screen(let mode, let color, let ap):
            let modeVal = try await evaluate(mode).asInt
            let colorVal: Int
            if let color {
                colorVal = try await evaluate(color).asInt
            } else {
                colorVal = 0
            }
            let apVal: Int
            if let ap {
                apVal = try await evaluate(ap).asInt
            } else {
                apVal = 0
            }
            screen.setScreen(modeValue: modeVal, colorSwitch: colorVal, ap: apVal)
        case .color(let fg, let bg, _):
            let fgVal = try await evaluate(fg).asInt
            let bgVal: Int?
            if let bg {
                bgVal = try await evaluate(bg).asInt
            } else {
                bgVal = nil
            }
            screen.setColor(foreground: fgVal, background: bgVal)
        case .pset(let x, let y, let color):
            let px = try await evaluate(x).asInt
            let py = try await evaluate(y).asInt
            let c: Int
            if let color {
                c = try await evaluate(color).asInt
            } else {
                c = screen.foreground
            }
            screen.pset(x: px, y: py, colorIndex: c)
        case .preset(let x, let y, let color):
            let px = try await evaluate(x).asInt
            let py = try await evaluate(y).asInt
            let c: Int
            if let color {
                c = try await evaluate(color).asInt
            } else {
                c = screen.background
            }
            screen.preset(x: px, y: py, colorIndex: c)
        case .line(let x1, let y1, let x2, let y2, let color, let boxed):
            let fx = try await evaluate(x1).asInt
            let fy = try await evaluate(y1).asInt
            let c: Int
            if let color {
                c = try await evaluate(color).asInt
            } else {
                c = screen.foreground
            }
            if let x2, let y2 {
                let tx = try await evaluate(x2).asInt
                let ty = try await evaluate(y2).asInt
                screen.drawLine(x1: fx, y1: fy, x2: tx, y2: ty, colorIndex: c, boxed: boxed)
            }
        case .circle(let x, let y, let radius, let color, _, _):
            let cx = try await evaluate(x).asInt
            let cy = try await evaluate(y).asInt
            let r = try await evaluate(radius).asInt
            let c: Int
            if let color {
                c = try await evaluate(color).asInt
            } else {
                c = screen.foreground
            }
            screen.drawCircle(cx: cx, cy: cy, radius: r, colorIndex: c)
        case .selectCase(let expr, let clauses):
            let value = try await evaluate(expr)
            for clause in clauses {
                if try await clauseMatches(clause, value: value) {
                    if let jump = try await executeBlock(clause.statements, program: program, at: pc) {
                        return jump
                    }
                    break
                }
            }
        case .beep:
            output?.beep()
        case .sleep(let duration):
            let seconds = try await evaluate(duration).asDouble
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        case .callProcedure(let name, let args):
            try await invokeProcedure(name, args: args)
        case .exitSub:
            throw QBError.exitSub
        case .exitFunction:
            throw QBError.exitFunction
        }
        return nil
    }

    private func invokeProcedure(_ name: String, args: [Expr]) async throws {
        guard let proc = procedures[name.uppercased()] else {
            throw QBError.runtime("Unknown procedure \(name)")
        }
        if proc.kind == .function {
            _ = try await runUserFunction(proc, args: args)
            return
        }
        try await runProcedureBody(proc, args: args)
    }

    private func runUserFunction(_ proc: ProcedureDef, args: [Expr]) async throws -> QBValue {
        functionReturnValue = nil
        activeFunctionName = proc.name
        defer { activeFunctionName = nil }
        try await runProcedureBody(proc, args: args)
        if let ret = functionReturnValue {
            return ret
        }
        return defaultQBValue(for: proc.returnType)
    }

    private func runProcedureBody(_ proc: ProcedureDef, args: [Expr]) async throws {
        environment.pushScope()
        defer { environment.popScope() }
        try await bindProcedureArgs(proc.params, args: args)

        let context = ParsedProgram(lines: [], procedures: procedures)
        do {
            for line in proc.body {
                if let jump = try await executeLine(line, program: context, at: 0) {
                    if jump == -1 { return }
                }
            }
        } catch QBError.exitSub where proc.kind == .sub {
            return
        } catch QBError.exitFunction where proc.kind == .function {
            return
        }
    }

    private func bindProcedureArgs(_ params: [ProcedureParam], args: [Expr]) async throws {
        guard params.count == args.count else {
            throw QBError.runtime("Argument count mismatch: expected \(params.count), got \(args.count)")
        }
        for (param, arg) in zip(params, args) {
            if case .variable(let varName, _) = arg {
                environment.bindParameter(name: param.name, type: param.type, aliasTo: varName)
            } else {
                let value = try await evaluate(arg)
                environment.bindParameter(name: param.name, type: param.type, value: value)
            }
        }
    }

    private func executeBlock(_ statements: [Statement], program: ParsedProgram, at pc: Int) async throws -> Int? {
        for statement in statements {
            if let jump = try await executeStatement(statement, program: program, at: pc) {
                return jump
            }
        }
        return nil
    }

    private func executePrint(_ items: [PrintItem]) async throws {
        var line = ""
        var needNewColumn = false
        var currentCol = screen.cursorCol

        for item in items {
            switch item {
            case .expression(let expr):
                line += formatPrintValue(try await evaluate(expr))
                needNewColumn = false
            case .separator(.semicolon):
                needNewColumn = true
            case .separator(.comma):
                let zone = 14 - ((currentCol - 1) % 14)
                line += String(repeating: " ", count: max(1, zone))
                currentCol += zone
                needNewColumn = true
            case .tab(let columnExpr):
                if let columnExpr {
                    let targetCol = max(1, min(try await evaluate(columnExpr).asInt, screen.textCols))
                    if currentCol > targetCol {
                        line += "\n"
                        currentCol = 1
                    }
                    let spaces = max(0, targetCol - currentCol)
                    line += String(repeating: " ", count: spaces)
                    currentCol = targetCol
                } else {
                    let zone = 14 - ((currentCol - 1) % 14)
                    line += String(repeating: " ", count: max(1, zone))
                    currentCol += zone
                }
            case .spc(let count):
                line += String(repeating: " ", count: max(0, count))
                currentCol += count
            }
            currentCol = screen.cursorCol + line.count
        }

        let advanceLine = !needNewColumn && !items.isEmpty
        output?.write(line)
        screen.writeText(line + (advanceLine ? "\n" : ""), advanceLine: advanceLine)
        if advanceLine {
            output?.write("\n")
        }
    }

    private func executeInput(prompts: [String], variables: [Expr]?) async throws {
        for prompt in prompts {
            output?.write(prompt)
        }
        guard let variables else { return }
        for variable in variables {
            let response = try await input?.prompt(prompts.last ?? "? ") ?? ""
            try await assign(variable, value: inputValue(response, for: variable))
        }
    }

    private func inputValue(_ response: String, for variable: Expr) -> QBValue {
        guard case .variable(_, let type) = variable else {
            return .string(response)
        }
        switch type {
        case .string:
            return .string(response)
        case .integer:
            return .integer(Int(response.trimmingCharacters(in: .whitespaces)) ?? 0)
        case .long:
            return .long(Int(response.trimmingCharacters(in: .whitespaces)) ?? 0)
        case .single, .double, .variant:
            let trimmed = response.trimmingCharacters(in: .whitespaces)
            if let value = Double(trimmed) {
                return QBValue.from(value, type: type)
            }
            return QBValue.from(0, type: type)
        }
    }

    private func assign(_ target: Expr, value: QBValue) async throws {
        switch target {
        case .variable(let name, let type):
            if let active = activeFunctionName, name == active {
                functionReturnValue = value
                return
            }
            try environment.setVariable(name, value: value, type: type)
        case .function("INDEX", _):
            let access = try resolveArrayAccess(target)
            let indices = try await evaluateIndices(access.indices)
            try environment.setArray(access.name, indices: indices, value: value, type: access.type)
        default:
            throw QBError.runtime("Invalid assignment target")
        }
    }

    private func resolveArrayAccess(_ expr: Expr) throws -> (name: String, type: QBType, indices: [Expr]) {
        switch expr {
        case .function("INDEX", let args) where args.count == 2:
            let inner = try resolveArrayAccess(args[0])
            return (inner.name, inner.type, inner.indices + [args[1]])
        case .variable(let name, let type):
            return (name, type, [])
        default:
            throw QBError.runtime("Invalid array access")
        }
    }

    public func evaluate(_ expr: Expr) async throws -> QBValue {
        switch expr {
        case .integer(let v): return .integer(v)
        case .float(let v): return .single(v)
        case .string(let v): return .string(v)
        case .variable(let name, _):
            return try environment.getVariable(name)
        case .unary(let op, let rhs):
            let value = try await evaluate(rhs)
            switch op {
            case .neg: return QBValue.from(-value.asDouble, type: .variant)
            case .not: return .bool(!value.asBool)
            }
        case .binary(let op, let lhs, let rhs):
            return try await evaluateBinary(op, lhs: lhs, rhs: rhs)
        case .function(let name, let args):
            return try await evaluateFunction(name, args: args)
        }
    }

    private func evaluateBinary(_ op: BinaryOp, lhs: Expr, rhs: Expr) async throws -> QBValue {
        if op == .and || op == .or || op == .xor || op == .eqv || op == .imp {
            let left = try await evaluate(lhs).asBool
            let right = try await evaluate(rhs).asBool
            switch op {
            case .and: return .bool(left && right)
            case .or: return .bool(left || right)
            case .xor: return .bool(left != right)
            case .eqv: return .bool(left == right)
            case .imp: return .bool(!left || right)
            default: break
            }
        }

        let left = try await evaluate(lhs)
        let right = try await evaluate(rhs)

        if case .string = left, case .string = right, op == .add {
            return .string(left.asString + right.asString)
        }

        let l = left.asDouble
        let r = right.asDouble
        switch op {
        case .add: return QBValue.from(l + r, type: .variant)
        case .sub: return QBValue.from(l - r, type: .variant)
        case .mul: return QBValue.from(l * r, type: .variant)
        case .div: return QBValue.from(l / r, type: .variant)
        case .intDiv: return .integer(Int(l) / Int(r))
        case .pow: return QBValue.from(pow(l, r), type: .variant)
        case .mod: return .integer(Int(l) % Int(r))
        case .eq: return .bool(l == r)
        case .ne: return .bool(l != r)
        case .lt: return .bool(l < r)
        case .le: return .bool(l <= r)
        case .gt: return .bool(l > r)
        case .ge: return .bool(l >= r)
        default: return .integer(0)
        }
    }

    private func evaluateFunction(_ name: String, args: [Expr]) async throws -> QBValue {
        let upper = name.uppercased()
        if upper == "INDEX", args.count == 2 {
            let access = try resolveArrayAccess(.function("INDEX", args))
            let indices = try await evaluateIndices(access.indices)
            return try environment.getArray(access.name, indices: indices)
        }

        if let proc = procedures[upper], proc.kind == .function {
            return try await runUserFunction(proc, args: args)
        }

        let evaluated = try await evaluateAll(args)
        switch upper {
        case "ABS": return QBValue.from(abs(evaluated[0].asDouble), type: .variant)
        case "INT": return .integer(evaluated[0].asInt)
        case "SGN":
            let v = evaluated[0].asDouble
            return .integer(v > 0 ? 1 : (v < 0 ? -1 : 0))
        case "SQR": return QBValue.from(sqrt(evaluated[0].asDouble), type: .variant)
        case "SIN": return QBValue.from(sin(evaluated[0].asDouble), type: .variant)
        case "COS": return QBValue.from(cos(evaluated[0].asDouble), type: .variant)
        case "TAN": return QBValue.from(tan(evaluated[0].asDouble), type: .variant)
        case "RND":
            if evaluated.isEmpty {
                return .single(environment.nextRandom())
            }
            let n = evaluated[0].asDouble
            if n == 0 {
                return .single(environment.lastRandom)
            }
            if n < 0 {
                environment.seedRandom(Int(n))
                return .single(environment.nextRandom())
            }
            let bound = Int(n)
            if bound > 0 {
                return .integer(Int(environment.nextRandom() * Double(bound)) + 1)
            }
            return .single(environment.nextRandom())
        case "EXP": return QBValue.from(exp(evaluated[0].asDouble), type: .variant)
        case "LOG": return QBValue.from(log(evaluated[0].asDouble), type: .variant)
        case "ATN": return QBValue.from(atan(evaluated[0].asDouble), type: .variant)
        case "FIX": return QBValue.from(Double(Int(evaluated[0].asDouble)), type: .variant)
        case "INKEY", "INKEY$": return .string("")
        case "CHR", "CHR$": return .string(String(Character(UnicodeScalar(evaluated[0].asInt % 256)!)))
        case "STR", "STR$": return .string(formatStr(evaluated[0]))
        case "VAL": return QBValue.from(Double(evaluated[0].asString) ?? 0, type: .variant)
        case "LEN": return .integer(evaluated[0].asString.count)
        case "LEFT", "LEFT$":
            let s = evaluated[0].asString
            let n = max(0, evaluated[1].asInt)
            return .string(String(s.prefix(n)))
        case "RIGHT", "RIGHT$":
            let s = evaluated[0].asString
            let n = max(0, evaluated[1].asInt)
            return .string(String(s.suffix(n)))
        case "MID", "MID$":
            let s = evaluated[0].asString
            let start = max(1, evaluated[1].asInt)
            let length = evaluated.count > 2 ? max(0, evaluated[2].asInt) : s.count - start + 1
            let offset = start - 1
            guard offset < s.count else { return .string("") }
            let end = min(s.count, offset + length)
            return .string(String(s[s.index(s.startIndex, offsetBy: offset)..<s.index(s.startIndex, offsetBy: end)]))
        case "UCASE", "UCASE$": return .string(evaluated[0].asString.uppercased())
        case "LCASE", "LCASE$": return .string(evaluated[0].asString.lowercased())
        case "INSTR":
            if evaluated.count == 2 {
                let start = evaluated[0].asString
                let needle = evaluated[1].asString
                if let range = start.range(of: needle) {
                    return .integer(start.distance(from: start.startIndex, to: range.lowerBound) + 1)
                }
                return .integer(0)
            }
            let startAt = max(1, evaluated[1].asInt)
            let haystack = evaluated[0].asString
            let needle = evaluated[2].asString
            let offset = startAt - 1
            guard offset < haystack.count else { return .integer(0) }
            let slice = String(haystack[haystack.index(haystack.startIndex, offsetBy: offset)...])
            if let range = slice.range(of: needle) {
                return .integer(offset + slice.distance(from: slice.startIndex, to: range.lowerBound) + 1)
            }
            return .integer(0)
        case "STRING", "STRING$":
            let count = max(0, evaluated[0].asInt)
            let ch = evaluated.count > 1 ? evaluated[1].asString.first.map(String.init) ?? " " : " "
            return .string(String(repeating: ch, count: count))
        default:
            throw QBError.runtime("Unknown function \(upper)")
        }
    }

    private func clauseMatches(_ clause: CaseClause, value: QBValue) async throws -> Bool {
        if clause.isElse {
            return true
        }
        if let op = clause.isCompare, let rhs = clause.compareValue {
            let left = value.asDouble
            let right = try await evaluate(rhs).asDouble
            switch op {
            case .eq: return left == right
            case .ne: return left != right
            case .lt: return left < right
            case .le: return left <= right
            case .gt: return left > right
            case .ge: return left >= right
            default: return false
            }
        }
        guard let values = clause.values else { return false }
        let actual = value.asDouble
        for caseValue in values {
            let expected = try await evaluate(caseValue).asDouble
            if actual == expected {
                return true
            }
        }
        return false
    }

    private func formatStr(_ value: QBValue) -> String {
        switch value {
        case .string(let s):
            return s
        case .integer(let v):
            return v >= 0 ? " \(v)" : String(v)
        case .long(let v):
            return v >= 0 ? " \(v)" : String(v)
        case .single(let v):
            return v >= 0 ? " \(formatPrintValue(.single(v)))" : formatPrintValue(.single(v))
        case .double(let v):
            return v >= 0 ? " \(String(v))" : String(v)
        case .bool(let v):
            return v ? " -1" : " 0"
        }
    }

    private func formatPrintValue(_ value: QBValue) -> String {
        switch value {
        case .single(let v):
            return v.rounded() == Double(Float(v)) ? String(Int(v)) : String(v)
        case .double(let v):
            return String(v)
        default:
            return value.asString
        }
    }

    private func skipWhileEnd(program: ParsedProgram, from pc: Int) throws -> Int? {
        var depth = 1
        var index = pc + 1
        while index < program.lines.count {
            for statement in program.lines[index].statements {
                if case .whileLoop = statement { depth += 1 }
                if case .wend = statement {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index += 1
        }
        throw QBError.runtime("WEND not found")
    }

    private func preloadData(from program: ParsedProgram) async throws {
        environment.resetData()
        for line in program.lines {
            for statement in line.statements {
                if case .data(let values) = statement {
                    let lineNum = line.lineNumber ?? line.sourceLine
                    environment.registerDataLine(lineNum)
                    var resolved: [QBValue] = []
                    for value in values {
                        resolved.append(try await evaluate(value))
                    }
                    environment.appendData(resolved)
                }
            }
        }
    }

    private func resolveJump(_ target: Int, in program: ParsedProgram) -> Int? {
        if let linePC = program.lineIndex[target] {
            return linePC
        }
        if target >= 0 && target < program.lines.count {
            return target
        }
        return nil
    }

    private func evaluateIndices(_ indices: [Expr]) async throws -> [Int] {
        var result: [Int] = []
        for index in indices {
            result.append(try await evaluate(index).asInt)
        }
        return result
    }

    private func evaluateAll(_ args: [Expr]) async throws -> [QBValue] {
        var result: [QBValue] = []
        for arg in args {
            result.append(try await evaluate(arg))
        }
        return result
    }

    private func defaultQBValue(for type: QBType) -> QBValue {
        switch type {
        case .integer: return .integer(0)
        case .long: return .long(0)
        case .single: return .single(0)
        case .double: return .double(0)
        case .string: return .string("")
        case .variant: return .integer(0)
        }
    }

    private func skipToNext(program: ParsedProgram, from pc: Int, keyword: Keyword) throws -> Int {
        var index = pc + 1
        while index < program.lines.count {
            for statement in program.lines[index].statements {
                switch (keyword, statement) {
                case (.next, .next), (.loop, .loop(_)), (.wend, .wend):
                    return index
                default:
                    break
                }
            }
            index += 1
        }
        throw QBError.runtime("\(keyword.rawValue.uppercased()) not found")
    }
}

private struct ForFrame {
    let name: String
    let type: QBType
    let end: Double
    let step: Double
    let linePC: Int
}

private struct DoFrame {
    let mode: DoMode
    let linePC: Int
}