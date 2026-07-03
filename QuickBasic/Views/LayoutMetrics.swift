import SwiftUI

enum LayoutMetrics {
    static func isCompact(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .compact
    }

    static func lineNumberGutterWidth(compact: Bool) -> CGFloat {
        compact ? 36 : 48
    }

    static func welcomeMaxWidth(compact: Bool) -> CGFloat {
        compact ? 340 : 520
    }

    static func outputTextMaxHeight(compact: Bool, totalHeight: CGFloat, hasGraphics: Bool) -> CGFloat {
        guard hasGraphics else { return .infinity }
        if compact {
            return max(96, totalHeight * 0.38)
        }
        return 120
    }

    static func graphicsMaxHeight(compact: Bool, totalHeight: CGFloat, hasGraphics: Bool) -> CGFloat? {
        guard hasGraphics else { return nil }
        if compact {
            return max(140, totalHeight * 0.52)
        }
        return nil
    }
}