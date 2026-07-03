import SwiftUI

struct StatusBarView: View {
    let modeLabel: String

    var body: some View {
        HStack(spacing: 0) {
            Text("F1=Help   Enter=Execute   Esc=Cancel   Tab=Next Field   Arrow=Next Item")
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.statusText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Text(modeLabel)
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.statusText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(QBTheme.statusBackground)
    }
}