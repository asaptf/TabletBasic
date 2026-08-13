import Foundation

public protocol QBInputHandler: AnyObject, Sendable {
    func prompt(_ text: String) async throws -> String
}

public protocol QBKeySource: AnyObject, Sendable {
    func pollKey() -> String
}

/// Testable FIFO of keystrokes for `INKEY$`. The IDE and tests share this type.
public final class QueueKeySource: QBKeySource, @unchecked Sendable {
    private var queue: [String] = []
    private let lock = NSLock()

    public init() {}

    public func enqueue(_ key: String) {
        lock.lock()
        queue.append(key)
        lock.unlock()
    }

    public func pollKey() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return "" }
        return queue.removeFirst()
    }
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