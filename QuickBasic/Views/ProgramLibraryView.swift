import SwiftUI
import QBEngine

struct ProgramLibraryView: View {
    @ObservedObject var viewModel: IDEViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedProgram: SampleProgram?
    @State private var searchText = ""

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    private var enableSearch: Bool {
        isUITesting || LayoutMetrics.isCompact(horizontalSizeClass)
    }

    private var displayedPrograms: [(ProgramCategory, [SampleProgram])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return SampleProgramLibrary.grouped() }
        return SampleProgramLibrary.grouped().compactMap { category, programs in
            let filtered = programs.filter {
                $0.filename.lowercased().contains(query) || $0.title.lowercased().contains(query)
            }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        Group {
            if LayoutMetrics.isCompact(horizontalSizeClass) {
                compactLibrary
            } else {
                regularLibrary
            }
        }
        .onAppear {
            selectedProgram = SampleProgramLibrary.all.first
        }
    }

    private var programList: some View {
        List {
            ForEach(displayedPrograms, id: \.0) { category, programs in
                Section(category.rawValue) {
                    ForEach(programs) { program in
                        programRow(program)
                    }
                }
            }
        }
        .font(QBTheme.monoFont)
        .modifier(ConditionalSampleSearch(isEnabled: enableSearch, text: $searchText))
    }

    private var compactLibrary: some View {
        NavigationStack {
            programList
                .navigationTitle("Sample Programs")
                .navigationDestination(for: SampleProgram.self) { program in
                    ProgramDetailPane(program: program, viewModel: viewModel, onClose: { dismiss() })
                }
        }
    }

    private var regularLibrary: some View {
        NavigationSplitView {
            List(selection: $selectedProgram) {
                ForEach(displayedPrograms, id: \.0) { category, programs in
                    Section(category.rawValue) {
                        ForEach(programs) { program in
                            programRow(program)
                                .tag(program)
                        }
                    }
                }
            }
            .font(QBTheme.monoFont)
            .navigationTitle("Sample Programs")
            .modifier(ConditionalSampleSearch(isEnabled: enableSearch, text: $searchText))
        } detail: {
            if let program = selectedProgram {
                ProgramDetailPane(program: program, viewModel: viewModel, onClose: { dismiss() })
            } else {
                ContentUnavailableView(
                    "Select a Program",
                    systemImage: "doc.text",
                    description: Text("Choose one of 80 sample programs to load into the editor.")
                )
            }
        }
    }

    @ViewBuilder
    private func programRow(_ program: SampleProgram) -> some View {
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(program.filename)
                .font(QBTheme.monoTitle)
            Text(program.title)
                .font(QBTheme.monoSmall)
        }
        .accessibilityIdentifier("sample_\(program.filename)")

        if LayoutMetrics.isCompact(horizontalSizeClass) {
            NavigationLink(value: program) {
                label
            }
        } else {
            label
        }
    }
}

private struct ProgramDetailPane: View {
    let program: SampleProgram
    @ObservedObject var viewModel: IDEViewModel
    let onClose: () -> Void
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(program.filename)
                        .font(QBTheme.monoTitle)
                        .foregroundStyle(QBTheme.editorBackground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(QBTheme.menuText.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(program.title)
                        .font(.headline)
                    Text(program.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                BasicCodePreview(code: program.code)

                actionButtons
            }
            .padding(LayoutMetrics.isCompact(horizontalSizeClass) ? 16 : 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            SampleActionButton(title: "Load", icon: "doc.text", style: .primary) {
                viewModel.loadSampleProgram(program)
                onClose()
            }
            .accessibilityIdentifier("loadProgram")

            SampleActionButton(title: "Load & Run", icon: "play.fill", style: .accent) {
                viewModel.loadSampleProgram(program)
                onClose()
                viewModel.runProgram()
            }
            .accessibilityIdentifier("loadAndRun")

            SampleActionButton(title: "Cancel", icon: "xmark", style: .secondary) {
                onClose()
            }
        }
    }
}

private struct SampleActionButton: View {
    enum Style {
        case primary, accent, secondary
    }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary: .white
        case .accent: Color(red: 0.05, green: 0.08, blue: 0.2)
        case .secondary: QBTheme.menuText.opacity(0.9)
        }
    }

    private var background: Color {
        switch style {
        case .primary: Color(red: 0.1, green: 0.35, blue: 0.85)
        case .accent: Color(red: 0.95, green: 0.88, blue: 0.35)
        case .secondary: Color(red: 0.05, green: 0.1, blue: 0.35)
        }
    }

    private var border: Color {
        switch style {
        case .primary: Color.white.opacity(0.35)
        case .accent: Color.white.opacity(0.55)
        case .secondary: QBTheme.menuText.opacity(0.25)
        }
    }
}

private struct ConditionalSampleSearch: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(text: $text, prompt: "Filter samples")
                .accessibilityIdentifier("sampleProgramSearch")
        } else {
            content
        }
    }
}