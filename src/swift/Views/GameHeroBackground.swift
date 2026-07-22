// GameHeroBackground.swift — dynamic ambient backdrop for the games hub.
// AYS2: additive (seam) — new file, not present upstream.
// SPDX-License-Identifier: GPL-3.0+
//
// A full-bleed banner built from the focused game's own cover art (blurred
// and stretched to fill), not an abstract color wash — the same pattern as
// the PS5/Xbox home screen, where the background behind the dashboard is
// always a real image of the highlighted title. Cross-fades as focus moves
// across the carousel. Scoped to the Games section only per the perf
// agreement: idle-screen cost, never during gameplay.

import SwiftUI

/// Full-bleed blurred banner behind the dashboard, built from the focused
/// game's own cover. Falls back to the neutral RetroBackground when there's
/// no focused cover yet (empty library, or still loading).
struct AmbientHeroBackground: View {
    let focusedImage: UIImage?
    let focusKey: String?
    // AYS2: Performance Mode (seam) — the full-bleed 32-radius blur of the
    // focused cover is the single most expensive launcher effect. In
    // Performance Mode we drop it entirely and show only the flat
    // RetroBackground, so the hub costs almost nothing to draw.
    @State private var settings = SettingsStore.shared

    var body: some View {
        ZStack {
            RetroBackground()
            if let focusedImage, !settings.performanceMode {
                GeometryReader { proxy in
                    Image(uiImage: focusedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                // AYS2: was 60 — read as an unrecognizable smear rather than
                // a soft ambient echo of the cover art (seam/fix).
                .blur(radius: 32, opaque: true)
                .overlay(
                    LinearGradient(
                        colors: [Retro.bg.opacity(0.55), Retro.bg.opacity(0.82), Retro.bg.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Retro.bg.opacity(0.25))
                .id(focusKey)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: focusKey)
    }
}
