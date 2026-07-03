import Foundation

enum LoopsPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "16-for",
            filename: "FORLOOP.BAS",
            title: "FOR...NEXT Loop",
            category: .loops,
            description: "Count from 1 to 10 with a FOR loop.",
            smokeTestMarker: "Done!",
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
            id: "17-while",
            filename: "WHILE.BAS",
            title: "WHILE...WEND",
            category: .loops,
            description: "Top-tested loop with WHILE...WEND.",
            smokeTestMarker: "128",
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
            id: "18-nested",
            filename: "NESTED.BAS",
            title: "Nested Loops",
            category: .loops,
            description: "Nested FOR loops drawing a number grid.",
            smokeTestMarker: "25",
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
            id: "19-doloop",
            filename: "DOLOOP.BAS",
            title: "DO...LOOP",
            category: .loops,
            description: "Bottom-tested DO...LOOP with EXIT DO.",
            smokeTestMarker: "DO loop done",
            code: """
            ' DOLOOP.BAS - DO...LOOP with early exit
            N% = 0
            DO
                N% = N% + 1
                IF N% >= 5 THEN GOTO 90
            LOOP
            90 PRINT "DO loop done at"; N%
            """
        ),
        SampleProgram(
            id: "20-dountil",
            filename: "DOUNTIL.BAS",
            title: "DO UNTIL",
            category: .loops,
            description: "Repeat until a condition becomes true.",
            smokeTestMarker: "Count complete",
            code: """
            ' DOUNTIL.BAS - DO UNTIL at top
            N% = 0
            DO UNTIL N% >= 5
                N% = N% + 1
                PRINT N%,
            LOOP
            PRINT
            PRINT "Count complete"
            """
        ),
        SampleProgram(
            id: "21-dowhile",
            filename: "DOWHILE.BAS",
            title: "DO WHILE",
            category: .loops,
            description: "Repeat while a condition stays true.",
            smokeTestMarker: "DO WHILE done",
            code: """
            ' DOWHILE.BAS - DO WHILE at top
            N% = 10
            PRINT "Halving:"
            DO WHILE N% >= 1
                PRINT N%,
                N% = N% \\ 2
            LOOP
            PRINT
            PRINT "DO WHILE done"
            """
        ),
        SampleProgram(
            id: "22-step",
            filename: "STEPLOOP.BAS",
            title: "FOR with STEP",
            category: .loops,
            description: "Count backwards using STEP -1.",
            smokeTestMarker: "Negative step",
            code: """
            ' STEPLOOP.BAS - FOR with negative STEP
            PRINT "Negative step:"
            FOR I% = 5 TO 1 STEP -1
                PRINT I%,
            NEXT I%
            PRINT
            PRINT "Negative step done"
            """
        ),
        SampleProgram(
            id: "23-exitfor",
            filename: "EXITFOR.BAS",
            title: "EXIT FOR",
            category: .loops,
            description: "Leave a FOR loop early with EXIT FOR.",
            smokeTestMarker: "Found 7",
            code: """
            ' EXITFOR.BAS - Leave a FOR loop early
            FOR I% = 1 TO 20
                IF I% = 7 THEN PRINT "Found 7 at iteration"; I%: GOTO 99
            NEXT I%
            99 END
            """
        ),
        SampleProgram(
            id: "24-exitdo",
            filename: "EXITDO.BAS",
            title: "EXIT DO",
            category: .loops,
            description: "Break out of a DO...LOOP with EXIT DO.",
            smokeTestMarker: "Exited at 5",
            code: """
            ' EXITDO.BAS - Leave a DO loop early
            N% = 0
            DO
                N% = N% + 1
                PRINT "Tick"; N%
                IF N% = 5 THEN PRINT "Exited at 5": GOTO 90
            LOOP
            90 END
            """
        ),
        SampleProgram(
            id: "25-countdown",
            filename: "COUNTDOWN.BAS",
            title: "Countdown",
            category: .loops,
            description: "Classic countdown using a FOR loop.",
            smokeTestMarker: "Blastoff!",
            code: """
            ' COUNTDOWN.BAS - Countdown loop
            PRINT "Countdown:"
            FOR T% = 5 TO 1 STEP -1
                PRINT T%,
            NEXT T%
            PRINT
            PRINT "Blastoff!"
            """
        )
    ]
}