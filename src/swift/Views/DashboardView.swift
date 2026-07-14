// DashboardView.swift — ELORIS-PRISM console-style home (NXE shell).
// SPDX-License-Identifier: GPL-3.0+
//
// The ELORIS-PRISM identity layer: a light NXE field, a horizontal top nav
// (logo · bumpers · tabs), PlayStation-blue accent and a tiled Settings hub.
// The sections host the full ARMSX2 feature views (games, BIOS, help, settings)
// unchanged, so no emulator functionality is lost — only the shell is ours.

import SwiftUI

enum DashSection: String, CaseIterable, Identifiable {
    case games = "Games", bios = "BIOS", settings = "Settings", help = "Help"
    var id: String { rawValue }
}

struct DashboardView: View {
    @State private var section: DashSection = .games

    var body: some View {
        ZStack {
            RetroBackground()
            VStack(spacing: 0) {
                TopNav(section: $section)
                Rectangle().fill(Retro.line).frame(height: 1)
                content
            }
        }
        .preferredColorScheme(.light)   // NXE dashboard is always light
        .tint(Retro.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .games:    GameListView()
        case .bios:     BIOSListView()
        case .settings: SettingsGridView()
        case .help:     HelpView()
        }
    }
}

// MARK: - Top navigation bar (logo · bumpers · tabs)

struct TopNav: View {
    @Binding var section: DashSection

    var body: some View {
        HStack(spacing: 12) {
            // Logo mark in a rounded square, like the console's home glyph.
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Retro.line2, lineWidth: 1.5)
                .frame(width: 34, height: 34)
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 15, height: 15)
                        .rotationEffect(.degrees(45))
                )

            BumperPill(text: "LB")

            // Section tabs with the active PlayStation-blue underline.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(DashSection.allCases) { s in
                        Button {
                            section = s
                            SoundManager.shared.play(.nav)
                        } label: {
                            VStack(spacing: 5) {
                                Text(s.rawValue)
                                    .font(.system(size: 17, weight: section == s ? .bold : .regular))
                                    .foregroundStyle(section == s ? Retro.ink : Retro.mut)
                                Rectangle()
                                    .fill(section == s ? Retro.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            BumperPill(text: "RB")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Settings as a tiled grid (console-dashboard "hub")

struct SettingsGridView: View {
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    SettingsTile(title: "Emulation", subtitle: "Core · Speed · Cheats",
                                 systemImage: "cpu") { EmulatorSettingsView() }
                    SettingsTile(title: "Video", subtitle: "Renderer · Resolution · FPS",
                                 systemImage: "display") { GraphicsSettingsView() }
                    SettingsTile(title: "Overlay", subtitle: "OSD · HUD · Stats",
                                 systemImage: "text.below.photo") { OverlaySettingsView() }
                    SettingsTile(title: "Controls", subtitle: "Gamepad · Mapping",
                                 systemImage: "gamecontroller") { GamepadSettingsView() }
                    SettingsTile(title: "Virtual Pad", subtitle: "Touch · Layout · Scale",
                                 systemImage: "hand.draw") { VirtualPadSettingsView() }
                    SettingsTile(title: "System", subtitle: "Sounds · About · Version",
                                 systemImage: "gearshape") { SystemSettingsView() }
                }
                .padding(16)
            }
            .background(RetroBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// One large solid tile in the Settings hub.
struct SettingsTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                // Big translucent icon, bottom-right.
                Image(systemName: systemImage)
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(.white.opacity(0.20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
            }
            .frame(height: 132)
            .shadow(color: Retro.accentDeep.opacity(0.25), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

/// Small "System" settings screen (the bits that had no dedicated view).
struct SystemSettingsView: View {
    @AppStorage("uiSoundsEnabled") private var uiSoundsEnabled = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $uiSoundsEnabled) {
                    Label("UI Sounds", systemImage: "speaker.wave.2")
                }
            } footer: {
                Text("Original menu sounds. Obeys the mute switch.")
            }
            Section {
                NavigationLink {
                    TermsOfUseView(mode: .view)
                } label: {
                    Label("Terms of Use & Privacy", systemImage: "hand.raised")
                }
                NavigationLink {
                    LicenseView()
                } label: {
                    Label("Licenses & Credits", systemImage: "doc.text")
                }
            } footer: {
                Text("Diagnostics are anonymous — device model, iOS version and technical logs on crashes/errors, to fix bugs. No account or personal data.")
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(ARMSX2Bridge.buildVersion())
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("System")
        .navigationBarTitleDisplayMode(.inline)
    }
}
