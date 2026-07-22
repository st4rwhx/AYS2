// GuideStore.swift — per-game walkthrough/guide URL storage.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: community request — open a walkthrough/guide for the running game from
// inside the pause menu, without leaving the app. This store remembers the URL
// the player last used for each game (keyed by its ISO name), and falls back to
// a web search for the game's title when no URL has been set yet.
//
// Storage is UserDefaults (a small string map). No emulator/bridge coupling.

import Foundation
import SwiftUI

@Observable
final class GuideStore: @unchecked Sendable {
    static let shared = GuideStore()

    private let defaultsKey = "com.ays2.guideURLsByGame"
    private var urlsByGame: [String: String]

    private init() {
        urlsByGame = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
    }

    /// Normalises a raw game/ISO name into a stable map key. Empty → nil.
    private func key(for gameName: String?) -> String? {
        guard let raw = gameName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    /// A default guide URL for a game with no saved URL: a web search for the
    /// game's title plus "walkthrough". Falls back to a generic search if the
    /// title can't be percent-encoded.
    private func defaultURL(forTitle title: String) -> URL {
        let query = "\(title) walkthrough guide"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "ps2 walkthrough"
        return URL(string: "https://www.google.com/search?q=\(encoded)")
            ?? URL(string: "https://www.google.com")!
    }

    /// The saved guide URL string for a game, if the player set one.
    func savedURLString(for gameName: String?) -> String? {
        guard let key = key(for: gameName) else { return nil }
        return urlsByGame[key]
    }

    /// The URL to open for a game: the saved one if valid, else a title search.
    /// `displayTitle` is the human-readable game name used to build the fallback
    /// search (may differ from the storage key when the ISO name is a filename).
    func resolvedURL(for gameName: String?, displayTitle: String) -> URL {
        if let saved = savedURLString(for: gameName), let url = normalizedURL(from: saved) {
            return url
        }
        return defaultURL(forTitle: displayTitle.isEmpty ? "PlayStation 2" : displayTitle)
    }

    /// Persists a user-entered URL string for a game. An empty string clears it.
    func setURLString(_ string: String, for gameName: String?) {
        guard let key = key(for: gameName) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            urlsByGame.removeValue(forKey: key)
        } else {
            urlsByGame[key] = trimmed
        }
        UserDefaults.standard.set(urlsByGame, forKey: defaultsKey)
    }

    /// Turns a possibly-bare user string into a valid http(s) URL, adding a
    /// scheme when the user omitted it. Returns nil for hopeless input.
    func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        // No scheme (or a bad one) — try prepending https:// if it looks like a host.
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }
        return nil
    }
}
