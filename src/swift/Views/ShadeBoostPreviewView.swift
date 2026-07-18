// ShadeBoostPreviewView.swift — Live Shade Boost preview over bundled footage
// AYS2: additive (seam) — new file, not present upstream.
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UIKit
import ImageIO

/// Decodes the bundled `shadeboost_preview.gif` once into frames + per-frame
/// delays, so ShadeBoostPreviewView doesn't re-decode on every slider tick.
@MainActor
private final class ShadeBoostPreviewClip {
    static let shared = ShadeBoostPreviewClip()

    let frames: [Image]
    private let cumulativeDurations: [Double]
    private let totalDuration: Double

    private init() {
        guard
            let url = Bundle.main.url(forResource: "shadeboost_preview", withExtension: "gif"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            frames = []
            cumulativeDurations = []
            totalDuration = 0
            return
        }

        let count = CGImageSourceGetCount(source)
        var decodedFrames: [Image] = []
        var durations: [Double] = []
        decodedFrames.reserveCapacity(count)
        durations.reserveCapacity(count)

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            decodedFrames.append(Image(uiImage: UIImage(cgImage: cgImage)))

            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gifProperties?[kCGImagePropertyGIFDelayTime] as? Double)
                ?? 0.1
            durations.append(max(delay, 0.02))
        }

        frames = decodedFrames
        var cumulative: [Double] = []
        cumulative.reserveCapacity(durations.count)
        var running: Double = 0
        for duration in durations {
            running += duration
            cumulative.append(running)
        }
        cumulativeDurations = cumulative
        totalDuration = running
    }

    func frameIndex(at elapsed: Double) -> Int {
        guard totalDuration > 0, !frames.isEmpty else { return 0 }
        let position = elapsed.truncatingRemainder(dividingBy: totalDuration)
        for (index, cutoff) in cumulativeDurations.enumerated() where position < cutoff {
            return index
        }
        return frames.count - 1
    }
}

/// Loops a short bundled gameplay clip through the exact brightness/contrast/
/// saturation/gamma math the GS renderer uses (`ps_shadeboost` in
/// convert.metal, mirrored in ShadeBoostPreview.metal), so the Shade Boost
/// sliders in Settings show their effect without a game loaded.
struct ShadeBoostPreviewView: View {
    let brightnessPercent: Int
    let contrastPercent: Int
    let saturationPercent: Int
    let gammaPercent: Int

    private let clip = ShadeBoostPreviewClip.shared

    var body: some View {
        Group {
            if clip.frames.isEmpty {
                Color.black
            } else {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    clip.frames[clip.frameIndex(at: elapsed)]
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
        .colorEffect(
            ShaderLibrary.default.shadeBoost(
                .float(Float(brightnessPercent) / 50.0),
                .float(Float(contrastPercent) / 50.0),
                .float(Float(saturationPercent) / 50.0),
                .float(Float(gammaPercent) / 50.0)
            )
        )
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}
