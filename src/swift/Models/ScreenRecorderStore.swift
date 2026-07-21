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
// Concurrency: the completion-handler ReplayKit APIs deliver non-Sendable
// values (a preview controller, errors) off the main thread, which fights strict
// concurrency. So we drive the *async/await* variants instead — Swift
// auto-generates `startRecording() async throws` and
// `stopRecording(withOutput:) async throws` from the (Error?)->Void completions.
// The whole flow runs on the main actor (`run()` is @MainActor), so there are no
// escaping closures capturing self and nothing non-Sendable ever crosses an
// isolation boundary. The recording stops straight to a file; the view turns the
// resulting shareItem into a SwiftUI share sheet.

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
        Task { @MainActor in await run() }
    }

    @MainActor
    private func run() async {
#if canImport(ReplayKit)
        let recorder = RPScreenRecorder.shared()
        if isRecording {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("AYS2-\(Self.fileTimestamp()).mp4")
            do {
                try await recorder.stopRecording(withOutput: url)
                isRecording = false
                shareItem = ShareSheetItem(url: url)
                lastStatusMessage = "Recording saved — share it"
            } catch {
                isRecording = false
                lastStatusMessage = "Recording error: \(error.localizedDescription)"
            }
        } else {
            guard recorder.isAvailable else {
                lastStatusMessage = "Screen recording isn't available right now."
                return
            }
            recorder.isMicrophoneEnabled = false
            do {
                try await recorder.startRecording()
                isRecording = true
                lastStatusMessage = "Recording started"
            } catch {
                lastStatusMessage = "Couldn't start recording: \(error.localizedDescription)"
            }
        }
#else
        lastStatusMessage = "Screen recording isn't available on this platform."
#endif
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
