import Foundation

enum MathPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "41-random",
            filename: "DICE.BAS",
            title: "Random Numbers",
            category: .math,
            description: "RANDOMIZE and RND for dice simulation.",
            smokeTestMarker: "Rolling dice",
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
            id: "42-fib",
            filename: "FIBON.BAS",
            title: "Fibonacci",
            category: .math,
            description: "Generate Fibonacci numbers.",
            smokeTestMarker: "Fibonacci",
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
            id: "43-table",
            filename: "TABLES.BAS",
            title: "Multiplication Table",
            category: .math,
            description: "Print a multiplication table.",
            smokeTestMarker: "----+",
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
            id: "44-primes",
            filename: "PRIMES.BAS",
            title: "Prime Numbers",
            category: .math,
            description: "List primes up to 50 using trial division.",
            smokeTestMarker: "Primes to 50:",
            code: """
            ' PRIMES.BAS - Primes up to 50
            PRINT "Primes to 50:"
            FOR N% = 2 TO 50
                PRIME% = 1
                FOR D% = 2 TO INT(SQR(N%))
                    IF N% MOD D% = 0 THEN PRIME% = 0
                NEXT D%
                IF PRIME% = 1 THEN PRINT N%,
            NEXT N%
            PRINT
            """
        ),
        SampleProgram(
            id: "45-factorial",
            filename: "FACTOR.BAS",
            title: "Factorial",
            category: .math,
            description: "Compute factorial with a FOR loop.",
            smokeTestMarker: "6! =",
            code: """
            ' FACTOR.BAS - Factorial
            N% = 6
            RESULT% = 1
            FOR I% = 1 TO N%
                RESULT% = RESULT% * I%
            NEXT I%
            PRINT "6! ="; RESULT%
            """
        ),
        SampleProgram(
            id: "46-average",
            filename: "AVGNUM.BAS",
            title: "Mean Value",
            category: .math,
            description: "Average of a set of numbers.",
            smokeTestMarker: "Mean:",
            code: """
            ' AVGNUM.BAS - Arithmetic mean
            SUM% = 10 + 20 + 30 + 40
            COUNT% = 4
            PRINT "Mean:"; SUM% / COUNT%
            """
        ),
        SampleProgram(
            id: "47-powers",
            filename: "POWERS.BAS",
            title: "Powers Table",
            category: .math,
            description: "Print powers of 3.",
            smokeTestMarker: "Powers of 3:",
            code: """
            ' POWERS.BAS - Powers of 3
            PRINT "Powers of 3:"
            FOR E% = 0 TO 6
                PRINT "3^"; E%; "="; 3 ^ E%
            NEXT E%
            """
        ),
        SampleProgram(
            id: "48-mod",
            filename: "MODDEMO.BAS",
            title: "MOD Operator",
            category: .math,
            description: "Remainders with the MOD operator.",
            smokeTestMarker: "MOD demo",
            code: """
            ' MODDEMO.BAS - MOD operator
            PRINT "MOD demo"
            FOR N% = 1 TO 12
                PRINT N%; "MOD 5 ="; N% MOD 5
            NEXT N%
            """
        ),
        SampleProgram(
            id: "49-abs",
            filename: "ABSVAL.BAS",
            title: "ABS Function",
            category: .math,
            description: "Absolute value with ABS.",
            smokeTestMarker: "ABS values:",
            code: """
            ' ABSVAL.BAS - ABS function
            PRINT "ABS values:"
            FOR N% = -3 TO 3
                PRINT "ABS("; N%; ")="; ABS(N%)
            NEXT N%
            """
        ),
        SampleProgram(
            id: "50-series",
            filename: "SERIES.BAS",
            title: "Series Sum",
            category: .math,
            description: "Sum the first N integers.",
            smokeTestMarker: "Series sum:",
            code: """
            ' SERIES.BAS - Sum 1 to N
            N% = 100
            SUM% = 0
            FOR I% = 1 TO N%
                SUM% = SUM% + I%
            NEXT I%
            PRINT "Series sum:"; SUM%
            """
        )
    ]
}