import Foundation

public protocol QBInputHandler: AnyObject, Sendable {
    func prompt(_ text: String) async throws -> String
}

public protocol QBOutputHandler: AnyObject, Sendable {
    func write(_ text: String)
    func writeLine(_ text: String)
    func clear()
    func beep()
}

public final class ConsoleOutputHandler: QBOutputHandler, @unchecked Sendable {
    public private(set) var buffer: String = ""

    public init() {}

    public func write(_ text: String) {
        buffer += text
    }

    public func writeLine(_ text: String) {
        buffer += text + "\n"
    }

    public func clear() {
        buffer = ""
    }

    public func beep() {}
}