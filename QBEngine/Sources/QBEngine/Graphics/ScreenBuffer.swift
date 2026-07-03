import Foundation

public struct QBColor: Sendable, Equatable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum ScreenMode: Sendable, Equatable {
    case text(columns: Int, rows: Int)
    case medium(width: Int, height: Int, colors: Int)
    case high(width: Int, height: Int)
    case vga256(width: Int, height: Int)
}

public final class ScreenBuffer: @unchecked Sendable {
    public private(set) var mode: ScreenMode = .text(columns: 80, rows: 25)
    public private(set) var pixels: [QBColor]
    public private(set) var width: Int = 80
    public private(set) var height: Int = 25
    public var foreground: Int = 15
    public var background: Int = 0
    public var cursorRow: Int = 1
    public var cursorCol: Int = 1
    public var textRows: Int = 25
    public var textCols: Int = 80
    public var textCells: [Character]

    private static let palette: [QBColor] = [
        QBColor(red: 0, green: 0, blue: 0),
        QBColor(red: 0, green: 0, blue: 170),
        QBColor(red: 0, green: 170, blue: 0),
        QBColor(red: 0, green: 170, blue: 170),
        QBColor(red: 170, green: 0, blue: 0),
        QBColor(red: 170, green: 0, blue: 170),
        QBColor(red: 170, green: 85, blue: 0),
        QBColor(red: 170, green: 170, blue: 170),
        QBColor(red: 85, green: 85, blue: 85),
        QBColor(red: 85, green: 85, blue: 255),
        QBColor(red: 85, green: 255, blue: 85),
        QBColor(red: 85, green: 255, blue: 255),
        QBColor(red: 255, green: 85, blue: 85),
        QBColor(red: 255, green: 85, blue: 255),
        QBColor(red: 255, green: 255, blue: 85),
        QBColor(red: 255, green: 255, blue: 255)
    ]

    public init() {
        pixels = Array(repeating: Self.palette[0], count: 80 * 25)
        textCells = Array(repeating: " ", count: 80 * 25)
    }

    /// Restores the default text mode and clears all pixels (e.g. before running a new program).
    public func reset() {
        mode = .text(columns: 80, rows: 25)
        width = 80
        height = 25
        textCols = 80
        textRows = 25
        foreground = 15
        background = 0
        cls()
    }

    public var isGraphicsMode: Bool {
        switch mode {
        case .text:
            return false
        case .medium, .high, .vga256:
            return true
        }
    }

    public func setScreen(modeValue: Int, colorSwitch: Int = 0, ap: Int = 0) {
        _ = colorSwitch
        _ = ap
        switch modeValue {
        case 0:
            mode = .text(columns: 80, rows: 25)
            resize(width: 640, height: 400)
            textCols = 80
            textRows = 25
        case 1:
            mode = .medium(width: 320, height: 200, colors: 2)
            resize(width: 320, height: 200)
            textCols = 40
            textRows = 25
        case 2:
            mode = .high(width: 640, height: 200)
            resize(width: 640, height: 200)
            textCols = 80
            textRows = 25
        case 13:
            mode = .vga256(width: 320, height: 200)
            resize(width: 320, height: 200)
            textCols = 40
            textRows = 25
        default:
            mode = .text(columns: 80, rows: 25)
            resize(width: 640, height: 400)
            textCols = 80
            textRows = 25
        }
        cls()
    }

    public func cls() {
        let bg = colorAt(index: background)
        pixels = Array(repeating: bg, count: width * height)
        textCells = Array(repeating: " ", count: textCols * textRows)
        cursorRow = 1
        cursorCol = 1
    }

    public func setColor(foreground fg: Int, background bg: Int? = nil) {
        foreground = max(0, min(fg, 15))
        if let bg {
            background = max(0, min(bg, 15))
        }
    }

    public func locate(row: Int, col: Int) {
        cursorRow = max(1, min(row, textRows))
        cursorCol = max(1, min(col, textCols))
    }

    public func writeText(_ text: String, advanceLine: Bool) {
        for char in text {
            if char == "\n" {
                cursorCol = 1
                cursorRow += 1
                if cursorRow > textRows {
                    scrollText()
                }
                continue
            }
            let index = (cursorRow - 1) * textCols + (cursorCol - 1)
            if index >= 0 && index < textCells.count {
                textCells[index] = char
            }
            drawCharacter(char, row: cursorRow, col: cursorCol)
            cursorCol += 1
            if cursorCol > textCols {
                cursorCol = 1
                cursorRow += 1
                if cursorRow > textRows {
                    scrollText()
                }
            }
        }
        if advanceLine {
            cursorCol = 1
            cursorRow += 1
            if cursorRow > textRows {
                scrollText()
            }
        }
    }

    public func pset(x: Int, y: Int, colorIndex: Int) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        pixels[y * width + x] = colorAt(index: colorIndex)
    }

    public func preset(x: Int, y: Int, colorIndex: Int) {
        pset(x: x, y: y, colorIndex: colorIndex)
    }

    public func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, colorIndex: Int, boxed: Bool) {
        if boxed {
            fillRect(x1: x1, y1: y1, x2: x2, y2: y2, colorIndex: colorIndex)
            return
        }
        var x = x1
        var y = y1
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let sx = x1 < x2 ? 1 : -1
        let sy = y1 < y2 ? 1 : -1
        var err = dx - dy

        while true {
            pset(x: x, y: y, colorIndex: colorIndex)
            if x == x2 && y == y2 { break }
            let e2 = err * 2
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
    }

    public func drawCircle(cx: Int, cy: Int, radius: Int, colorIndex: Int) {
        guard radius > 0 else {
            pset(x: cx, y: cy, colorIndex: colorIndex)
            return
        }
        var x = 0
        var y = radius
        var d = 3 - 2 * radius
        while x <= y {
            plotCirclePoints(cx: cx, cy: cy, x: x, y: y, color: colorIndex)
            if d < 0 {
                d += 4 * x + 6
            } else {
                d += 4 * (x - y) + 10
                y -= 1
            }
            x += 1
        }
    }

    public func colorAt(index: Int) -> QBColor {
        if case .vga256 = mode {
            return vgaColor(index)
        }
        let clamped = max(0, min(index, 15))
        return Self.palette[clamped]
    }

    private func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: colorAt(index: background), count: width * height)
        textCells = Array(repeating: " ", count: textCols * textRows)
    }

    private func scrollText() {
        for row in 1..<textRows {
            for col in 1...textCols {
                let src = (row) * textCols + (col - 1)
                let dst = (row - 1) * textCols + (col - 1)
                textCells[dst] = textCells[src]
            }
        }
        for col in 1...textCols {
            textCells[(textRows - 1) * textCols + (col - 1)] = " "
        }
        cursorRow = textRows
    }

    private func drawCharacter(_ char: Character, row: Int, col: Int) {
        let charWidth = max(8, width / textCols)
        let charHeight = max(12, height / textRows)
        let x0 = (col - 1) * charWidth
        let y0 = (row - 1) * charHeight
        let color = colorAt(index: foreground)
        for dy in 0..<charHeight {
            for dx in 0..<charWidth {
                if char == " " { continue }
                let px = x0 + dx
                let py = y0 + dy
                if px < width && py < height {
                    pixels[py * width + px] = color
                }
            }
        }
    }

    private func fillRect(x1: Int, y1: Int, x2: Int, y2: Int, colorIndex: Int) {
        let left = min(x1, x2)
        let right = max(x1, x2)
        let top = min(y1, y2)
        let bottom = max(y1, y2)
        for y in top...bottom {
            for x in left...right {
                pset(x: x, y: y, colorIndex: colorIndex)
            }
        }
    }

    private func plotCirclePoints(cx: Int, cy: Int, x: Int, y: Int, color: Int) {
        pset(x: cx + x, y: cy + y, colorIndex: color)
        pset(x: cx - x, y: cy + y, colorIndex: color)
        pset(x: cx + x, y: cy - y, colorIndex: color)
        pset(x: cx - x, y: cy - y, colorIndex: color)
        pset(x: cx + y, y: cy + x, colorIndex: color)
        pset(x: cx - y, y: cy + x, colorIndex: color)
        pset(x: cx + y, y: cy - x, colorIndex: color)
        pset(x: cx - y, y: cy - x, colorIndex: color)
    }

    private func vgaColor(_ index: Int) -> QBColor {
        let hue = Double(index) / 256.0
        let r = UInt8((sin(hue * 6.28) * 0.5 + 0.5) * 255)
        let g = UInt8((sin(hue * 6.28 + 2.1) * 0.5 + 0.5) * 255)
        let b = UInt8((sin(hue * 6.28 + 4.2) * 0.5 + 0.5) * 255)
        return QBColor(red: r, green: g, blue: b)
    }
}