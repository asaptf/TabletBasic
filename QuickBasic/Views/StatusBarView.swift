import SwiftUI

struct StatusBarView: View {
    let modeLabel: String
    let statusMessage: String

    var body: some View {
        HStack(spacing: 8) {
            Text("F1=Help   F5=Run   Enter=Execute   Esc=Cancel")
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.statusText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(QBTheme.monoSmall)
                    .foregroundStyle(QBTheme.statusSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }

            Text(modeLabel)
                .font(QBTheme.monoSmall)
                .foregroundStyle(QBTheme.statusText)
                .layoutPriority(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(QBTheme.statusBackground)
    }
}