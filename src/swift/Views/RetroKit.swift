// RetroKit.swift — light "console dashboard" (NXE-style) design system.
// SPDX-License-Identifier: GPL-3.0+
//
// Faithful rebuild of the modern console-dashboard look: an airy light field,
// a horizontal top nav, big solid tiles, full uncropped covers and clean white
// cards. Xbox's dashboard is green; this is a PS2 emulator, so the single
// accent is PlayStation blue. Native SwiftUI — no third-party code.

import SwiftUI

enum Retro {
    // Light NXE base — airy, near-white with a faint cool tint.
    static let bg     = Color(red: 0.929, green: 0.941, blue: 0.961) // #EDF0F5
    static let bg2    = Color(red: 0.882, green: 0.902, blue: 0.937) // #E1E6EF (left band)
    static let panel  = Color.white
    static let panel2 = Color(red: 0.957, green: 0.965, blue: 0.980) // #F4F6FA
    static let line   = Color(red: 0.827, green: 0.847, blue: 0.886) // #D3D8E2
    static let line2  = Color(red: 0.737, green: 0.765, blue: 0.816) // #BCC3D0

    // Ink on light.
    static let ink    = Color(red: 0.106, green: 0.114, blue: 0.141) // #1B1D24
    static let mut    = Color(red: 0.353, green: 0.376, blue: 0.439) // #5A6070
    static let faint  = Color(red: 0.541, green: 0.565, blue: 0.627) // #8A90A0

    /// PlayStation blue accent (the console-dashboard tile colour).
    static let accent     = Color(red: 0.153, green: 0.427, blue: 1.0)  // #2769FF
    static let accentDeep = Color(red: 0.102, green: 0.310, blue: 0.800) // #1A4FCC

    static let mono = Font.system(.footnote, design: .monospaced)

    /// Standard PS2 DVD-case cover ratio (height ÷ width).
    static let coverRatio: CGFloat = 1.40
}

/// Light NXE backdrop: a subtle deeper band on the left fading into an airy
/// near-white field, exactly like the console dashboard.
struct RetroBackground: View {
    var body: some View {
        ZStack {
            Retro.bg.ignoresSafeArea()
            LinearGradient(colors: [Retro.bg2, Retro.bg, Retro.bg, Retro.panel2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }
}

/// A game's cover art shown whole and uncropped at true PS2 case proportions —
/// the full artwork, never cut. Falls back to a solid tile with the title when
/// no cover is available.
struct CleanCover: View {
    let gameName: String
    var width: CGFloat = 150

    @State private var image: UIImage?

    private var height: CGFloat { width * Retro.coverRatio }

    var body: some View {
        ZStack {
            // Neutral backdrop so an off-ratio cover letterboxes cleanly
            // instead of being cropped.
            Retro.panel2
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                LinearGradient(colors: [Retro.panel, Retro.panel2], startPoint: .top, endPoint: .bottom)
                Text(gameName)
                    .font(.system(size: width * 0.11, weight: .semibold))
                    .foregroundStyle(Retro.mut)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(10)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Retro.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 8)
        .task(id: gameName) {
            image = nil
            guard let serial = await CoverArtManager.shared.serial(forGameName: gameName),
                  !serial.isEmpty else { return }
            if let data = await CoverArtManager.shared.imageData(for: serial) {
                image = UIImage(data: data)
            }
        }
    }
}

/// Small accent section label (e.g. "Indexed 4 games").
struct RetroLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Retro.accent)
    }
}

/// Solid PlayStation-blue primary action.
struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 11).padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                         startPoint: .top, endPoint: .bottom))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Shared console-dashboard chrome

/// The bumper-button pill (LB / RB) shown either side of the top nav.
struct BumperPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Retro.mut)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Retro.line2, lineWidth: 1.5))
    }
}

/// The bottom action-hint bar (Ⓐ select  Ⓑ back …) like the console dashboard.
struct HintBar: View {
    struct Hint: Identifiable { let id = UUID(); let glyph: String; let color: Color; let label: String }
    let hints: [Hint]

    var body: some View {
        HStack(spacing: 18) {
            Spacer(minLength: 0)
            ForEach(hints) { h in
                HStack(spacing: 6) {
                    Text(h.glyph)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(h.color))
                    Text(h.label)
                        .font(.footnote)
                        .foregroundStyle(Retro.mut)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }
}
