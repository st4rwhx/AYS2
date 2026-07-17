// CoverThumbnailView.swift - Cover thumbnail rendering and cache
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UIKit
import ImageIO

struct CoverThumbnailView: View {
    let gameName: String
    let coverURL: URL?
    let coverSignature: String?
    let width: CGFloat
    let height: CGFloat

    @State private var image: UIImage?
    @State private var angleX: Double = 0
    @State private var angleY: Double = 0
    @State private var scale3D: CGFloat = 1.0

    private var cacheID: String {
        "\(coverSignature ?? "placeholder")|\(Int(width))x\(Int(height))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: gameName.lowercased().hasSuffix(".chd") ? "archivebox" : "opticaldisc")
                        .font(.system(size: 24, weight: .medium))
                    Text(gameName.lowercased().hasSuffix(".chd") ? "CHD" : "PS2")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(scale3D)
        .rotation3DEffect(
            .degrees(angleY),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.7
        )
        .rotation3DEffect(
            .degrees(angleX),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: 0.7
        )
        .shadow(color: .black.opacity(0.3), radius: 8 + angleY.magnitude * 0.05, x: angleY * 0.5, y: angleX * 0.5)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let relX = (location.y - (height / 2)) / (height / 2)
                let relY = (location.x - (width / 2)) / (width / 2)
                withAnimation(.easeOut(duration: 0.2)) {
                    angleX = -relX * 15
                    angleY = relY * 15
                    scale3D = 1.05
                }
            case .ended:
                withAnimation(.easeOut(duration: 0.4)) {
                    angleX = 0
                    angleY = 0
                    scale3D = 1.0
                }
            }
        }
        .task(id: cacheID) {
            await loadThumbnail()
        }
        .accessibilityHidden(true)
    }

    @MainActor
    private func loadThumbnail() async {
        guard let coverURL else {
            image = nil
            return
        }

        let scale = UIScreen.main.scale
        if let cached = CoverThumbnailCache.shared.cachedImage(for: coverURL, signature: coverSignature, width: width, height: height, scale: scale) {
            image = cached
            return
        }

        image = await CoverThumbnailCache.shared.thumbnail(for: coverURL, signature: coverSignature, width: width, height: height, scale: scale)
    }
}

final class CoverThumbnailCache: @unchecked Sendable {
    static let shared = CoverThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 768
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func cachedImage(for url: URL, signature: String?, width: CGFloat, height: CGFloat, scale: CGFloat) -> UIImage? {
        cache.object(forKey: cacheKey(for: url, signature: signature, width: width, height: height, scale: scale))
    }

    func thumbnail(for url: URL, signature: String?, width: CGFloat, height: CGFloat, scale: CGFloat) async -> UIImage? {
        let key = cacheKey(for: url, signature: signature, width: width, height: height, scale: scale)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let path = url.path
        let maxPixelSize = max(1, Int(max(width, height) * scale))
        let image = await Task.detached(priority: .utility) {
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            ] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                return UIImage(contentsOfFile: path)
            }

            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }.value

        if let image {
            let cost = max(1, Int(image.size.width * image.scale * image.size.height * image.scale * 4))
            cache.setObject(image, forKey: key, cost: cost)
        }

        return image
    }

    static func signature(for url: URL?) -> String? {
        guard let url else { return nil }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values?.fileSize ?? 0
        return "\(url.path)|\(modified)|\(size)"
    }

    private func cacheKey(for url: URL, signature: String?, width: CGFloat, height: CGFloat, scale: CGFloat) -> NSString {
        let pixelWidth = Int(width * scale)
        let pixelHeight = Int(height * scale)
        return "\(signature ?? url.path)|\(pixelWidth)x\(pixelHeight)" as NSString
    }
}
