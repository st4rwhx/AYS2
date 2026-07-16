// CastingIntegration.cpp — Frame routing and protocol coordination
// SPDX-License-Identifier: GPL-3.0+

#include "CastingIntegration.h"
#include <iostream>
#include <sstream>

namespace AYS2::Casting {

CastingIntegration& CastingIntegration::getInstance() {
    static CastingIntegration instance;
    return instance;
}

CastingIntegration::CastingIntegration() {
}

CastingIntegration::~CastingIntegration() {
    shutdown();
}

void CastingIntegration::initialize() {
    if (isInitialized_.exchange(true)) {
        return;
    }
    
    std::cout << "[CastingIntegration] Initializing frame routing system\n";
    
    // Initialize all protocol managers
    CastingManager::getInstance().initialize();
    
#ifdef __APPLE__
    AirPlayManager::getInstance().initialize();
#endif
    
    GoogleCastManager::getInstance().initialize();
    DLNAManager::getInstance().initialize();
    WebRTCManager::getInstance().initialize();
    
    std::cout << "[CastingIntegration] All protocol managers initialized\n";
}

void CastingIntegration::shutdown() {
    if (!isInitialized_.exchange(false)) {
        return;
    }
    
    std::cout << "[CastingIntegration] Shutting down\n";
    
    CastingManager::getInstance().shutdown();
    
#ifdef __APPLE__
    AirPlayManager::getInstance().shutdown();
#endif
    
    GoogleCastManager::getInstance().shutdown();
    DLNAManager::getInstance().shutdown();
    WebRTCManager::getInstance().shutdown();
}

void CastingIntegration::submitVideoFrame(const uint8_t* h264Data, size_t size, 
                                           int64_t timestampUs, bool isKeyframe) {
    if (!isInitialized_.load()) {
        return;
    }
    
    routeVideoFrame(h264Data, size, timestampUs, isKeyframe);
}

void CastingIntegration::submitAudioFrame(const float* audioData, int sampleCount, int sampleRate) {
    if (!isInitialized_.load()) {
        return;
    }
    
    routeAudioFrame(audioData, sampleCount, sampleRate);
}

void CastingIntegration::routeVideoFrame(const uint8_t* h264Data, size_t size, 
                                          int64_t timestampUs, bool isKeyframe) {
    CastingManager& manager = CastingManager::getInstance();
    
    if (!manager.isConnected()) {
        return;  // No active casting session
    }
    
    // Get active device and protocol
    auto activeDevice = manager.getActiveCastingDevice();
    if (!activeDevice) {
        return;
    }
    
    CastingProtocol protocol = activeDevice->getSelectedProtocol();
    
    // Route to protocol-specific manager
    switch (protocol) {
        case CastingProtocol::AirPlay2:
#ifdef __APPLE__
            AirPlayManager::getInstance().submitVideoFrame(h264Data, size, timestampUs, isKeyframe);
#endif
            break;
            
        case CastingProtocol::GoogleCast:
            GoogleCastManager::getInstance().submitVideoFrame(h264Data, size, timestampUs, isKeyframe);
            break;
            
        case CastingProtocol::DLNA_UPnP:
            // DLNA doesn't use frame submission, uses HTTP streaming
            break;
            
        case CastingProtocol::WebRTC:
            WebRTCManager::getInstance().submitVideoFrame(h264Data, size, timestampUs, isKeyframe);
            break;
            
        default:
            break;
    }
}

void CastingIntegration::routeAudioFrame(const float* audioData, int sampleCount, int sampleRate) {
    CastingManager& manager = CastingManager::getInstance();
    
    if (!manager.isConnected()) {
        return;
    }
    
    auto activeDevice = manager.getActiveCastingDevice();
    if (!activeDevice) {
        return;
    }
    
    CastingProtocol protocol = activeDevice->getSelectedProtocol();
    
    switch (protocol) {
        case CastingProtocol::AirPlay2:
#ifdef __APPLE__
            AirPlayManager::getInstance().submitAudioFrame(audioData, sampleCount, sampleRate);
#endif
            break;
            
        case CastingProtocol::GoogleCast:
            GoogleCastManager::getInstance().submitAudioFrame(audioData, sampleCount, sampleRate);
            break;
            
        case CastingProtocol::DLNA_UPnP:
            // DLNA uses HTTP streaming
            break;
            
        case CastingProtocol::WebRTC:
            WebRTCManager::getInstance().submitAudioFrame(audioData, sampleCount, sampleRate);
            break;
            
        default:
            break;
    }
}

void CastingIntegration::getStatistics(std::string& outStats) {
    std::ostringstream oss;
    
    oss << "\n=== AYS2 Casting Statistics ===\n";
    
#ifdef __APPLE__
    oss << "\n[AirPlay 2]\n";
    // Would add AirPlay statistics
#endif
    
    oss << "\n[Google Cast]\n";
    oss << "  Frames sent: " << GoogleCastManager::getInstance().getFramesSent() << "\n";
    
    oss << "\n[DLNA/UPnP]\n";
    auto dlnaStats = DLNAManager::getInstance().getStats();
    oss << "  Bytes served: " << dlnaStats.bytesServed << "\n";
    oss << "  HTTP requests: " << dlnaStats.httpRequests << "\n";
    oss << "  SSDP discoveries: " << dlnaStats.ssdpDiscoveries << "\n";
    
    oss << "\n[WebRTC]\n";
    auto webrtcStats = WebRTCManager::getInstance().getStats();
    oss << "  Bytes sent: " << webrtcStats.bytesSent << "\n";
    oss << "  Frames sent: " << webrtcStats.framesSent << "\n";
    oss << "  Frames dropped: " << webrtcStats.framesDropped << "\n";
    oss << "  Latency: " << webrtcStats.latencyMs << " ms\n";
    
    outStats = oss.str();
}

} // namespace AYS2::Casting

