import Foundation

public final class Executor: @unchecked Sendable {
    public let environment = Environment()
    public let screen = ScreenBuffer()
    public weak var output: QBOutputHandler?
    public var input: QBInputHandler?

    private var returnStack: [Int] = []
    private var forStack: [ForFrame] = []
    private var whileStack: [Int] = []
    private var doStack: [DoFrame] = []
    private var procedures: [String: ProcedureDef] = [:]
    private var typeDefs: [String: TypeDef] = [:]
    private var activeFunctionName: String?
    private var functionReturnValue: QBValue?
    private var activeProcedureName: String?

    // Control / debug
    public var shouldStop = false
    public var breakpoints: Set<Int> = []
    public var stepMode = false
    public var isPaused = false
    public private(set) var currentSourceLine: Int = 0
    public var watches: [String] = []
    public private(set) var lastWatchSnapshot: [String: String] = [:]
    /// When true, hits breakpoint/step and waits for resumeStep()/continueRunning().
    public var debugEnabled = false
    private var stepResumeContinuation: CheckedContinuation<Void, Never>?
    /// Set when resume arrives before the pause continuation is registered (race-safe).
    private var resumeRequested = false
    private var pauseReason: String?
    private let pauseLock = NSLock()

    public init() {}

    public func requestStop() {
        shouldStop = true
        // Only wake a parked pause; do not sticky-set resumeRequested when not paused
        // (that would skip the next run's first breakpoint).
        pauseLock.lock()
        if let cont = stepResumeContinuation {
            stepResumeContinuation = nil
            resumeRequested = false
            pauseLock.unlock()
            isPaused = false
            cont.resume()
        } else {
            pauseLock.unlock()
            isPaused = false
        }
    }

    public func injectKey(_ key: String) {
        environment.injectKey(key)
    }

    /// Clears pause/resume control state so a new run never inherits a sticky resume.
    public func resetDebugControlState() {
        pauseLock.lock()
        stepResumeContinuation = nil
        resumeRequested = false
        pauseLock.unlock()
        isPaused = false
        shouldStop = false
        pauseReason = nil
    }

    public func resumeStep() {
        pauseLock.lock()
        if let cont = stepResumeContinuation {
            stepResumeContinuation = nil
            resumeRequested = false
            pauseLock.unlock()
            isPaused = false
            cont.resume()
        } else {
            // Continuation not registered yet — mark so waitForDebugPause resumes immediately
            resumeRequested = true
            pauseLock.unlock()
            isPaused = false
        }
    }

    public func continueRunning() {
        stepMode = false
        resumeStep()
    }

    /// Race-safe pause used for breakpoints and single-step.
    private func waitForDebugPause(reason: String) async {
        pauseReason = reason
        isPaused = true
        _ = watchSnapshot()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            pauseLock.lock()
            if resumeRequested {
                resumeRequested = false
                pauseLock.unlock()
                cont.resume()
            } else {
                stepResumeContinuation = cont
                pauseLock.unlock()
            }
        }
        isPaused = false
    }

    public func watchSnapshot() -> [String: String] {
        var result: [String: String] = [:]
        for name in watches {
            result[name.uppercased()] = environment.watchValue(name: name)
        }
        lastWatchSnapshot = result
        return result
    }

    public func execute(program: ParsedProgram) async throws {
        procedures = program.procedures
        typeDefs = program.typeDefs
        environment.registerTypes(typeDefs)
        // Drop sticky resume from a prior stop/resume that arrived while not paused
        resetDebugControlState()
        returnStack = []
        forStack = []
        whileStack = []
        doStack = []
        try await preloadData(from: program)
        var pc = 0
        while pc < program.lines.count {
            if shouldStop {
                throw QBError.programStopped
            }
            let line = program.lines[pc]
            currentSourceLine = line.sourceLine
            if debugEnabled {
                if breakpoints.contains(line.sourceLine) || stepMode {
                    await waitForDebugPause(reason: stepMode ? "step" : "breakpoint")
                    if shouldStop { throw QBError.programStopped }
                }
            }
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
        environment.fileStore.closeAll()
    }

    private func executeLine(_ line: ProgramLine, program: ParsedProgram, at pc: Int) async throws -> Int? {
        for statement in line.statements {
            if shouldStop { throw QBError.programStopped }
            if let jump = try await executeStatement(statement, program: program, at: pc) {
                return jump
            }
        }
        return nil
    }

    private func executeStatement(_ statement: Statement, program: ParsedProgram, at pc: Int) async throws -> Int? {
        switch statement {
        case .rem, .label, .declare, .typeDef:
            return nil
        case .print(let items):
            try await executePrint(items)
        case .printUsing(let format, let values):
            try await executePrintUsing(format: format, values: values)
        case .input(let prompts, let vars):
            try await executeInput(prompts: prompts, variables: vars)
        case .lineInput(let prompt, let target):
            if let prompt {
                output?.write(prompt)
            }
            let response = try await input?.prompt(prompt ?? "? ") ?? ""
            try await assign(target, value: .string(response))
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
        case .goto(let target):
            return try resolveTarget(target, program: program)
        case .gosub(let target):
            returnStack.append(pc + 1)
            return try resolveTarget(target, program: program)
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
            try await dimensionArray(name: name, type: type, bounds: bounds)
        case .dimAs(let name, let type, let bounds):
            if bounds.isEmpty {
                if case .userType(let typeName) = type {
                    let record = try environment.makeRecord(typeName: typeName)
                    try environment.setVariable(name, value: record, type: type)
                } else {
                    try environment.setVariable(name, value: defaultValue(for: type), type: type)
                }
            } else {
                try await dimensionArray(name: name, type: type, bounds: bounds)
            }
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
        case .onGoto(let expr, let targets):
            let index = try await evaluate(expr).asInt
            if index >= 1 && index <= targets.count {
                return try resolveTarget(targets[index - 1], program: program)
            }
        case .onGosub(let expr, let targets):
            let index = try await evaluate(expr).asInt
            if index >= 1 && index <= targets.count {
                returnStack.append(pc + 1)
                return try resolveTarget(targets[index - 1], program: program)
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
            let colorVal = color != nil ? try await evaluate(color!).asInt : 0
            let apVal = ap != nil ? try await evaluate(ap!).asInt : 0
            screen.setScreen(modeValue: modeVal, colorSwitch: colorVal, ap: apVal)
        case .color(let fg, let bg, _):
            let fgVal = try await evaluate(fg).asInt
            let bgVal = bg != nil ? try await evaluate(bg!).asInt : nil
            screen.setColor(foreground: fgVal, background: bgVal)
        case .locate(let row, let col):
            let r = try await evaluate(row).asInt
            let c = col != nil ? try await evaluate(col!).asInt : screen.cursorCol
            screen.locate(row: r, col: c)
        case .pset(let x, let y, let color):
            let px = try await evaluate(x).asInt
            let py = try await evaluate(y).asInt
            let c = color != nil ? try await evaluate(color!).asInt : screen.foreground
            screen.pset(x: px, y: py, colorIndex: c)
        case .preset(let x, let y, let color):
            let px = try await evaluate(x).asInt
            let py = try await evaluate(y).asInt
            let c = color != nil ? try await evaluate(color!).asInt : screen.background
            screen.preset(x: px, y: py, colorIndex: c)
        case .line(let x1, let y1, let x2, let y2, let color, let style):
            let fx = try await evaluate(x1).asInt
            let fy = try await evaluate(y1).asInt
            let c = color != nil ? try await evaluate(color!).asInt : screen.foreground
            if let x2, let y2 {
                let tx = try await evaluate(x2).asInt
                let ty = try await evaluate(y2).asInt
                screen.drawLine(x1: fx, y1: fy, x2: tx, y2: ty, colorIndex: c, style: style)
            }
        case .circle(let x, let y, let radius, let color, _, _):
            let cx = try await evaluate(x).asInt
            let cy = try await evaluate(y).asInt
            let r = try await evaluate(radius).asInt
            let c = color != nil ? try await evaluate(color!).asInt : screen.foreground
            screen.drawCircle(cx: cx, cy: cy, radius: r, colorIndex: c)
        case .paint(let x, let y, let paintColor, let border):
            let px = try await evaluate(x).asInt
            let py = try await evaluate(y).asInt
            let pc = paintColor != nil ? try await evaluate(paintColor!).asInt : screen.foreground
            let bc = border != nil ? try await evaluate(border!).asInt : nil
            screen.paint(x: px, y: py, paintColor: pc, borderColor: bc)
        case .draw(let expr):
            let cmd = try await evaluate(expr).asString
            screen.drawMacro(cmd)
        case .getSprite(let x1, let y1, let x2, let y2, let name):
            screen.getSprite(
                x1: try await evaluate(x1).asInt,
                y1: try await evaluate(y1).asInt,
                x2: try await evaluate(x2).asInt,
                y2: try await evaluate(y2).asInt,
                name: name
            )
        case .putSprite(let x, let y, let name):
            screen.putSprite(x: try await evaluate(x).asInt, y: try await evaluate(y).asInt, name: name)
        case .constDecl(let items):
            for (name, type, expr) in items {
                let value = try await evaluate(expr)
                try environment.defineConstant(name, value: value)
                _ = type
            }
        case .swap(let a, let b):
            let va = try await evaluate(a)
            let vb = try await evaluate(b)
            try await assign(a, value: vb)
            try await assign(b, value: va)
        case .optionBase(let base):
            environment.optionBase = base
        case .midAssign(let target, let startExpr, let lenExpr, let valueExpr):
            guard case .variable(let name, _) = target else {
                throw QBError.runtime("MID$ assignment requires a string variable")
            }
            var s = try environment.getVariable(name).asString
            let start = max(1, try await evaluate(startExpr).asInt)
            let replacement = try await evaluate(valueExpr).asString
            let length = lenExpr != nil ? try await evaluate(lenExpr!).asInt : replacement.count
            let offset = start - 1
            if offset >= s.count {
                s += replacement
            } else {
                let end = min(s.count, offset + max(0, length))
                let prefix = String(s.prefix(offset))
                let suffix = String(s.dropFirst(end))
                let mid = String(replacement.prefix(max(0, length)))
                s = prefix + mid + suffix
            }
            try environment.setVariable(name, value: .string(s), type: .string)
        case .open(let path, let mode, let handle):
            try environment.fileStore.open(path: path, mode: mode, handle: handle)
        case .close(let handles):
            if let handles {
                for h in handles { try environment.fileStore.close(h) }
            } else {
                try environment.fileStore.close(nil)
            }
        case .printHash(let handle, let items):
            var line = ""
            var needSemi = false
            for item in items {
                switch item {
                case .expression(let expr):
                    line += formatPrintValue(try await evaluate(expr))
                    needSemi = false
                case .separator(.semicolon):
                    needSemi = true
                case .separator(.comma):
                    line += ","
                    needSemi = true
                case .tab, .spc, .using:
                    break
                }
            }
            try environment.fileStore.printHash(handle, text: line, newline: !needSemi)
        case .inputHash(let handle, let vars):
            for variable in vars {
                let response = try environment.fileStore.inputHash(handle)
                try await assign(variable, value: inputValue(response, for: variable))
            }
        case .lineInputHash(let handle, let target):
            let response = try environment.fileStore.lineInputHash(handle)
            try await assign(target, value: .string(response))
        case .shared(let names):
            for name in names {
                environment.bindShared(name)
            }
        case .static(let names):
            let proc = activeProcedureName ?? "_MAIN"
            for name in names {
                let type = environment.defaultType(for: name)
                environment.bindStatic(procedure: proc, name: name, type: type)
            }
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
            let nanos = UInt64(max(0, seconds) * 1_000_000_000)
            // Poll stop while sleeping in short slices
            var remaining = nanos
            while remaining > 0 {
                if shouldStop { throw QBError.programStopped }
                let slice = min(remaining, 50_000_000)
                try await Task.sleep(nanoseconds: slice)
                remaining -= slice
            }
        case .callProcedure(let name, let args):
            try await invokeProcedure(name, args: args)
        case .exitSub:
            throw QBError.exitSub
        case .exitFunction:
            throw QBError.exitFunction
        }
        return nil
    }

    private func dimensionArray(name: String, type: QBType, bounds: [Expr]) async throws {
        var parsedBounds: [Int] = []
        for bound in bounds {
            if case .function("__BOUNDS__", let args) = bound, args.count == 2 {
                parsedBounds.append(try await evaluate(args[0]).asInt)
                parsedBounds.append(try await evaluate(args[1]).asInt)
            } else {
                let upper = try await evaluate(bound).asInt
                parsedBounds.append(environment.optionBase)
                parsedBounds.append(upper)
            }
        }
        try environment.dimension(name, type: type, bounds: parsedBounds)
    }

    private func resolveTarget(_ target: JumpTarget, program: ParsedProgram) throws -> Int {
        switch target {
        case .lineNumber(let line):
            return line
        case .label(let name):
            guard let pc = program.labelIndex[name.uppercased()] else {
                throw QBError.runtime("Label \(name) not found")
            }
            // Return a synthetic marker: negative encoding of pc+1, resolved specially
            // Better: store line number if present, else use resolve via special path
            if let lineNum = program.lines[pc].lineNumber {
                return lineNum
            }
            // Encode pc as large negative-ish: we use resolveJumpLabel
            return -(pc + 1)
        }
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
        let previous = activeProcedureName
        activeProcedureName = proc.name
        defer { activeProcedureName = previous }
        environment.pushScope()
        defer { environment.popScope() }
        try await bindProcedureArgs(proc.params, args: args)

        let context = ParsedProgram(lines: proc.body, procedures: procedures, typeDefs: typeDefs)
        do {
            for (idx, line) in proc.body.enumerated() {
                if shouldStop { throw QBError.programStopped }
                if let jump = try await executeLine(line, program: context, at: idx) {
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
            case .using(let format, let values):
                line += try await formatUsing(format: format, values: values)
                needNewColumn = false
            }
            currentCol = screen.cursorCol + line.replacingOccurrences(of: "\n", with: "").count
        }

        let advanceLine = !needNewColumn && !items.isEmpty
        output?.write(line)
        screen.writeText(line + (advanceLine ? "\n" : ""), advanceLine: advanceLine)
        if advanceLine {
            output?.write("\n")
        }
    }

    private func executePrintUsing(format: String, values: [Expr]) async throws {
        let text = try await formatUsing(format: format, values: values)
        output?.write(text)
        output?.write("\n")
        screen.writeText(text + "\n", advanceLine: true)
    }

    private func formatUsing(format: String, values: [Expr]) async throws -> String {
        var result = ""
        var valueIndex = 0
        var i = format.startIndex
        while i < format.endIndex {
            if format[i] == "#" || format[i] == "." || format[i] == "+" || format[i] == "-" || format[i] == "*" || format[i] == "$" || format[i] == "," {
                var mask = ""
                while i < format.endIndex {
                    let ch = format[i]
                    if ch == "#" || ch == "." || ch == "+" || ch == "-" || ch == "*" || ch == "$" || ch == "," || ch == "\\" {
                        mask.append(ch)
                        i = format.index(after: i)
                    } else {
                        break
                    }
                }
                let value: QBValue
                if valueIndex < values.count {
                    value = try await evaluate(values[valueIndex])
                    valueIndex += 1
                } else {
                    value = .integer(0)
                }
                result += applyNumericMask(mask, value: value.asDouble)
            } else if format[i] == "&" {
                i = format.index(after: i)
                let value: QBValue
                if valueIndex < values.count {
                    value = try await evaluate(values[valueIndex])
                    valueIndex += 1
                } else {
                    value = .string("")
                }
                result += value.asString
            } else if format[i] == "\\" {
                // fixed-length string field \...\\
                var width = 2
                i = format.index(after: i)
                while i < format.endIndex && format[i] == " " {
                    width += 1
                    i = format.index(after: i)
                }
                if i < format.endIndex && format[i] == "\\" {
                    i = format.index(after: i)
                }
                let value: String
                if valueIndex < values.count {
                    value = try await evaluate(values[valueIndex]).asString
                    valueIndex += 1
                } else {
                    value = ""
                }
                result += String(value.padding(toLength: width, withPad: " ", startingAt: 0).prefix(width))
            } else {
                result.append(format[i])
                i = format.index(after: i)
            }
        }
        return result
    }

    private func applyNumericMask(_ mask: String, value: Double) -> String {
        let hasDecimal = mask.contains(".")
        if !hasDecimal {
            let width = mask.filter { $0 == "#" || $0 == "*" }.count
            let text = String(Int(value.rounded()))
            if width <= 0 { return text }
            if text.count >= width { return text }
            return String(repeating: " ", count: width - text.count) + text
        }
        let parts = mask.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intWidth = parts.first?.filter { $0 == "#" || $0 == "*" }.count ?? 0
        let fracWidth = parts.count > 1 ? parts[1].filter { $0 == "#" || $0 == "*" }.count : 0
        let format = "%\(intWidth + (fracWidth > 0 ? fracWidth + 1 : 0)).\(fracWidth)f"
        var text = String(format: format, value)
        if text.count < intWidth + (fracWidth > 0 ? fracWidth + 1 : 0) {
            text = String(repeating: " ", count: max(0, intWidth + fracWidth + 1 - text.count)) + text
        }
        return text
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
        case .userType:
            return .string(response)
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
        case .fieldAccess(let base, let field):
            if case .variable(let name, _) = base {
                try environment.setRecordField(variable: name, field: field, value: value)
            } else {
                throw QBError.runtime("Invalid field assignment target")
            }
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
        case .fieldAccess(let base, let field):
            if case .variable(let name, _) = base {
                return try environment.getRecordField(variable: name, field: field)
            }
            let value = try await evaluate(base)
            guard case .record(_, let fields) = value, let fieldValue = fields[field.uppercased()] else {
                throw QBError.runtime("Invalid field access")
            }
            return fieldValue
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

        // String comparisons must use string semantics (not VAL→0)
        if case .string = left, case .string = right {
            let ls = left.asString
            let rs = right.asString
            switch op {
            case .eq: return .bool(ls == rs)
            case .ne: return .bool(ls != rs)
            case .lt: return .bool(ls < rs)
            case .le: return .bool(ls <= rs)
            case .gt: return .bool(ls > rs)
            case .ge: return .bool(ls >= rs)
            default: break
            }
        }
        // Mixed string/number equality (common in QB)
        if op == .eq || op == .ne {
            if case .string = left, case .string = right {
                // handled above
            } else if case .string = left {
                let equal = left.asString == right.asString || left.asDouble == right.asDouble
                return .bool(op == .eq ? equal : !equal)
            } else if case .string = right {
                let equal = left.asString == right.asString || left.asDouble == right.asDouble
                return .bool(op == .eq ? equal : !equal)
            }
        }

        let l = left.asDouble
        let r = right.asDouble
        switch op {
        case .add: return QBValue.from(l + r, type: .variant)
        case .sub: return QBValue.from(l - r, type: .variant)
        case .mul: return QBValue.from(l * r, type: .variant)
        case .div: return QBValue.from(l / r, type: .variant)
        case .intDiv: return .integer(Int(l) / max(1, Int(r) == 0 ? 1 : Int(r)))
        case .pow: return QBValue.from(pow(l, r), type: .variant)
        case .mod: return .integer(Int(l) % max(1, abs(Int(r)) == 0 ? 1 : Int(r)))
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

        // Zero-arg builtins may not evaluate args
        switch upper {
        case "TIMER":
            return .double(environment.timerSeconds())
        case "DATE", "DATE$":
            let f = DateFormatter()
            f.dateFormat = "MM-dd-yyyy"
            return .string(f.string(from: Date()))
        case "TIME", "TIME$":
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return .string(f.string(from: Date()))
        case "INKEY", "INKEY$":
            return .string(environment.pollKey())
        default:
            break
        }

        let evaluated = try await evaluateAll(args)
        switch upper {
        case "ABS": return QBValue.from(abs(evaluated[0].asDouble), type: .variant)
        case "INT": return .integer(Int(floor(evaluated[0].asDouble)))
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
        case "CINT": return .integer(Int(evaluated[0].asDouble.rounded()))
        case "CDBL": return .double(evaluated[0].asDouble)
        case "CSNG": return .single(evaluated[0].asDouble)
        case "CLNG": return .long(Int(evaluated[0].asDouble.rounded()))
        case "ASC":
            let s = evaluated[0].asString
            guard let first = s.unicodeScalars.first else { return .integer(0) }
            return .integer(Int(first.value))
        case "CHR", "CHR$":
            let code = evaluated[0].asInt % 256
            if let scalar = UnicodeScalar(code) {
                return .string(String(Character(scalar)))
            }
            return .string("")
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
        case "LTRIM", "LTRIM$":
            return .string(evaluated[0].asString.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression))
        case "RTRIM", "RTRIM$":
            return .string(evaluated[0].asString.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression))
        case "SPACE", "SPACE$":
            let n = max(0, evaluated[0].asInt)
            return .string(String(repeating: " ", count: n))
        case "HEX", "HEX$":
            return .string(String(evaluated[0].asInt, radix: 16).uppercased())
        case "OCT", "OCT$":
            return .string(String(evaluated[0].asInt, radix: 8))
        case "INSTR":
            if evaluated.count == 2 {
                let start = evaluated[0].asString
                let needle = evaluated[1].asString
                if let range = start.range(of: needle) {
                    return .integer(start.distance(from: start.startIndex, to: range.lowerBound) + 1)
                }
                return .integer(0)
            }
            // INSTR(start, haystack, needle) or INSTR(haystack, needle) already handled
            if evaluated.count >= 3 {
                // QB: INSTR([start,] string1, string2)
                let maybeStart = evaluated[0]
                // Heuristic: if first is numeric-ish and second is string
                let startAt = max(1, maybeStart.asInt)
                let haystack = evaluated[1].asString
                let needle = evaluated[2].asString
                let offset = startAt - 1
                guard offset < haystack.count else { return .integer(0) }
                let slice = String(haystack[haystack.index(haystack.startIndex, offsetBy: offset)...])
                if let range = slice.range(of: needle) {
                    return .integer(offset + slice.distance(from: slice.startIndex, to: range.lowerBound) + 1)
                }
                return .integer(0)
            }
            return .integer(0)
        case "STRING", "STRING$":
            let count = max(0, evaluated[0].asInt)
            let ch: String
            if evaluated.count > 1 {
                if case .string = evaluated[1] {
                    ch = evaluated[1].asString.first.map(String.init) ?? " "
                } else {
                    let code = evaluated[1].asInt % 256
                    ch = UnicodeScalar(code).map { String(Character($0)) } ?? " "
                }
            } else {
                ch = " "
            }
            return .string(String(repeating: ch, count: count))
        case "LBOUND":
            let arrayName: String
            if case .variable(let n, _) = args[0] {
                arrayName = n
            } else {
                arrayName = evaluated[0].asString
            }
            let dim = evaluated.count > 1 ? evaluated[1].asInt : 1
            return .integer(try environment.lbound(arrayName, dimension: dim))
        case "UBOUND":
            let arrayName: String
            if case .variable(let n, _) = args[0] {
                arrayName = n
            } else {
                arrayName = evaluated[0].asString
            }
            let dim = evaluated.count > 1 ? evaluated[1].asInt : 1
            return .integer(try environment.ubound(arrayName, dimension: dim))
        case "POINT":
            return .integer(screen.point(x: evaluated[0].asInt, y: evaluated[1].asInt))
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
        if let values = clause.values {
            for expr in values {
                let v = try await evaluate(expr)
                if v.asString == value.asString || v.asDouble == value.asDouble {
                    return true
                }
            }
        }
        return false
    }

    private func formatStr(_ value: QBValue) -> String {
        switch value {
        case .string(let s): return s
        default:
            let d = value.asDouble
            if d >= 0 {
                return " \(formatPrintValue(value))"
            }
            return formatPrintValue(value)
        }
    }

    private func formatPrintValue(_ value: QBValue) -> String {
        switch value {
        case .string(let s): return s
        case .bool(let b): return b ? "-1" : "0"
        case .integer(let v): return String(v)
        case .long(let v): return String(v)
        case .single(let v), .double(let v):
            if v.rounded() == v {
                return String(Int(v))
            }
            return String(v)
        case .record(let typeName, _):
            return "{\(typeName)}"
        }
    }

    private func skipWhileEnd(program: ParsedProgram, from pc: Int) throws -> Int? {
        var depth = 1
        var i = pc + 1
        while i < program.lines.count {
            for statement in program.lines[i].statements {
                switch statement {
                case .whileLoop: depth += 1
                case .wend:
                    depth -= 1
                    if depth == 0 {
                        return program.lines[i].lineNumber ?? i
                    }
                default: break
                }
            }
            i += 1
        }
        throw QBError.runtime("WHILE without WEND")
    }

    private func preloadData(from program: ParsedProgram) async throws {
        environment.resetData()
        for line in program.lines {
            for statement in line.statements {
                if case .data(let items) = statement {
                    if let lineNumber = line.lineNumber {
                        environment.registerDataLine(lineNumber)
                    }
                    var values: [QBValue] = []
                    for expr in items {
                        values.append(try await evaluate(expr))
                    }
                    environment.appendData(values)
                }
            }
        }
    }

    private func resolveJump(_ target: Int, in program: ParsedProgram) -> Int? {
        if target < 0 {
            let pc = -target - 1
            if pc >= 0 && pc < program.lines.count {
                return pc
            }
            return nil
        }
        if let linePC = program.lineIndex[target] {
            return linePC
        }
        // Also allow direct PC for for-loop restarts when no line numbers
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
        defaultValue(for: type)
    }

    private func skipToNext(program: ParsedProgram, from pc: Int, keyword: Keyword) throws -> Int {
        var depth = 1
        var i = pc + 1
        while i < program.lines.count {
            for statement in program.lines[i].statements {
                switch (keyword, statement) {
                case (.next, .forLoop): depth += 1
                case (.next, .next):
                    depth -= 1
                    if depth == 0 { return i + 1 }
                case (.loop, .doLoop): depth += 1
                case (.loop, .loop):
                    depth -= 1
                    if depth == 0 { return i + 1 }
                case (.wend, .whileLoop): depth += 1
                case (.wend, .wend):
                    depth -= 1
                    if depth == 0 { return i + 1 }
                default: break
                }
            }
            i += 1
        }
        throw QBError.runtime("Missing matching \(keyword.rawValue.uppercased())")
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
