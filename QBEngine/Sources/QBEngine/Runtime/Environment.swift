import Foundation

private enum VariableBinding {
    case stored(QBValue, QBType)
    case alias(String)
}

private struct VariableScope {
    var bindings: [String: VariableBinding] = [:]
}

public final class Environment: @unchecked Sendable {
    private var scalars: [String: QBValue] = [:]
    private var arrays: [String: QBArray] = [:]
    private var constants: [String: QBValue] = [:]
    private var defaultTypes: [Character: QBType] = [:]
    private var scopeStack: [VariableScope] = []
    private var dataItems: [QBValue] = []
    private var dataPointer: Int = 0
    private var dataLineStarts: [(line: Int, index: Int)] = []
    private var staticStorage: [String: [String: QBValue]] = [:]
    private var typeDefs: [String: TypeDef] = [:]
    public var optionBase: Int = 0
    public var randomSeed: UInt64 = 1
    public private(set) var lastRandom: Double = 0
    public let fileStore = FileStore()
    public var keyQueue: [String] = []
    public var programStartTime: Date = Date()

    public init() {
        seedRandom()
        programStartTime = Date()
    }

    public func resetSession() {
        scalars.removeAll()
        arrays.removeAll()
        constants.removeAll()
        scopeStack.removeAll()
        defaultTypes.removeAll()
        typeDefs.removeAll()
        dataItems = []
        dataPointer = 0
        dataLineStarts = []
        staticStorage.removeAll()
        optionBase = 0
        keyQueue.removeAll()
        programStartTime = Date()
        fileStore.closeAll()
    }

    public func registerTypes(_ defs: [String: TypeDef]) {
        typeDefs = defs
    }

    public func typeDef(named name: String) -> TypeDef? {
        typeDefs[name.uppercased()]
    }

    public func defaultType(for name: String) -> QBType {
        guard let first = name.uppercased().first else { return .variant }
        return defaultTypes[first] ?? .variant
    }

    public func setDefaultType(_ type: QBType, from start: Character, to end: Character) {
        let lower = min(start, end)
        let upper = max(start, end)
        for code in lower.asciiValue!...upper.asciiValue! {
            let scalar = UnicodeScalar(code)
            defaultTypes[Character(scalar)] = type
        }
    }

    public func pushScope() {
        scopeStack.append(VariableScope())
    }

    public func popScope() {
        guard !scopeStack.isEmpty else { return }
        scopeStack.removeLast()
    }

    public func bindParameter(name: String, type: QBType, aliasTo variable: String) {
        let key = name.uppercased()
        guard !scopeStack.isEmpty else { return }
        scopeStack[scopeStack.count - 1].bindings[key] = .alias(variable.uppercased())
    }

    public func bindParameter(name: String, type: QBType, value: QBValue) {
        let key = name.uppercased()
        guard !scopeStack.isEmpty else { return }
        scopeStack[scopeStack.count - 1].bindings[key] = .stored(coerce(value, to: type), type)
    }

    public func bindShared(_ name: String) {
        let key = name.uppercased()
        guard !scopeStack.isEmpty else { return }
        // Alias to global of the same name (resolved specially to avoid circular lookup)
        scopeStack[scopeStack.count - 1].bindings[key] = .alias("__GLOBAL__." + key)
    }

    public func bindStatic(procedure: String, name: String, type: QBType) {
        let proc = procedure.uppercased()
        let key = name.uppercased()
        if staticStorage[proc] == nil {
            staticStorage[proc] = [:]
        }
        if staticStorage[proc]?[key] == nil {
            staticStorage[proc]?[key] = defaultValue(for: type)
        }
        guard !scopeStack.isEmpty else { return }
        let storageKey = "\(proc).\(key)"
        // Alias to a pseudo-global key held in scalars via static bridge
        if scalars[storageKey] == nil {
            scalars[storageKey] = staticStorage[proc]?[key] ?? defaultValue(for: type)
        }
        scopeStack[scopeStack.count - 1].bindings[key] = .alias(storageKey)
    }

    public func syncStaticFromScalars(procedure: String, name: String) {
        let proc = procedure.uppercased()
        let key = name.uppercased()
        let storageKey = "\(proc).\(key)"
        if let value = scalars[storageKey] {
            staticStorage[proc]?[key] = value
        }
    }

    public func defineConstant(_ name: String, value: QBValue) throws {
        let key = name.uppercased()
        if constants[key] != nil {
            throw QBError.runtime("Constant \(key) already defined")
        }
        constants[key] = value
    }

    public func getVariable(_ name: String) throws -> QBValue {
        let key = name.uppercased()
        if let constant = constants[key] { return constant }
        if let value = try resolveScopedVariable(key) {
            return value
        }
        if let value = scalars[key] { return value }
        let type = defaultType(for: key)
        return defaultValue(for: type)
    }

    public func setVariable(_ name: String, value: QBValue, type: QBType) throws {
        let key = name.uppercased()
        if constants[key] != nil {
            throw QBError.runtime("Cannot assign to constant \(key)")
        }
        if try setScopedVariable(key, value: value, type: type) {
            return
        }
        scalars[key] = coerce(value, to: type)
    }

    public func setRecordField(variable: String, field: String, value: QBValue) throws {
        let key = variable.uppercased()
        let fieldKey = field.uppercased()
        var record = try getVariable(key)
        guard case .record(let typeName, var fields) = record else {
            throw QBError.runtime("Variable \(key) is not a user-defined type")
        }
        fields[fieldKey] = value
        record = .record(typeName: typeName, fields: fields)
        try setVariable(key, value: record, type: .userType(typeName))
    }

    public func getRecordField(variable: String, field: String) throws -> QBValue {
        let record = try getVariable(variable)
        guard case .record(_, let fields) = record else {
            throw QBError.runtime("Variable \(variable) is not a user-defined type")
        }
        guard let value = fields[field.uppercased()] else {
            throw QBError.runtime("Unknown field \(field)")
        }
        return value
    }

    public func makeRecord(typeName: String) throws -> QBValue {
        guard let def = typeDefs[typeName.uppercased()] else {
            throw QBError.runtime("Unknown type \(typeName)")
        }
        var fields: [String: QBValue] = [:]
        for field in def.fields {
            fields[field.name] = defaultValue(for: field.type)
        }
        return .record(typeName: def.name, fields: fields)
    }

    private func resolveScopedVariable(_ key: String, visited: Set<String> = []) throws -> QBValue? {
        guard !visited.contains(key) else {
            throw QBError.runtime("Circular parameter alias for '\(key)'")
        }
        var nextVisited = visited
        nextVisited.insert(key)

        for scope in scopeStack.reversed() {
            guard let binding = scope.bindings[key] else { continue }
            switch binding {
            case .stored(let value, _):
                return value
            case .alias(let target):
                let globalKey = target.hasPrefix("__GLOBAL__.") ? String(target.dropFirst("__GLOBAL__.".count)) : target
                if target.hasPrefix("__GLOBAL__.") {
                    if let value = scalars[globalKey] { return value }
                    if let constant = constants[globalKey] { return constant }
                    return defaultValue(for: defaultType(for: globalKey))
                }
                if let value = try resolveScopedVariable(target, visited: nextVisited) {
                    return value
                }
                if let value = scalars[target] {
                    return value
                }
                if let constant = constants[target] {
                    return constant
                }
                return defaultValue(for: defaultType(for: target))
            }
        }
        return nil
    }

    private func setScopedVariable(_ key: String, value: QBValue, type: QBType) throws -> Bool {
        for index in stride(from: scopeStack.count - 1, through: 0, by: -1) {
            guard let binding = scopeStack[index].bindings[key] else { continue }
            switch binding {
            case .stored(_, let storedType):
                scopeStack[index].bindings[key] = .stored(coerce(value, to: storedType), storedType)
                return true
            case .alias(let target):
                if target.hasPrefix("__GLOBAL__.") {
                    let globalKey = String(target.dropFirst("__GLOBAL__.".count))
                    scalars[globalKey] = coerce(value, to: type)
                    return true
                }
                try setVariable(target, value: value, type: type)
                return true
            }
        }
        return false
    }

    public func getArray(_ name: String, indices: [Int]) throws -> QBValue {
        let key = name.uppercased()
        guard let array = arrays[key] else {
            throw QBError.runtime("Array '\(key)' not dimensioned")
        }
        return try array.get(indices)
    }

    public func setArray(_ name: String, indices: [Int], value: QBValue, type: QBType) throws {
        let key = name.uppercased()
        guard let array = arrays[key] else {
            throw QBError.runtime("Array '\(key)' not dimensioned")
        }
        try array.set(indices, value: coerce(value, to: type))
    }

    public func dimension(_ name: String, type: QBType, bounds: [Int]) throws {
        let key = name.uppercased()
        arrays[key] = try QBArray(type: type, bounds: bounds, optionBase: optionBase)
    }

    public func lbound(_ name: String, dimension: Int = 1) throws -> Int {
        let key = name.uppercased()
        guard let array = arrays[key] else {
            throw QBError.runtime("Array '\(key)' not dimensioned")
        }
        return try array.lbound(dimension: dimension)
    }

    public func ubound(_ name: String, dimension: Int = 1) throws -> Int {
        let key = name.uppercased()
        guard let array = arrays[key] else {
            throw QBError.runtime("Array '\(key)' not dimensioned")
        }
        return try array.ubound(dimension: dimension)
    }

    public func eraseArray(_ name: String) {
        arrays.removeValue(forKey: name.uppercased())
    }

    public func injectKey(_ key: String) {
        keyQueue.append(key)
    }

    public func pollKey() -> String {
        guard !keyQueue.isEmpty else { return "" }
        return keyQueue.removeFirst()
    }

    public func resetData() {
        dataItems = []
        dataPointer = 0
        dataLineStarts = []
    }

    public var dataCount: Int { dataItems.count }

    public func registerDataLine(_ lineNumber: Int) {
        dataLineStarts.append((line: lineNumber, index: dataItems.count))
    }

    public func appendData(_ values: [QBValue]) {
        dataItems.append(contentsOf: values)
    }

    public func readNext() throws -> QBValue {
        guard dataPointer < dataItems.count else {
            throw QBError.runtime("Out of DATA")
        }
        let value = dataItems[dataPointer]
        dataPointer += 1
        return value
    }

    public func restore(pointer: Int) {
        dataPointer = max(0, min(pointer, dataItems.count))
    }

    public func restoreToLine(_ line: Int) {
        if let match = dataLineStarts.first(where: { $0.line >= line }) {
            dataPointer = match.index
        } else {
            dataPointer = dataItems.count
        }
    }

    public func seedRandom(_ seed: Int? = nil) {
        if let seed {
            randomSeed = UInt64(truncatingIfNeeded: seed)
        } else {
            randomSeed = UInt64(Date().timeIntervalSince1970 * 1000)
        }
    }

    public func nextRandom() -> Double {
        randomSeed = randomSeed &* 1_103_515_245 &+ 12_345
        let value = Double(randomSeed % 32_768) / 32_768.0
        lastRandom = value
        return value
    }

    public func timerSeconds() -> Double {
        Date().timeIntervalSince(programStartTime)
    }

    public func allScalarSnapshot() -> [String: QBValue] {
        var result = scalars
        for (key, value) in constants {
            result[key] = value
        }
        return result
    }

    public func watchValue(name: String) -> String {
        let key = name.uppercased()
        if let constant = constants[key] {
            return constant.asString
        }
        if let value = try? getVariable(key) {
            return value.asString
        }
        return "0"
    }

    private func coerce(_ value: QBValue, to type: QBType) -> QBValue {
        switch type {
        case .integer: return .integer(value.asInt)
        case .long: return .long(value.asInt)
        case .single: return .single(value.asDouble)
        case .double: return .double(value.asDouble)
        case .string: return .string(value.asString)
        case .variant: return value
        case .userType:
            if case .record = value { return value }
            return value
        }
    }
}

public final class QBArray: @unchecked Sendable {
    private let type: QBType
    private let lowerBounds: [Int]
    private let upperBounds: [Int]
    private var storage: [QBValue]

    public init(type: QBType, bounds: [Int], optionBase: Int = 0) throws {
        guard bounds.count % 2 == 0 else {
            throw QBError.runtime("Invalid DIM bounds")
        }
        self.type = type
        var lowers: [Int] = []
        var uppers: [Int] = []
        for i in stride(from: 0, to: bounds.count, by: 2) {
            let lower = bounds[i]
            let upper = bounds[i + 1]
            // When parser only supplies upper bounds as pairs (base, upper)
            lowers.append(lower)
            uppers.append(upper)
        }
        // If a single upper was passed as [base, upper] from executor with optionBase
        _ = optionBase
        self.lowerBounds = lowers
        self.upperBounds = uppers
        let count = zip(lowers, uppers).reduce(1) { partial, pair in
            partial * max(0, pair.1 - pair.0 + 1)
        }
        self.storage = Array(repeating: defaultValue(for: type), count: max(count, 0))
    }

    public func get(_ indices: [Int]) throws -> QBValue {
        let offset = try computeOffset(indices)
        return storage[offset]
    }

    public func set(_ indices: [Int], value: QBValue) throws {
        let offset = try computeOffset(indices)
        storage[offset] = value
    }

    public func lbound(dimension: Int) throws -> Int {
        let index = dimension - 1
        guard index >= 0 && index < lowerBounds.count else {
            throw QBError.runtime("Invalid dimension")
        }
        return lowerBounds[index]
    }

    public func ubound(dimension: Int) throws -> Int {
        let index = dimension - 1
        guard index >= 0 && index < upperBounds.count else {
            throw QBError.runtime("Invalid dimension")
        }
        return upperBounds[index]
    }

    private func computeOffset(_ indices: [Int]) throws -> Int {
        guard indices.count == lowerBounds.count else {
            throw QBError.runtime("Wrong number of dimensions")
        }
        var offset = 0
        var multiplier = 1
        for i in (0..<indices.count).reversed() {
            let index = indices[i]
            let lower = lowerBounds[i]
            let upper = upperBounds[i]
            guard index >= lower && index <= upper else {
                throw QBError.runtime("Subscript out of range")
            }
            offset += (index - lower) * multiplier
            multiplier *= (upper - lower + 1)
        }
        return offset
    }
}

func defaultValue(for type: QBType) -> QBValue {
    switch type {
    case .integer: return .integer(0)
    case .long: return .long(0)
    case .single: return .single(0)
    case .double: return .double(0)
    case .string: return .string("")
    case .variant: return .integer(0)
    case .userType(let name): return .record(typeName: name, fields: [:])
    }
}
