// HiddenGamesStore.swift — user-hidden library entries
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user suggestion — let people hide entries from the library (games
// they don't want listed, or stray files like BIOS images that live in a
// scanned subfolder and show up as "games"). Kept deliberately simple: a
// persisted set of boot names (the same stable identifier favorites use,
// via ARMSX2Bridge.isFavorite/setFavorite), plus a session-only "reveal"
// flag so a hidden entry can still be surfaced and un-hidden from the same
// library screen. No core/INI involvement — this is purely an app-side
// display filter.

import Foundation
import SwiftUI

// Matches the codebase's store pattern (SettingsStore etc.): @Observable +
// @unchecked Sendable rather than @MainActor, so it can back a plain @State
// in a View without actor-isolation friction. Only ever touched from the
// main thread (UI), and UserDefaults is itself thread-safe.
@Observable
final class HiddenGamesStore: @unchecked Sendable {
    static let shared = HiddenGamesStore()

    private let defaultsKey = "ARMSX2iOSHiddenGameBootNames"

    // Boot names of hidden entries. Boot name (not the volatile file-URL id)
    // is used so a hidden entry stays hidden across reinstalls/path changes,
    // matching how favorites are keyed.
    private(set) var hiddenBootNames: Set<String>

    // When true, the library shows hidden entries too (so they can be
    // un-hidden). Session-only on purpose — reopening the app returns to the
    // normal filtered view. Not persisted.
    var revealHidden: Bool = false

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        hiddenBootNames = Set(saved)
    }

    func isHidden(_ bootName: String) -> Bool {
        hiddenBootNames.contains(bootName)
    }

    func setHidden(_ hidden: Bool, bootName: String) {
        if hidden {
            hiddenBootNames.insert(bootName)
        } else {
            hiddenBootNames.remove(bootName)
        }
        persist()
    }

    func toggle(bootName: String) {
        setHidden(!isHidden(bootName), bootName: bootName)
    }

    var hiddenCount: Int { hiddenBootNames.count }

    private func persist() {
        UserDefaults.standard.set(Array(hiddenBootNames), forKey: defaultsKey)
    }
}
