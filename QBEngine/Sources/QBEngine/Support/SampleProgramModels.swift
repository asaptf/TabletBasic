import Foundation

public struct SampleProgram: Identifiable, Hashable, Sendable {
    public let id: String
    public let filename: String
    public let title: String
    public let category: ProgramCategory
    public let description: String
    public let code: String
    public let smokeTestMarker: String

    public init(
        id: String,
        filename: String,
        title: String,
        category: ProgramCategory,
        description: String,
        smokeTestMarker: String,
        code: String
    ) {
        self.id = id
        self.filename = filename
        self.title = title
        self.category = category
        self.description = description
        self.smokeTestMarker = smokeTestMarker
        self.code = code
    }
}

public enum ProgramCategory: String, CaseIterable, Identifiable, Sendable {
    case basics = "Basics"
    case loops = "Loops"
    case subroutines = "Subroutines"
    case data = "Data & Arrays"
    case graphics = "Graphics"
    case math = "Math & Patterns"
    case strings = "Strings"
    case logic = "Logic & Bitwise"

    public var id: String { rawValue }
}

public enum SampleProgramLibrary {
    public static let programCount = 81

    public static let all: [SampleProgram] =
        BasicsPrograms.all
        + LoopsPrograms.all
        + SubroutinesPrograms.all
        + DataPrograms.all
        + MathPrograms.all
        + GraphicsPrograms.all
        + StringsPrograms.all
        + LogicPrograms.all

    public static func grouped() -> [(ProgramCategory, [SampleProgram])] {
        ProgramCategory.allCases.compactMap { category in
            let items = all.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
}