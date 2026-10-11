import SwiftUI

/// Monochrome palette: the UI follows the system appearance, the logo is always black and white.
enum Brand {
    /// Accent for fills, rings and the primary button: white in dark mode, black in light mode.
    static let ink = Color.primary
    /// Text or glyphs drawn on top of `ink`.
    static let onInk = Color(nsColor: .windowBackgroundColor)
}

/// The logo mark (shaded crescent crossed by a bar), drawn as vectors so it stays sharp at any size.
/// Geometry matches Resources/logo.svg.
struct MoonMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 256
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (x + 5) * k, y: y * k) }

            // Crescent = circle r62 at (120,128) minus circle r52 at (146,112).
            let outer = Path(ellipseIn: CGRect(x: (120 + 5 - 62) * k, y: (128 - 62) * k, width: 124 * k, height: 124 * k))
            let cut = Path(ellipseIn: CGRect(x: (146 + 5 - 52) * k, y: (112 - 52) * k, width: 104 * k, height: 104 * k))
            ctx.fill(outer.subtracting(cut), with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(white: 1.0), location: 0),
                    .init(color: Color(white: 0.66), location: 0.5),
                    .init(color: Color(white: 0.23), location: 1),
                ]),
                startPoint: pt(100, 66), endPoint: pt(150, 190)))

            var bar = Path()
            bar.move(to: pt(74, 192)); bar.addLine(to: pt(184, 64))
            ctx.stroke(bar, with: .color(Color(white: 0.02)), style: StrokeStyle(lineWidth: 22 * k, lineCap: .round))
            ctx.stroke(bar, with: .linearGradient(
                Gradient(colors: [Color(white: 0.56), Color(white: 0.95)]),
                startPoint: pt(74, 192), endPoint: pt(184, 64)),
                style: StrokeStyle(lineWidth: 10 * k, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Black rounded tile behind the mark, like the app icon.
struct LogoTile: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(LinearGradient(colors: [Color(white: 0.11), .black], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.23)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            MoonMark().padding(size * 0.06)
        }
        .frame(width: size, height: size)
    }
}
