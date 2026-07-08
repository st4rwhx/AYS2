// PS2WaveBackground.swift — animated PS2-dashboard-style background.
// SPDX-License-Identifier: GPL-3.0+
//
// Recreates the feel of the PlayStation 2 system menu: dark backdrop with
// slow, undulating "dune" ridges whose colour drifts over time (the real PS2
// tinted its background from its internal clock). Pure SwiftUI (TimelineView +
// Canvas), so it runs anywhere with no Metal setup.

import SwiftUI

struct PS2WaveBackground: View {
    // Number of stacked ridges from back (top) to front (bottom).
    private let ridgeCount = 7

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                draw(&ctx, size: size, t: t)
            }
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        // --- base vertical gradient (near-black -> deep blue) ---
        let base = Gradient(colors: [
            Color(red: 0.01, green: 0.02, blue: 0.06),
            Color(red: 0.02, green: 0.05, blue: 0.14)
        ])
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(base,
                                  startPoint: CGPoint(x: 0, y: 0),
                                  endPoint: CGPoint(x: 0, y: size.height))
        )

        let w = size.width
        let h = size.height
        let step: CGFloat = 6

        for i in 0..<ridgeCount {
            let f = Double(i) / Double(ridgeCount - 1)   // 0 = back/top, 1 = front/bottom
            let baseY = h * CGFloat(0.30 + 0.66 * f)
            let amp = CGFloat(18 + 16 * Double(i))
            let phase = t * (0.12 + 0.045 * Double(i))

            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w {
                let xn = Double(x / max(w, 1))
                let y = baseY
                    + CGFloat(sin(xn * .pi * 2 * 1.2 + phase)) * amp
                    + CGFloat(sin(xn * .pi * 2 * 2.6 - phase * 0.7)) * amp * 0.38
                path.addLine(to: CGPoint(x: x, y: y))
                x += step
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()

            // Hue drifts slowly through blues/teals/violets (0.50–0.74),
            // offset per ridge so the layers shimmer against each other.
            let hue = 0.50 + 0.12 * (0.5 + 0.5 * sin(t * 0.035 + f * 1.6))
            let ridgeColor = Color(hue: hue,
                                   saturation: 0.85,
                                   brightness: 0.35 + 0.16 * f)
                .opacity(0.30)

            ctx.fill(path, with: .color(ridgeColor))

            // Bright crest line for the "dune edge" glow.
            var crest = Path()
            x = 0
            var first = true
            while x <= w {
                let xn = Double(x / max(w, 1))
                let y = baseY
                    + CGFloat(sin(xn * .pi * 2 * 1.2 + phase)) * amp
                    + CGFloat(sin(xn * .pi * 2 * 2.6 - phase * 0.7)) * amp * 0.38
                let p = CGPoint(x: x, y: y)
                if first { crest.move(to: p); first = false } else { crest.addLine(to: p) }
                x += step
            }
            let crestColor = Color(hue: hue, saturation: 0.6, brightness: 0.95)
                .opacity(0.10 + 0.10 * f)
            ctx.stroke(crest, with: .color(crestColor), lineWidth: 1.5)
        }
    }
}

/// Convenience modifier: place the animated PS2 background behind any content
/// and make the content's own scroll surfaces transparent so it shows through.
extension View {
    func ps2Background() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PS2WaveBackground())
    }
}
