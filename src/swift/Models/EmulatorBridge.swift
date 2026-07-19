// EmulatorBridge.swift — SwiftUI ↔ C++ emulator bridge
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum StikDebugLauncher {
    private static let lastAutoOpenKey = "ARMSX2iOSLastStikDebugAutoOpenTime"
    private static let autoOpenCooldown: TimeInterval = 120
    private static func log(_ message: String) {
        print("[ARMSX2 iOS] StikDebug \(message)")
    }

    static func open(reason: String = "manual", completion: ((Bool) -> Void)? = nil) {
#if canImport(UIKit)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.armsx2.ios"
        let encodedBundleID = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        let candidates = [
            "stikdebug://enable-jit?bundle-id=\(encodedBundleID)",
            "stikjit://enable-jit?bundle-id=\(encodedBundleID)",
            "stikdebug://"
        ].compactMap(URL.init(string:))

        guard !candidates.isEmpty else {
            log("open failed: no valid launch URLs")
            completion?(false)
            return
        }

        openFirstAvailableURL(candidates, reason: reason, completion: completion)
#else
        log("open skipped: UIKit unavailable reason=\(reason)")
        completion?(false)
#endif
    }

    // AYS2: TrollStore JIT support (seam) — TrollStore 2.0.12+ exposes its
    // own enable-jit deep link, functionally the same round-trip as
    // StikDebug's (switch to the JIT-granting app, it flips CS_DEBUGGED for
    // us, switch back). Deliberately NOT folded into open()'s candidate
    // chain or autoOpenIfNeeded(): TrollStore reuses the system
    // "apple-magnifier" URL scheme to avoid jailbreak-detection heuristics,
    // which is also the real Magnifier accessibility feature's scheme — on
    // a device without TrollStore installed, iOS may still resolve that
    // scheme to the real Magnifier app and report success, so this can't be
    // trusted to "fail silently" the way stikdebug:// does for someone who
    // doesn't have it. Kept as an explicit, user-initiated action only
    // (Settings button), never auto-triggered.
    //
    // Only meaningfully useful on TrollStore installs still on an
    // unpatched build (iOS 14.0–16.6.1, the 16.7 RC/20H18, or exactly
    // 17.0) — Apple closed the underlying CoreTrust bug in the final
    // 16.7 and in 17.0.1, so TrollStore can't be freshly installed past
    // that regardless of this button.
    static func openTrollStore(reason: String = "manual", completion: ((Bool) -> Void)? = nil) {
#if canImport(UIKit)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.armsx2.ios"
        let encodedBundleID = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        guard let url = URL(string: "apple-magnifier://enable-jit?bundle-id=\(encodedBundleID)") else {
            log("openTrollStore failed: invalid launch URL")
            completion?(false)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            log("openTrollStore \(success ? "succeeded" : "failed") reason=\(reason) url=\(url.absoluteString)")
            completion?(success)
        }
#else
        log("openTrollStore skipped: UIKit unavailable reason=\(reason)")
        completion?(false)
#endif
    }

#if canImport(UIKit)
    private static func openFirstAvailableURL(_ urls: [URL], reason: String, completion: ((Bool) -> Void)?) {
        guard let url = urls.first else {
            log("open failed reason=\(reason): no URL scheme accepted")
            completion?(false)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            log("open \(success ? "succeeded" : "failed") reason=\(reason) url=\(url.absoluteString)")
            if success {
                completion?(true)
            } else {
                openFirstAvailableURL(Array(urls.dropFirst()), reason: reason, completion: completion)
            }
        }
    }
#endif

    static func autoOpenIfNeeded(reason: String) {
        guard SettingsStore.shared.autoOpenStikDebug else { return }
        guard !ARMSX2Bridge.isJITAvailable() else { return }

        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: lastAutoOpenKey)
        guard now - last >= autoOpenCooldown else {
            log("auto-open throttled reason=\(reason)")
            return
        }

        UserDefaults.standard.set(now, forKey: lastAutoOpenKey)
        open(reason: "auto-\(reason)")
    }
}

enum EmulatorState: String {
    case stopped = "Stopped"
    case running = "Running"
    case paused = "Paused"
    case saving = "Saving"
    case suspended = "Suspended"
}

@Observable
final class EmulatorBridge: @unchecked Sendable {
    static let shared = EmulatorBridge()

    var state: EmulatorState = .stopped
    var lastSaveDate: Date? = nil
    var lastSaveSuccess: Bool = true
    var biosName: String = "Unknown"
    var buildVersion: String = ""

    private init() {
        biosName = ARMSX2Bridge.biosName()
        buildVersion = ARMSX2Bridge.buildVersion()
    }

    func saveAll() {
        state = .saving
        ARMSX2Bridge.saveAllState()
        lastSaveDate = Date()
        lastSaveSuccess = true
        state = .running
    }

    func setPadButton(_ button: ARMSX2PadButton, pressed: Bool) {
        ARMSX2Bridge.setPadButton(button, pressed: pressed)
    }

    func setLeftStick(x: Float, y: Float) {
        ARMSX2Bridge.setLeftStickX(x, y: y)
    }

    func setRightStick(x: Float, y: Float) {
        ARMSX2Bridge.setRightStickX(x, y: y)
    }

    var isOsdVisible: Bool {
        get { ARMSX2Bridge.isPerformanceOverlayVisible() }
        set { ARMSX2Bridge.setPerformanceOverlayVisible(newValue) }
    }
}
