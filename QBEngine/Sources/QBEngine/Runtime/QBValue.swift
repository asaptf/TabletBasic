import Foundation

public enum QBValue: Sendable, Equatable {
    case integer(Int)
    case long(Int)
    case single(Double)
    case double(Double)
    case string(String)
    case bool(Bool)
    case record(typeName: String, fields: [String: QBValue])

    public var asDouble: Double {
        switch self {
        case .integer(let v): return Double(v)
        case .long(let v): return Double(v)
        case .single(let v): return v
        case .double(let v): return v
        case .string(let v): return Double(v) ?? 0
        case .bool(let v): return v ? -1 : 0
        case .record: return 0
        }
    }

    public var asInt: Int {
        switch self {
        case .integer(let v): return v
        case .long(let v): return v
        case .single(let v): return Int(v)
        case .double(let v): return Int(v)
        case .string(let v): return Int(v) ?? 0
        case .bool(let v): return v ? -1 : 0
        case .record: return 0
        }
    }

    public var asString: String {
        switch self {
        case .integer(let v): return String(v)
        case .long(let v): return String(v)
        case .single(let v): return formatSingle(v)
        case .double(let v): return String(v)
        case .string(let v): return v
        case .bool(let v): return v ? "-1" : "0"
        case .record(let typeName, _): return "{\(typeName)}"
        }
    }

    public var asBool: Bool {
        switch self {
        case .bool(let v): return v
        case .integer(let v): return v != 0
        case .long(let v): return v != 0
        case .single(let v): return v != 0
        case .double(let v): return v != 0
        case .string(let v): return !v.isEmpty && v != "0"
        case .record: return true
        }
    }

    public static func from(_ value: Double, type: QBType) -> QBValue {
        switch type {
        case .integer: return .integer(Int(value))
        case .long: return .long(Int(value))
        case .single: return .single(Float(value).rounded(toPlaces: 6))
        case .double: return .double(value)
        case .string: return .string(String(value))
        case .variant: return value.rounded() == value ? .integer(Int(value)) : .single(value)
        case .userType: return .integer(Int(value))
        }
    }

    private func formatSingle(_ value: Double) -> String {
        let rounded = Float(value).rounded(toPlaces: 6)
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}

private extension Float {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (Double(self) * divisor).rounded() / divisor
    }
}
