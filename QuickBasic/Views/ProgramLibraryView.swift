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
                    description: Text("Choose one of 20 sample programs to load into the editor.")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.filename)
                        .font(.title2.bold())
                    Text(program.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(program.description)
                        .foregroundStyle(.secondary)
                }

                Text(program.code)
                    .font(QBTheme.monoFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                actionButtons
            }
            .padding(LayoutMetrics.isCompact(horizontalSizeClass) ? 16 : 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let buttons = Group {
            Button("Load into Editor") {
                viewModel.loadSampleProgram(program)
                onClose()
            }
            .buttonStyle(.borderedProminent)

            Button("Load && Run") {
                viewModel.loadSampleProgram(program)
                onClose()
                viewModel.runProgram()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("loadAndRun")

            Button("Cancel") { onClose() }
                .buttonStyle(.bordered)
        }

        if LayoutMetrics.isCompact(horizontalSizeClass) {
            VStack(spacing: 10) {
                buttons
            }
        } else {
            HStack(spacing: 12) {
                buttons
            }
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