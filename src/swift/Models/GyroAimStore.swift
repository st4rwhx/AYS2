// GyroAimStore.swift — motion-controlled analog aiming (gyro aim)
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user suggestion — gyroscope aiming, i.e. tilt the device to nudge an
// analog stick (typically the right stick, for camera/aim in shooters).
//
// Design notes:
//   * Velocity style. We map the device's angular velocity (rotationRate, in
//     rad/s) straight onto stick deflection, so the stick self-centers the
//     moment the device stops moving — no attitude integration, no drift, no
//     need for a recenter gesture.
//   * Axis mapping is tuned for landscape gameplay: on-screen horizontal (yaw)
//     is rotation about the device X axis, on-screen vertical (pitch) about the
//     device Y axis. landscapeLeft and landscapeRight are a 180° flip about the
//     screen normal, which negates both X and Y, so the two orientations differ
//     only by sign — fully covered by the invert toggles below. No axis-swap
//     control is needed.
//   * Feeds through EmulatorBridge (the same stick entry points the on-screen
//     thumbsticks use). Last-writer-wins per frame with the on-screen stick,
//     which is the intended behaviour: dragging the physical stick overrides
//     gyro for that frame.
//   * Opt-in and gated to active gameplay. GameScreenView calls
//     setGameplayActive(_:) so motion updates only run while a game is on
//     screen and unpaused; when it stops we re-center the chosen stick so a
//     lingering deflection can't leave the aim drifting.

import Foundation
import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif

@Observable
final class GyroAimStore: @unchecked Sendable {
    static let shared = GyroAimStore()

    private let enabledKey = "ARMSX2iOSGyroAimEnabled"
    private let sensitivityKey = "ARMSX2iOSGyroAimSensitivity"
    private let leftStickKey = "ARMSX2iOSGyroAimUsesLeftStick"
    private let invertXKey = "ARMSX2iOSGyroAimInvertX"
    private let invertYKey = "ARMSX2iOSGyroAimInvertY"

    static let minSensitivity: Double = 0.5
    static let maxSensitivity: Double = 5.0
    static let defaultSensitivity: Double = 2.0

    // Below this |deflection| the stick reads as centered — swallows resting
    // hand tremor so the aim doesn't creep while the device is held still.
    private static let deadzone: Double = 0.03

    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: enabledKey)
            refreshMotion()
        }
    }

    // Higher = a given tilt speed produces a larger stick deflection.
    var sensitivity: Double {
        didSet {
            let clamped = min(max(sensitivity, Self.minSensitivity), Self.maxSensitivity)
            if clamped != sensitivity { sensitivity = clamped; return }
            UserDefaults.standard.set(sensitivity, forKey: sensitivityKey)
        }
    }

    // Which analog stick gyro drives. Right stick (aim/camera) by default.
    var usesLeftStick: Bool {
        didSet {
            UserDefaults.standard.set(usesLeftStick, forKey: leftStickKey)
            // Moved the target: make sure the stick we're no longer driving is
            // released, otherwise it could stay stuck from the last update.
            recenter(leftStick: !usesLeftStick)
        }
    }

    var invertX: Bool { didSet { UserDefaults.standard.set(invertX, forKey: invertXKey) } }
    var invertY: Bool { didSet { UserDefaults.standard.set(invertY, forKey: invertYKey) } }

#if canImport(CoreMotion)
    @ObservationIgnored private let motion = CMMotionManager()
#endif
    // True while a game is on screen and unpaused. Motion only runs when this
    // and `enabled` are both true.
    @ObservationIgnored private var gameplayActive = false

    private init() {
        let defaults = UserDefaults.standard
        enabled = defaults.bool(forKey: enabledKey)
        let savedSensitivity = defaults.object(forKey: sensitivityKey) as? Double
        sensitivity = min(max(savedSensitivity ?? Self.defaultSensitivity,
                              Self.minSensitivity), Self.maxSensitivity)
        usesLeftStick = defaults.bool(forKey: leftStickKey)
        invertX = defaults.bool(forKey: invertXKey)
        invertY = defaults.bool(forKey: invertYKey)
    }

    /// Called by GameScreenView as gameplay becomes visible/hidden or paused.
    func setGameplayActive(_ active: Bool) {
        guard gameplayActive != active else { return }
        gameplayActive = active
        refreshMotion()
    }

    // Whether motion is available at all (Simulator / rare hardware may lack it).
    var isAvailable: Bool {
#if canImport(CoreMotion)
        return motion.isDeviceMotionAvailable
#else
        return false
#endif
    }

    private func refreshMotion() {
        if enabled && gameplayActive {
            start()
        } else {
            stop()
        }
    }

    private func start() {
#if canImport(CoreMotion)
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.apply(rotationRate: data.rotationRate)
        }
#endif
    }

    private func stop() {
#if canImport(CoreMotion)
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
#endif
        recenter(leftStick: usesLeftStick)
    }

    private func recenter(leftStick: Bool) {
        if leftStick {
            EmulatorBridge.shared.setLeftStick(x: 0, y: 0)
        } else {
            EmulatorBridge.shared.setRightStick(x: 0, y: 0)
        }
    }

#if canImport(CoreMotion)
    private func apply(rotationRate rate: CMRotationRate) {
        // rate is rad/s about the device body axes. 0.35 keeps a comfortable
        // wrist flick (~a few rad/s) inside full deflection at mid sensitivity.
        let scale = sensitivity * 0.35
        var x = Double(rate.x) * scale   // yaw   → on-screen horizontal (landscape)
        var y = Double(rate.y) * scale   // pitch → on-screen vertical   (landscape)
        if invertX { x = -x }
        if invertY { y = -y }

        let cx = clampDeadzoned(x)
        let cy = clampDeadzoned(y)
        if usesLeftStick {
            EmulatorBridge.shared.setLeftStick(x: cx, y: cy)
        } else {
            EmulatorBridge.shared.setRightStick(x: cx, y: cy)
        }
    }

    private func clampDeadzoned(_ value: Double) -> Float {
        if abs(value) < Self.deadzone { return 0 }
        return Float(min(max(value, -1.0), 1.0))
    }
#endif
}
