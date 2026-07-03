import Foundation

public enum ProcedureKind: String, Sendable {
    case sub
    case function
}

public struct ProcedureParam: Sendable {
    public let name: String
    public let type: QBType

    public init(name: String, type: QBType) {
        self.name = name
        self.type = type
    }
}

public struct ProcedureDef: Sendable {
    public let name: String
    public let kind: ProcedureKind
    public let params: [ProcedureParam]
    public let returnType: QBType
    public let body: [ProgramLine]
    public let sourceLine: Int

    public init(
        name: String,
        kind: ProcedureKind,
        params: [ProcedureParam],
        returnType: QBType,
        body: [ProgramLine],
        sourceLine: Int
    ) {
        self.name = name.uppercased()
        self.kind = kind
        self.params = params
        self.returnType = returnType
        self.body = body
        self.sourceLine = sourceLine
    }
}