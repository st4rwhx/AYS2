// RetroKit.swift — light "console dashboard" (NXE-style) design system.
// SPDX-License-Identifier: GPL-3.0+
//
// Faithful rebuild of the modern console-dashboard look: an airy light field,
// a horizontal top nav, big solid tiles and clean white cards. Xbox's dashboard
// is green; this is a PS2 emulator, so the single accent is PlayStation blue.
// Native SwiftUI — no third-party code.

import SwiftUI
import UIKit

/// Builds a Color that adapts to the active light/dark interface style, so the
/// whole NXE design system flips together with the app's appearance setting.
private func dyn(
    _ light: (Double, Double, Double),
    _ dark: (Double, Double, Double)
) -> Color {
    Color(uiColor: UIColor { tc in
        let c = tc.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

enum Retro {
    // NXE base — airy near-white in light, deep near-black in dark.
    static let bg     = dyn((0.929, 0.941, 0.961), (0.055, 0.063, 0.075)) // #EDF0F5 / #0E1013
    static let bg2    = dyn((0.882, 0.902, 0.937), (0.082, 0.090, 0.110)) // #E1E6EF / #15171C
    static let panel  = dyn((1.000, 1.000, 1.000), (0.106, 0.114, 0.141)) // white  / #1B1D24
    static let panel2 = dyn((0.957, 0.965, 0.980), (0.141, 0.153, 0.196)) // #F4F6FA / #242732
    static let line   = dyn((0.827, 0.847, 0.886), (0.165, 0.176, 0.212)) // #D3D8E2 / #2A2D36
    static let line2  = dyn((0.737, 0.765, 0.816), (0.227, 0.243, 0.290)) // #BCC3D0 / #3A3E4A

    // Ink — dark on light, near-white on dark.
    static let ink    = dyn((0.106, 0.114, 0.141), (0.941, 0.945, 0.961)) // #1B1D24 / #F0F1F5
    static let mut    = dyn((0.353, 0.376, 0.439), (0.604, 0.631, 0.698)) // #5A6070 / #9AA1B2
    static let faint  = dyn((0.541, 0.565, 0.627), (0.420, 0.447, 0.502)) // #8A90A0 / #6B7280

    /// PlayStation blue accent (works on both light and dark fields).
    static let accent     = Color(red: 0.153, green: 0.427, blue: 1.0)   // #2769FF
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

/// A PlayStation face button (△ ○ ✕ □) drawn in its signature colour.
enum PSButton: String, Identifiable {
    case triangle, circle, cross, square
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .triangle: return "triangle"
        case .circle:   return "circle"
        case .cross:    return "xmark"
        case .square:   return "square"
        }
    }
    var color: Color {
        switch self {
        case .triangle: return Color(red: 0.13, green: 0.75, blue: 0.55) // green
        case .circle:   return Color(red: 0.92, green: 0.26, blue: 0.30) // red
        case .cross:    return Color(red: 0.30, green: 0.55, blue: 0.95) // blue
        case .square:   return Color(red: 0.95, green: 0.42, blue: 0.72) // pink
        }
    }
}

struct PSGlyph: View {
    let button: PSButton
    var body: some View {
        Image(systemName: button.symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(button.color)
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(button.color, lineWidth: 1.5))
    }
}

/// The bottom action-hint bar (△ select  ✕ back …) using PS2 face buttons.
struct HintBar: View {
    struct Hint: Identifiable { let id = UUID(); let button: PSButton; let label: String }
    let hints: [Hint]

    var body: some View {
        HStack(spacing: 18) {
            Spacer(minLength: 0)
            ForEach(hints) { h in
                HStack(spacing: 6) {
                    PSGlyph(button: h.button)
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
