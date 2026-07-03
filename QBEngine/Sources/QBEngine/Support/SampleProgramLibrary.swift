import Foundation

public struct SampleProgram: Identifiable, Hashable, Sendable {
    public let id: String
    public let filename: String
    public let title: String
    public let category: ProgramCategory
    public let description: String
    public let code: String

    public init(id: String, filename: String, title: String, category: ProgramCategory, description: String, code: String) {
        self.id = id
        self.filename = filename
        self.title = title
        self.category = category
        self.description = description
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

    public var id: String { rawValue }
}

public enum SampleProgramLibrary {
    public static let all: [SampleProgram] = [
        SampleProgram(
            id: "01-hello",
            filename: "HELLO.BAS",
            title: "Hello World",
            category: .basics,
            description: "Classic first program using PRINT.",
            code: """
            ' HELLO.BAS - Your first TabletBasic program
            PRINT "Hello, World!"
            PRINT "Welcome to TabletBasic"
            PRINT
            PRINT "Programming is fun!"
            """
        ),
        SampleProgram(
            id: "02-vars",
            filename: "VARS.BAS",
            title: "Variables Demo",
            category: .basics,
            description: "Integer, single-precision, and string variables.",
            code: """
            ' VARS.BAS - Variable types
            NAME$ = "TabletBasic"
            VERSION! = 4.5
            YEAR% = 1988
            PRINT "Language:"; NAME$
            PRINT "Version:"; VERSION!
            PRINT "Released:"; YEAR%
            """
        ),
        SampleProgram(
            id: "03-math",
            filename: "MATH.BAS",
            title: "Math Expressions",
            category: .basics,
            description: "Arithmetic, powers, and built-in functions.",
            code: """
            ' MATH.BAS - Expressions and functions
            A = 16
            PRINT "Square root of"; A; "is"; SQR(A)
            PRINT "Sine of 90 degrees:"; SIN(1.5708)
            PRINT "2 to the power 8:"; 2 ^ 8
            PRINT "10 MOD 3 ="; 10 MOD 3
            """
        ),
        SampleProgram(
            id: "04-if",
            filename: "COMPARE.BAS",
            title: "IF...THEN",
            category: .basics,
            description: "Conditional branching with IF...THEN...ELSE.",
            code: """
            ' COMPARE.BAS - Conditional logic
            SCORE% = 85
            PRINT "Score:"; SCORE%
            IF SCORE% >= 90 THEN PRINT "Grade: A": GOTO 99
            IF SCORE% >= 80 THEN PRINT "Grade: B": GOTO 99
            PRINT "Grade: C"
            99 END
            """
        ),
        SampleProgram(
            id: "05-for",
            filename: "FORLOOP.BAS",
            title: "FOR...NEXT Loop",
            category: .loops,
            description: "Count from 1 to 10 with a FOR loop.",
            code: """
            ' FORLOOP.BAS - Counting loop
            PRINT "Counting to 10:"
            FOR I% = 1 TO 10
                PRINT I%,
            NEXT I%
            PRINT
            PRINT "Done!"
            """
        ),
        SampleProgram(
            id: "06-while",
            filename: "WHILE.BAS",
            title: "WHILE...WEND",
            category: .loops,
            description: "Top-tested loop with WHILE...WEND.",
            code: """
            ' WHILE.BAS - WHILE loop
            N% = 1
            PRINT "Powers of 2:"
            WHILE N% <= 128
                PRINT N%
                N% = N% * 2
            WEND
            """
        ),
        SampleProgram(
            id: "07-nested",
            filename: "NESTED.BAS",
            title: "Nested Loops",
            category: .loops,
            description: "Nested FOR loops drawing a number grid.",
            code: """
            ' NESTED.BAS - Nested FOR loops
            FOR ROW% = 1 TO 5
                FOR COL% = 1 TO 5
                    PRINT ROW% * COL%,
                NEXT COL%
                PRINT
            NEXT ROW%
            """
        ),
        SampleProgram(
            id: "08-gosub",
            filename: "GOSUB.BAS",
            title: "GOSUB...RETURN",
            category: .subroutines,
            description: "Classic subroutines with line numbers.",
            code: """
            ' GOSUB.BAS - Subroutines
            10 PRINT "Main program starting"
            20 GOSUB 1000
            30 GOSUB 2000
            40 PRINT "Main program ending"
            50 END
            1000 PRINT "  Subroutine A"
            1010 RETURN
            2000 PRINT "  Subroutine B"
            2010 RETURN
            """
        ),
        SampleProgram(
            id: "09-on-gosub",
            filename: "MENU.BAS",
            title: "ON GOSUB",
            category: .subroutines,
            description: "Dispatch to subroutines by index.",
            code: """
            ' MENU.BAS - ON GOSUB dispatch
            FOR CHOICE% = 1 TO 3
                PRINT "Choice:"; CHOICE%
                ON CHOICE% GOSUB 100, 200, 300
            NEXT CHOICE%
            END
            100 PRINT "  Option 1 selected"
            110 RETURN
            200 PRINT "  Option 2 selected"
            210 RETURN
            300 PRINT "  Option 3 selected"
            310 RETURN
            """
        ),
        SampleProgram(
            id: "10-data",
            filename: "DATAREAD.BAS",
            title: "DATA & READ",
            category: .data,
            description: "Store and read inline data values.",
            code: """
            ' DATAREAD.BAS - DATA and READ
            PRINT "Planet data:"
            FOR I% = 1 TO 4
                READ PLANET$, DISTANCE!
                PRINT PLANET$; " -"; DISTANCE!; "million km"
            NEXT I%
            DATA "Mercury", 57.9
            DATA "Venus", 108.2
            DATA "Earth", 149.6
            DATA "Mars", 227.9
            """
        ),
        SampleProgram(
            id: "11-array",
            filename: "ARRAY.BAS",
            title: "Arrays",
            category: .data,
            description: "DIM statement and array indexing.",
            code: """
            ' ARRAY.BAS - Array basics
            DIM SCORES%(5)
            FOR I% = 1 TO 5
                SCORES%(I%) = I% * 10
            NEXT I%
            PRINT "Test scores:"
            FOR I% = 1 TO 5
                PRINT "  Test"; I%; ":"; SCORES%(I%)
            NEXT I%
            """
        ),
        SampleProgram(
            id: "12-random",
            filename: "DICE.BAS",
            title: "Random Numbers",
            category: .math,
            description: "RANDOMIZE and RND for dice simulation.",
            code: """
            ' DICE.BAS - Random numbers
            RANDOMIZE 42
            PRINT "Rolling dice ten times:"
            FOR I% = 1 TO 10
                DIE% = INT(RND * 6) + 1
                PRINT "Roll"; I%; ":"; DIE%
            NEXT I%
            """
        ),
        SampleProgram(
            id: "13-fib",
            filename: "FIBON.BAS",
            title: "Fibonacci",
            category: .math,
            description: "Generate Fibonacci numbers.",
            code: """
            ' FIBON.BAS - Fibonacci sequence
            A% = 0
            B% = 1
            PRINT "Fibonacci numbers:"
            FOR I% = 1 TO 15
                PRINT B%,
                C% = A% + B%
                A% = B%
                B% = C%
            NEXT I%
            PRINT
            """
        ),
        SampleProgram(
            id: "14-table",
            filename: "TABLES.BAS",
            title: "Multiplication Table",
            category: .math,
            description: "Print a multiplication table.",
            code: """
            ' TABLES.BAS - Multiplication table
            PRINT "  x |  1  2  3  4  5"
            PRINT "----+--------------"
            FOR R% = 1 TO 5
                PRINT R%; " |";
                FOR C% = 1 TO 5
                    PRINT R% * C%,
                NEXT C%
                PRINT
            NEXT R%
            """
        ),
        SampleProgram(
            id: "15-graphics",
            filename: "SHAPES.BAS",
            title: "Basic Shapes",
            category: .graphics,
            description: "SCREEN 13 with CIRCLE and LINE.",
            code: """
            ' SHAPES.BAS - Draw basic shapes
            SCREEN 13
            CLS
            CIRCLE (160, 100), 60, 4
            LINE (100, 160)-(220, 160), 2
            LINE (100, 40)-(100, 160), 3
            LINE (220, 40)-(220, 160), 3
            PRINT "Shapes drawn!"
            """
        ),
        SampleProgram(
            id: "16-boxes",
            filename: "BOXES.BAS",
            title: "Nested Boxes",
            category: .graphics,
            description: "Draw concentric boxes with LINE...B.",
            code: """
            ' BOXES.BAS - Nested boxes
            SCREEN 13
            CLS
            COLOR 4
            FOR S% = 10 TO 140 STEP 15
                LINE (160 - S%, 100 - S%)-(160 + S%, 100 + S%), 4, B
            NEXT S%
            PRINT "Nested boxes"
            """
        ),
        SampleProgram(
            id: "17-stars",
            filename: "STARS.BAS",
            title: "Starfield",
            category: .graphics,
            description: "Random stars using PSET.",
            code: """
            ' STARS.BAS - Random starfield
            SCREEN 13
            CLS
            RANDOMIZE 7
            FOR I% = 1 TO 200
                X% = INT(RND * 319)
                Y% = INT(RND * 199)
                C% = INT(RND * 15) + 1
                PSET (X%, Y%), C%
            NEXT I%
            PRINT "Starfield complete"
            """
        ),
        SampleProgram(
            id: "18-circles",
            filename: "MOIRE.BAS",
            title: "Moire Pattern",
            category: .graphics,
            description: "Concentric circles create a moire effect.",
            code: """
            ' MOIRE.BAS - Concentric circles
            SCREEN 13
            CLS
            FOR R% = 5 TO 150 STEP 5
                C% = (R% MOD 15) + 1
                CIRCLE (160, 100), R%, C%
            NEXT R%
            PRINT "Moire pattern"
            """
        ),
        SampleProgram(
            id: "19-sine",
            filename: "SINEWAVE.BAS",
            title: "Sine Wave",
            category: .graphics,
            description: "Plot a sine wave using LINE.",
            code: """
            ' SINEWAVE.BAS - Plot sine wave
            SCREEN 13
            CLS
            LINE (0, 100)-(319, 100), 7
            X1% = 0
            Y1% = 100 - INT(SIN(0) * 80)
            FOR X2% = 1 TO 319
                Y2% = 100 - INT(SIN(X2% / 50) * 80)
                LINE (X1%, Y1%)-(X2%, Y2%), 3
                X1% = X2%
                Y1% = Y2%
            NEXT X2%
            PRINT "Sine wave plotted"
            """
        ),
        SampleProgram(
            id: "20-flag",
            filename: "FLAG.BAS",
            title: "Simple Flag",
            category: .graphics,
            description: "Draw a simple flag with colored rectangles.",
            code: """
            ' FLAG.BAS - Simple flag drawing
            SCREEN 13
            CLS
            LINE (40, 40)-(280, 160), 1, B
            LINE (40, 40)-(120, 100), 4, B
            LINE (120, 40)-(280, 100), 15, B
            LINE (40, 100)-(280, 160), 2, B
            CIRCLE (80, 70), 20, 15
            PRINT "Flag drawn!"
            """
        )
    ]

    public static func grouped() -> [(ProgramCategory, [SampleProgram])] {
        ProgramCategory.allCases.compactMap { category in
            let items = all.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
}