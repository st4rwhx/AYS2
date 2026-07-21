// GameNameStore.swift — user-defined display names for games.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: community request — let users rename games, mainly for modded ISOs whose
// embedded title is glitched or cryptic (e.g. "UN6" for a Naruto mod). This only
// overrides the *displayed* name; the game's real identity (boot name, serial,
// CRC, cover lookup, favorites, per-game settings) is untouched, so a rename can
// never break booting or matching. Stored in UserDefaults, keyed by boot name.

import Foundation
import SwiftUI

@Observable
final class GameNameStore: @unchecked Sendable {
    static let shared = GameNameStore()

    private let defaultsKey = "com.ays2.customGameNames"
    private var namesByBoot: [String: String]

    private init() {
        namesByBoot = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
    }

    /// The user's custom name for a game, or nil if none is set.
    func customName(forBoot bootName: String) -> String? {
        guard let value = namesByBoot[bootName],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    /// The name to show for a game: the custom one if set, else the original.
    func displayName(forBoot bootName: String, fallback: String) -> String {
        customName(forBoot: bootName) ?? fallback
    }

    /// Sets (or, with an empty string, clears) the custom name for a game.
    func setName(_ name: String, forBoot bootName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            namesByBoot.removeValue(forKey: bootName)
        } else {
            namesByBoot[bootName] = trimmed
        }
        UserDefaults.standard.set(namesByBoot, forKey: defaultsKey)
    }
}
