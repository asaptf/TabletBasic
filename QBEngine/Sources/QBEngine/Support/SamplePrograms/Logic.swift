import Foundation

enum LogicPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "73-andor",
            filename: "ANDOR.BAS",
            title: "AND OR NOT",
            category: .logic,
            description: "Boolean logic with AND, OR, and NOT.",
            smokeTestMarker: "Logic table:",
            code: """
            ' ANDOR.BAS - AND, OR, NOT
            PRINT "Logic table:"
            PRINT "T AND T ="; -1 AND -1
            PRINT "T OR F  ="; -1 OR 0
            PRINT "NOT F   ="; NOT 0
            """
        ),
        SampleProgram(
            id: "74-xor",
            filename: "XORBIT.BAS",
            title: "XOR Operator",
            category: .logic,
            description: "Exclusive-or truth values with XOR.",
            smokeTestMarker: "XOR demo:",
            code: """
            ' XORBIT.BAS - XOR operator
            PRINT "XOR demo:"
            PRINT "T XOR T ="; -1 XOR -1
            PRINT "T XOR F ="; -1 XOR 0
            PRINT "F XOR F ="; 0 XOR 0
            """
        ),
        SampleProgram(
            id: "75-eqvimp",
            filename: "EQVIMP.BAS",
            title: "EQV and IMP",
            category: .logic,
            description: "Equivalence and implication operators.",
            smokeTestMarker: "EQV and IMP:",
            code: """
            ' EQVIMP.BAS - EQV and IMP
            PRINT "EQV and IMP:"
            PRINT "T EQV T ="; -1 EQV -1
            PRINT "T IMP F ="; -1 IMP 0
            PRINT "F IMP T ="; 0 IMP -1
            """
        ),
        SampleProgram(
            id: "76-truth",
            filename: "TRUTH.BAS",
            title: "Truth Values",
            category: .logic,
            description: "How IF treats numeric truth values.",
            smokeTestMarker: "NOT true",
            code: """
            ' TRUTH.BAS - Numeric truth in IF
            IF NOT 0 THEN PRINT "NOT false"
            PRINT "NOT true"
            """
        ),
        SampleProgram(
            id: "77-flags",
            filename: "FLAGS.BAS",
            title: "Bit Flags",
            category: .logic,
            description: "Combine flags with OR and test with AND.",
            smokeTestMarker: "Flag set",
            code: """
            ' FLAGS.BAS - Bit-style flags
            FLAG_READ% = 1
            FLAG_WRITE% = 2
            PERMS% = FLAG_READ% OR FLAG_WRITE%
            IF PERMS% AND FLAG_WRITE% THEN PRINT "Flag set"
            """
        ),
        SampleProgram(
            id: "78-parity",
            filename: "PARITY.BAS",
            title: "Even or Odd",
            category: .logic,
            description: "Test parity using MOD and AND.",
            smokeTestMarker: "Parity:",
            code: """
            ' PARITY.BAS - Even/odd check
            PRINT "Parity:"
            FOR N% = 1 TO 8
                IF N% MOD 2 = 0 THEN PRINT N%; "even"
                IF N% MOD 2 <> 0 THEN PRINT N%; "odd"
            NEXT N%
            """
        ),
        SampleProgram(
            id: "79-range",
            filename: "RANGE.BAS",
            title: "Range Check",
            category: .logic,
            description: "Validate a value lies within bounds.",
            smokeTestMarker: "In range",
            code: """
            ' RANGE.BAS - Range validation
            X% = 15
            LOW% = 10
            HIGH% = 20
            IF X% >= LOW% AND X% <= HIGH% THEN PRINT "In range"
            """
        ),
        SampleProgram(
            id: "80-switch",
            filename: "SWITCH.BAS",
            title: "ON GOTO Switch",
            category: .logic,
            description: "Multi-way branch using ON GOTO.",
            smokeTestMarker: "Case C",
            code: """
            ' SWITCH.BAS - ON GOTO switch
            CHOICE% = 3
            ON CHOICE% GOTO 100, 200, 300, 400
            END
            100 PRINT "Case A": END
            200 PRINT "Case B": END
            300 PRINT "Case C": END
            400 PRINT "Case D": END
            """
        )
    ]
}