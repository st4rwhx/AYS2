// AYS2Diagnostics.h — AYS2 Flight Recorder (additive).
// SPDX-License-Identifier: GPL-3.0+
//
// Layer 1 of the AYS2 diagnostic system: a ring buffer of per-window
// performance snapshots. It hooks the single point where PCSX2 already
// aggregates every metric (PerformanceMetrics::Update, every UPDATE_INTERVAL =
// 0.5 s), so it costs one struct copy per half-second and touches NO hot path
// (no recompiler, no VU, no DMAC surgery). The iOS layer feeds it thermal /
// RAM / battery each frame via SetDeviceState.
//
// This is deliberately dumb: it only *records* what the emulator already
// measures. Interpretation (rules, signatures, the "why") lives above it, in
// Swift and in the AI-Diagnostic-Engine knowledge base — never here.

#pragma once

#include <cstdint>

namespace AYS2Diagnostics
{
	// One captured window. ~48 bytes; 512 of them ≈ 4 minutes at 0.5 s cadence.
	struct Snapshot
	{
		double t_seconds;    // wall-clock seconds since the first record
		float fps;           // output VPS
		float internal_fps;  // emulated game FPS (0 if unknown)
		float speed;         // % of full speed
		float avg_frame_ms;  // average frame time this window
		float min_frame_ms;  // best frame this window
		float max_frame_ms;  // worst frame this window (spike detector)
		float ee_pct;        // EE/CPU thread usage %
		float gs_pct;        // GS thread usage %
		float vu_pct;        // VU thread usage %
		float gpu_ms;        // Metal present time
		float gpu_pct;       // GPU busy %
		float ram_gb;        // app resident RAM (GB), -1 if unknown
		std::uint8_t thermal;// 0 nominal, 1 fair, 2 serious, 3 critical
		std::int8_t battery; // 0..100, -1 unknown
		std::uint8_t flags;  // bit0: low-power mode
	};

	static constexpr int kCapacity = 512;

	// Called from PerformanceMetrics::Update (core) once per aggregation window.
	void RecordFrame();

	// Called from the iOS device-stats poller (ios_main.mm) each frame.
	void SetDeviceState(std::uint8_t thermal, float ram_gb, int battery, bool low_power);

	// The recorder is off by default; the Diagnostics screen turns it on so we
	// never pay even the tiny cost unless the user is actually looking.
	void SetEnabled(bool enabled);
	bool IsEnabled();

	// Copy up to `max` most-recent snapshots (oldest first) into `out`.
	// Returns the number written. Thread-safe.
	int CopyRecent(Snapshot* out, int max);

	void Clear();
}
