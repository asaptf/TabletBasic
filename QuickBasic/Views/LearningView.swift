import SwiftUI

struct LearningView: View {
    @ObservedObject var viewModel: IDEViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLesson: Lesson?

    var body: some View {
        NavigationSplitView {
            List(LessonCatalog.all, selection: $selectedLesson) { lesson in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chapter \(lesson.chapter)")
                        .font(QBTheme.monoSmall)
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(lesson)
            }
            .navigationTitle(AppBranding.guideTitle)
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
        .onAppear {
            if selectedLesson == nil {
                selectedLesson = LessonCatalog.all.first
            }
        }
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @ObservedObject var viewModel: IDEViewModel
    var onClose: (() -> Void)?

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

                HStack(spacing: 12) {
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

                if showHints {
                    ForEach(lesson.hints, id: \.self) { hint in
                        Label(hint, systemImage: "lightbulb")
                    }
                }
            }
            .padding(24)
        }
    }
}