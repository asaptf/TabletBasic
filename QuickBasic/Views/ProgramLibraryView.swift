import SwiftUI
import QBEngine

struct ProgramLibraryView: View {
    @ObservedObject var viewModel: IDEViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedProgram: SampleProgram?
    @State private var searchText = ""

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
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
        NavigationSplitView {
            List(selection: $selectedProgram) {
                ForEach(displayedPrograms, id: \.0) { category, programs in
                    Section(category.rawValue) {
                        ForEach(programs) { program in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.filename)
                                    .font(QBTheme.monoTitle)
                                Text(program.title)
                                    .font(QBTheme.monoSmall)
                            }
                            .tag(program)
                            .accessibilityIdentifier("sample_\(program.filename)")
                        }
                    }
                }
            }
            .navigationTitle("Sample Programs")
            .font(QBTheme.monoFont)
            .modifier(ConditionalSampleSearch(isEnabled: isUITesting, text: $searchText))
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
        .onAppear {
            selectedProgram = SampleProgramLibrary.all.first
        }
    }
}

private struct ProgramDetailPane: View {
    let program: SampleProgram
    @ObservedObject var viewModel: IDEViewModel
    let onClose: () -> Void

    var body: some View {
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

            ScrollView {
                Text(program.code)
                    .font(QBTheme.monoFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
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
            }
        }
        .padding(20)
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