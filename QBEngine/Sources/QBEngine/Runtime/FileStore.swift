import Foundation

/// Sandboxed sequential file I/O for OPEN/CLOSE/PRINT#/INPUT#/LINE INPUT#.
public final class FileStore: @unchecked Sendable {
    public private(set) var baseDirectory: URL
    private var openFiles: [Int: OpenFile] = [:]

    private struct OpenFile {
        var mode: FileMode
        var path: URL
        var buffer: String
        var readOffset: String.Index
        var dirty: Bool
    }

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("TabletBasicFiles", isDirectory: true)
            try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            self.baseDirectory = temp
        }
        try? FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    public func setBaseDirectory(_ url: URL) {
        closeAll()
        baseDirectory = url
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func open(path: String, mode: FileMode, handle: Int) throws {
        if openFiles[handle] != nil {
            throw QBError.runtime("File #\(handle) already open")
        }
        let url = resolve(path: path)
        var buffer = ""
        switch mode {
        case .input:
            if !FileManager.default.fileExists(atPath: url.path) {
                throw QBError.runtime("File not found: \(path)")
            }
            buffer = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        case .output:
            buffer = ""
            try "".write(to: url, atomically: true, encoding: .utf8)
        case .append:
            buffer = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        case .random:
            buffer = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        openFiles[handle] = OpenFile(
            mode: mode,
            path: url,
            buffer: buffer,
            readOffset: buffer.startIndex,
            dirty: mode == .output
        )
    }

    public func close(_ handle: Int?) throws {
        if let handle {
            try flushAndRemove(handle)
        } else {
            closeAll()
        }
    }

    public func closeAll() {
        for handle in openFiles.keys {
            try? flushAndRemove(handle)
        }
    }

    public func printHash(_ handle: Int, text: String, newline: Bool) throws {
        guard var file = openFiles[handle] else {
            throw QBError.runtime("File #\(handle) not open")
        }
        guard file.mode == .output || file.mode == .append || file.mode == .random else {
            throw QBError.runtime("File #\(handle) not open for output")
        }
        file.buffer += text
        if newline { file.buffer += "\n" }
        file.dirty = true
        openFiles[handle] = file
    }

    public func inputHash(_ handle: Int) throws -> String {
        guard var file = openFiles[handle] else {
            throw QBError.runtime("File #\(handle) not open")
        }
        guard file.mode == .input || file.mode == .append || file.mode == .random else {
            throw QBError.runtime("File #\(handle) not open for input")
        }
        if file.readOffset >= file.buffer.endIndex {
            throw QBError.runtime("Input past end of file")
        }
        let remaining = file.buffer[file.readOffset...]
        if let comma = remaining.firstIndex(of: ","),
           (remaining.firstIndex(of: "\n").map { comma < $0 } ?? true) {
            let value = String(remaining[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
            file.readOffset = file.buffer.index(after: comma)
            openFiles[handle] = file
            return value
        }
        if let nl = remaining.firstIndex(of: "\n") {
            let value = String(remaining[..<nl]).trimmingCharacters(in: .whitespacesAndNewlines)
            file.readOffset = file.buffer.index(after: nl)
            openFiles[handle] = file
            return value
        }
        let value = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        file.readOffset = file.buffer.endIndex
        openFiles[handle] = file
        return value
    }

    public func lineInputHash(_ handle: Int) throws -> String {
        guard var file = openFiles[handle] else {
            throw QBError.runtime("File #\(handle) not open")
        }
        if file.readOffset >= file.buffer.endIndex {
            throw QBError.runtime("Input past end of file")
        }
        let remaining = file.buffer[file.readOffset...]
        if let nl = remaining.firstIndex(of: "\n") {
            let value = String(remaining[..<nl])
            file.readOffset = file.buffer.index(after: nl)
            openFiles[handle] = file
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        }
        let value = String(remaining)
        file.readOffset = file.buffer.endIndex
        openFiles[handle] = file
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
    }

    public func readFileContents(_ path: String) throws -> String {
        let url = resolve(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func resolve(path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return baseDirectory.appendingPathComponent(path)
    }

    private func flushAndRemove(_ handle: Int) throws {
        guard var file = openFiles[handle] else { return }
        if file.dirty {
            try file.buffer.write(to: file.path, atomically: true, encoding: .utf8)
            file.dirty = false
        }
        openFiles.removeValue(forKey: handle)
    }
}
