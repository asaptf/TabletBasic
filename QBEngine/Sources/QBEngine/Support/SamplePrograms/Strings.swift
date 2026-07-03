import Foundation

enum StringsPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "65-chrstr",
            filename: "CHRSTR.BAS",
            title: "CHR$ and STR$",
            category: .strings,
            description: "Convert between numbers and strings.",
            smokeTestMarker: "ASCII 65",
            code: """
            ' CHRSTR.BAS - CHR$ and STR$
            CODE% = 65
            PRINT "ASCII 65 is"; CHR(CODE%)
            N% = 42
            PRINT "STR gives"; STR(N%)
            """
        ),
        SampleProgram(
            id: "66-lenleft",
            filename: "LENLEFT.BAS",
            title: "LEN LEFT$ RIGHT$",
            category: .strings,
            description: "Measure and slice strings.",
            smokeTestMarker: "Len=11",
            code: """
            ' LENLEFT.BAS - LEN, LEFT$, RIGHT$
            WORD$ = "TabletBasic"
            PRINT "Len=11:"; LEN(WORD$)
            PRINT "Left:"; LEFT(WORD$, 6)
            PRINT "Right:"; RIGHT(WORD$, 5)
            """
        ),
        SampleProgram(
            id: "67-val",
            filename: "VALDEMO.BAS",
            title: "VAL Function",
            category: .strings,
            description: "Parse a numeric string with VAL.",
            smokeTestMarker: "VAL=42",
            code: """
            ' VALDEMO.BAS - VAL function
            NUM$ = "42"
            N% = VAL(NUM$)
            PRINT "VAL=42:"; N%
            PRINT "Double:"; VAL("3.14")
            """
        ),
        SampleProgram(
            id: "68-concat",
            filename: "CONCAT.BAS",
            title: "String Concatenation",
            category: .strings,
            description: "Join strings with the + operator.",
            smokeTestMarker: "Hello World",
            code: """
            ' CONCAT.BAS - String concatenation
            A$ = "Hello"
            B$ = " World"
            C$ = A$ + B$
            PRINT C$
            """
        ),
        SampleProgram(
            id: "69-midchar",
            filename: "MIDCHAR.BAS",
            title: "Extract Characters",
            category: .strings,
            description: "Walk a string using LEFT$ and RIGHT$.",
            smokeTestMarker: "Letters:",
            code: """
            ' MIDCHAR.BAS - Extract each character
            TEXT$ = "BASIC"
            PRINT "Letters:"
            FOR I% = 1 TO LEN(TEXT$)
                CH$ = RIGHT(LEFT(TEXT$, I%), 1)
                PRINT CH$,
            NEXT I%
            PRINT
            """
        ),
        SampleProgram(
            id: "70-reverse",
            filename: "REVERSE.BAS",
            title: "Reverse String",
            category: .strings,
            description: "Build a reversed copy of a string.",
            smokeTestMarker: "Reversed:",
            code: """
            ' REVERSE.BAS - Reverse a string
            S$ = "TABLET"
            R$ = ""
            FOR I% = LEN(S$) TO 1 STEP -1
                R$ = R$ + RIGHT(LEFT(S$, I%), 1)
            NEXT I%
            PRINT "Reversed:"; R$
            """
        ),
        SampleProgram(
            id: "71-compare",
            filename: "STRCMP.BAS",
            title: "String Compare",
            category: .strings,
            description: "Compare two strings for equality.",
            smokeTestMarker: "Match!",
            code: """
            ' STRCMP.BAS - String comparison
            A$ = "YES"
            B$ = "YES"
            IF A$ = B$ THEN PRINT "Match!"
            """
        ),
        SampleProgram(
            id: "72-palindrome",
            filename: "PALINDRM.BAS",
            title: "Palindrome Check",
            category: .strings,
            description: "Test whether a word reads the same backwards.",
            smokeTestMarker: "Palindrome!",
            code: """
            ' PALINDRM.BAS - Palindrome test
            WORD$ = "LEVEL"
            REV$ = ""
            FOR I% = LEN(WORD$) TO 1 STEP -1
                REV$ = REV$ + RIGHT(LEFT(WORD$, I%), 1)
            NEXT I%
            IF WORD$ = REV$ THEN PRINT "Palindrome!"
            """
        )
    ]
}