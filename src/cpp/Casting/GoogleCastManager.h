// GoogleCastManager.h — Google Cast SDK integration for Chromecast + Android TV
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include <memory>
#include <atomic>
#include <string>

#ifdef __APPLE__
#import <Foundation/Foundation.h>
#import <GoogleCast/GoogleCast.h>
#endif

namespace AYS2::Casting {

class GoogleCastManager {
public:
    static GoogleCastManager& getInstance();
    
    void initialize();
    void shutdown();
    
    // Device discovery for Google Cast
    void discoverDevices(CastingDeviceList& outDevices);
    
    // Connection management
    bool connect(const CastingDevicePtr& device);
    void disconnect();
    bool isConnected() const { return isConnected_.load(); }
    
    // Media streaming (H.264 video + AAC audio)
    void submitVideoFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe);
    void submitAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    // Status
    int getLatencyMs() const;
    uint32_t getFramesSent() const { return framesSent_; }
    
private:
    GoogleCastManager();
    ~GoogleCastManager();
    
    GoogleCastManager(const GoogleCastManager&) = delete;
    GoogleCastManager& operator=(const GoogleCastManager&) = delete;
    
#ifdef __APPLE__
    // GCKCastSession management
    GCKCastSession* castSession_ = nullptr;
    
    // Custom message channel for raw video/audio streaming
    GCKGenericChannel* mediaChannel_ = nullptr;
    
    // Device scanner for discovery
    GCKDeviceScanner* deviceScanner_ = nullptr;
    
    // Connection callbacks
    void setupChannels();
    void setupDeviceScanner();
#endif
    
    std::atomic<bool> isInitialized_{false};
    std::atomic<bool> isConnected_{false};
    std::atomic<uint32_t> framesSent_{0};
    
    std::string receiverAppId_;  // Google Cast app ID (custom receiver)
    std::string deviceName_;
};

} // namespace AYS2::Casting

