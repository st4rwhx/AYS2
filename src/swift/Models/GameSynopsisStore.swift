// GameSynopsisStore.swift - per-game synopsis lookup (community database, cached)
// AYS2: additive (seam) — new file, not present upstream.
// SPDX-License-Identifier: GPL-3.0+
//
// Same fetch-by-serial pattern CoverStore already uses for cover art, applied
// to short game descriptions: Tom-Bruise/PS2-OPL-CFG-Database (GPL-3.0,
// ScreenScraper-sourced, ~13.6k PS2 titles, English + French CFG folders).
// Works for the whole library automatically — any game with a recognized
// serial gets a synopsis, not a hardcoded list, exactly like cover art
// already does. Results are cached to disk so a given game's synopsis is
// fetched over the network at most once per install.

import Foundation

actor GameSynopsisStore {
    static let shared = GameSynopsisStore()

    private let diskCacheURL: URL
    private var cache: [String: String] = [:]
    private var cacheLoaded = false

    private init() {
        let docs = URL(fileURLWithPath: ARMSX2Bridge.documentsDirectory(), isDirectory: true)
        diskCacheURL = docs.appendingPathComponent("armsx2_synopses.json")
    }

    /// Best-effort synopsis for a game, or nil if unavailable (unrecognized
    /// serial, no network, or the database simply has no description for
    /// that title). Always resolves the same way on failure: show nothing,
    /// never a placeholder. Tries French first when `preferFrench` is set,
    /// falling back to English (the French CFG folder covers fewer titles).
    func synopsis(rawSerial: String, preferFrench: Bool) async -> String? {
        guard let serial = CoverStore.oplSerial(from: rawSerial) else { return nil }
        if preferFrench, let text = await fetchAndCache(serial: serial, french: true) {
            return text
        }
        return await fetchAndCache(serial: serial, french: false)
    }

    private func fetchAndCache(serial: String, french: Bool) async -> String? {
        loadCacheIfNeeded()

        let key = "\(french ? "fr" : "en")|\(serial)"
        if let cached = cache[key] {
            // Repair on read too — the disk cache can already hold entries
            // saved before the mojibake fix, and this round trip is a no-op
            // for already-clean text.
            return cached.isEmpty ? nil : Self.repairMojibake(cached)
        }

        let folder = french ? "CFG_fr" : "CFG_en"
        guard let url = URL(string: "https://raw.githubusercontent.com/Tom-Bruise/PS2-OPL-CFG-Database/master/\(folder)/\(serial).cfg") else {
            return nil
        }

        var text = ""
        if let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            text = Self.parseDescription(from: String(decoding: data, as: UTF8.self)) ?? ""
        }

        cache[key] = text
        persistCache()
        return text.isEmpty ? nil : text
    }

    private func loadCacheIfNeeded() {
        guard !cacheLoaded else { return }
        cacheLoaded = true
        guard let data = try? Data(contentsOf: diskCacheURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        cache = decoded
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: diskCacheURL, options: .atomic)
    }

    private static func parseDescription(from cfgText: String) -> String? {
        for line in cfgText.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            guard line[line.startIndex..<eq] == "Description" else { continue }
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : repairMojibake(value)
        }
        return nil
    }

    /// Some entries in the upstream community database are double-encoded —
    /// UTF-8 bytes (e.g. a curly apostrophe) were once mis-read as
    /// Windows-1252 and re-saved as UTF-8, so "you'll" shows up as literal
    /// "youâ€™ll" (seam/fix, not a missing-language issue). Re-encoding the
    /// decoded string as Windows-1252 recovers the original UTF-8 bytes,
    /// which then decode cleanly. Only succeeds (and is only applied) when
    /// that round trip actually produces valid UTF-8 — correctly-encoded
    /// text fails the round trip and passes through untouched.
    private static func repairMojibake(_ text: String) -> String {
        guard let reinterpretedBytes = text.data(using: .windowsCP1252),
              let repaired = String(data: reinterpretedBytes, encoding: .utf8) else {
            return text
        }
        return repaired
    }
}
