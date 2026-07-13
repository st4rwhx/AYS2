// CoverArtManager.swift — fetch & cache PS2 box/disc art by disc serial.
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UIKit

/// Downloads and caches PS2 cover art keyed by disc serial (e.g. "SLUS-20946").
/// Art comes from the community xlenore/ps2-covers CDN. Results are cached in
/// memory and on disk (Documents/covers) so each serial is fetched at most once.
final class CoverArtManager: @unchecked Sendable {
    static let shared = CoverArtManager()

    // Cache raw image bytes (Sendable) rather than UIImage: under Swift 6 strict
    // concurrency a non-Sendable UIImage can't cross from this nonisolated actor
    // back to the MainActor view. Views decode UIImage(data:) on the main thread.
    private let memCache = NSCache<NSString, NSData>()
    private let session: URLSession
    private let lock = NSLock()
    private var negative = Set<String>()  // serials known to have no art

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
        memCache.countLimit = 256
    }

    private var coversDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Ordered art sources for a serial. The disc face prefers an authentic disc
    /// label when available, then falls back to the box cover — so a disc is never
    /// left blank. Only the verified box-cover source is wired today; add disc-label
    /// templates at the front of this list to enable the authentic printed look.
    private func candidateURLs(for serial: String) -> [URL] {
        let s = serial.uppercased()
        return [
            "https://raw.githubusercontent.com/xlenore/ps2-covers/main/covers/default/\(s).jpg"
        ].compactMap { URL(string: $0) }
    }

    /// Raw cover bytes for a serial, or nil if none exists. Safe to call
    /// repeatedly; hits memory, then disk, then the network (at most once per
    /// serial). Callers decode UIImage(data:) themselves (on the main thread).
    func imageData(for serial: String) async -> Data? {
        let s = serial.uppercased()
        guard !s.isEmpty else { return nil }
        let key = s as NSString
        if let cached = memCache.object(forKey: key) { return cached as Data }

        if isNegative(s) { return nil }

        let diskURL = coversDir.appendingPathComponent("\(s).img")
        if let data = try? Data(contentsOf: diskURL), UIImage(data: data) != nil {
            memCache.setObject(data as NSData, forKey: key)
            return data
        }

        for url in candidateURLs(for: s) {
            guard let (data, resp) = try? await session.data(from: url),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  UIImage(data: data) != nil else { continue }
            try? data.write(to: diskURL, options: .atomic)
            memCache.setObject(data as NSData, forKey: key)
            return data
        }

        markNegative(s)
        return nil
    }

    // NSLock.lock()/unlock() are unavailable from async contexts under Swift 6,
    // so the critical sections live in these synchronous helpers.
    private func isNegative(_ s: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return negative.contains(s)
    }
    private func markNegative(_ s: String) {
        lock.lock(); defer { lock.unlock() }
        negative.insert(s)
    }

    // MARK: - Serial resolution (game file name -> disc serial), cached per file.

    // Reading a serial goes through PCSX2's GameList, which mutates the GLOBAL
    // CDVD device: it is neither thread-safe nor safe while a VM exists. So all
    // scans are serialized on this one queue, and skipped entirely whenever a VM
    // is live (running or paused). Results are cached per file name so each ISO
    // is scanned at most once.
    private let scanQueue = DispatchQueue(label: "com.ayanodeath.elorisprism.coverserialscan")

    /// Resolves the disc serial for a game file name. Returns nil (without
    /// caching) if a VM is active, so it retries once the emulator is idle.
    func serial(forGameName name: String) async -> String? {
        let cacheKey = "coverSerial.\(name)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            return cached.isEmpty ? nil : cached
        }
        // Never touch the global CDVD while a game is loaded.
        if iPSX2Bridge.isVMActive() { return nil }

        let isoDir = iPSX2Bridge.isoDirectory()
        var path = (isoDir as NSString).appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: path) {
            path = (iPSX2Bridge.documentsDirectory() as NSString).appendingPathComponent(name)
        }

        let outcome: (scanned: Bool, serial: String?) = await withCheckedContinuation { cont in
            scanQueue.async {
                // Re-check inside the serialized queue — a VM may have started.
                if iPSX2Bridge.isVMActive() {
                    cont.resume(returning: (false, nil))
                } else {
                    cont.resume(returning: (true, iPSX2Bridge.readDiscSerial(path)))
                }
            }
        }
        // Cache only a completed scan (empty string = "scanned, no serial"), so a
        // scan skipped due to an active VM is retried later.
        if outcome.scanned {
            UserDefaults.standard.set(outcome.serial ?? "", forKey: cacheKey)
        }
        return outcome.serial
    }
}

// MARK: - Views

/// Async cover image for an already-resolved serial (e.g. the running game's
/// serial from `currentGameSerial`), avoiding a fresh ISO scan.
struct SerialCoverImage<Placeholder: View>: View {
    let serial: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: serial) {
            image = nil
            guard let serial, !serial.isEmpty else { return }
            if let data = await CoverArtManager.shared.imageData(for: serial) {
                image = UIImage(data: data)
            }
        }
    }
}

/// The disc shown in the game list: real cover art clipped to a circle when
/// available, otherwise the drawn blue PS2 disc. Uses a ZStack so it fills
/// whatever frame the caller sets before clipping.
struct DiscFace: View {
    let gameName: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                DiscArt()
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        // hub hole so a cover-on-disc still reads as a disc
        .overlay(
            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height)
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: d * 0.28, height: d * 0.28)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        )
        .task(id: gameName) {
            image = nil
            guard let serial = await CoverArtManager.shared.serial(forGameName: gameName),
                  !serial.isEmpty else { return }
            if let data = await CoverArtManager.shared.imageData(for: serial) {
                image = UIImage(data: data)
            }
        }
    }
}
