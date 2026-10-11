import SwiftUI

enum Brand {
    static let navy = Color(red: 0.086, green: 0.133, blue: 0.247)   // #16223F
    static let amber = Color(red: 0.988, green: 0.639, blue: 0.067)  // #FCA311
}

/// The logo mark (crescent crossed by a bar), drawn as vectors so it stays sharp at any size.
struct MoonMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 256
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (x + 5) * k, y: y * k) }
            // Crescent = circle r62 at (120,128) minus circle r52 at (146,112); see Resources/logo.svg.
            var crescent = Path()
            crescent.addEllipse(in: CGRect(x: (120 + 5 - 62) * k, y: (128 - 62) * k, width: 124 * k, height: 124 * k))
            var cut = Path()
            cut.addEllipse(in: CGRect(x: (146 + 5 - 52) * k, y: (112 - 52) * k, width: 104 * k, height: 104 * k))
            ctx.fill(crescent.subtracting(cut), with: .color(Color(red: 0.96, green: 0.97, blue: 0.98)))

            var bar = Path()
            bar.move(to: pt(74, 192)); bar.addLine(to: pt(184, 64))
            ctx.stroke(bar, with: .color(Brand.navy), style: StrokeStyle(lineWidth: 22 * k, lineCap: .round))
            ctx.stroke(bar, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 10 * k, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Rounded tile behind the mark, like the app icon.
struct LogoTile: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(LinearGradient(colors: [Color(red: 0.114, green: 0.176, blue: 0.314), Brand.navy],
                                     startPoint: .top, endPoint: .bottom))
            MoonMark().padding(size * 0.06)
        }
        .frame(width: size, height: size)
    }
}
