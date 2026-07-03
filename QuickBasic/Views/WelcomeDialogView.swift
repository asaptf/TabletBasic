import SwiftUI

struct WelcomeDialogView: View {
    let onEnter: () -> Void
    let onEscape: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("Welcome to")
                    .font(QBTheme.dialogFont)
                Text(AppBranding.fullTitle)
                    .font(QBTheme.dialogFont)
                Text(AppBranding.copyright)
                    .font(QBTheme.dialogFont)
                Text("All rights reserved.")
                    .font(QBTheme.dialogFont)
                    .padding(.bottom, 8)

                Button(action: onEnter) {
                    Text("< Press Enter to see the \(AppBranding.name) Learning Guide >")
                        .font(QBTheme.dialogFont)
                }
                .buttonStyle(.plain)

                Button(action: onEscape) {
                    Text("< Press ESC to clear this dialog box >")
                        .font(QBTheme.dialogFont)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcomeDismiss")
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(QBTheme.dialogText)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(QBTheme.dialogBackground)
            .overlay(
                Rectangle()
                    .stroke(QBTheme.dialogBorder, lineWidth: 2)
            )
            .frame(maxWidth: 520)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QBTheme.background)
    }
}