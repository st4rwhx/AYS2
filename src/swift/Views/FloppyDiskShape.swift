// FloppyDiskShape.swift — a classic "save" floppy-disk glyph drawn natively.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user request — the on-screen Quick Save button should look like a
// floppy disk (the universal "save" icon), and Quick Load like a reload
// arrow. SF Symbols has no floppy, so we draw one as a SwiftUI Shape (no
// asset-catalog dependency, scales cleanly at any size). Even-odd fill punches
// the shutter window and the label so it reads as a floppy in one flat color.

import SwiftUI

struct FloppyDiskShape: Shape {
    func path(in rect: CGRect) -> Path {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var p = Path()

        // Body outline with the classic cut top-right corner.
        p.move(to: P(0.08, 0.06))
        p.addLine(to: P(0.70, 0.06))
        p.addLine(to: P(0.94, 0.30))
        p.addLine(to: P(0.94, 0.94))
        p.addLine(to: P(0.08, 0.94))
        p.closeSubpath()

        // Top shutter window (the metal slider), punched as a hole.
        p.move(to: P(0.30, 0.10))
        p.addLine(to: P(0.62, 0.10))
        p.addLine(to: P(0.62, 0.30))
        p.addLine(to: P(0.30, 0.30))
        p.closeSubpath()

        // Bottom label, punched as a hole.
        p.move(to: P(0.24, 0.52))
        p.addLine(to: P(0.78, 0.52))
        p.addLine(to: P(0.78, 0.88))
        p.addLine(to: P(0.24, 0.88))
        p.closeSubpath()

        return p
    }
}
