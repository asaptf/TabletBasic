import SwiftUI

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
    @State private var openMenuTitle: String?
    @State private var highlightedIndex: Int = 0
    @State private var anchors: [Int: CGFloat] = [:]

    private let menus: [DOSMenuDefinition] = [
        DOSMenuDefinition(title: "File", items: [
            .init("New...", action: .newFile),
            .init("Open Sample Program...", action: .openSamples),
            .separator,
            .init("Clear Output", action: .clear)
        ]),
        DOSMenuDefinition(title: "Edit", items: [
            .init("Insert Line Numbers", action: .insertLineNumber)
        ]),
        DOSMenuDefinition(title: "View", items: [
            .init("Return to Editor", action: .returnToEditor)
        ]),
        DOSMenuDefinition(title: "Search", items: [
            .init("Find...", action: nil, enabled: false),
            .init("Find Next", action: nil, enabled: false)
        ]),
        DOSMenuDefinition(title: "Run", items: [
            .init("Start", action: .run),
            .init("Restart", action: .run)
        ]),
        DOSMenuDefinition(title: "Debug", items: [
            .init("Step", action: nil, enabled: false),
            .init("Trace Into", action: nil, enabled: false)
        ]),
        DOSMenuDefinition(title: "Options", items: [
            .init("Display...", action: nil, enabled: false),
            .init("Language...", action: nil, enabled: false)
        ]),
        DOSMenuDefinition(title: "Help", items: [
            .init("Help (F1)", action: .help),
            .init("Learning Guide", action: .survivalGuide),
            .separator,
            .init("About \(AppBranding.name)...", action: .about)
        ])
    ]

    var body: some View {
        VStack(spacing: 0) {
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
            .frame(height: 28)
            .background(QBTheme.menuBackground)
            .coordinateSpace(name: "menubar")
            .onPreferenceChange(MenuAnchorKey.self) { anchors = $0 }
            .overlay(alignment: .topLeading) {
                if let openTitle = openMenuTitle,
                   let menu = menus.first(where: { $0.title == openTitle }),
                   let menuIndex = menus.firstIndex(where: { $0.title == openTitle }) {
                    dosDropdown(menu: menu)
                        .offset(x: anchors[menuIndex] ?? menuXOffset(for: menuIndex), y: 28)
                }
            }

            Text(viewModel.documentName)
                .font(QBTheme.monoMenu)
                .foregroundStyle(QBTheme.menuText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
        .background(QBTheme.menuBackground)
        .onChange(of: openMenuTitle) { _, newValue in
            isMenuOpen = newValue != nil
        }
        .onChange(of: isMenuOpen) { _, open in
            if !open {
                openMenuTitle = nil
                highlightedIndex = 0
            }
        }
    }

    private func menuBarButton(_ menu: DOSMenuDefinition) -> some View {
        let isOpen = openMenuTitle == menu.title
        return Button {
            if isOpen {
                closeMenu()
            } else {
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
                if item.isSeparator {
                    Rectangle()
                        .fill(QBTheme.dosMenuBorder)
                        .frame(width: itemWidth - 8, height: 1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
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
                                        ? (highlightedIndex == index ? QBTheme.dosMenuHighlightText : QBTheme.dosMenuText)
                                        : QBTheme.dosMenuDisabledText
                                )
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .frame(width: itemWidth, alignment: .leading)
                        .background(highlightedIndex == index && item.enabled ? QBTheme.dosMenuHighlightBackground : QBTheme.dosMenuBackground)
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.enabled)
                    .accessibilityIdentifier("menuItem_\(menu.title)_\(item.title)")
                    .onHover { hovering in
                        if hovering && item.enabled {
                            highlightedIndex = index
                        }
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
        highlightedIndex = 0
        isMenuOpen = false
    }
}

private struct MenuAnchorKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}