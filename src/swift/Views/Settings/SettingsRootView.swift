// SettingsRootView.swift — Settings navigation root
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct SettingsRootView: View {
    @AppStorage("uiSoundsEnabled") private var uiSoundsEnabled = true
    // Same UserDefaults key TelemetryManager reads; default on.
    @AppStorage("telemetryEnabled") private var diagnosticsEnabled = true

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
                Toggle(isOn: $diagnosticsEnabled) {
                    Label("Anonymous Diagnostics", systemImage: "waveform.path.ecg")
                }
            } footer: {
                Text("Sends an anonymous report when the app crashes (device model, iOS version and a technical log — no account or personal data) so bugs can be fixed. No gameplay or personal data is collected.")
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
                    LicenseView()
                } label: {
                    Label("Licenses & Credits", systemImage: "doc.text")
                }
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
