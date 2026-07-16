// DiagnosticsStore.swift — AYS2 diagnostics: reads the Flight Recorder and runs
// the first, deliberately-honest rules pass (additive).
// SPDX-License-Identifier: GPL-3.0+
//
// This is Layer 3 (rules) sitting on Layer 1 (the C++ Flight Recorder). It only
// asserts what the recorded metrics actually prove. It NEVER claims a cause it
// cannot observe — no "VU1 stall", no "DMA sync" — because AYS2 does not
// instrument those yet. A confident wrong diagnosis is worse than none.

import Foundation
import SwiftUI

struct DiagSnapshot: Identifiable {
    let id = UUID()
    let t: Double
    let fps: Double
    let internalFps: Double
    let speed: Double
    let avgFrameMs: Double
    let minFrameMs: Double
    let maxFrameMs: Double
    let eePct: Double
    let gsPct: Double
    let vuPct: Double
    let gpuMs: Double
    let gpuPct: Double
    let ramGb: Double
    let thermal: Int      // 0 nominal, 1 fair, 2 serious, 3 critical
    let battery: Int
    let lowPower: Bool

    init(_ d: [String: NSNumber]) {
        t = d["t"]?.doubleValue ?? 0
        fps = d["fps"]?.doubleValue ?? 0
        internalFps = d["internalFps"]?.doubleValue ?? 0
        speed = d["speed"]?.doubleValue ?? 0
        avgFrameMs = d["avgFrameMs"]?.doubleValue ?? 0
        minFrameMs = d["minFrameMs"]?.doubleValue ?? 0
        maxFrameMs = d["maxFrameMs"]?.doubleValue ?? 0
        eePct = d["eePct"]?.doubleValue ?? 0
        gsPct = d["gsPct"]?.doubleValue ?? 0
        vuPct = d["vuPct"]?.doubleValue ?? 0
        gpuMs = d["gpuMs"]?.doubleValue ?? 0
        gpuPct = d["gpuPct"]?.doubleValue ?? 0
        ramGb = d["ramGb"]?.doubleValue ?? -1
        thermal = d["thermal"]?.intValue ?? 0
        battery = d["battery"]?.intValue ?? -1
        lowPower = (d["lowPower"]?.intValue ?? 0) != 0
    }
}

struct DiagFinding: Identifiable {
    enum Severity: Int { case info, warn, critical }
    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
    let confidence: String   // "observed" / "likely" / "possible"
    let systemImage: String
}

@Observable
final class DiagnosticsStore: @unchecked Sendable {
    static let shared = DiagnosticsStore()

    private(set) var snapshots: [DiagSnapshot] = []
    var isRecording: Bool { ARMSX2Bridge.isDiagnosticsRecording() }

    private init() {}

    func setRecording(_ on: Bool) {
        ARMSX2Bridge.setDiagnosticsRecording(on)
    }

    func clear() {
        ARMSX2Bridge.clearDiagnostics()
        snapshots = []
    }

    func refresh() {
        let raw = ARMSX2Bridge.diagnosticsSnapshots()
        snapshots = raw.map { DiagSnapshot($0) }
    }

    private func thermalName(_ t: Int) -> String {
        switch t {
        case 3: return "Critical"
        case 2: return "Serious"
        case 1: return "Fair"
        default: return "Nominal"
        }
    }

    // MARK: - The honest rules pass
    //
    // Every finding below is grounded in a metric AYS2 actually records. The
    // wording stays at the altitude the data supports ("GPU-bound", "thermal
    // throttling", "stutter") and never invents a subsystem-level cause.

    var findings: [DiagFinding] {
        guard snapshots.count >= 4 else { return [] }
        // Analyse the most recent ~30 s window (0.5 s cadence → ~60 samples).
        let window = Array(snapshots.suffix(60))
        var out: [DiagFinding] = []

        let speeds = window.map(\.speed).sorted()
        let medianSpeed = speeds[speeds.count / 2]
        let peakThermal = window.map(\.thermal).max() ?? 0
        let anyLowPower = window.contains { $0.lowPower }

        // 1. Thermal throttling — the #1 real cause on iPhone.
        if peakThermal >= 2 && medianSpeed < 92 {
            out.append(DiagFinding(
                severity: peakThermal >= 3 ? .critical : .warn,
                title: "Thermal throttling",
                detail: "Heat reached \(thermalName(peakThermal)) while speed fell to \(Int(medianSpeed))%. iOS is capping the CPU/GPU clocks — this is a device limit, not a bug. Let the device cool, lower resolution scale, or cap the frame rate.",
                confidence: "observed",
                systemImage: "thermometer.sun.fill"))
        }

        // 2. Sustained slowdown → GPU-bound vs CPU/EE-bound split.
        if medianSpeed < 90 && peakThermal < 2 {
            let avgGpu = window.map(\.gpuPct).reduce(0, +) / Double(window.count)
            let avgEe = window.map(\.eePct).reduce(0, +) / Double(window.count)
            if avgGpu > 85 && avgGpu > avgEe {
                out.append(DiagFinding(
                    severity: .warn,
                    title: "GPU-bound",
                    detail: "Speed ~\(Int(medianSpeed))% with GPU busy ~\(Int(avgGpu))% (above the EE thread). The Metal renderer is the bottleneck — try a lower internal resolution or disable heavy upscaling for this game.",
                    confidence: "likely",
                    systemImage: "cpu.fill"))
            } else {
                out.append(DiagFinding(
                    severity: .warn,
                    title: "CPU/EE-bound",
                    detail: "Speed ~\(Int(medianSpeed))% with the EE thread at ~\(Int(avgEe))% and GPU not saturated. The emulated CPU is the limit — this game is demanding for the recompiler on this device.",
                    confidence: "likely",
                    systemImage: "memorychip.fill"))
            }
        }

        // 3. Stutter vs steady: spikes while the average is healthy.
        let avgFrame = window.map(\.avgFrameMs).reduce(0, +) / Double(window.count)
        let worstSpike = window.map(\.maxFrameMs).max() ?? 0
        if avgFrame > 0 && worstSpike > avgFrame * 2.5 && medianSpeed >= 90 {
            out.append(DiagFinding(
                severity: .info,
                title: "Frame-time spikes (stutter)",
                detail: "Average frame time is healthy (\(String(format: "%.1f", avgFrame)) ms) but the worst frame hit \(String(format: "%.1f", worstSpike)) ms. Feels like an occasional hitch rather than a slowdown — often streaming/compilation of new code or a background task.",
                confidence: "observed",
                systemImage: "waveform.path.ecg"))
        }

        // 4. Memory — honest, no false alarm (we don't know device total here).
        if let maxRam = window.map(\.ramGb).max(), maxRam >= 2.6 {
            out.append(DiagFinding(
                severity: maxRam >= 3.0 ? .warn : .info,
                title: "High app memory",
                detail: "App RAM reached \(String(format: "%.1f", maxRam)) GB. On memory-constrained iPhones iOS may terminate the app — watch for crashes on lower-RAM devices.",
                confidence: "observed",
                systemImage: "internaldrive.fill"))
        }

        // 5. Low-power mode confound.
        if anyLowPower {
            out.append(DiagFinding(
                severity: .info,
                title: "Low Power Mode is on",
                detail: "iOS Low Power Mode throttles performance. Any slowdown above may simply be this — retest with it off before drawing conclusions.",
                confidence: "observed",
                systemImage: "battery.25"))
        }

        if out.isEmpty {
            out.append(DiagFinding(
                severity: .info,
                title: "No problem detected",
                detail: "Over the recorded window speed and frame times look healthy. Keep the recorder on and reproduce the issue, then check again.",
                confidence: "observed",
                systemImage: "checkmark.seal.fill"))
        }
        return out
    }
}
