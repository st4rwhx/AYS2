// AirPlayFrameCapture.h — Metal frame capture for AirPlay streaming
// Uses IOSurface for zero-copy GPU access with frame pacing
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <cstdint>
#include <memory>

#ifdef __APPLE__
#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include <IOSurface/IOSurface.h>
#endif

namespace AYS2::Casting {

class AirPlayFrameCapture {
public:
    static AirPlayFrameCapture& getInstance();
    
    // Initialize frame capture (call from app startup)
    void initialize();
    void shutdown();
    
    // Capture Metal texture after rendering completes
    // Uses IOSurface for zero-copy access
    void captureRenderTarget(void* metalTexture, int width, int height, int64_t timestampUs);
    
    // Enable/disable capturing
    void setEnabled(bool enabled);
    bool isEnabled() const;
    
    // Statistics
    uint32_t getFramesCaptured() const { return framesCaptured_; }
    uint32_t getFramesDropped() const { return framesDropped_; }
    double getAverageJitterMs() const;
    
private:
    AirPlayFrameCapture();
    ~AirPlayFrameCapture();
    
    AirPlayFrameCapture(const AirPlayFrameCapture&) = delete;
    AirPlayFrameCapture& operator=(const AirPlayFrameCapture&) = delete;
    
#ifdef __APPLE__
    // Create IOSurface-backed CVPixelBuffer from Metal texture (zero-copy)
    CVPixelBufferRef createIOSurfacePixelBuffer(id<MTLTexture> texture);
#endif
    
    bool enabled_ = false;
    uint32_t framesCaptured_ = 0;
    uint32_t framesDropped_ = 0;
};

} // namespace AYS2::Casting