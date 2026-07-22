// BootSplashView.swift - Fullscreen boot intro video
// SPDX-License-Identifier: GPL-3.0+

import AVFoundation
import SwiftUI
import UIKit

struct BootSplashView: View {
    // AYS2: the old boot_intro.mp4 was a corrupt 32-byte stub (a bare MP4
    // container header, no actual video track) — AVPlayer couldn't play it
    // cleanly, and the splash likely rode out close to this whole timeout on
    // every launch before falling through here. The new intro is a real,
    // self-generated ~2.4s clip that ends via AVPlayerItemDidPlayToEndTime
    // well before this fires — kept as a safety net only, tightened down
    // now that it's not doing the real work (seam/fix).
    private static let hardTimeout: UInt64 = 4_000_000_000

    let onFinished: () -> Void
    @State private var finished = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            BootSplashPlayerView(onFinished: finish)
                .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finish()
        }
        .task {
            try? await Task.sleep(nanoseconds: Self.hardTimeout)
            finish()
        }
    }

    @MainActor
    private func finish() {
        guard !finished else {
            return
        }

        finished = true
        onFinished()
    }
}

private struct BootSplashPlayerView: UIViewRepresentable {
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> BootSplashPlayerUIView {
        let view = BootSplashPlayerUIView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect

        guard let url = Bundle.main.url(forResource: "boot_intro", withExtension: "mp4") else {
            DispatchQueue.main.async {
                context.coordinator.finish()
            }
            return view
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        context.coordinator.player = player
        context.coordinator.observe(item: item)
        view.playerLayer.player = player
        player.play()

        return view
    }

    func updateUIView(_ uiView: BootSplashPlayerUIView, context: Context) {
    }

    static func dismantleUIView(_ uiView: BootSplashPlayerUIView, coordinator: Coordinator) {
        uiView.playerLayer.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.stopObserving()
    }

    final class Coordinator: @unchecked Sendable {
        var player: AVPlayer?
        private let onFinished: () -> Void
        private var endToken: NSObjectProtocol?
        private var errorToken: NSObjectProtocol?

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        deinit {
            stopObserving()
        }

        func observe(item: AVPlayerItem) {
            stopObserving()

            endToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.finish()
            }

            errorToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.finish()
            }
        }

        func stopObserving() {
            if let endToken {
                NotificationCenter.default.removeObserver(endToken)
                self.endToken = nil
            }
            if let errorToken {
                NotificationCenter.default.removeObserver(errorToken)
                self.errorToken = nil
            }
            player = nil
        }

        func finish() {
            onFinished()
        }
    }
}

private final class BootSplashPlayerUIView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
