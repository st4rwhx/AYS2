// GraphicsSettingsView.swift — Renderer, upscale, filter, and display settings
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct GraphicsSettingsView: View {
    @State private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Renderer") {
                Picker("Renderer", selection: $settings.renderer) {
                    Text("Metal (Hardware)").tag(17)
                    Text("Software").tag(13)
                    Text("Null (No Output)").tag(11)
                }
                Text("Metal is recommended. Software is slow but accurate. Null disables rendering (for testing). Requires restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Upscaling") {
                Picker("Internal Resolution", selection: $settings.upscaleMultiplier) {
                    Text("Native (1x)").tag(Float(1.0))
                    Text("2x — ~HD").tag(Float(2.0))
                    Text("3x — ~QHD").tag(Float(3.0))
                    Text("4x — ~4K").tag(Float(4.0))
                    Text("5x").tag(Float(5.0))
                    Text("6x").tag(Float(6.0))
                    Text("8x — ~8K").tag(Float(8.0))
                }
                Text("Multiplies the game's NATIVE resolution — which varies per game (e.g. 512×448 or 640×448). There is no fixed 1080p/4K: the image scales up from native by this factor. Higher = sharper but heavier. Requires restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Filtering") {
                Picker("Texture Filtering", selection: $settings.textureFiltering) {
                    Text("Nearest (Pixelated)").tag(0)
                    Text("Bilinear (Forced)").tag(1)
                    Text("Bilinear (PS2 Default)").tag(2)
                    Text("Bilinear (Forced excl. Sprite)").tag(3)
                }

                Toggle("FXAA", isOn: $settings.fxaa)
                Text("Fast anti-aliasing. Smooths edges but may blur textures slightly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("CAS Sharpening", isOn: Binding(
                    get: { settings.casMode > 0 },
                    set: { settings.casMode = $0 ? 1 : 0 }
                ))
                if settings.casMode > 0 {
                    HStack {
                        Text("Sharpness")
                        Slider(value: Binding(
                            get: { Float(settings.casSharpness) / 100.0 },
                            set: { settings.casSharpness = Int($0 * 100) }
                        ), in: 0...1)
                        Text("\(settings.casSharpness)%")
                            .font(.caption)
                            .frame(width: 40)
                    }
                }
                Text("Contrast Adaptive Sharpening via Metal. Sharpens the image after rendering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Picker("Deinterlace", selection: $settings.interlaceMode) {
                    Text("Automatic (Default)").tag(0)
                    Text("Off").tag(1)
                    Text("Weave (TFF)").tag(2)
                    Text("Weave (BFF)").tag(3)
                    Text("Bob (TFF)").tag(4)
                    Text("Bob (BFF)").tag(5)
                    Text("Blend (TFF)").tag(6)
                    Text("Blend (BFF)").tag(7)
                    Text("Adaptive (TFF)").tag(8)
                    Text("Adaptive (BFF)").tag(9)
                }

                Picker("Aspect Ratio", selection: $settings.aspectRatio) {
                    Text("Auto 4:3 / 3:2 (Default)").tag(0)
                    Text("4:3").tag(1)
                    Text("16:9 (Widescreen)").tag(2)
                    Text("Stretch to Window").tag(3)
                }
            }

            Section("Quality") {
                Picker("Blending Accuracy", selection: $settings.blendingAccuracy) {
                    Text("Minimum (Fast)").tag(0)
                    Text("Basic (Default)").tag(1)
                    Text("Medium").tag(2)
                    Text("High").tag(3)
                    Text("Full (Slow)").tag(4)
                    Text("Ultra (Very Slow)").tag(5)
                }
                Text("Higher accuracy fixes transparency issues but reduces performance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Dithering", selection: $settings.dithering) {
                    Text("Off").tag(0)
                    Text("Unscaled").tag(1)
                    Text("Scaled (Default)").tag(2)
                }
            }

            Section("VSync") {
                Stepper("Queue Size: \(settings.vsyncQueueSize)", value: $settings.vsyncQueueSize, in: 0...3)
                Text("Frames the GS thread may buffer. PCSX2 default is 2. Higher smooths frame pacing but adds input latency; 0 is lowest latency.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset Graphics to Defaults") {
                    settings.resetGraphicsDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Graphics")
        .navigationBarTitleDisplayMode(.inline)
    }
}
