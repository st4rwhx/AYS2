// AirPlayManager.h — AirPlay 2 video + audio streaming for Apple TV
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include "AirPlayProtocol.h"
#include "VideoEncoder.h"
#include "AirPlayNetworkTransport.h"
#include <memory>
#include <atomic>

#ifdef __APPLE__
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <Network/Network.h>
#endif

namespace AYS2::Casting {

class AirPlayManager {
public:
    static AirPlayManager& getInstance();
    
    void initialize();
    void shutdown();
    
    // Device discovery for AirPlay 2 compatible devices
    void discoverDevices(CastingDeviceList& outDevices);
    
    // Connection management
    bool connect(const CastingDevicePtr& device);
    void disconnect();
    bool isConnected() const { return isConnected_.load(); }
    
    // Video submission
    void submitVideoFrame(const uint8_t* frameData, int width, int height, int64_t timestampUs);
    
    // Audio submission
    void submitAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    // Status
    int getLatencyMs() const;
    
private:
    AirPlayManager();
    ~AirPlayManager();
    
    AirPlayManager(const AirPlayManager&) = delete;
    AirPlayManager& operator=(const AirPlayManager&) = delete;
    
#ifdef __APPLE__
    // Metal rendering and capture
    void captureGameRenderTarget();
    void encodeVideoFrame();
    
    // Encoded frame output callback (static for VideoToolbox)
    static void encodeCallbackHandler(void* refcon, VTEncodeInfoFlags infoFlags,
                                     CMSampleBufferRef sampleBuffer);
    void handleEncodedFrame(CMSampleBufferRef sampleBuffer);
    
    // Frame transmission
    void transmitEncodedFrame(const AirPlayFramePtr& frame);
    
    // Core properties
    AVAudioSession* audioSession_;
    VTCompressionSessionRef compressionSession_;
    nw_connection_t airplayConnection_;
    
    // AirPlay 2 protocol handler
    std::shared_ptr<AirPlayProtocol> protocol_;
    
    // Video encoder (H.264 via VideoToolbox)
    std::shared_ptr<VideoEncoder> videoEncoder_;
    
    // Network transport (RTP/UDP over Network Framework)
    std::shared_ptr<AirPlayNetworkTransport> networkTransport_;
#endif
    
    std::atomic<bool> isInitialized_{false};
    std::atomic<bool> isConnected_{false};
    
    // Video encoding state
    int frameWidth_;
    int frameHeight_;
    int frameRate_;
};

} // namespace AYS2::Casting
