import Foundation

enum BasicLanguageGuide {
    struct Section: Identifiable {
        let id: String
        let title: String
        let content: String
    }

    static let sections: [Section] = [
        Section(
            id: "getting-started",
            title: "Getting Started",
            content: """
            TabletBasic is a retro BASIC learning environment for iPhone, iPad, and Mac. \
            Type a program in the editor, press F5 to run it, and read the output in the \
            panel below. Use Help > Learning Guide for 16 step-by-step chapters.

            A minimal program:
              PRINT "Hello, World!"

            Comments start with REM or an apostrophe ('). The interpreter ignores them.
            Programs run top to bottom unless GOTO, GOSUB, or a loop changes the flow.
            """
        ),
        Section(
            id: "editor-keys",
            title: "Editor & Keys",
            content: """
            F1          Open this help screen
            F5          Run the current program (same as Run > Start)
            Enter       Run program, or execute immediate-mode input
            Esc         Cancel output view / clear immediate line

            The editor uses a monospaced font with syntax highlighting for keywords, \
            strings, numbers, and comments. On iPad and Mac you can use a hardware keyboard; \
            on iPhone, tap the editor to show the on-screen keyboard.

            Immediate mode (the input line at the bottom) evaluates one statement or \
            expression without a full program — useful for quick experiments:
              ? 2 + 2
              PRINT SQR(144)
            """
        ),
        Section(
            id: "variable-types",
            title: "Variable Types",
            content: """
            Variable names are letters, digits, and underscores. The last character \
            can be a type suffix:

              %   Integer       COUNT%, INDEX%
              &   Long integer  BIG&
              !   Single        TEMP!, PI!
              #   Double        RATE#
              $   String        NAME$, TITLE$

            Without a suffix, DEFINT/DEFSNG/DEFSTR (or assignment) sets the type.

            Examples:
              AGE% = 16
              PRICE! = 9.99
              LABEL$ = "TabletBasic"

            Arrays are declared with DIM:
              DIM SCORES%(10)
              SCORES%(1) = 100
            """
        ),
        Section(
            id: "statements",
            title: "Statements",
            content: """
            Output and input:
              PRINT "Hello"; NAME$
              PRINT A, B          ' comma advances to next print zone
              INPUT "Name"; N$

            Assignment:
              LET X = 10          ' LET is optional
              X = X + 1

            Control flow:
              IF X > 0 THEN PRINT "Positive"
              IF X < 0 THEN PRINT "Negative" ELSE PRINT "Zero"

            Program structure:
              END                 ' stop execution
              STOP                ' halt with message
              REM Comment         ' or use '

            Other:
              BEEP                ' play a short tone
              SLEEP 1             ' pause one second
            """
        ),
        Section(
            id: "loops",
            title: "Loops",
            content: """
            FOR...NEXT — counted loop:
              FOR I% = 1 TO 10
                  PRINT I%
              NEXT I%

              FOR I% = 10 TO 1 STEP -1
                  PRINT I%
              NEXT I%

            WHILE...WEND — test at top:
              WHILE N% < 100
                  N% = N% * 2
              WEND

            DO...LOOP — flexible repetition:
              DO
                  PRINT "At least once"
              LOOP WHILE X < 10

              DO WHILE X < 10
                  X = X + 1
              LOOP

              DO
                  X = X + 1
              LOOP UNTIL X >= 10

            Early exit:
              EXIT FOR
              EXIT DO
              EXIT WHILE
            """
        ),
        Section(
            id: "subroutines",
            title: "Subroutines",
            content: """
            GOSUB calls a subroutine; RETURN resumes after the call.

              PRINT "Start"
              GOSUB 1000
              PRINT "Done"
              END
              1000 PRINT "Subroutine"
              1010 RETURN

            GOTO jumps without saving a return address:
              GOTO 200

            ON...GOTO / ON...GOSUB dispatch by index (1-based):
              ON CHOICE% GOSUB 100, 200, 300

            Line numbers are optional but traditional for GOSUB targets. \
            Always place END before subroutine code so execution does not fall through.
            """
        ),
        Section(
            id: "data-arrays",
            title: "Data & Arrays",
            content: """
            DATA embeds constant values; READ loads them into variables:
              FOR I% = 1 TO 3
                  READ A%, B$
                  PRINT A%; B$
              NEXT I%
              DATA 10, "Alpha"
              DATA 20, "Beta"
              DATA 30, "Gamma"

            RESTORE rewinds the data pointer:
              RESTORE
              READ A%, B$

            Arrays:
              DIM ITEMS$(5)
              ITEMS$(1) = "First"
              PRINT ITEMS$(1)

            Multi-dimensional arrays:
              DIM GRID%(3, 3)
              GRID%(2, 2) = 99
            """
        ),
        Section(
            id: "string-functions",
            title: "String Functions",
            content: """
            Concatenation:
              FULL$ = FIRST$ + " " + LAST$

            Functions:
              LEN(S$)             ' length in characters
              LEFT$(S$, N)        ' first N characters
              RIGHT$(S$, N)       ' last N characters
              STR$(N)             ' number to string
              VAL(S$)             ' string to number
              CHR$(N)             ' character from ASCII code

            Example:
              WORD$ = "TabletBasic"
              PRINT LEN(WORD$)
              PRINT LEFT$(WORD$, 6)
            """
        ),
        Section(
            id: "math-functions",
            title: "Math Functions",
            content: """
            Operators:
              +  -  *  /           ' arithmetic
              ^                    ' power
              \\                   ' integer division
              MOD                  ' remainder

            Functions:
              ABS(X)    SQR(X)     INT(X)     SGN(X)
              SIN(X)    COS(X)     TAN(X)
              RND       RANDOMIZE

            RND returns 0 to 1 (exclusive of 1). Seed the generator:
              RANDOMIZE 42
              DIE% = INT(RND * 6) + 1

            Angles in SIN/COS/TAN are in radians. \
            Multiply degrees by 3.14159 / 180 to convert.
            """
        ),
        Section(
            id: "graphics",
            title: "Graphics",
            content: """
            SCREEN 13 selects 320×200, 256-color graphics mode.

              SCREEN 13
              CLS
              COLOR 4, 0
              CIRCLE (160, 100), 50, 4
              LINE (10, 10)-(100, 100), 2
              LINE (10, 10)-(100, 100), 2, B    ' box
              PSET (50, 50), 15
              PRESET (50, 50)                   ' erase pixel

            Coordinates: (x, y) with origin top-left.
            Colors are palette indices 0–255 (mode 13 uses 0–15 prominently).

            Combine loops with graphics for patterns — see the Learning Guide \
            chapters on Graphics Basics and Graphics Patterns.
            """
        ),
        Section(
            id: "logic-operators",
            title: "Logic Operators",
            content: """
            Relational operators:
              =   <>   <   >   <=   >=

            Logical operators:
              NOT   AND   OR   XOR   EQV   IMP

            In IF tests, zero is false; any non-zero value is true.
            Classic BASIC also uses -1 for true in some contexts.

            Examples:
              IF AGE% >= 18 AND HAS_TICKET% THEN PRINT "Enter"
              IF NOT DONE% THEN PRINT "Working..."
              IF X% = 0 OR Y% = 0 THEN PRINT "On axis"
            """
        ),
        Section(
            id: "tips",
            title: "Tips",
            content: """
            • Start with Help > Learning Guide — 16 chapters cover the full language.
            • Open File > Open Sample Program for 80 built-in demos to study and modify.
            • Use ' comments to explain your code; future-you will thank present-you.
            • Run often. Small steps make debugging easier than big rewrites.
            • In PRINT, semicolon (;) stays on the line; comma (,) jumps to the next zone.
            • Save your work with File > Save or Save As to Files / iCloud.
            • Graphics programs still PRINT text — check both the text and graphics panels.
            • TabletBasic aims for educational compatibility, not full DOS QuickBASIC.
            """
        )
    ]
}