import SwiftUI

enum QBTheme {
    // Classic DOS VGA text mode: blue background #0000AA
    static let background = Color(red: 0, green: 0, blue: 170 / 255)
    static let menuBackground = Color(red: 0, green: 0, blue: 170 / 255)
    static let editorBackground = Color(red: 0, green: 0, blue: 170 / 255)
    static let immediateBackground = Color(red: 0, green: 0, blue: 140 / 255)
    static let statusBackground = Color(red: 0, green: 0, blue: 170 / 255)

    static let menuText = Color.white
    static let menuBarActiveBackground = Color.white
    static let menuBarActiveText = Color.black

    static let editorText = Color.white
    static let lineNumberText = Color(red: 0.7, green: 0.85, blue: 1.0)
    static let immediateText = Color.white
    static let statusText = Color.white

    static let dialogBackground = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let dialogText = Color.black
    static let dialogBorder = Color.black

    static let selectionHighlight = Color(red: 0, green: 0, blue: 0.45)

    // DOS-style dropdown menus (1980s gray palette)
    static let dosMenuBackground = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let dosMenuText = Color.black
    static let dosMenuHighlightBackground = Color.black
    static let dosMenuHighlightText = Color.white
    static let dosMenuBorder = Color.black
    static let dosMenuDisabledText = Color(red: 0.45, green: 0.45, blue: 0.45)

    static let monoFont = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoMenu = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monoTitle = Font.system(size: 15, weight: .semibold, design: .monospaced)
    static let dialogFont = Font.system(size: 14, weight: .regular, design: .monospaced)
}