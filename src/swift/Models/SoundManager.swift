// SoundManager.swift — original PS2-flavored UI sounds (no Sony assets).
// SPDX-License-Identifier: GPL-3.0+

import AVFoundation

/// Plays short, original UI sounds for menu interactions. Uses the `.ambient`
/// audio session so it obeys the mute switch and mixes with other audio, and
/// never fights the emulator's own audio (menu sounds only fire in the menu).
final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()

    enum UISound: String, CaseIterable {
        case nav, select, back, boot
    }

    /// User-toggleable (Settings). Defaults to on.
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "uiSoundsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "uiSoundsEnabled") }
    }

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for s in UISound.allCases { preload(s.rawValue) }
    }

    private func preload(_ name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.prepareToPlay()
        players[name] = player
    }

    func play(_ sound: UISound) {
        guard enabled, let player = players[sound.rawValue] else { return }
        player.currentTime = 0
        player.play()
    }
}
