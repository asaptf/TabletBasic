import Foundation

struct Lesson: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let starterCode: String
    let expectedOutput: String?
    let hints: [String]
    let chapter: Int
    let relatedSamples: [String]
}