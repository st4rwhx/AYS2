// ScreenRecorderStore.swift — in-app gameplay recording via ReplayKit.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user request — record gameplay from inside the app (a button), rather
// than reaching into iOS Control Center. ReplayKit's RPScreenRecorder captures
// the whole app (video + app audio) without touching the Metal render path.
// Microphone is off (so no NSMicrophoneUsageDescription is required); app audio
// is still captured.
//
// Note: this uses the same real-time H.264 encoder as iOS screen recording, so
// the performance cost during recording is the same — it's an in-app trigger,
// not a cheaper capture path.
//
// Concurrency: rather than the RPPreviewViewController flow (which forces manual
// UIViewController presentation and drags non-Sendable values across actor
// boundaries — a losing fight with strict concurrency), we stop straight to a
// file with stopRecording(withOutput:). The completion delivers only an Error,
// which we reduce to a Sendable String before hopping to the main actor. The
// store is @MainActor and publishes a shareItem the view turns into a SwiftUI
// share sheet — so only Sendable values (URL, String) ever cross a boundary.

import Foundation
import SwiftUI
#if canImport(ReplayKit)
import ReplayKit
#endif

@Observable
final class ScreenRecorderStore: @unchecked Sendable {
    static let shared = ScreenRecorderStore()

    private(set) var isRecording = false
    /// Set when a recording finishes; the view presents a share sheet for it.
    var shareItem: ShareSheetItem?
    /// Set on start/stop/errors; the view surfaces it as a status toast.
    var lastStatusMessage: String?

    private init() {}

    var isAvailable: Bool {
#if canImport(ReplayKit)
        return RPScreenRecorder.shared().isAvailable
#else
        return false
#endif
    }

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    private func start() {
#if canImport(ReplayKit)
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            lastStatusMessage = "Screen recording isn't available right now."
            return
        }
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            let message = error.map { "Couldn't start recording: \($0.localizedDescription)" }
            Task { @MainActor in
                guard let self else { return }
                if let message {
                    self.lastStatusMessage = message
                    return
                }
                self.isRecording = true
                self.lastStatusMessage = "Recording started"
            }
        }
#else
        lastStatusMessage = "Screen recording isn't available on this platform."
#endif
    }

    private func stop() {
#if canImport(ReplayKit)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AYS2-\(UUID().uuidString).mp4")
        RPScreenRecorder.shared().stopRecording(withOutput: url) { [weak self] error in
            let message = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                self.isRecording = false
                if let message {
                    self.lastStatusMessage = "Recording error: \(message)"
                    return
                }
                self.shareItem = ShareSheetItem(url: url)
                self.lastStatusMessage = "Recording saved — share it"
            }
        }
#endif
    }
}
