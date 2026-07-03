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
}

enum LessonCatalog {
    static let all: [Lesson] = [
        Lesson(
            id: "01-hello",
            title: "Hello, World!",
            subtitle: "Your first PRINT statement",
            description: "TabletBasic programs use PRINT to display text. Run the program with F5.",
            starterCode: """
            ' Lesson 1: Hello, World!
            PRINT "Hello, World!"
            PRINT "Welcome to TabletBasic"
            """,
            expectedOutput: "Hello, World!",
            hints: ["Press F5 to run your program.", "Lines starting with ' are comments (REM)."],
            chapter: 1
        ),
        Lesson(
            id: "02-variables",
            title: "Variables",
            subtitle: "Store numbers and text",
            description: "Use LET or simple assignment to store values. Type suffixes: % integer, $ string, ! single.",
            starterCode: """
            ' Lesson 2: Variables
            NAME$ = "Student"
            AGE% = 16
            PRINT "Name:"; NAME$
            PRINT "Age:"; AGE%
            """,
            expectedOutput: "Name:",
            hints: ["NAME$ is a string variable.", "AGE% is an integer variable."],
            chapter: 2
        ),
        Lesson(
            id: "03-loops",
            title: "FOR...NEXT Loops",
            subtitle: "Repeat code with counters",
            description: "FOR loops are essential in BASIC. The counter variable steps from start to end.",
            starterCode: """
            ' Lesson 3: Loops
            PRINT "Counting:"
            FOR I% = 1 TO 5
                PRINT I%
            NEXT I%
            """,
            expectedOutput: "Counting:",
            hints: ["Indentation is optional in BASIC.", "NEXT I% closes the FOR loop."],
            chapter: 3
        ),
        Lesson(
            id: "04-graphics",
            title: "Simple Graphics",
            subtitle: "Draw with SCREEN, CIRCLE, LINE",
            description: "SCREEN 13 sets 320x200 graphics mode. Use CIRCLE and LINE to draw shapes.",
            starterCode: """
            ' Lesson 4: Graphics
            SCREEN 13
            CLS
            CIRCLE (160, 100), 50, 4
            LINE (50, 150)-(270, 150), 2
            LINE (50, 150)-(160, 50), 2, B
            PRINT "Graphics ready!"
            """,
            expectedOutput: "Graphics ready!",
            hints: ["SCREEN 13 is 320x200, 256 colors.", "Add , B to LINE to draw a box."],
            chapter: 4
        ),
        Lesson(
            id: "05-subroutines",
            title: "GOSUB and RETURN",
            subtitle: "Reusable subroutines",
            description: "GOSUB jumps to a subroutine; RETURN comes back. Classic BASIC structure.",
            starterCode: """
            ' Lesson 5: Subroutines
            PRINT "Main program"
            GOSUB 1000
            PRINT "Back in main"
            END
            1000 PRINT "Inside subroutine"
            1010 RETURN
            """,
            expectedOutput: "Main program",
            hints: ["Line numbers help with GOSUB targets.", "END stops the program."],
            chapter: 5
        )
    ]
}