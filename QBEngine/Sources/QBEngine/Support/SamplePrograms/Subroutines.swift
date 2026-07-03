import Foundation

enum SubroutinesPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "26-gosub",
            filename: "GOSUB.BAS",
            title: "GOSUB...RETURN",
            category: .subroutines,
            description: "Classic subroutines with line numbers.",
            smokeTestMarker: "Main program ending",
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
            id: "27-on-gosub",
            filename: "MENU.BAS",
            title: "ON GOSUB",
            category: .subroutines,
            description: "Dispatch to subroutines by index.",
            smokeTestMarker: "Option 3 selected",
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
            id: "28-return",
            filename: "RETDEMO.BAS",
            title: "Nested GOSUB",
            category: .subroutines,
            description: "Subroutines calling other subroutines.",
            smokeTestMarker: "Back from sub",
            code: """
            ' RETDEMO.BAS - Nested GOSUB calls
            PRINT "Main start"
            GOSUB 100
            PRINT "Back from sub"
            END
            100 PRINT "  In subroutine"
            110 GOSUB 200
            120 RETURN
            200 PRINT "    Inner subroutine"
            210 RETURN
            """
        ),
        SampleProgram(
            id: "29-ongoto",
            filename: "ONGOTO.BAS",
            title: "ON GOTO",
            category: .subroutines,
            description: "Jump to a labeled branch by index.",
            smokeTestMarker: "Branch 2",
            code: """
            ' ONGOTO.BAS - ON GOTO dispatch
            CHOICE% = 2
            PRINT "Selecting branch"; CHOICE%
            ON CHOICE% GOTO 100, 200, 300
            END
            100 PRINT "Branch 1": END
            200 PRINT "Branch 2": END
            300 PRINT "Branch 3": END
            """
        ),
        SampleProgram(
            id: "30-flow",
            filename: "FLOWCHART.BAS",
            title: "Subroutine Flow",
            category: .subroutines,
            description: "Structured flow using multiple GOSUB calls.",
            smokeTestMarker: "Flow complete",
            code: """
            ' FLOWCHART.BAS - Subroutine workflow
            PRINT "Flow start"
            GOSUB 500
            GOSUB 600
            PRINT "Flow complete"
            END
            500 PRINT "  Step A"
            510 RETURN
            600 PRINT "  Step B"
            610 RETURN
            """
        ),
        SampleProgram(
            id: "31-stack",
            filename: "CALLSTACK.BAS",
            title: "Return Stack",
            category: .subroutines,
            description: "Demonstrate GOSUB return order.",
            smokeTestMarker: "Stack demo done",
            code: """
            ' CALLSTACK.BAS - Return stack order
            PRINT "Stack demo"
            GOSUB 100
            GOSUB 200
            PRINT "Stack demo done"
            END
            100 PRINT "  Push A"
            110 RETURN
            200 PRINT "  Push B"
            210 RETURN
            """
        )
    ]
}