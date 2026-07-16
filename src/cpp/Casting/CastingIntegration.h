// CastingIntegration.h — Frame submission integration point
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingManager.h"
#include "AirPlayManager.h"
#include "GoogleCastManager.h"
#include "DLNAManager.h"
#include "WebRTCManager.h"
#include <memory>
#include <atomic>

namespace AYS2::Casting {

class CastingIntegration {
public:
    static CastingIntegration& getInstance();
    
    void initialize();
    void shutdown();
    
    // Frame submission - routes to active protocol manager
    void submitVideoFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe);
    void submitAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    // Get statistics from all protocols
    void getStatistics(std::string& outStats);
    
private:
    CastingIntegration();
    ~CastingIntegration();
    
    CastingIntegration(const CastingIntegration&) = delete;
    CastingIntegration& operator=(const CastingIntegration&) = delete;
    
    // Route frame to appropriate protocol based on active device
    void routeVideoFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe);
    void routeAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    std::atomic<bool> isInitialized_{false};
};

} // namespace AYS2::Casting

