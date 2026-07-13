// RetroKit.swift — clean, solid "console dashboard" design system.
// SPDX-License-Identifier: GPL-3.0+
//
// Flat, defined, solid — no glass, no photos, no bubbles. A dark console-grade
// base, one PlayStation-blue accent, mono labels. Layout inspired by the
// horizontal-nav + cover-carousel dashboards of modern console emulators,
// rebuilt natively in SwiftUI (no third-party code — those apps are closed).

import SwiftUI

enum Retro {
    static let bg     = Color(red: 0.055, green: 0.059, blue: 0.071) // #0E0F12
    static let bg2    = Color(red: 0.071, green: 0.075, blue: 0.094) // #12131A
    static let panel  = Color(red: 0.094, green: 0.102, blue: 0.125) // #181A20
    static let panel2 = Color(red: 0.118, green: 0.129, blue: 0.161) // #1E2129
    static let line   = Color(red: 0.172, green: 0.184, blue: 0.216) // #2C2F38
    static let line2  = Color(red: 0.227, green: 0.243, blue: 0.286) // #3A3E49
    static let ink    = Color(red: 0.925, green: 0.921, blue: 0.902) // #ECEBE6
    static let mut    = Color(red: 0.545, green: 0.560, blue: 0.603) // #8B8F9A
    static let faint  = Color(red: 0.361, green: 0.376, blue: 0.412) // #5C6069
    /// PlayStation blue accent.
    static let accent = Color(red: 0.153, green: 0.427, blue: 1.0)   // #2769FF

    static let mono = Font.system(.footnote, design: .monospaced)
}

/// Solid dark backdrop with a faint retro grid fading from the top.
struct RetroBackground: View {
    var body: some View {
        ZStack {
            Retro.bg.ignoresSafeArea()
            GeometryReader { geo in
                Path { p in
                    let step: CGFloat = 46
                    var x: CGFloat = 0
                    while x <= geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += step }
                    var y: CGFloat = 0
                    while y <= geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += step }
                }
                .stroke(Retro.line, lineWidth: 1)
                .mask(
                    LinearGradient(colors: [.white.opacity(0.5), .clear],
                                   startPoint: .top, endPoint: .center)
                )
            }
            .ignoresSafeArea()
        }
    }
}

/// A game's cover art, clean — just the artwork, no frame. Falls back to a
/// solid tile with the title when no cover is available.
struct CleanCover: View {
    let gameName: String
    var width: CGFloat = 150

    @State private var image: UIImage?

    private var height: CGFloat { width * 1.32 }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Retro.panel2, Retro.bg2], startPoint: .top, endPoint: .bottom)
                    Text(gameName)
                        .font(.system(size: width * 0.11, weight: .bold, design: .rounded))
                        .foregroundStyle(Retro.mut)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(10)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Retro.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 16, x: 0, y: 14)
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

/// Uppercase mono section label used across the dashboard.
struct RetroLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Retro.mono)
            .tracking(2)
            .foregroundStyle(Retro.faint)
    }
}

/// Solid PlayStation-blue primary action.
struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.vertical, 12).padding(.horizontal, 22)
            .background(Retro.accent)
            .overlay(Rectangle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
