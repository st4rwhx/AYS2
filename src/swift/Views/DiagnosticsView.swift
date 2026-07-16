// DiagnosticsView.swift — AYS2 diagnostics screen (Flight Recorder + findings).
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct DiagnosticsView: View {
    @State private var settings = SettingsStore.shared
    @State private var store = DiagnosticsStore.shared
    @State private var recording = ARMSX2Bridge.isDiagnosticsRecording()

    var showsClose = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                recorderCard
                if let latest = store.snapshots.last {
                    liveStats(latest)
                    speedChart
                }
                findingsCard
                footer
            }
            .padding(16)
        }
        .background(RetroBackground().ignoresSafeArea())
        .navigationTitle(settings.localized("Diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Poll the recorder ~2×/s while the screen is visible.
            while !Task.isCancelled {
                store.refresh()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "stethoscope")
                .font(.system(size: 34))
                .foregroundStyle(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                                startPoint: .top, endPoint: .bottom))
            Text(settings.localized("Flight Recorder"))
                .font(.title3.weight(.heavy)).foregroundStyle(Retro.ink)
            Text(settings.localized("Records real emulator metrics so problems can be analysed instead of guessed."))
                .font(.caption).foregroundStyle(Retro.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var recorderCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $recording) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.localized("Record metrics")).foregroundStyle(Retro.ink)
                    Text(settings.localized("On only while you're diagnosing. Near-zero overhead."))
                        .font(.caption2).foregroundStyle(Retro.mut)
                }
            }
            .tint(Retro.accent)
            .onChange(of: recording) { _, on in store.setRecording(on) }

            HStack(spacing: 12) {
                stat(settings.localized("Samples"), "\(store.snapshots.count)")
                Divider().frame(height: 28)
                stat(settings.localized("Span"),
                     store.snapshots.count >= 2
                        ? "\(Int((store.snapshots.last!.t - store.snapshots.first!.t)))s"
                        : "—")
                Spacer()
                Button {
                    SoundManager.shared.play(.nav)
                    store.clear()
                } label: {
                    Label(settings.localized("Clear"), systemImage: "trash")
                        .font(.caption.weight(.semibold)).foregroundStyle(Retro.accent)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.line, lineWidth: 1))
    }

    private func liveStats(_ s: DiagSnapshot) -> some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 10) {
            metric("Speed", String(format: "%.0f%%", s.speed))
            metric("FPS", String(format: "%.0f", s.fps))
            metric("Frame", String(format: "%.1fms", s.avgFrameMs))
            metric("EE", String(format: "%.0f%%", s.eePct))
            metric("GS", String(format: "%.0f%%", s.gsPct))
            metric("GPU", String(format: "%.1fms", s.gpuMs))
            metric("VU", String(format: "%.0f%%", s.vuPct))
            metric("RAM", s.ramGb >= 0 ? String(format: "%.1fGB", s.ramGb) : "—")
            metric("Heat", ["Nominal", "Fair", "Serious", "Critical"][min(max(s.thermal, 0), 3)])
        }
    }

    private var speedChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(settings.localized("Speed % — last window"))
                .font(.caption.weight(.semibold)).foregroundStyle(Retro.mut)
            Canvas { ctx, size in
                let pts = store.snapshots.suffix(120).map(\.speed)
                guard pts.count >= 2 else { return }
                let maxV = 110.0
                let stepX = size.width / CGFloat(pts.count - 1)
                // 100% reference line.
                var ref = Path()
                let refY = size.height * (1 - CGFloat(100.0 / maxV))
                ref.move(to: CGPoint(x: 0, y: refY))
                ref.addLine(to: CGPoint(x: size.width, y: refY))
                ctx.stroke(ref, with: .color(Retro.line2.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                var path = Path()
                for (i, v) in pts.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height * (1 - CGFloat(min(v, maxV) / maxV))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(Retro.accent), lineWidth: 2)
            }
            .frame(height: 90)
            .background(RoundedRectangle(cornerRadius: 10).fill(Retro.panel2))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.line, lineWidth: 1))
    }

    private var findingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.localized("Analysis"))
                .font(.headline).foregroundStyle(Retro.ink)
            if store.snapshots.count < 4 {
                Text(settings.localized("Record for a few seconds while reproducing the issue, then findings appear here."))
                    .font(.caption).foregroundStyle(Retro.mut)
            } else {
                ForEach(store.findings) { f in findingRow(f) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.line, lineWidth: 1))
    }

    private func findingRow(_ f: DiagFinding) -> some View {
        let color: Color = f.severity == .critical ? .red
            : (f.severity == .warn ? .orange : Retro.accent)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: f.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(settings.localized(f.title))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Retro.ink)
                    Text(f.confidence.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(color.opacity(0.85)))
                }
                Text(settings.localized(f.detail))
                    .font(.caption).foregroundStyle(Retro.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        Text(settings.localized("The analysis only reports what the recorded metrics prove. It never guesses subsystem-level causes (VU/DMA/GS internals) that AYS2 doesn't yet measure."))
            .font(.caption2).foregroundStyle(Retro.faint)
            .multilineTextAlignment(.center)
            .padding(.bottom, 20)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Retro.ink)
            Text(label).font(.caption2).foregroundStyle(Retro.faint)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(Retro.ink).minimumScaleFactor(0.7).lineLimit(1)
            Text(settings.localized(label)).font(.caption2).foregroundStyle(Retro.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Retro.panel2))
    }
}
