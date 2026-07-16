// FramePacingController.mm — Frame timing and synchronization implementation
// SPDX-License-Identifier: GPL-3.0+

#include "FramePacingController.h"

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#include "common/Console.h"
#include <cmath>

namespace AYS2::Casting {

FramePacingController& FramePacingController::getInstance()
{
    static FramePacingController instance;
    return instance;
}

FramePacingController::FramePacingController()
    : targetFrameRate_(60), targetFrameIntervalUs_(16667),
      lastFrameTimestampUs_(0), frameStartTimestampUs_(0),
      averageFrameTimeMs_(16.667), jitterMs_(0.0)
{
}

FramePacingController::~FramePacingController()
{
    shutdown();
}

void FramePacingController::initialize(int frameRate)
{
    if (frameRate <= 0 || frameRate > 240) {
        Console.Error("[FramePacing] Invalid frame rate: %d", frameRate);
        return;
    }
    
    targetFrameRate_ = frameRate;
    targetFrameIntervalUs_ = 1000000LL / frameRate;
    
    Console.WriteLn("[FramePacing] Initialized for %d FPS (target interval: %.2f ms)",
        frameRate, targetFrameIntervalUs_ / 1000.0);
}

void FramePacingController::shutdown()
{
    Console.WriteLn("[FramePacing] Stats - Encoded: %d, Skipped: %d, Late: %d, Jitter: %.2f ms",
        framesEncoded_.load(), framesSkipped_.load(), frameLateCount_.load(), jitterMs_);
}

void FramePacingController::onFrameStarted()
{
    frameStartTimestampUs_ = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::high_resolution_clock::now().time_since_epoch()
    ).count();
}

void FramePacingController::onFrameCompleted()
{
    int64_t now = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::high_resolution_clock::now().time_since_epoch()
    ).count();
    
    // Calculate actual frame time
    if (lastFrameTimestampUs_ > 0) {
        int64_t actualIntervalUs = now - lastFrameTimestampUs_;
        double actualIntervalMs = actualIntervalUs / 1000.0;
        
        // Update exponential moving average for frame time
        averageFrameTimeMs_ = (1.0 - JITTER_ALPHA) * averageFrameTimeMs_ +
                            JITTER_ALPHA * actualIntervalMs;
        
        // Calculate deviation from target
        double deviationMs = std::abs(actualIntervalMs - (targetFrameIntervalUs_ / 1000.0));
        
        // Update jitter (EMA of deviation)
        jitterMs_ = (1.0 - JITTER_ALPHA) * jitterMs_ + JITTER_ALPHA * deviationMs;
        
        // Check for frame timing issues
        if (actualIntervalUs > targetFrameIntervalUs_ * 1.5) {
            // Frame took >1.5x normal time (late frame)
            frameLateCount_++;
            Console.Warning("[FramePacing] Late frame: %.2f ms (target: %.2f ms)",
                actualIntervalMs, targetFrameIntervalUs_ / 1000.0);
        }
    }
    
    lastFrameTimestampUs_ = now;
    framesEncoded_++;
}

int64_t FramePacingController::getCurrentFrameTimestampUs() const
{
    // Use CMClock for precise media-synchronized timing
    // Research: CMClockGetHostTimeClock() provides monotonic time suitable for A/V sync
    // Better than mach_absolute_time() because it's already in media timebase
    @autoreleasepool {
        CMClockRef hostClock = CMClockGetHostTimeClock();
        CMTime now = CMClockGetTime(hostClock);
        
        // Convert CMTime to microseconds with high precision
        // CMTime is already in correct timebase for audio/video synchronization
        return (int64_t)(CMTimeGetSeconds(now) * 1000000.0);
    }
}

bool FramePacingController::shouldSkipFrame() const
{
    // Skip frames if encoder is falling behind (adaptive)
    // In a real system, this would check encoder queue depth
    // For now, we never skip unless explicitly needed
    return false;
}

double FramePacingController::getAverageFrameTimeMs() const
{
    return averageFrameTimeMs_;
}

double FramePacingController::getFrameJitterMs() const
{
    return jitterMs_;
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

FramePacingController& FramePacingController::getInstance()
{
    static FramePacingController instance;
    return instance;
}

FramePacingController::FramePacingController() { }
FramePacingController::~FramePacingController() { }
void FramePacingController::initialize(int) { }
void FramePacingController::shutdown() { }
void FramePacingController::onFrameStarted() { }
void FramePacingController::onFrameCompleted() { }
int64_t FramePacingController::getCurrentFrameTimestampUs() const { return 0; }
bool FramePacingController::shouldSkipFrame() const { return false; }
double FramePacingController::getAverageFrameTimeMs() const { return 0.0; }
double FramePacingController::getFrameJitterMs() const { return 0.0; }

} // namespace AYS2::Casting

#endif
