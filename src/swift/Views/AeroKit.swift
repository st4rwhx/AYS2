// AeroKit.swift — light screen backdrop helper.
// SPDX-License-Identifier: GPL-3.0+
//
// The app's design language is the solid light "Clean Retro" / NXE skin
// (see RetroKit.swift). All that remains here is `aeroScreen()`, which puts
// the light backdrop behind a screen and hides the nav-bar chrome.

import SwiftUI

extension View {
    /// Places the app's light NXE backdrop behind a screen. Grouped lists keep
    /// their native white cards.
    func aeroScreen() -> some View {
        self
            .background(RetroBackground())
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}
