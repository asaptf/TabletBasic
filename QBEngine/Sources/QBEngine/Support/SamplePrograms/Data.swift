import Foundation

enum DataPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "32-data",
            filename: "DATAREAD.BAS",
            title: "DATA & READ",
            category: .data,
            description: "Store and read inline data values.",
            smokeTestMarker: "Planet data:",
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
            id: "33-array",
            filename: "ARRAY.BAS",
            title: "Arrays",
            category: .data,
            description: "DIM statement and array indexing.",
            smokeTestMarker: "Test scores:",
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
            id: "34-matrix",
            filename: "MATRIX.BAS",
            title: "Row-Major Matrix",
            category: .data,
            description: "Store a 3x3 grid in a 1D array.",
            smokeTestMarker: "Matrix sum:",
            code: """
            ' MATRIX.BAS - Row-major 1D storage
            DIM GRID%(9)
            COLS% = 3
            FOR R% = 1 TO 3
                FOR C% = 1 TO 3
                    IDX% = (R% - 1) * COLS% + C%
                    GRID%(IDX%) = R% * C%
                NEXT C%
            NEXT R%
            SUM% = 0
            FOR I% = 1 TO 9
                SUM% = SUM% + GRID%(I%)
            NEXT I%
            PRINT "Matrix sum:"; SUM%
            """
        ),
        SampleProgram(
            id: "35-restore",
            filename: "RESTORE.BAS",
            title: "RESTORE",
            category: .data,
            description: "Re-read DATA from the beginning.",
            smokeTestMarker: "Second pass:",
            code: """
            ' RESTORE.BAS - RESTORE pointer
            PRINT "First pass:"
            FOR I% = 1 TO 3
                READ V%
                PRINT V%,
            NEXT I%
            PRINT
            RESTORE
            PRINT "Second pass:"
            FOR I% = 1 TO 3
                READ V%
                PRINT V%,
            NEXT I%
            PRINT
            DATA 10, 20, 30
            """
        ),
        SampleProgram(
            id: "36-readmix",
            filename: "READMIX.BAS",
            title: "Mixed DATA",
            category: .data,
            description: "Read strings and numbers from DATA.",
            smokeTestMarker: "Mixed data:",
            code: """
            ' READMIX.BAS - Mixed types in DATA
            PRINT "Mixed data:"
            READ NAME$, AGE%, SCORE!
            PRINT NAME$; "age"; AGE%; "score"; SCORE!
            DATA "Alex", 12, 95.5
            """
        ),
        SampleProgram(
            id: "37-sumarray",
            filename: "SUMARRAY.BAS",
            title: "Sum an Array",
            category: .data,
            description: "Fill an array and compute its total.",
            smokeTestMarker: "Array sum:",
            code: """
            ' SUMARRAY.BAS - Sum array elements
            DIM VALS%(10)
            FOR I% = 1 TO 10
                VALS%(I%) = I%
            NEXT I%
            SUM% = 0
            FOR I% = 1 TO 10
                SUM% = SUM% + VALS%(I%)
            NEXT I%
            PRINT "Array sum:"; SUM%
            """
        ),
        SampleProgram(
            id: "38-strdata",
            filename: "STRDATA.BAS",
            title: "String DATA",
            category: .data,
            description: "Read a list of strings from DATA.",
            smokeTestMarker: "Colors:",
            code: """
            ' STRDATA.BAS - String DATA items
            PRINT "Colors:"
            FOR I% = 1 TO 4
                READ HUE$
                PRINT "  "; HUE$
            NEXT I%
            DATA "Red", "Green", "Blue", "Yellow"
            """
        ),
        SampleProgram(
            id: "39-totavg",
            filename: "TOTAVG.BAS",
            title: "Average from DATA",
            category: .data,
            description: "Compute average of DATA values.",
            smokeTestMarker: "Average:",
            code: """
            ' TOTAVG.BAS - Average from DATA
            SUM% = 0
            FOR I% = 1 TO 5
                READ SCORE%
                SUM% = SUM% + SCORE%
            NEXT I%
            PRINT "Average:"; SUM% / 5
            DATA 80, 90, 70, 85, 95
            """
        ),
        SampleProgram(
            id: "40-sequence",
            filename: "SEQUENCE.BAS",
            title: "Number Sequence",
            category: .data,
            description: "Build a sequence from DATA and READ.",
            smokeTestMarker: "Sequence:",
            code: """
            ' SEQUENCE.BAS - DATA-driven sequence
            PRINT "Sequence:"
            FOR I% = 1 TO 6
                READ N%
                PRINT N%,
            NEXT I%
            PRINT
            DATA 2, 4, 8, 16, 32, 64
            """
        )
    ]
}