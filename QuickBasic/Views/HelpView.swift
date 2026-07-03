import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpSection("Keys", """
                    F1          Display this help
                    F5          Start program
                    Enter       Execute (run or immediate)
                    Esc         Cancel / return to editor
                    """)

                    helpSection("Menus", """
                    File > Open...               Open .bas from Files / iCloud
                    File > Save / Save As...     Save to Files / iCloud
                    File > Open Sample Program   20 built-in demos
                    Run > Start                  Run current program
                    Help > Learning Guide        Step-by-step lessons
                    Help > About                 Author and app info
                    """)

                    helpSection("Statements", """
                    PRINT  INPUT  IF...THEN  FOR...NEXT
                    WHILE...WEND  GOSUB  RETURN  GOTO
                    DIM  DATA  READ  SCREEN  LINE  CIRCLE
                    """)
                }
                .padding()
            }
            .font(QBTheme.monoFont)
            .navigationTitle("\(AppBranding.name) Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func helpSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}