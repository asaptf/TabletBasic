import Foundation

enum GraphicsPrograms {
    static let all: [SampleProgram] = [
        SampleProgram(
            id: "51-graphics",
            filename: "SHAPES.BAS",
            title: "Basic Shapes",
            category: .graphics,
            description: "SCREEN 13 with CIRCLE and LINE.",
            smokeTestMarker: "Shapes drawn!",
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
            id: "52-boxes",
            filename: "BOXES.BAS",
            title: "Nested Boxes",
            category: .graphics,
            description: "Draw concentric boxes with LINE...B.",
            smokeTestMarker: "Nested boxes",
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
            id: "53-stars",
            filename: "STARS.BAS",
            title: "Starfield",
            category: .graphics,
            description: "Random stars using PSET.",
            smokeTestMarker: "Starfield complete",
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
            id: "54-circles",
            filename: "MOIRE.BAS",
            title: "Moire Pattern",
            category: .graphics,
            description: "Concentric circles create a moire effect.",
            smokeTestMarker: "Moire pattern",
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
            id: "55-sine",
            filename: "SINEWAVE.BAS",
            title: "Sine Wave",
            category: .graphics,
            description: "Plot a sine wave using LINE.",
            smokeTestMarker: "Sine wave plotted",
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
            id: "56-flag",
            filename: "FLAG.BAS",
            title: "Simple Flag",
            category: .graphics,
            description: "Draw a simple flag with colored rectangles.",
            smokeTestMarker: "Flag drawn!",
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
        ),
        SampleProgram(
            id: "57-lines",
            filename: "LINES.BAS",
            title: "Line Fan",
            category: .graphics,
            description: "Radiating lines from a center point.",
            smokeTestMarker: "Lines drawn",
            code: """
            ' LINES.BAS - Radiating lines
            SCREEN 13
            CLS
            CX% = 160
            CY% = 100
            FOR A% = 0 TO 315 STEP 45
                X% = CX% + INT(COS(A% / 57.3) * 80)
                Y% = CY% + INT(SIN(A% / 57.3) * 80)
                LINE (CX%, CY%)-(X%, Y%), 2
            NEXT A%
            PRINT "Lines drawn"
            """
        ),
        SampleProgram(
            id: "58-colors",
            filename: "COLORS.BAS",
            title: "Color Bars",
            category: .graphics,
            description: "Draw vertical bars in palette colors.",
            smokeTestMarker: "Palette set",
            code: """
            ' COLORS.BAS - Color palette bars
            SCREEN 13
            CLS
            FOR C% = 1 TO 15
                X1% = (C% - 1) * 20
                X2% = X1% + 18
                LINE (X1%, 40)-(X2%, 160), C%, B
            NEXT C%
            PRINT "Palette set"
            """
        ),
        SampleProgram(
            id: "59-preset",
            filename: "PRESET.BAS",
            title: "PRESET Erase",
            category: .graphics,
            description: "Draw dots then erase with PRESET.",
            smokeTestMarker: "Erase dots",
            code: """
            ' PRESET.BAS - PSET and PRESET
            SCREEN 13
            CLS
            FOR I% = 1 TO 20
                X% = 50 + I% * 10
                PSET (X%, 100), 4
            NEXT I%
            FOR I% = 1 TO 10
                X% = 50 + I% * 10
                PRESET (X%, 100)
            NEXT I%
            PRINT "Erase dots"
            """
        ),
        SampleProgram(
            id: "60-grid",
            filename: "GRIDGFX.BAS",
            title: "Graphics Grid",
            category: .graphics,
            description: "Draw a coordinate grid with LINE.",
            smokeTestMarker: "Grid drawn",
            code: """
            ' GRIDGFX.BAS - Coordinate grid
            SCREEN 13
            CLS
            FOR X% = 0 TO 320 STEP 20
                LINE (X%, 0)-(X%, 199), 8
            NEXT X%
            FOR Y% = 0 TO 200 STEP 20
                LINE (0, Y%)-(319, Y%), 8
            NEXT Y%
            PRINT "Grid drawn"
            """
        ),
        SampleProgram(
            id: "61-spiral",
            filename: "SPIRAL.BAS",
            title: "Circle Spiral",
            category: .graphics,
            description: "Offset circles form a spiral pattern.",
            smokeTestMarker: "Spiral done",
            code: """
            ' SPIRAL.BAS - Offset circles
            SCREEN 13
            CLS
            FOR I% = 1 TO 12
                R% = I% * 8
                CIRCLE (160 + I% * 3, 100), R%, (I% MOD 15) + 1
            NEXT I%
            PRINT "Spiral done"
            """
        ),
        SampleProgram(
            id: "62-bars",
            filename: "BARCHART.BAS",
            title: "Bar Chart",
            category: .graphics,
            description: "Simple bar chart with filled boxes.",
            smokeTestMarker: "Bar chart",
            code: """
            ' BARCHART.BAS - Simple bar chart
            SCREEN 13
            CLS
            DIM H%(5)
            H%(1) = 40: H%(2) = 80: H%(3) = 60: H%(4) = 100: H%(5) = 30
            FOR I% = 1 TO 5
                X1% = 40 + (I% - 1) * 50
                X2% = X1% + 35
                Y2% = 170
                Y1% = Y2% - H%(I%)
                LINE (X1%, Y1%)-(X2%, Y2%), I% + 2, BF
            NEXT I%
            PRINT "Bar chart"
            """
        ),
        SampleProgram(
            id: "63-triangle",
            filename: "TRIANGLE.BAS",
            title: "Triangle",
            category: .graphics,
            description: "Draw a triangle with three LINE calls.",
            smokeTestMarker: "Triangle done",
            code: """
            ' TRIANGLE.BAS - Triangle outline
            SCREEN 13
            CLS
            LINE (160, 30)-(60, 170), 4
            LINE (60, 170)-(260, 170), 4
            LINE (260, 170)-(160, 30), 4
            PRINT "Triangle done"
            """
        ),
        SampleProgram(
            id: "64-checker",
            filename: "CHECKER.BAS",
            title: "Checkerboard",
            category: .graphics,
            description: "Alternating squares with LINE...B.",
            smokeTestMarker: "Checkerboard",
            code: """
            ' CHECKER.BAS - Checkerboard pattern
            SCREEN 13
            CLS
            SIZE% = 20
            FOR ROW% = 0 TO 9
                FOR COL% = 0 TO 15
                    IF (ROW% + COL%) MOD 2 = 0 THEN X1% = COL% * SIZE%: Y1% = ROW% * SIZE%: X2% = X1% + SIZE% - 1: Y2% = Y1% + SIZE% - 1: LINE (X1%, Y1%)-(X2%, Y2%), 15, B
                NEXT COL%
            NEXT ROW%
            PRINT "Checkerboard"
            """
        )
    ]
}