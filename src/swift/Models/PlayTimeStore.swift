// PlayTimeStore.swift — per-game total play time
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user suggestion — a play-time tracker like Dolphin/PPSSPP, shown in
// the game Info panel. Accumulates wall-clock time a game's VM is actually
// running, keyed on boot name (the same stable identifier favorites/hidden
// entries use). Purely app-side (UserDefaults) — no core involvement.
//
// AppState drives it: a session starts when bootGame(isoName:) runs and is
// flushed on VM shutdown and on app-backgrounding (so time survives an app
// kill in the background). BIOS-only boots are not tracked.

import Foundation
import SwiftUI

@Observable
final class PlayTimeStore: @unchecked Sendable {
    static let shared = PlayTimeStore()

    private let defaultsKey = "ARMSX2iOSPlayTimeSeconds"

    // bootName -> accumulated seconds.
    private(set) var secondsByGame: [String: Double]

    private init() {
        secondsByGame = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double]) ?? [:]
    }

    func addSeconds(_ seconds: Double, forGame bootName: String) {
        guard seconds > 0, !bootName.isEmpty else { return }
        secondsByGame[bootName, default: 0] += seconds
        persist()
    }

    func seconds(forGame bootName: String) -> Double {
        secondsByGame[bootName] ?? 0
    }

    /// "12h 34m", "45m", "2m", or nil when there's no recorded time yet.
    func formatted(forGame bootName: String) -> String? {
        let total = seconds(forGame: bootName)
        guard total >= 60 else {
            // Under a minute: only worth showing once a game's actually been played.
            return total > 0 ? "< 1m" : nil
        }
        let totalMinutes = Int(total / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func resetTime(forGame bootName: String) {
        secondsByGame.removeValue(forKey: bootName)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(secondsByGame, forKey: defaultsKey)
    }
}
