import SwiftUI

enum Brand {
    static let navy = Color(red: 0.078, green: 0.129, blue: 0.239)   // #14213D
    static let amber = Color(red: 0.988, green: 0.639, blue: 0.067)  // #FCA311
}

/// The logo's eye, drawn as vectors so it stays sharp at any size.
struct EyeMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 256
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            var almond = Path()
            almond.move(to: pt(28, 128))
            almond.addQuadCurve(to: pt(228, 128), control: pt(128, 36))
            almond.addQuadCurve(to: pt(28, 128), control: pt(128, 220))
            ctx.fill(almond, with: .color(Brand.amber))
            ctx.fill(Path(ellipseIn: CGRect(x: 86 * k, y: 86 * k, width: 84 * k, height: 84 * k)),
                     with: .color(Brand.navy))
            var moon = Path()
            moon.move(to: pt(138, 104))
            moon.addArc(center: pt(138, 128), radius: 24 * k, startAngle: .degrees(-90),
                        endAngle: .degrees(90), clockwise: true)
            moon.addArc(center: pt(138, 128), radius: 20 * k, startAngle: .degrees(90),
                        endAngle: .degrees(-90), clockwise: false)
            ctx.fill(moon, with: .color(Brand.amber))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Rounded tile behind the eye, like the app icon.
struct LogoTile: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23).fill(Brand.navy)
            EyeMark().padding(size * 0.06)
        }
        .frame(width: size, height: size)
    }
}
