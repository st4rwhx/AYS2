// ScreenRecorderStore.swift — in-app gameplay recording via ReplayKit.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user request — record gameplay from inside the app (a button), rather
// than reaching into iOS Control Center. ReplayKit's RPScreenRecorder captures
// the whole app (video + app audio) without touching the Metal render path, and
// hands back a preview controller to save to Photos or share. Microphone is off
// (so no NSMicrophoneUsageDescription is required); app audio is still captured.
//
// Note: this uses the same real-time H.264 encoder as iOS screen recording, so
// the performance cost during recording is the same — it's an in-app trigger,
// not a cheaper capture path.
//
// The @Observable store is kept separate from the ReplayKit preview delegate
// (a plain NSObject), so the observable type never has to be an NSObject.
// UIKit access (presenting/dismissing the preview) is hopped onto the main
// actor via `Task { @MainActor in }`, since ReplayKit's completion handlers
// run off the main thread.

import Foundation
import SwiftUI
#if canImport(ReplayKit)
import ReplayKit
#endif

@Observable
final class ScreenRecorderStore: @unchecked Sendable {
    static let shared = ScreenRecorderStore()

    private(set) var isRecording = false

#if canImport(ReplayKit)
    @ObservationIgnored private let previewDelegate = RecorderPreviewDelegate()
#endif

    private init() {}

    var isAvailable: Bool {
#if canImport(ReplayKit)
        return RPScreenRecorder.shared().isAvailable
#else
        return false
#endif
    }

    /// Toggles recording. `status` reports user-facing messages (start/stop/errors).
    func toggle(status: @escaping (String) -> Void) {
        if isRecording {
            stop(status: status)
        } else {
            start(status: status)
        }
    }

    private func start(status: @escaping (String) -> Void) {
#if canImport(ReplayKit)
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            status("Screen recording isn't available right now.")
            return
        }
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            Task { @MainActor in
                if let error {
                    status("Couldn't start recording: \(error.localizedDescription)")
                    return
                }
                self?.isRecording = true
                status("Recording started")
            }
        }
#else
        status("Screen recording isn't available on this platform.")
#endif
    }

    private func stop(status: @escaping (String) -> Void) {
#if canImport(ReplayKit)
        RPScreenRecorder.shared().stopRecording { [weak self] previewController, error in
            Task { @MainActor in
                self?.isRecording = false
                if let error {
                    status("Recording error: \(error.localizedDescription)")
                    return
                }
                guard let previewController else {
                    status("Recording stopped.")
                    return
                }
                previewController.previewControllerDelegate = self?.previewDelegate
                Self.present(previewController)
                status("Recording stopped — save or share it")
            }
        }
#endif
    }

#if canImport(ReplayKit)
    @MainActor
    private static func present(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else {
            return
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // formSheet on iPad, full screen on iPhone — matches the system preview.
        controller.modalPresentationStyle = UIDevice.current.userInterfaceIdiom == .pad ? .formSheet : .fullScreen
        top.present(controller, animated: true)
    }
#endif
}

#if canImport(ReplayKit)
/// Plain NSObject so it can be an @objc ReplayKit delegate without dragging the
/// observable store into NSObject territory.
private final class RecorderPreviewDelegate: NSObject, RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        Task { @MainActor in previewController.dismiss(animated: true) }
    }
}
#endif
