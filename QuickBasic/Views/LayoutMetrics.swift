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

    static let compactMenuSectionHeaderHeight: CGFloat = 22
    static let compactMenuItemRowHeight: CGFloat = 23
    static let compactMenuSeparatorHeight: CGFloat = 7
    static let compactBottomChromeHeight: CGFloat = 88

    static func compactOverflowContentHeight(
        sectionCount: Int,
        itemCount: Int,
        separatorCount: Int
    ) -> CGFloat {
        CGFloat(sectionCount) * compactMenuSectionHeaderHeight
            + CGFloat(itemCount) * compactMenuItemRowHeight
            + CGFloat(separatorCount) * compactMenuSeparatorHeight
    }

    static func compactOverflowAvailableHeight(
        screenHeight: CGFloat,
        menuHeaderHeight: CGFloat,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        screenHeight - safeAreaTop - menuHeaderHeight - compactBottomChromeHeight
    }
}