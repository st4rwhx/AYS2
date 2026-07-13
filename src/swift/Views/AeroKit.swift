// AeroKit.swift — leftover glossy-aqua palette + the light screen backdrop helper.
// SPDX-License-Identifier: GPL-3.0+
//
// The app's design language moved to the solid light "Clean Retro" / NXE skin
// (see RetroKit.swift). All that remains here is the small aqua palette still
// used by the glossy on-screen virtual controller, plus `aeroScreen()` which
// puts the light backdrop behind a screen.

import SwiftUI

/// Glossy aqua tones used by the virtual on-screen controller buttons.
enum Aero {
    static let sky  = Color(red: 0.17, green: 0.66, blue: 0.90)
    static let deep = Color(red: 0.04, green: 0.37, blue: 0.66)
    static let ink  = Color(red: 0.04, green: 0.18, blue: 0.28)
}

extension View {
    /// Places the app's light NXE backdrop behind a screen. Grouped lists keep
    /// their native white cards.
    func aeroScreen() -> some View {
        self
            .background(RetroBackground())
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}
