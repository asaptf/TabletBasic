import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            Text(AppBranding.fullTitle)
                .font(QBTheme.dialogFont)
            Text(AppBranding.copyright)
                .font(QBTheme.dialogFont)

            Text("Created by \(AppBranding.authorName)")
                .font(QBTheme.dialogFont)

            Button {
                openURL(AppBranding.linkedInURL)
            } label: {
                Text(AppBranding.linkedInURL.absoluteString)
                    .font(QBTheme.monoSmall)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("BASIC interpreter and retro IDE for iPhone, iPad, and Mac.")
                .font(QBTheme.dialogFont)
                .multilineTextAlignment(.center)

            Button("OK") { dismiss() }
                .font(QBTheme.dialogFont)
                .padding(.top, 8)
                .accessibilityIdentifier("aboutDismiss")
        }
        .foregroundStyle(QBTheme.dialogText)
        .padding(28)
        .background(QBTheme.dialogBackground)
        .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 2))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QBTheme.background)
    }
}