// GameHeroBackground.swift — dynamic ambient backdrop for the games hub.
// AYS2: additive (seam) — new file, not present upstream.
// SPDX-License-Identifier: GPL-3.0+
//
// Samples the dominant color of the focused game's cover art (CIAreaAverage,
// a single-pixel-output Core Image reduction — cheap, no per-frame cost since
// it only reruns when the focused cover image changes) and washes it behind
// the dashboard, cross-fading with a spring as focus moves. This is the
// console-hub "ambient light" effect (PS5/Xbox home), scoped to the Games
// section only per the perf agreement: idle-screen cost, never during
// gameplay.

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// A Swift actor, not @MainActor: CIContext.render is real work (tens of ms
/// on a large cover), and this must never run on the main thread. Callers
/// just `await` it — the actor hop off the main thread happens for free.
actor AmbientCoverColorCache {
    static let shared = AmbientCoverColorCache()
    private var cache: [String: Color] = [:]
    // CIContext is documented thread-safe for concurrent use by Apple, so
    // one shared instance on this actor is fine.
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Average color of the image, cached by a caller-supplied stable key
    /// (we use the cover URL's absoluteString) so repeated focus on the same
    /// game is free after the first pass.
    func averageColor(for image: UIImage, key: String) -> Color {
        if let cached = cache[key] { return cached }
        let color = Self.computeAverageColor(image: image, context: context) ?? Retro.accentDeep
        cache[key] = color
        return color
    }

    private static func computeAverageColor(image: UIImage, context: CIContext) -> Color? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: nil)
        return Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
    }
}

/// Full-bleed ambient wash behind the dashboard, tinted by the focused
/// game's cover. Falls back to the neutral RetroBackground when there's no
/// focused cover yet (empty library, or still loading).
struct AmbientHeroBackground: View {
    let focusedImage: UIImage?
    let focusKey: String?

    @State private var tint: Color?

    var body: some View {
        ZStack {
            RetroBackground()
            if let tint {
                RadialGradient(
                    colors: [tint.opacity(0.55), tint.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 40,
                    endRadius: 520
                )
                .ignoresSafeArea()
                .blendMode(.plusLighter)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: tint)
        .task(id: focusKey) {
            guard let focusedImage, let focusKey else {
                tint = nil
                return
            }
            // AmbientCoverColorCache is its own actor, so this await already
            // hops off the main thread for the CIContext.render work.
            tint = await AmbientCoverColorCache.shared.averageColor(for: focusedImage, key: focusKey)
        }
    }
}
