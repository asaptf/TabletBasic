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
    private var defaultTypes: [Character: QBType] = [:]
    private var scopeStack: [VariableScope] = []
    private var dataItems: [QBValue] = []
    private var dataPointer: Int = 0
    private var dataLineStarts: [(line: Int, index: Int)] = []
    public var randomSeed: UInt64 = 1
    public private(set) var lastRandom: Double = 0

    public init() {
        seedRandom()
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

    public func getVariable(_ name: String) throws -> QBValue {
        let key = name.uppercased()
        if let value = try resolveScopedVariable(key) {
            return value
        }
        if let value = scalars[key] { return value }
        let type = defaultType(for: key)
        return defaultValue(for: type)
    }

    public func setVariable(_ name: String, value: QBValue, type: QBType) throws {
        let key = name.uppercased()
        if try setScopedVariable(key, value: value, type: type) {
            return
        }
        scalars[key] = coerce(value, to: type)
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
                if let value = try resolveScopedVariable(target, visited: nextVisited) {
                    return value
                }
                if let value = scalars[target] {
                    return value
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
        arrays[key] = try QBArray(type: type, bounds: bounds)
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

    private func coerce(_ value: QBValue, to type: QBType) -> QBValue {
        switch type {
        case .integer: return .integer(value.asInt)
        case .long: return .long(value.asInt)
        case .single: return .single(value.asDouble)
        case .double: return .double(value.asDouble)
        case .string: return .string(value.asString)
        case .variant: return value
        }
    }
}

public final class QBArray: @unchecked Sendable {
    private let type: QBType
    private let lowerBounds: [Int]
    private let upperBounds: [Int]
    private var storage: [QBValue]

    public init(type: QBType, bounds: [Int]) throws {
        guard bounds.count % 2 == 0 else {
            throw QBError.runtime("Invalid DIM bounds")
        }
        self.type = type
        var lowers: [Int] = []
        var uppers: [Int] = []
        for i in stride(from: 0, to: bounds.count, by: 2) {
            lowers.append(bounds[i])
            uppers.append(bounds[i + 1])
        }
        self.lowerBounds = lowers
        self.upperBounds = uppers
        let count = zip(lowers, uppers).reduce(1) { partial, pair in
            partial * (pair.1 - pair.0 + 1)
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

private func defaultValue(for type: QBType) -> QBValue {
    switch type {
    case .integer: return .integer(0)
    case .long: return .long(0)
    case .single: return .single(0)
    case .double: return .double(0)
    case .string: return .string("")
    case .variant: return .integer(0)
    }
}