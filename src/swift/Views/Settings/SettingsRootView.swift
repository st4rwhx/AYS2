// SettingsRootView.swift — Settings navigation root
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct SettingsRootView: View {
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
                    EmulatorSettingsView()
                } label: {
                    Label("Emulator", systemImage: "cpu")
                }
                NavigationLink {
                    GraphicsSettingsView()
                } label: {
                    Label("Graphics", systemImage: "paintbrush")
                }
                NavigationLink {
                    OverlaySettingsView()
                } label: {
                    Label("Overlay (OSD)", systemImage: "text.below.photo")
                }
                NavigationLink {
                    GamepadSettingsView()
                } label: {
                    Label("Game Controller", systemImage: "gamecontroller")
                }
                NavigationLink {
                    VirtualPadSettingsView()
                } label: {
                    Label("Virtual Pad", systemImage: "hand.draw")
                }
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
                Text("Diagnostics are anonymous and part of the Terms of Use — device model, iOS version and technical logs on crashes/errors, to fix bugs. No account or personal data.")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(iPSX2Bridge.buildVersion())
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
