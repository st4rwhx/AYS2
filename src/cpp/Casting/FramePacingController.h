// FramePacingController.h — Frame timing and synchronization for real-time encoding
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <cstdint>
#include <atomic>
#include <queue>
#include <mutex>
#include <chrono>

#ifdef __APPLE__
#include <CoreVideo/CoreVideo.h>
#endif

namespace AYS2::Casting {

class FramePacingController {
public:
    static FramePacingController& getInstance();
    
    // Initialize with target frame rate
    void initialize(int frameRate = 60);
    void shutdown();
    
    // Frame timing management
    void onFrameStarted();  // Called when game frame rendering starts
    void onFrameCompleted(); // Called when game frame rendering completes (EndPresent)
    
    // Get accurate timestamp for frame (synchronized to display)
    int64_t getCurrentFrameTimestampUs() const;
    
    // Check if we should skip frame (for adaptive bitrate)
    bool shouldSkipFrame() const;
    
    // Statistics
    double getAverageFrameTimeMs() const;
    double getFrameJitterMs() const;  // Standard deviation of frame timing
    int getFramesSkipped() const { return framesSkipped_; }
    int getFramesEncoded() const { return framesEncoded_; }
    
private:
    FramePacingController();
    ~FramePacingController();
    
    FramePacingController(const FramePacingController&) = delete;
    FramePacingController& operator=(const FramePacingController&) = delete;
    
    int targetFrameRate_ = 60;
    int64_t targetFrameIntervalUs_ = 16667;  // ~16.67ms @ 60fps
    int64_t lastFrameTimestampUs_ = 0;
    int64_t frameStartTimestampUs_ = 0;
    
    // Jitter tracking (exponential moving average)
    double averageFrameTimeMs_ = 0.0;
    double jitterMs_ = 0.0;
    static constexpr double JITTER_ALPHA = 0.1;  // EMA smoothing
    
    // Frame skipping stats
    std::atomic<int> framesSkipped_{0};
    std::atomic<int> framesEncoded_{0};
    std::atomic<int> frameLateCount_{0};
};

} // namespace AYS2::Casting

