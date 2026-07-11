import Foundation

public enum QBError: Error, Equatable, Sendable, LocalizedError {
    case syntax(String)
    case runtime(String)
    case endProgram
    case stopProgram
    case breakLoop
    case breakDo
    case breakWhile
    case exitSub
    case exitFunction
    case programStopped
    case breakpointHit
    case stepComplete

    public var errorDescription: String? {
        switch self {
        case .syntax(let message): return "Syntax error: \(message)"
        case .runtime(let message): return "Runtime error: \(message)"
        case .endProgram: return "END"
        case .stopProgram: return "STOP"
        case .breakLoop: return nil
        case .breakDo: return nil
        case .breakWhile: return nil
        case .exitSub: return nil
        case .exitFunction: return nil
        case .programStopped: return "Program stopped"
        case .breakpointHit: return "Breakpoint"
        case .stepComplete: return "Step"
        }
    }
}
