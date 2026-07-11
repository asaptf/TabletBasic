import Foundation

/// One source line tagged with its original 1-based physical line number
/// (editor / breakpoint coordinates).
struct PhysicalLine: Sendable {
    let text: String
    let sourceLine: Int

    init(text: String, sourceLine: Int) {
        self.text = text
        self.sourceLine = sourceLine
    }
}
