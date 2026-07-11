import SwiftUI
import UIKit

struct DOSMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: IDEAction?
    let enabled: Bool

    init(_ title: String, action: IDEAction?, enabled: Bool = true) {
        self.title = title
        self.action = action
        self.enabled = enabled
    }

    static let separator = DOSMenuItem("—", action: nil, enabled: false)
    var isSeparator: Bool { action == nil && title == "—" }
}

struct DOSMenuDefinition: Identifiable {
    let id = UUID()
    let title: String
    let items: [DOSMenuItem]
}

struct DOSMenuBar: View {
    @ObservedObject var viewModel: IDEViewModel
    @Binding var isMenuOpen: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var openMenuTitle: String?
    @State private var compactMenuOpen = false
    @State private var highlightedIndex: Int = 0
    @State private var anchors: [Int: CGFloat] = [:]

    private var menus: [DOSMenuDefinition] {
        [
            DOSMenuDefinition(title: "File", items: [
                .init("New...", action: .newFile),
                .init("Open...", action: .openFile),
                .init("Save", action: .saveFile),
                .init("Save As...", action: .saveAsFile),
                .init("Open Sample Program...", action: .openSamples),
                .separator,
                .init("Clear Output", action: .clear)
            ]),
            DOSMenuDefinition(title: "Edit", items: [
                .init("Find...", action: .find),
                .init("Find Next", action: .findNext),
                .separator,
                .init("Insert Line Numbers", action: .insertLineNumber)
            ]),
            DOSMenuDefinition(title: "View", items: [
                .init("Return to Editor", action: .returnToEditor)
            ]),
            DOSMenuDefinition(title: "Run", items: [
                .init("Start", action: .run),
                .init("Restart", action: .run),
                .init("Stop", action: .stop),
                .separator,
                .init("Step", action: .step),
                .init("Continue", action: .continueRun),
                .init("Toggle Breakpoint", action: .toggleBreakpoint)
            ]),
            DOSMenuDefinition(title: "Help", items: [
                .init("Help (F1)", action: .help),
                .init("Learning Guide", action: .survivalGuide),
                .separator,
                .init("About", action: .about)
            ])
        ]
    }

    private var compactLayout: Bool {
        LayoutMetrics.isCompact(horizontalSizeClass)
    }

    private var menuBarRowHeight: CGFloat {
        compactLayout ? 32 : 28
    }

    var body: some View {
        VStack(spacing: 0) {
            if compactLayout {
                compactMenuBarRow
            } else {
                regularMenuBarRow
            }

            Text(viewModel.documentName)
                .font(compactLayout ? QBTheme.monoSmall : QBTheme.monoMenu)
                .foregroundStyle(QBTheme.menuText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, compactLayout ? 6 : 4)
        }
        .background(QBTheme.menuBackground)
        .overlay(alignment: .topLeading) {
            menuDropdownOverlay
        }
        .onChange(of: openMenuTitle) { _, newValue in
            isMenuOpen = newValue != nil || compactMenuOpen
        }
        .onChange(of: compactMenuOpen) { _, open in
            isMenuOpen = open || openMenuTitle != nil
        }
        .onChange(of: isMenuOpen) { _, open in
            if !open {
                openMenuTitle = nil
                compactMenuOpen = false
                highlightedIndex = 0
            }
        }
    }

    @ViewBuilder
    private var menuDropdownOverlay: some View {
        if compactLayout && compactMenuOpen {
            compactOverflowMenu
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
                .offset(y: menuBarRowHeight)
        } else if !compactLayout,
                  let openTitle = openMenuTitle,
                  let menu = menus.first(where: { $0.title == openTitle }),
                  let menuIndex = menus.firstIndex(where: { $0.title == openTitle }) {
            dosDropdown(menu: menu)
                .offset(x: anchors[menuIndex] ?? menuXOffset(for: menuIndex), y: menuBarRowHeight)
        }
    }

    private var regularMenuBarRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(menus.enumerated()), id: \.element.id) { index, menu in
                menuBarButton(menu)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: MenuAnchorKey.self,
                                value: [index: geo.frame(in: .named("menubar")).minX]
                            )
                        }
                    )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(height: menuBarRowHeight)
        .coordinateSpace(name: "menubar")
        .onPreferenceChange(MenuAnchorKey.self) { anchors = $0 }
    }

    private var compactMenuBarRow: some View {
        HStack(spacing: 8) {
            Button {
                dismissKeyboard()
                compactMenuOpen.toggle()
                if compactMenuOpen {
                    openMenuTitle = nil
                }
            } label: {
                Text("⋯")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(compactMenuOpen ? QBTheme.menuBarActiveText : QBTheme.menuText)
                    .frame(width: 36, height: 28)
                    .background(compactMenuOpen ? QBTheme.menuBarActiveBackground : Color.clear)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menuOverflow")
            .accessibilityLabel("Menu")

            Text("Menu")
                .font(QBTheme.monoMenu)
                .foregroundStyle(QBTheme.menuText)

            Spacer(minLength: 0)

            Button {
                closeMenu()
                viewModel.handleShortcut(.run)
            } label: {
                Text("Run")
                    .font(QBTheme.monoMenu.weight(.semibold))
                    .foregroundStyle(QBTheme.menuText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quickRun")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(height: menuBarRowHeight)
    }

    private var compactOverflowMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(menus) { menu in
                Text(menu.title)
                    .font(QBTheme.monoMenu.weight(.bold))
                    .foregroundStyle(QBTheme.dosMenuText)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(QBTheme.dosMenuBackground)

                ForEach(menu.items) { item in
                    menuItemRow(item, menu: menu, compact: true)
                }
            }
        }
    }

    @ViewBuilder
    private var compactOverflowMenu: some View {
        let idealHeight = compactOverflowIdealHeight
        let availableHeight = compactOverflowAvailableHeight
        let menuBody = compactOverflowMenuBody(
            idealHeight: idealHeight,
            availableHeight: availableHeight
        )

        menuBody
            .frame(width: compactOverflowWidth)
            .background(QBTheme.dosMenuBackground)
            .overlay(
                Rectangle()
                    .strokeBorder(QBTheme.dosMenuBorder, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.25), radius: 0, x: 1, y: 1)
    }

    @ViewBuilder
    private func compactOverflowMenuBody(idealHeight: CGFloat, availableHeight: CGFloat) -> some View {
        if idealHeight <= availableHeight {
            compactOverflowMenuContent
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ScrollView {
                compactOverflowMenuContent
            }
            .frame(height: availableHeight)
        }
    }

    private var compactOverflowWidth: CGFloat {
        let maxLen = menus.flatMap(\.items).map(\.title.count).max() ?? 20
        let preferred = CGFloat(max(220, maxLen * 9 + 40))
        let screenWidth = UIScreen.main.bounds.width
        return min(screenWidth - 16, min(320, preferred))
    }

    private var documentNameRowHeight: CGFloat {
        compactLayout ? 28 : 24
    }

    private var compactOverflowIdealHeight: CGFloat {
        let allItems = menus.flatMap(\.items)
        return LayoutMetrics.compactOverflowContentHeight(
            sectionCount: menus.count,
            itemCount: allItems.filter { !$0.isSeparator }.count,
            separatorCount: allItems.filter(\.isSeparator).count
        )
    }

    private var compactOverflowAvailableHeight: CGFloat {
        LayoutMetrics.compactOverflowAvailableHeight(
            screenHeight: UIScreen.main.bounds.height,
            menuHeaderHeight: menuBarRowHeight + documentNameRowHeight,
            safeAreaTop: keyWindowSafeAreaTop
        )
    }

    private var keyWindowSafeAreaTop: CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.isKeyWindow {
                return window.safeAreaInsets.top
            }
        }
        return 0
    }

    private func menuBarButton(_ menu: DOSMenuDefinition) -> some View {
        let isOpen = openMenuTitle == menu.title
        return Button {
            if isOpen {
                closeMenu()
            } else {
                compactMenuOpen = false
                openMenuTitle = menu.title
                highlightedIndex = firstSelectableIndex(in: menu)
                isMenuOpen = true
            }
        } label: {
            Text(menu.title)
                .font(QBTheme.monoMenu)
                .foregroundStyle(isOpen ? QBTheme.menuBarActiveText : QBTheme.menuText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isOpen ? QBTheme.menuBarActiveBackground : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("menu\(menu.title)")
    }

    private func dosDropdown(menu: DOSMenuDefinition) -> some View {
        let itemWidth = dropdownWidth(for: menu)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.element.id) { index, item in
                menuItemRow(item, menu: menu, width: itemWidth, highlighted: highlightedIndex == index)
                    .onHover { hovering in
                        if hovering && item.enabled {
                            highlightedIndex = index
                        }
                    }
            }
        }
        .padding(.vertical, 2)
        .background(QBTheme.dosMenuBackground)
        .overlay(
            Rectangle()
                .strokeBorder(QBTheme.dosMenuBorder, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.25), radius: 0, x: 1, y: 1)
        .fixedSize()
    }

    @ViewBuilder
    private func menuItemRow(
        _ item: DOSMenuItem,
        menu: DOSMenuDefinition,
        width: CGFloat? = nil,
        highlighted: Bool = false,
        compact: Bool = false
    ) -> some View {
        let verticalPadding: CGFloat = compact ? 2 : 3

        if item.isSeparator {
            Rectangle()
                .fill(QBTheme.dosMenuBorder)
                .frame(width: (width ?? compactOverflowWidth) - 8, height: 1)
                .padding(.horizontal, 4)
                .padding(.vertical, verticalPadding)
        } else {
            Button {
                if item.enabled, let action = item.action {
                    viewModel.handleShortcut(action)
                    closeMenu()
                }
            } label: {
                HStack {
                    Text(item.title)
                        .font(QBTheme.monoMenu)
                        .foregroundStyle(
                            item.enabled
                                ? (highlighted ? QBTheme.dosMenuHighlightText : QBTheme.dosMenuText)
                                : QBTheme.dosMenuDisabledText
                        )
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, verticalPadding)
                .frame(width: width, alignment: .leading)
                .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
                .background(highlighted && item.enabled ? QBTheme.dosMenuHighlightBackground : QBTheme.dosMenuBackground)
            }
            .buttonStyle(.plain)
            .disabled(!item.enabled)
            .accessibilityIdentifier("menuItem_\(menu.title)_\(item.title)")
        }
    }

    private func dropdownWidth(for menu: DOSMenuDefinition) -> CGFloat {
        let maxLen = menu.items.map { $0.title.count }.max() ?? 12
        return CGFloat(max(160, maxLen * 9 + 32))
    }

    private func menuXOffset(for index: Int) -> CGFloat {
        CGFloat(index) * 72 + 4
    }

    private func firstSelectableIndex(in menu: DOSMenuDefinition) -> Int {
        menu.items.firstIndex { $0.enabled && !$0.isSeparator } ?? 0
    }

    func closeMenu() {
        openMenuTitle = nil
        compactMenuOpen = false
        highlightedIndex = 0
        isMenuOpen = false
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct MenuAnchorKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}