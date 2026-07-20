// TurboStore.swift — per-button autofire (turbo) configuration
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user suggestion — macro/turbo (autofire) for on-screen buttons with a
// selectable frequency (like Nether). Buttons the user marks as turbo are
// auto-repeated while held, at the configured rate. Purely app-side: the
// actual repeat loop lives in EmulatorBridge.setPadButton (the single choke
// point every on-screen and hardware press goes through), so this store only
// holds configuration. Opt-in — with no buttons marked turbo, input behaves
// exactly as before.

import Foundation
import SwiftUI

@Observable
final class TurboStore: @unchecked Sendable {
    static let shared = TurboStore()

    private let buttonsKey = "ARMSX2iOSTurboButtons"
    private let freqKey = "ARMSX2iOSTurboFrequencyHz"

    static let minFrequency: Double = 2
    static let maxFrequency: Double = 30
    static let defaultFrequency: Double = 10

    // Raw ARMSX2PadButton values marked as turbo.
    private(set) var turboButtons: Set<Int>

    // Presses per second while a turbo button is held.
    var frequencyHz: Double {
        didSet {
            let clamped = min(max(frequencyHz, Self.minFrequency), Self.maxFrequency)
            if clamped != frequencyHz { frequencyHz = clamped; return }
            UserDefaults.standard.set(frequencyHz, forKey: freqKey)
        }
    }

    private init() {
        turboButtons = Set((UserDefaults.standard.array(forKey: buttonsKey) as? [Int]) ?? [])
        let saved = UserDefaults.standard.object(forKey: freqKey) as? Double
        frequencyHz = min(max(saved ?? Self.defaultFrequency, Self.minFrequency), Self.maxFrequency)
    }

    func isTurbo(_ rawButton: Int) -> Bool { turboButtons.contains(rawButton) }

    func setTurbo(_ on: Bool, rawButton: Int) {
        if on { turboButtons.insert(rawButton) } else { turboButtons.remove(rawButton) }
        UserDefaults.standard.set(Array(turboButtons), forKey: buttonsKey)
    }

    var hasAnyTurbo: Bool { !turboButtons.isEmpty }
}
