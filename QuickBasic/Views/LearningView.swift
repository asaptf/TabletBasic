import SwiftUI

struct LearningView: View {
    @ObservedObject var viewModel: IDEViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedLesson: Lesson?

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
                LessonDetailView(lesson: lesson, viewModel: viewModel, onClose: { dismiss() })
            }
        }
    }

    private var regularGuide: some View {
        NavigationSplitView {
            lessonList
        } detail: {
            if let lesson = selectedLesson {
                LessonDetailView(lesson: lesson, viewModel: viewModel, onClose: { dismiss() })
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
            Text("Chapter \(lesson.chapter)")
                .font(QBTheme.monoSmall)
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

    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showHints = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.title)
                        .font(.largeTitle.bold())
                    Text(lesson.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(lesson.description)

                Text(lesson.starterCode)
                    .font(QBTheme.monoFont)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))

                actionButtons

                if showHints {
                    ForEach(lesson.hints, id: \.self) { hint in
                        Label(hint, systemImage: "lightbulb")
                    }
                }
            }
            .padding(LayoutMetrics.isCompact(horizontalSizeClass) ? 16 : 24)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let buttons = Group {
            Button("Open in Editor") {
                viewModel.loadLesson(lesson)
                onClose?()
            }
            .buttonStyle(.borderedProminent)

            Button("Run Lesson") {
                viewModel.loadLesson(lesson)
                onClose?()
                viewModel.runProgram()
            }
            .buttonStyle(.bordered)

            Button("Hints") { showHints.toggle() }
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