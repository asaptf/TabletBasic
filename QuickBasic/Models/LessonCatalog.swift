import Foundation

enum LessonCatalog {
    static let all: [Lesson] = [
        Lesson(
            id: "01-hello",
            title: "Hello, World!",
            subtitle: "Your first PRINT statement",
            description: """
            Every programmer starts somewhere, and in BASIC that place is PRINT. \
            This statement sends text to the screen so you can see your program work. \
            Run your program with F5 and watch the output appear below the editor.
            """,
            starterCode: """
            ' Chapter 1: Hello, World!
            PRINT "Hello, World!"
            PRINT "Welcome to TabletBasic"
            PRINT
            PRINT "Programming is fun!"
            """,
            expectedOutput: "Hello, World!",
            hints: [
                "Press F5 (or Enter) to run your program.",
                "Lines starting with ' are comments — the interpreter ignores them.",
                "PRINT with no arguments prints a blank line."
            ],
            chapter: 1,
            relatedSamples: ["HELLO.BAS"]
        ),
        Lesson(
            id: "02-variables",
            title: "Variables & Types",
            subtitle: "Store numbers and text",
            description: """
            Variables are named boxes that hold values your program can change. \
            BASIC uses type suffixes to tell the interpreter what kind of data you mean: \
            % for integers, $ for strings, ! for single-precision numbers, and # for doubles.
            """,
            starterCode: """
            ' Chapter 2: Variables and types
            NAME$ = "Student"
            AGE% = 16
            HEIGHT! = 5.9
            PRINT "Name:"; NAME$
            PRINT "Age:"; AGE%; "years"
            PRINT "Height:"; HEIGHT!; "feet"
            """,
            expectedOutput: "Name:",
            hints: [
                "NAME$ is a string variable because of the $ suffix.",
                "AGE% stores whole numbers; HEIGHT! stores decimals.",
                "Use a semicolon (;) in PRINT to keep items on the same line."
            ],
            chapter: 2,
            relatedSamples: ["VARS.BAS"]
        ),
        Lesson(
            id: "03-math",
            title: "Math & Expressions",
            subtitle: "Arithmetic, powers, and functions",
            description: """
            BASIC handles everyday math with +, -, *, /, and the power operator ^. \
            Built-in functions like SQR, ABS, and INT help you compute square roots, \
            absolute values, and whole-number results without writing extra logic.
            """,
            starterCode: """
            ' Chapter 3: Math and expressions
            A = 16
            B = 3
            PRINT "Sum:"; A + B
            PRINT "Product:"; A * B
            PRINT "Square root of"; A; "is"; SQR(A)
            PRINT "2 to the power 8:"; 2 ^ 8
            PRINT "10 MOD 3 ="; 10 MOD 3
            """,
            expectedOutput: "Sum:",
            hints: [
                "MOD returns the remainder after division: 10 MOD 3 is 1.",
                "INT() truncates toward zero: INT(3.9) gives 3.",
                "Operator precedence follows standard math: * and / before + and -."
            ],
            chapter: 3,
            relatedSamples: ["MATH.BAS", "FIBON.BAS"]
        ),
        Lesson(
            id: "04-if",
            title: "IF...THEN...ELSE",
            subtitle: "Make decisions in your code",
            description: """
            Programs become useful when they can choose different paths. \
            The IF statement tests a condition and runs code only when it is true. \
            Add ELSE to handle the alternative, or chain several IF lines for grading scales and menus.
            """,
            starterCode: """
            ' Chapter 4: Conditional branching
            SCORE% = 85
            PRINT "Score:"; SCORE%
            IF SCORE% >= 90 THEN PRINT "Grade: A": GOTO 99
            IF SCORE% >= 80 THEN PRINT "Grade: B": GOTO 99
            PRINT "Grade: C"
            99 END
            """,
            expectedOutput: "Score:",
            hints: [
                "Conditions use =, <>, <, >, <=, and >= to compare values.",
                "You can put a single statement on the same line: IF X > 0 THEN PRINT X",
                "Chain several IF lines for grading scales, menus, and decision trees."
            ],
            chapter: 4,
            relatedSamples: ["COMPARE.BAS"]
        ),
        Lesson(
            id: "05-for",
            title: "FOR...NEXT Loops",
            subtitle: "Repeat code with a counter",
            description: """
            FOR loops are the classic way to repeat code a known number of times. \
            The counter variable starts at one value, steps toward an end value, \
            and NEXT sends control back to the top until the range is finished.
            """,
            starterCode: """
            ' Chapter 5: FOR...NEXT loops
            PRINT "Counting to 5:"
            FOR I% = 1 TO 5
                PRINT I%,
            NEXT I%
            PRINT
            PRINT "Done!"
            """,
            expectedOutput: "Counting to 5:",
            hints: [
                "A trailing comma (,) in PRINT keeps the next value on the same line.",
                "Add STEP -1 to count downward: FOR I% = 10 TO 1 STEP -1",
                "Indentation is optional but helps you read nested loops."
            ],
            chapter: 5,
            relatedSamples: ["FORLOOP.BAS", "NESTED.BAS", "TABLES.BAS"]
        ),
        Lesson(
            id: "06-while",
            title: "WHILE...WEND Loops",
            subtitle: "Repeat while a condition is true",
            description: """
            WHILE loops test a condition before each pass through the loop body. \
            They are ideal when you do not know exactly how many repetitions you need — \
            for example, doubling a number until it exceeds a limit.
            """,
            starterCode: """
            ' Chapter 6: WHILE...WEND loops
            N% = 1
            PRINT "Powers of 2:"
            WHILE N% <= 128
                PRINT N%
                N% = N% * 2
            WEND
            PRINT "Finished at"; N%
            """,
            expectedOutput: "Powers of 2:",
            hints: [
                "The condition is checked at the top — if it starts false, the body never runs.",
                "Make sure something inside the loop eventually changes the condition.",
                "WEND must match its WHILE; mismatched pairs cause runtime errors."
            ],
            chapter: 6,
            relatedSamples: ["WHILE.BAS"]
        ),
        Lesson(
            id: "07-do",
            title: "DO...LOOP",
            subtitle: "Flexible top and bottom loops",
            description: """
            DO...LOOP is another repetition form that can test its condition at the top or bottom. \
            Use WHILE or UNTIL after DO or LOOP to control when the loop continues. \
            EXIT DO lets you leave early when a special case is found inside the loop.
            """,
            starterCode: """
            ' Chapter 7: DO...LOOP
            COUNT% = 0
            PRINT "Guessing game (fixed answer):"
            DO
                COUNT% = COUNT% + 1
                GUESS% = COUNT% * 3 MOD 7 + 1
                PRINT "Try"; COUNT%; ":"; GUESS%
            LOOP UNTIL GUESS% = 4
            PRINT "Found it on try"; COUNT%
            """,
            expectedOutput: "Guessing game",
            hints: [
                "DO WHILE condition runs zero or more times; DO UNTIL runs at least once.",
                "LOOP WHILE and LOOP UNTIL test after each iteration.",
                "EXIT DO jumps out immediately — useful inside nested logic."
            ],
            chapter: 7,
            relatedSamples: ["DOLOOP.BAS", "DOUNTIL.BAS", "DOWHILE.BAS"]
        ),
        Lesson(
            id: "08-gosub",
            title: "GOSUB & RETURN",
            subtitle: "Reusable subroutines",
            description: """
            GOSUB jumps to a labeled section of code and RETURN brings execution back. \
            This pattern was how classic BASIC organized reusable chunks before modern procedures. \
            Line numbers make subroutine targets easy to spot in small programs.
            """,
            starterCode: """
            ' Chapter 8: GOSUB and RETURN
            PRINT "Main program starting"
            GOSUB 1000
            GOSUB 2000
            PRINT "Main program ending"
            END
            1000 PRINT "  Inside subroutine A"
            1010 RETURN
            2000 PRINT "  Inside subroutine B"
            2010 RETURN
            """,
            expectedOutput: "Main program starting",
            hints: [
                "RETURN pops back to the line after the matching GOSUB.",
                "END stops the program so execution does not fall into subroutines.",
                "Each GOSUB pushes a return address; RETURN must match."
            ],
            chapter: 8,
            relatedSamples: ["GOSUB.BAS"]
        ),
        Lesson(
            id: "09-goto",
            title: "GOTO & ON GOTO",
            subtitle: "Jump to labeled lines",
            description: """
            GOTO transfers control directly to a line number, and ON...GOTO picks a target \
            from a list based on an index. These commands feel old-fashioned but teach how \
            early programs implemented menus, state machines, and error handling.
            """,
            starterCode: """
            ' Chapter 9: GOTO and ON GOTO
            FOR CHOICE% = 1 TO 3
                PRINT "Menu choice:"; CHOICE%
                ON CHOICE% GOSUB 100, 200, 300
            NEXT CHOICE%
            END
            100 PRINT "  -> Option 1: New file"
            110 RETURN
            200 PRINT "  -> Option 2: Open file"
            210 RETURN
            300 PRINT "  -> Option 3: Quit"
            310 RETURN
            """,
            expectedOutput: "Menu choice:",
            hints: [
                "ON expr GOTO 100, 200, 300 jumps to the expr-th line in the list.",
                "ON expr GOSUB works the same way but returns with RETURN.",
                "Overusing GOTO can make programs hard to follow — use it sparingly."
            ],
            chapter: 9,
            relatedSamples: ["MENU.BAS"]
        ),
        Lesson(
            id: "10-data",
            title: "DATA, READ & RESTORE",
            subtitle: "Embed values in your program",
            description: """
            DATA statements store literal values inside your source code, and READ pulls them \
            into variables one at a time. RESTORE resets the read pointer so you can scan the \
            same data again — handy for tables, planet lists, and lookup values.
            """,
            starterCode: """
            ' Chapter 10: DATA, READ, and RESTORE
            PRINT "Planet distances from the Sun:"
            FOR I% = 1 TO 4
                READ PLANET$, DISTANCE!
                PRINT "  "; PLANET$; " -"; DISTANCE!; "million km"
            NEXT I%
            PRINT
            PRINT "Reading again with RESTORE:"
            RESTORE
            READ P$, D!
            PRINT "Closest:"; P$; "("; D!; "million km)"
            DATA "Mercury", 57.9
            DATA "Venus", 108.2
            DATA "Earth", 149.6
            DATA "Mars", 227.9
            """,
            expectedOutput: "Planet distances",
            hints: [
                "DATA values must match the types of the variables in READ.",
                "Strings in DATA are written in quotes; numbers are bare.",
                "RESTORE with no argument rewinds to the first DATA line."
            ],
            chapter: 10,
            relatedSamples: ["DATAREAD.BAS"]
        ),
        Lesson(
            id: "11-arrays",
            title: "Arrays",
            subtitle: "Lists of related values",
            description: """
            An array stores many values under one name, indexed by position. \
            Use DIM to declare the size before you assign elements. \
            FOR loops pair naturally with arrays when filling tables or processing scores.
            """,
            starterCode: """
            ' Chapter 11: Arrays
            DIM SCORES%(5)
            FOR I% = 1 TO 5
                SCORES%(I%) = I% * 10
            NEXT I%
            PRINT "Test scores:"
            TOTAL% = 0
            FOR I% = 1 TO 5
                PRINT "  Test"; I%; ":"; SCORES%(I%)
                TOTAL% = TOTAL% + SCORES%(I%)
            NEXT I%
            PRINT "Average:"; TOTAL% / 5
            """,
            expectedOutput: "Test scores:",
            hints: [
                "DIM SCORES%(5) creates indices 1 through 5 by default.",
                "Access elements with parentheses: SCORES%(3) is the third score.",
                "Array names use the same type suffix as their elements."
            ],
            chapter: 11,
            relatedSamples: ["ARRAY.BAS"]
        ),
        Lesson(
            id: "12-strings",
            title: "Strings",
            subtitle: "Work with text",
            description: """
            String variables end with $ and support concatenation with the + operator. \
            Functions like LEN, LEFT$, RIGHT$, STR$, and VAL let you measure, slice, \
            convert, and parse text without writing complex parsing code by hand.
            """,
            starterCode: """
            ' Chapter 12: String operations
            GREETING$ = "Hello"
            NAME$ = "BASIC"
            MESSAGE$ = GREETING$ + ", " + NAME$ + "!"
            PRINT MESSAGE$
            PRINT "Length:"; LEN(MESSAGE$)
            PRINT "First 5 chars:"; LEFT(MESSAGE$, 5)
            PRINT "Last 5 chars:"; RIGHT(MESSAGE$, 5)
            SCORE$ = "95"
            PRINT "Numeric value:"; VAL(SCORE$) + 5
            """,
            expectedOutput: "Hello, BASIC!",
            hints: [
                "Use + to join strings: \"Hi\" + \" \" + \"there\"",
                "STR$ converts a number to text; VAL converts text to a number.",
                "LEFT(s$, n) returns the first n characters of s$."
            ],
            chapter: 12,
            relatedSamples: ["LENLEFT.BAS", "CONCAT.BAS", "VALDEMO.BAS"]
        ),
        Lesson(
            id: "13-logic",
            title: "Logic Operators",
            subtitle: "AND, OR, and NOT",
            description: """
            Logical operators combine true/false conditions into richer tests. \
            AND requires both sides to be true; OR needs only one; NOT flips a value. \
            In TabletBasic, -1 means true and 0 means false, following classic BASIC conventions.
            """,
            starterCode: """
            ' Chapter 13: Logic operators
            AGE% = 20
            HAS_ID% = -1
            PRINT "Age:"; AGE%; " Has ID:"; HAS_ID%
            IF AGE% >= 18 AND HAS_ID% THEN PRINT "Access granted"
            IF AGE% < 18 OR NOT HAS_ID% THEN PRINT "Access denied"
            LIGHT% = 0
            DOOR_OPEN% = 0
            IF LIGHT% OR DOOR_OPEN% THEN PRINT "Alarm triggered!"
            IF NOT LIGHT% AND NOT DOOR_OPEN% THEN PRINT "All secure"
            """,
            expectedOutput: "Access granted",
            hints: [
                "In BASIC, any non-zero number is considered true in IF tests.",
                "AND has higher precedence than OR — use parentheses when unsure.",
                "NOT, AND, and OR work in expressions as well as IF conditions."
            ],
            chapter: 13,
            relatedSamples: ["ANDOR.BAS", "RANGE.BAS", "FLAGS.BAS"]
        ),
        Lesson(
            id: "14-random",
            title: "Random Numbers",
            subtitle: "RANDOMIZE and RND",
            description: """
            Games, simulations, and demos need unpredictable values. \
            Call RANDOMIZE once to seed the generator, then use RND to get fractions between 0 and 1. \
            Combine RND with INT to roll dice, shuffle cards, or scatter stars on the screen.
            """,
            starterCode: """
            ' Chapter 14: Random numbers
            RANDOMIZE 42
            PRINT "Rolling a six-sided die ten times:"
            FOR I% = 1 TO 10
                DIE% = INT(RND * 6) + 1
                PRINT "Roll"; I%; ":"; DIE%
            NEXT I%
            PRINT
            PRINT "Random percent:"; INT(RND * 100); "%"
            """,
            expectedOutput: "Rolling a six-sided die",
            hints: [
                "INT(RND * 6) + 1 gives integers from 1 to 6.",
                "The same RANDOMIZE seed produces the same sequence — useful for testing.",
                "Call RANDOMIZE without a seed to use a less predictable starting point."
            ],
            chapter: 14,
            relatedSamples: ["DICE.BAS", "STARS.BAS"]
        ),
        Lesson(
            id: "15-graphics",
            title: "Graphics Basics",
            subtitle: "SCREEN, LINE, and CIRCLE",
            description: """
            TabletBasic can draw simple pictures inspired by classic SCREEN 13 mode (320×200, 256 colors). \
            Use CLS to clear the canvas, then CIRCLE and LINE to place shapes. \
            Text PRINT statements still appear alongside the graphics output panel.
            """,
            starterCode: """
            ' Chapter 15: Graphics basics
            SCREEN 13
            CLS
            CIRCLE (160, 100), 50, 4
            LINE (50, 150)-(270, 150), 2
            LINE (50, 150)-(160, 50), 2, B
            PRINT "Graphics ready!"
            """,
            expectedOutput: "Graphics ready!",
            hints: [
                "SCREEN 13 selects 320×200 pixel graphics with 256 colors.",
                "Coordinates are (x, y) with the origin at the top-left corner.",
                "Add , B to LINE to draw a filled box between two corners."
            ],
            chapter: 15,
            relatedSamples: ["SHAPES.BAS", "FLAG.BAS"]
        ),
        Lesson(
            id: "16-graphics-patterns",
            title: "Graphics Patterns",
            subtitle: "Loops, color, and PSET",
            description: """
            Combine loops with graphics commands to create patterns that would be tedious to draw by hand. \
            PSET paints individual pixels, COLOR selects palette entries, and nested FOR loops \
            build starfields, moiré circles, and animated-looking designs from simple rules.
            """,
            starterCode: """
            ' Chapter 16: Graphics patterns
            SCREEN 13
            CLS
            RANDOMIZE 7
            FOR I% = 1 TO 100
                X% = INT(RND * 319)
                Y% = INT(RND * 199)
                C% = INT(RND * 15) + 1
                PSET (X%, Y%), C%
            NEXT I%
            FOR R% = 20 TO 80 STEP 15
                CIRCLE (160, 100), R%, (R% MOD 15) + 1
            NEXT R%
            PRINT "Pattern complete!"
            """,
            expectedOutput: "Pattern complete!",
            hints: [
                "PSET (x, y), color paints one pixel — great for particle effects.",
                "Use MOD to cycle through a range of color indices in a loop.",
                "Try changing the RANDOMIZE seed to get different star placements."
            ],
            chapter: 16,
            relatedSamples: ["STARS.BAS", "MOIRE.BAS", "BOXES.BAS", "SINEWAVE.BAS"]
        )
    ]
}