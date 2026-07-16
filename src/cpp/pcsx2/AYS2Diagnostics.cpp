// AYS2Diagnostics.cpp — AYS2 Flight Recorder (additive).
// SPDX-License-Identifier: GPL-3.0+

#include "AYS2Diagnostics.h"
#include "PerformanceMetrics.h"

#include <atomic>
#include <chrono>
#include <mutex>

namespace
{
	std::mutex s_mutex;
	AYS2Diagnostics::Snapshot s_ring[AYS2Diagnostics::kCapacity]{};
	int s_head = 0;   // index of the next write slot
	int s_count = 0;  // number of valid entries (<= kCapacity)
	std::atomic<bool> s_enabled{false};

	// Device state pushed from the iOS layer; guarded by s_mutex.
	std::uint8_t s_dev_thermal = 0;
	float s_dev_ram_gb = -1.0f;
	int s_dev_battery = -1;
	bool s_dev_low_power = false;

	std::chrono::steady_clock::time_point s_start = std::chrono::steady_clock::now();
	bool s_started = false;
}

void AYS2Diagnostics::SetEnabled(bool enabled)
{
	s_enabled.store(enabled, std::memory_order_relaxed);
}

bool AYS2Diagnostics::IsEnabled()
{
	return s_enabled.load(std::memory_order_relaxed);
}

void AYS2Diagnostics::SetDeviceState(std::uint8_t thermal, float ram_gb, int battery, bool low_power)
{
	std::lock_guard<std::mutex> lock(s_mutex);
	s_dev_thermal = thermal;
	s_dev_ram_gb = ram_gb;
	s_dev_battery = battery;
	s_dev_low_power = low_power;
}

void AYS2Diagnostics::RecordFrame()
{
	if (!s_enabled.load(std::memory_order_relaxed))
		return;

	Snapshot s{};

	const auto now = std::chrono::steady_clock::now();
	{
		std::lock_guard<std::mutex> lock(s_mutex);
		if (!s_started)
		{
			s_start = now;
			s_started = true;
		}
		s.t_seconds = std::chrono::duration<double>(now - s_start).count();
		s.thermal = s_dev_thermal;
		s.ram_gb = s_dev_ram_gb;
		s.battery = static_cast<std::int8_t>(s_dev_battery);
		s.flags = s_dev_low_power ? 0x01 : 0x00;
	}

	s.fps = PerformanceMetrics::GetFPS();
	s.internal_fps = PerformanceMetrics::GetInternalFPS();
	s.speed = PerformanceMetrics::GetSpeed();
	s.avg_frame_ms = PerformanceMetrics::GetAverageFrameTime();
	s.min_frame_ms = PerformanceMetrics::GetMinimumFrameTime();
	s.max_frame_ms = PerformanceMetrics::GetMaximumFrameTime();
	s.ee_pct = static_cast<float>(PerformanceMetrics::GetCPUThreadUsage());
	s.gs_pct = PerformanceMetrics::GetGSThreadUsage();
	s.vu_pct = PerformanceMetrics::GetVUThreadUsage();
	s.gpu_ms = PerformanceMetrics::GetGPUAverageTime();
	s.gpu_pct = PerformanceMetrics::GetGPUUsage();

	std::lock_guard<std::mutex> lock(s_mutex);
	s_ring[s_head] = s;
	s_head = (s_head + 1) % kCapacity;
	if (s_count < kCapacity)
		s_count++;
}

int AYS2Diagnostics::CopyRecent(Snapshot* out, int max)
{
	if (!out || max <= 0)
		return 0;

	std::lock_guard<std::mutex> lock(s_mutex);
	const int n = (s_count < max) ? s_count : max;
	// Oldest of the last n, walking forward to newest.
	const int first = (s_head - n + kCapacity) % kCapacity;
	for (int i = 0; i < n; i++)
		out[i] = s_ring[(first + i) % kCapacity];
	return n;
}

void AYS2Diagnostics::Clear()
{
	std::lock_guard<std::mutex> lock(s_mutex);
	s_head = 0;
	s_count = 0;
	s_started = false;
}
