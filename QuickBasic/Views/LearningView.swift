import SwiftUI
import QBEngine

struct LearningView: View {
    @ObservedObject var viewModel: IDEViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedLesson: Lesson?
    @State private var completedIDs: Set<String> = LessonProgressStore.completedIDs()

    var body: some View {
        Group {
            if LayoutMetrics.isCompact(horizontalSizeClass) {
                compactGuide
            } else {
                regularGuide
            }
        }
        .onAppear {
            if selectedLesson == nil {
                selectedLesson = LessonCatalog.all.first
            }
        }
    }

    private var lessonList: some View {
        List(LessonCatalog.all, selection: $selectedLesson) { lesson in
            lessonRow(lesson)
        }
        .navigationTitle(AppBranding.guideTitle)
    }

    private var compactGuide: some View {
        NavigationStack {
            List(LessonCatalog.all) { lesson in
                NavigationLink(value: lesson) {
                    lessonLabel(lesson)
                }
            }
            .navigationTitle(AppBranding.guideTitle)
            .navigationDestination(for: Lesson.self) { lesson in
                LessonDetailView(
                    lesson: lesson,
                    viewModel: viewModel,
                    onClose: { dismiss() },
                    onProgressChange: { completedIDs = LessonProgressStore.completedIDs() }
                )
            }
        }
    }

    private var regularGuide: some View {
        NavigationSplitView {
            lessonList
        } detail: {
            if let lesson = selectedLesson {
                LessonDetailView(
                    lesson: lesson,
                    viewModel: viewModel,
                    onClose: { dismiss() },
                    onProgressChange: { completedIDs = LessonProgressStore.completedIDs() }
                )
            } else {
                ContentUnavailableView(
                    AppBranding.guideTitle,
                    systemImage: "book",
                    description: Text("Select a chapter to begin learning.")
                )
            }
        }
    }

    @ViewBuilder
    private func lessonRow(_ lesson: Lesson) -> some View {
        lessonLabel(lesson)
            .padding(.vertical, 4)
            .tag(lesson)
    }

    private func lessonLabel(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Chapter \(lesson.chapter)")
                    .font(QBTheme.monoSmall)
                if completedIDs.contains(lesson.id) {
                    Text("DONE")
                        .font(QBTheme.monoSmall)
                        .foregroundStyle(QBTheme.editorBackground)
                }
            }
            Text(lesson.title)
                .font(.headline)
            Text(lesson.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @ObservedObject var viewModel: IDEViewModel
    var onClose: (() -> Void)?
    var onProgressChange: (() -> Void)?

    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showHints = false
    @State private var checkResult: LessonCheckResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chapter \(lesson.chapter)")
                        .font(QBTheme.monoTitle)
                        .foregroundStyle(QBTheme.editorBackground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(QBTheme.menuText.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(lesson.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !lesson.relatedSamples.isEmpty {
                    relatedSamplesSection
                }

                BasicCodePreview(code: lesson.starterCode)

                actionButtons

                if let checkResult {
                    Text(checkResult.passed ? "PASS" : "FAIL")
                        .font(QBTheme.monoTitle)
                        .foregroundStyle(QBTheme.editorBackground)
                    if let error = checkResult.error {
                        Text(error)
                            .font(QBTheme.monoSmall)
                    } else if !checkResult.passed {
                        Text("Expected output to contain: \(lesson.expectedOutput ?? "")")
                            .font(QBTheme.monoSmall)
                    }
                }

                if showHints {
                    ForEach(lesson.hints, id: \.self) { hint in
                        Label(hint, systemImage: "lightbulb")
                    }
                }
            }
            .padding(LayoutMetrics.isCompact(horizontalSizeClass) ? 16 : 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var relatedSamplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Sample Programs")
                .font(.headline)
            Text("Open these from File > Open Sample Program, or tap to load into the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(lesson.relatedSamples, id: \.self) { filename in
                    Button(filename) {
                        if let program = SampleProgramLibrary.all.first(where: {
                            $0.filename.caseInsensitiveCompare(filename) == .orderedSame
                        }) {
                            viewModel.loadSampleProgram(program)
                            onClose?()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(QBTheme.monoSmall)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SampleActionButton(title: "Open in Editor", icon: "doc.text", style: .primary) {
                    viewModel.loadLesson(lesson)
                    onClose?()
                }

                SampleActionButton(title: "Run Lesson", icon: "play.fill", style: .accent) {
                    viewModel.loadLesson(lesson)
                    onClose?()
                    viewModel.runProgram()
                }
            }
            HStack(spacing: 10) {
                SampleActionButton(title: "Check", icon: "checkmark", style: .secondary) {
                    Task {
                        let result = await viewModel.checkLesson(lesson)
                        checkResult = result
                        if result.passed {
                            LessonProgressStore.markComplete(lesson.id)
                            onProgressChange?()
                        }
                    }
                }

                SampleActionButton(title: "Hints", icon: "lightbulb", style: .secondary) {
                    showHints.toggle()
                }
            }
        }
    }
}