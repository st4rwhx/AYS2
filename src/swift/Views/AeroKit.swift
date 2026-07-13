// AeroKit.swift — Frutiger Aero design system.
// SPDX-License-Identifier: GPL-3.0+
//
// Real photographic backdrops (bundled sky/water/nature shots) behind frosted
// "Aero glass" panels, glossy aqua controls, and the crystal motif. This is the
// shared material language for the whole app; individual screens build on it.

import SwiftUI

enum Aero {
    static let sky      = Color(red: 0.17, green: 0.66, blue: 0.90)
    static let deep     = Color(red: 0.04, green: 0.37, blue: 0.66)
    static let ink      = Color(red: 0.04, green: 0.18, blue: 0.28)
    static let ink2     = Color(red: 0.07, green: 0.26, blue: 0.38)
    static let leaf     = Color(red: 0.49, green: 0.85, blue: 0.34)

    /// Available photographic backdrops.
    enum Scene: String { case landscape = "AeroLandscape", underwater = "AeroUnderwater", dewdrop = "AeroDewdrop" }
}

// MARK: - Full-screen photographic backdrop

struct AeroBackground: View {
    var scene: Aero.Scene = .landscape

    // The app moved to the solid "Clean Retro" identity; this now renders the
    // retro backdrop so every screen that still calls `aeroScreen()` stays
    // consistent without touching each view.
    var body: some View {
        RetroBackground()
    }
}

// MARK: - Frosted Aero glass panel

struct AeroGlass: ViewModifier {
    var corner: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                // Glossy white tint — brighter at the top, like light on glass.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.50), .white.opacity(0.10), .white.opacity(0.22)],
                        startPoint: .top, endPoint: .bottom))
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // Crisp top-edge highlight.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 44)
                    .padding(.horizontal, 5)
                    .padding(.top, 4)
                    .blur(radius: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: Aero.deep.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

extension View {
    /// Wraps the view in a frosted, glossy Aero glass panel.
    func aeroGlass(corner: CGFloat = 22) -> some View { modifier(AeroGlass(corner: corner)) }

    /// Places the app's photographic backdrop behind a screen and makes its own
    /// scroll surfaces transparent so the photo shows through.
    func aeroScreen(_ scene: Aero.Scene = .landscape) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AeroBackground(scene: scene))
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Glossy aqua primary button (a pressable water droplet)

struct AeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [Aero.sky, Aero.deep],
                    startPoint: .top, endPoint: .bottom))
            )
            .overlay( // top gloss
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.75), .clear],
                                         startPoint: .top, endPoint: .center))
                    .padding(1.5)
                    .allowsHitTesting(false)
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 1))
            .shadow(color: Aero.deep.opacity(0.5), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - The crystal, as a glowing rounded badge

struct CrystalBadge: View {
    var size: CGFloat = 96

    var body: some View {
        Image("Crystal")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: size * 0.4)
                    .padding(3)
                    .allowsHitTesting(false)
            }
            .shadow(color: Aero.sky.opacity(0.6), radius: 22, y: 8)
    }
}

// MARK: - 3D game case (jaquette) — replaces the spinning disc

/// A game shown as a realistic 3D PS2 case: cover front + a left spine, tilted
/// in perspective with a top gloss and a soft contact shadow. Falls back to a
/// crystal case when no cover art is found.
struct BoxArt: View {
    let gameName: String
    var height: CGFloat = 150

    @State private var image: UIImage?

    private var caseWidth: CGFloat { height * 0.70 }   // PS2 DVD-case proportions
    private var spineWidth: CGFloat { max(6, height * 0.055) }

    var body: some View {
        HStack(spacing: 0) {
            // Left spine (the case's side face).
            Rectangle()
                .fill(LinearGradient(
                    colors: [.black.opacity(0.55), .white.opacity(0.18), .black.opacity(0.45)],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: spineWidth)
            // Front cover.
            frontCover
        }
        .frame(width: caseWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        )
        .rotation3DEffect(.degrees(15), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.55)
        .shadow(color: .black.opacity(0.45), radius: 9, x: -4, y: 9)
    }

    private var frontCover: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Aero.sky, Aero.ink], startPoint: .top, endPoint: .bottom)
                Image("Crystal")
                    .resizable().scaledToFit()
                    .padding(caseWidth * 0.16)
                    .shadow(color: Aero.sky.opacity(0.6), radius: 10)
            }
        }
        .overlay(alignment: .top) {   // wet top-gloss
            LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)
        }
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

// MARK: - Reusable empty-state that fills the screen (fixes the "floating card")

struct AeroEmptyState: View {
    let title: String
    let message: String
    let buttonTitle: String
    let systemImage: String
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                CrystalBadge(size: 104)
                    .padding(.bottom, 6)
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .shadow(color: Aero.ink.opacity(0.4), radius: 6, y: 2)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .shadow(color: Aero.ink.opacity(0.35), radius: 4, y: 1)
                    .padding(.horizontal, 8)
                Button(action: action) {
                    Label(buttonTitle, systemImage: systemImage)
                }
                .buttonStyle(AeroButtonStyle())
                .padding(.top, 8)
                if let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .shadow(color: Aero.ink.opacity(0.3), radius: 3, y: 1)
                        .padding(.top, 4)
                        .padding(.horizontal, 24)
                }
            }
            .padding(28)
            .aeroGlass(corner: 30)
            .padding(.horizontal, 26)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
