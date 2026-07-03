import Foundation

enum BasicsPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "01-hello",
            filename: "HELLO.BAS",
            title: "Hello World",
            category: .basics,
            description: "Classic first program using PRINT.",
            smokeTestMarker: "Hello, World!",
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
            smokeTestMarker: "TabletBasic",
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
            smokeTestMarker: "256",
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
            smokeTestMarker: "Grade: B",
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
            id: "05-printfmt",
            filename: "PRINTFMT.BAS",
            title: "PRINT Formatting",
            category: .basics,
            description: "Semicolons, commas, TAB, and SPC in PRINT.",
            smokeTestMarker: "Columns:",
            code: """
            ' PRINTFMT.BAS - PRINT separators and positioning
            PRINT "Columns:"
            PRINT "A"; "B"; "C"
            PRINT "X", "Y", "Z"
            PRINT "Name"; TAB(20); "Score"
            PRINT SPC(5); "Indented text"
            """
        ),
        SampleProgram(
            id: "06-remarks",
            filename: "REMARKS.BAS",
            title: "REM Comments",
            category: .basics,
            description: "Document code with apostrophe and REM comments.",
            smokeTestMarker: "Comments work",
            code: """
            ' REMARKS.BAS - Comments do not execute
            REM This line is ignored by the interpreter
            ' Another comment style
            PRINT "Comments work"
            """
        ),
        SampleProgram(
            id: "07-let",
            filename: "LETDEMO.BAS",
            title: "LET Statement",
            category: .basics,
            description: "Explicit LET assignment (optional in TabletBasic).",
            smokeTestMarker: "LET works",
            code: """
            ' LETDEMO.BAS - LET keyword
            LET X% = 10
            LET Y% = 25
            LET SUM% = X% + Y%
            PRINT "LET works:"; SUM%
            """
        ),
        SampleProgram(
            id: "08-deftypes",
            filename: "DEFTYPES.BAS",
            title: "DEF Type Ranges",
            category: .basics,
            description: "Default variable types with DEFINT and DEFSTR.",
            smokeTestMarker: "Default types",
            code: """
            ' DEFTYPES.BAS - DEFINT and DEFSTR
            DEFINT A-Z
            DEFSTR S-T
            A = 42
            B = 8
            S = "Hello"
            T = "World"
            PRINT "Default types:"; A; "+"; B; "="; A + B
            PRINT S; T
            """
        ),
        SampleProgram(
            id: "09-goto",
            filename: "GOTODEMO.BAS",
            title: "GOTO Branching",
            category: .basics,
            description: "Jump to a line number with GOTO.",
            smokeTestMarker: "Label 50",
            code: """
            ' GOTODEMO.BAS - GOTO jumps
            10 PRINT "Start"
            20 GOTO 50
            30 PRINT "Skipped"
            50 PRINT "Label 50 reached"
            60 END
            """
        ),
        SampleProgram(
            id: "10-stopend",
            filename: "STOPEND.BAS",
            title: "STOP and END",
            category: .basics,
            description: "Halt a program with STOP or END.",
            smokeTestMarker: "STOP reached",
            code: """
            ' STOPEND.BAS - STOP halts before END
            PRINT "STOP reached"
            STOP
            PRINT "Never printed"
            END
            """
        ),
        SampleProgram(
            id: "11-beep",
            filename: "BEEPDEMO.BAS",
            title: "BEEP",
            category: .basics,
            description: "Sound the speaker with BEEP.",
            smokeTestMarker: "Beep done",
            code: """
            ' BEEPDEMO.BAS - BEEP command
            PRINT "Listen..."
            BEEP
            PRINT "Beep done"
            """
        ),
        SampleProgram(
            id: "12-tab",
            filename: "TABDEMO.BAS",
            title: "TAB Function",
            category: .basics,
            description: "Align columns using TAB in PRINT.",
            smokeTestMarker: "TAB demo",
            code: """
            ' TABDEMO.BAS - TAB column alignment
            PRINT "TAB demo"
            PRINT "Item"; TAB(15); "Qty"; TAB(25); "Price"
            PRINT "Apple"; TAB(15); 3; TAB(25); 1.25
            PRINT "Pear"; TAB(15); 5; TAB(25); 0.99
            """
        ),
        SampleProgram(
            id: "13-spc",
            filename: "SPCDEMO.BAS",
            title: "SPC Function",
            category: .basics,
            description: "Insert spaces with SPC in PRINT output.",
            smokeTestMarker: "SPC demo",
            code: """
            ' SPCDEMO.BAS - SPC spacing
            PRINT "SPC demo"
            PRINT "Level 1"
            PRINT SPC(4); "Level 2"
            PRINT SPC(8); "Level 3"
            """
        ),
        SampleProgram(
            id: "14-constants",
            filename: "CONSTANTS.BAS",
            title: "Numeric Constants",
            category: .basics,
            description: "Integer and floating-point literals.",
            smokeTestMarker: "Pi approx",
            code: """
            ' CONSTANTS.BAS - Literal numbers
            PI! = 3.14159
            E! = 2.71828
            PRINT "Pi approx:"; PI!
            PRINT "E approx:"; E!
            PRINT "Sum:"; PI! + E!
            """
        ),
        SampleProgram(
            id: "15-linenum",
            filename: "LINENUMS.BAS",
            title: "Line Numbers",
            category: .basics,
            description: "Classic line-numbered BASIC style.",
            smokeTestMarker: "Line numbers",
            code: """
            ' LINENUMS.BAS - Line-numbered program
            100 PRINT "Line numbers"
            200 FOR N% = 1 TO 3
            210 PRINT "  Step"; N%
            220 NEXT N%
            300 END
            """
        )
    ]
}