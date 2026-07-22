// GamepadSettingsView.swift — Virtual pad + controller mapping
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

private struct PS2Button: Identifiable {
    let id: Int
    let name: String
}

private let ps2Buttons: [PS2Button] = [
    PS2Button(id: 0,  name: "D-Pad Up"),
    PS2Button(id: 1,  name: "D-Pad Down"),
    PS2Button(id: 2,  name: "D-Pad Left"),
    PS2Button(id: 3,  name: "D-Pad Right"),
    PS2Button(id: 4,  name: "Cross"),
    PS2Button(id: 5,  name: "Circle"),
    PS2Button(id: 6,  name: "Square"),
    PS2Button(id: 7,  name: "Triangle"),
    PS2Button(id: 8,  name: "L1"),
    PS2Button(id: 9,  name: "R1"),
    PS2Button(id: 12, name: "Start"),
    PS2Button(id: 13, name: "Select"),
    PS2Button(id: 14, name: "L3"),
    PS2Button(id: 15, name: "R3"),
]

private let multitapModes: [(id: Int, title: String)] = [
    (0, "Auto (3+ Controllers)"),
    (1, "Disabled"),
    (2, "Port 1 Multitap"),
    (3, "Port 2 Multitap"),
    (4, "Port 1 + Port 2 Multitap"),
]

private func multitapModeTitle(_ id: Int) -> String {
    multitapModes.first(where: { $0.id == id })?.title ?? "Auto"
}

// SDL_GamepadButton → display name (matches SDL3 enum order)
private func sdlButtonName(_ idx: Int) -> String {
    switch idx {
    case 0:  return "A / Cross"
    case 1:  return "B / Circle"
    case 2:  return "X / Square"
    case 3:  return "Y / Triangle"
    case 4:  return "Share / Back"
    case 5:  return "Guide / PS"
    case 6:  return "Options / Start"
    case 7:  return "L-Stick Press"
    case 8:  return "R-Stick Press"
    case 9:  return "L-Shoulder"
    case 10: return "R-Shoulder"
    case 11: return "D-Pad Up"
    case 12: return "D-Pad Down"
    case 13: return "D-Pad Left"
    case 14: return "D-Pad Right"
    case 15: return "Misc / Share"
    case 20: return "Touchpad"
    default: return "Button \(idx)"
    }
}

struct GamepadSettingsView: View {
    @State private var settings = SettingsStore.shared
    @State private var capturingIndex: Int? = nil
    @State private var mappingVersion = 0
    @State private var pollTimer: Timer? = nil
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    LocalMultiplayerSettingsView()
                } label: {
                    Label {
                        HStack {
                            Text(settings.localized("Local Multiplayer"))
                            Spacer()
                            Text(settings.localized(multitapModeTitle(settings.controllerMultitapMode)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.3")
                    }
                }
            } footer: {
                Text(settings.localized("Configure multitap for 3-4 local controllers."))
            }

            Section {
                NavigationLink {
                    AnalogStickSettingsView()
                } label: {
                    Label(settings.localized("Stick & Trigger Tuning"), systemImage: "slider.horizontal.3")
                }
            } footer: {
                Text(settings.localized("Deadzone, sensitivity, inversion and vibration for the analog sticks and triggers."))
            }

            // AYS2: controller hotkeys (seam).
            Section {
                Toggle(settings.localized("Controller Hotkeys"), isOn: $settings.openMenuWithControllerButton)
            } header: {
                Text(settings.localized("Hotkeys"))
            } footer: {
                Text(settings.localized("Tap Menu (\u{2261}) / Options to open the pause menu — then navigate it with the controller. Or hold Menu and press: Cross = quick save, Circle = quick load, R1 = toggle fast-forward. No need to reach for the on-screen buttons."))
            }

            Section {
                ForEach(ps2Buttons) { btn in
                    mappingRow(btn)
                }
            } header: {
                Text(settings.localized("Button Mapping"))
            } footer: {
                Text(settings.localized("Tap a row, then press a button on your controller to assign it. L2/R2 are analog triggers (not remappable)."))
            }

            Section {
                Button {
                    ARMSX2Bridge.testControllerRumble()
                    statusMessage = settings.localized("Controller rumble test sent.")
                } label: {
                    Label(settings.localized("Test Controller Rumble"), systemImage: "waveform.path")
                }

                Button(settings.localized("Reset to Default")) {
                    ARMSX2Bridge.resetButtonMappings()
                    mappingVersion += 1
                }
                .foregroundStyle(.red)
            } header: {
                Text(settings.localized("Tools"))
            } footer: {
                if let statusMessage {
                    Text(statusMessage)
                }
            }
        }
        .navigationTitle(settings.localized("Game Controller"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopCapture()
        }
    }

    @ViewBuilder
    private func mappingRow(_ btn: PS2Button) -> some View {
        let isCapturing = capturingIndex == btn.id
        let currentSDL = Int(ARMSX2Bridge.getButtonMapping(Int32(btn.id)))

        Button {
            if isCapturing {
                stopCapture()
            } else {
                startCapture(for: btn.id)
            }
        } label: {
            HStack {
                // Left: assigned controller button (prominent)
                if isCapturing {
                    Text(settings.localized("Press a button..."))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                } else {
                    Text(settings.localized(sdlButtonName(currentSDL)))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                Spacer()
                // Right: PS2 function name (secondary)
                Text(settings.localized(btn.name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .id(mappingVersion)
        }
        .listRowBackground(isCapturing ? Color.orange.opacity(0.15) : nil)
    }

    private func startCapture(for ps2Index: Int) {
        capturingIndex = ps2Index
        ARMSX2Bridge.startButtonCapture()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            ARMSX2Bridge.pollGamepadForCapture()
            let captured = ARMSX2Bridge.capturedButton()
            if captured >= 0 {
                ARMSX2Bridge.setButtonMapping(Int32(ps2Index), toSDLButton: captured)
                Task { @MainActor in
                    stopCapture()
                    mappingVersion += 1
                }
            }
        }
    }

    private func stopCapture() {
        pollTimer?.invalidate()
        pollTimer = nil
        capturingIndex = nil
        ARMSX2Bridge.stopButtonCapture()
    }
}

struct LocalMultiplayerSettingsView: View {
    @State private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Picker(settings.localized("Multitap Mode"), selection: $settings.controllerMultitapMode) {
                    ForEach(multitapModes, id: \.id) { mode in
                        Text(settings.localized(mode.title)).tag(mode.id)
                    }
                }

                HStack {
                    Text(settings.localized("Current Mode"))
                    Spacer()
                    Text(settings.localized(multitapModeTitle(settings.controllerMultitapMode)))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(settings.localized("Multitap"))
            } footer: {
                Text(settings.localized("Auto enables Port 1 multitap when 3 or more controllers are detected before boot. Manual modes take effect on the next boot/reset."))
            }

            Section(settings.localized("Controller Mapping")) {
                Text(settings.localized("Disabled maps controllers 1-2 to normal PS2 ports. Port 1 Multitap maps controllers 1-4 to 1A/1B/1C/1D. Port 2 Multitap keeps controller 1 on Port 1 and maps controllers 2-4 to Port 2 multitap slots."))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(settings.localized("Local Multiplayer"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// AYS2: analog stick / trigger tuning (seam) — deadzone, anti-deadzone-style
// sensitivity boost, button/trigger deadzone, stick inversion and vibration
// scale. The emulator core already supports all of this (PadDualshock2's
// SettingInfo array); it was simply never exposed on iOS.
private let invertOptions: [(id: Int, title: String)] = [
    (0, "Not Inverted"),
    (1, "Invert Left/Right"),
    (2, "Invert Up/Down"),
    (3, "Invert Left/Right + Up/Down"),
]

struct AnalogStickSettingsView: View {
    @State private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                percentSlider(settings.localized("Deadzone"), value: $settings.padAnalogDeadzone, range: 0...1)
                Text(settings.localized("Ignores small stick movements around center — raise this if your stick drifts at rest."))
                    .font(.caption).foregroundStyle(.secondary)

                percentSlider(settings.localized("Sensitivity"), value: $settings.padAnalogSensitivity, range: 0.01...2)
                Text(settings.localized("Scales stick movement past the deadzone, so the full range is still reachable — 130-140% is recommended on most modern controllers."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text(settings.localized("Left/Right Analog Sticks"))
            }

            Section {
                Picker(settings.localized("Invert Left Stick"), selection: $settings.padInvertLeftStick) {
                    ForEach(invertOptions, id: \.id) { opt in
                        Text(settings.localized(opt.title)).tag(opt.id)
                    }
                }
                Picker(settings.localized("Invert Right Stick"), selection: $settings.padInvertRightStick) {
                    ForEach(invertOptions, id: \.id) { opt in
                        Text(settings.localized(opt.title)).tag(opt.id)
                    }
                }
            } header: {
                Text(settings.localized("Inversion"))
            }

            Section {
                percentSlider(settings.localized("Button/Trigger Deadzone"), value: $settings.padButtonDeadzone, range: 0...1)
                Text(settings.localized("Ignores light presses on L2/R2 and other pressure-sensitive buttons."))
                    .font(.caption).foregroundStyle(.secondary)

                percentSlider(settings.localized("Pressure Modifier"), value: $settings.padPressureModifier, range: 0.01...1)
                Text(settings.localized("Pressure applied while a modifier button is held, for games that read analog button pressure."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text(settings.localized("Buttons & Triggers"))
            }

            Section {
                percentSlider(settings.localized("Large Motor"), value: $settings.padLargeMotorScale, range: 0...2)
                percentSlider(settings.localized("Small Motor"), value: $settings.padSmallMotorScale, range: 0...2)
            } header: {
                Text(settings.localized("Vibration Strength"))
            } footer: {
                Text(settings.localized("Scales the low-frequency (large) and high-frequency (small) rumble motors independently."))
            }

            Section {
                Button(settings.localized("Reset to Default")) {
                    settings.padAnalogDeadzone = 0.0
                    settings.padAnalogSensitivity = 1.33
                    settings.padButtonDeadzone = 0.0
                    settings.padInvertLeftStick = 0
                    settings.padInvertRightStick = 0
                    settings.padLargeMotorScale = 1.0
                    settings.padSmallMotorScale = 1.0
                    settings.padPressureModifier = 1.0
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(settings.localized("Stick & Trigger Tuning"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func percentSlider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, onEditingChanged: { editing in
                if editing { settings.beginVisualSliderEdit() } else { settings.endVisualSliderEdit() }
            })
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}
