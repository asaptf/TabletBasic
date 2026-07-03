import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text(AppBranding.fullTitle)
                .font(QBTheme.dialogFont)
            Text(AppBranding.copyright)
                .font(QBTheme.dialogFont)
            Text("BASIC interpreter and retro IDE for iPad and Mac.")
                .font(QBTheme.dialogFont)
                .multilineTextAlignment(.center)
            Button("OK") { dismiss() }
                .font(QBTheme.dialogFont)
                .padding(.top, 8)
        }
        .foregroundStyle(QBTheme.dialogText)
        .padding(28)
        .background(QBTheme.dialogBackground)
        .overlay(Rectangle().stroke(QBTheme.dialogBorder, lineWidth: 2))
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QBTheme.background)
    }
}