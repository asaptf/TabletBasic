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
    public private(set) var pixelIndices: [Int]
    public private(set) var width: Int = 80
    public private(set) var height: Int = 25
    public var foreground: Int = 15
    public var background: Int = 0
    public var cursorRow: Int = 1
    public var cursorCol: Int = 1
    public var textRows: Int = 25
    public var textCols: Int = 80
    public var textCells: [Character]
    public var sprites: [String: [Int]] = [:]

    private var drawX: Int = 0
    private var drawY: Int = 0
    private var drawAngle: Int = 0
    private var drawScale: Double = 1.0

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

    /// Standard VGA mode 13h DAC palette (256 colors).
    private static let vgaPalette: [QBColor] = {
        var colors = palette
        let levels: [UInt8] = [0, 51, 102, 153, 204, 255]
        for red in levels {
            for green in levels {
                for blue in levels {
                    colors.append(QBColor(red: red, green: green, blue: blue))
                }
            }
        }
        for level in 0..<24 {
            let gray = UInt8(level * 10 + 8)
            colors.append(QBColor(red: gray, green: gray, blue: gray))
        }
        return colors
    }()

    public init() {
        pixels = Array(repeating: Self.palette[0], count: 80 * 25)
        pixelIndices = Array(repeating: 0, count: 80 * 25)
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
        sprites.removeAll()
        drawX = 0
        drawY = 0
        drawAngle = 0
        drawScale = 1.0
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
        pixelIndices = Array(repeating: background, count: width * height)
        textCells = Array(repeating: " ", count: textCols * textRows)
        cursorRow = 1
        cursorCol = 1
    }

    public func setColor(foreground fg: Int, background bg: Int? = nil) {
        foreground = max(0, min(fg, 255))
        if let bg {
            background = max(0, min(bg, 255))
        }
    }

    public func locate(row: Int, col: Int) {
        cursorRow = max(1, min(row, textRows))
        cursorCol = max(1, min(col, textCols))
    }

    public func textAt(row: Int, col: Int) -> Character {
        let r = max(1, min(row, textRows))
        let c = max(1, min(col, textCols))
        let index = (r - 1) * textCols + (c - 1)
        guard index >= 0 && index < textCells.count else { return " " }
        return textCells[index]
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
            if !isGraphicsMode {
                drawCharacter(char, row: cursorRow, col: cursorCol)
            }
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
        let idx = y * width + x
        pixelIndices[idx] = colorIndex
        pixels[idx] = colorAt(index: colorIndex)
    }

    public func point(x: Int, y: Int) -> Int {
        guard x >= 0, y >= 0, x < width, y < height else { return -1 }
        return pixelIndices[y * width + x]
    }

    public func preset(x: Int, y: Int, colorIndex: Int) {
        pset(x: x, y: y, colorIndex: colorIndex)
    }

    public func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, colorIndex: Int, style: LineBoxStyle) {
        switch style {
        case .filled:
            fillRect(x1: x1, y1: y1, x2: x2, y2: y2, colorIndex: colorIndex)
        case .box:
            // Outline only
            drawLine(x1: x1, y1: y1, x2: x2, y2: y1, colorIndex: colorIndex, style: .none)
            drawLine(x1: x2, y1: y1, x2: x2, y2: y2, colorIndex: colorIndex, style: .none)
            drawLine(x1: x2, y1: y2, x2: x1, y2: y2, colorIndex: colorIndex, style: .none)
            drawLine(x1: x1, y1: y2, x2: x1, y2: y1, colorIndex: colorIndex, style: .none)
        case .none:
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
    }

    /// Backward-compatible wrapper used by older call sites.
    public func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, colorIndex: Int, boxed: Bool) {
        drawLine(x1: x1, y1: y1, x2: x2, y2: y2, colorIndex: colorIndex, style: boxed ? .filled : .none)
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

    public func paint(x: Int, y: Int, paintColor: Int, borderColor: Int?) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let target = point(x: x, y: y)
        if let border = borderColor, target == border { return }
        if target == paintColor { return }
        var stack: [(Int, Int)] = [(x, y)]
        var visited = Set<Int>()
        while let (cx, cy) = stack.popLast() {
            guard cx >= 0, cy >= 0, cx < width, cy < height else { continue }
            let key = cy * width + cx
            if visited.contains(key) { continue }
            visited.insert(key)
            let current = point(x: cx, y: cy)
            if let border = borderColor {
                if current == border { continue }
            } else if current != target {
                continue
            }
            pset(x: cx, y: cy, colorIndex: paintColor)
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }

    /// Executes a subset of QB DRAW macro language: U/D/L/R/E/F/G/H, M, B, N, C, A, S, numbers.
    public func drawMacro(_ command: String) {
        var i = command.startIndex
        var noDrawNext = false
        var blankMove = false
        while i < command.endIndex {
            let ch = command[i].uppercased()
            i = command.index(after: i)
            switch ch {
            case " ":
                continue
            case "B":
                blankMove = true
            case "N":
                noDrawNext = true
            case "C":
                let (n, next) = readNumber(command, from: i)
                i = next
                if let n { foreground = n }
            case "A":
                let (n, next) = readNumber(command, from: i)
                i = next
                if let n { drawAngle = (n % 4) * 90 }
            case "S":
                let (n, next) = readNumber(command, from: i)
                i = next
                if let n { drawScale = Double(n) / 4.0 }
            case "M":
                let rel = i < command.endIndex && (command[i] == "+" || command[i] == "-")
                let (xVal, afterX) = readSignedNumber(command, from: i)
                i = afterX
                if i < command.endIndex && command[i] == "," {
                    i = command.index(after: i)
                }
                let (yVal, afterY) = readSignedNumber(command, from: i)
                i = afterY
                let nx = rel ? drawX + (xVal ?? 0) : (xVal ?? drawX)
                let ny = rel ? drawY + (yVal ?? 0) : (yVal ?? drawY)
                moveDraw(toX: nx, toY: ny, blank: blankMove, noDraw: noDrawNext)
                blankMove = false
                noDrawNext = false
            case "U", "D", "L", "R", "E", "F", "G", "H":
                let (n, next) = readNumber(command, from: i)
                i = next
                let dist = Int(Double(n ?? 1) * drawScale)
                var dx = 0
                var dy = 0
                switch ch {
                case "U": dy = -dist
                case "D": dy = dist
                case "L": dx = -dist
                case "R": dx = dist
                case "E": dx = dist; dy = -dist
                case "F": dx = dist; dy = dist
                case "G": dx = -dist; dy = dist
                case "H": dx = -dist; dy = -dist
                default: break
                }
                // Apply angle rotation in 90° steps
                let steps = ((drawAngle % 360) + 360) % 360 / 90
                for _ in 0..<steps {
                    let tx = dx
                    dx = -dy
                    dy = tx
                }
                moveDraw(toX: drawX + dx, toY: drawY + dy, blank: blankMove, noDraw: noDrawNext)
                blankMove = false
                noDrawNext = false
            default:
                continue
            }
        }
    }

    public func getSprite(x1: Int, y1: Int, x2: Int, y2: Int, name: String) {
        let left = max(0, min(x1, x2))
        let right = min(width - 1, max(x1, x2))
        let top = max(0, min(y1, y2))
        let bottom = min(height - 1, max(y1, y2))
        var data: [Int] = [right - left + 1, bottom - top + 1]
        for y in top...bottom {
            for x in left...right {
                data.append(point(x: x, y: y))
            }
        }
        sprites[name.uppercased()] = data
    }

    public func putSprite(x: Int, y: Int, name: String) {
        guard let data = sprites[name.uppercased()], data.count >= 2 else { return }
        let w = data[0]
        let h = data[1]
        var i = 2
        for dy in 0..<h {
            for dx in 0..<w {
                if i < data.count {
                    pset(x: x + dx, y: y + dy, colorIndex: data[i])
                    i += 1
                }
            }
        }
    }

    public func colorAt(index: Int) -> QBColor {
        if case .vga256 = mode {
            let clamped = max(0, min(index, 255))
            return Self.vgaPalette[min(clamped, Self.vgaPalette.count - 1)]
        }
        let clamped = max(0, min(index, 15))
        return Self.palette[clamped]
    }

    private func moveDraw(toX: Int, toY: Int, blank: Bool, noDraw: Bool) {
        if !blank {
            drawLine(x1: drawX, y1: drawY, x2: toX, y2: toY, colorIndex: foreground, style: .none)
        }
        if !noDraw {
            drawX = toX
            drawY = toY
        }
    }

    private func readNumber(_ s: String, from: String.Index) -> (Int?, String.Index) {
        var i = from
        while i < s.endIndex && s[i].isWhitespace { i = s.index(after: i) }
        var digits = ""
        while i < s.endIndex && s[i].isNumber {
            digits.append(s[i])
            i = s.index(after: i)
        }
        return (digits.isEmpty ? nil : Int(digits), i)
    }

    private func readSignedNumber(_ s: String, from: String.Index) -> (Int?, String.Index) {
        var i = from
        while i < s.endIndex && s[i].isWhitespace { i = s.index(after: i) }
        var sign = 1
        if i < s.endIndex && (s[i] == "+" || s[i] == "-") {
            if s[i] == "-" { sign = -1 }
            i = s.index(after: i)
        }
        let (n, next) = readNumber(s, from: i)
        return (n.map { $0 * sign }, next)
    }

    private func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: colorAt(index: background), count: width * height)
        pixelIndices = Array(repeating: background, count: width * height)
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
                    let idx = py * width + px
                    pixels[idx] = color
                    pixelIndices[idx] = foreground
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
}
