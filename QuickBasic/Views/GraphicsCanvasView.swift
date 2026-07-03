import SwiftUI
import QBEngine

struct GraphicsCanvasView: View {
    let screen: ScreenBuffer
    let revision: Int

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / CGFloat(screen.width)
            let scaleY = size.height / CGFloat(screen.height)
            let scale = min(scaleX, scaleY)

            let drawWidth = CGFloat(screen.width) * scale
            let drawHeight = CGFloat(screen.height) * scale
            let offsetX = (size.width - drawWidth) / 2
            let offsetY = (size.height - drawHeight) / 2

            context.fill(
                Path(CGRect(x: offsetX, y: offsetY, width: drawWidth, height: drawHeight)),
                with: .color(.black)
            )

            for y in 0..<screen.height {
                for x in 0..<screen.width {
                    let index = y * screen.width + x
                    guard index < screen.pixels.count else { continue }
                    let color = screen.pixels[index]
                    let rect = CGRect(
                        x: offsetX + CGFloat(x) * scale,
                        y: offsetY + CGFloat(y) * scale,
                        width: max(1, scale),
                        height: max(1, scale)
                    )
                    context.fill(
                        Path(rect),
                        with: .color(Color(
                            red: Double(color.red) / 255,
                            green: Double(color.green) / 255,
                            blue: Double(color.blue) / 255
                        ))
                    )
                }
            }
        }
        .aspectRatio(CGFloat(screen.width) / CGFloat(screen.height), contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(QBTheme.menuText.opacity(0.4), lineWidth: 1)
        )
        .id(revision)
    }
}