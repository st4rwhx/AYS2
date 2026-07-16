// WebRTCManager.h — WebRTC universal fallback casting to browser receivers
// SPDX-License-Identifier: GPL-3.0+
//
// Provides WebRTC peer-to-peer connection to browser-based receivers
// for Mac, Windows, Linux, iOS Safari browsers.
//
// WebRTC Latency: <500ms (acceptable for demos/slideshows, not gaming)
// Protocol: WebRTC DataChannel + MediaStream API
// Receiver: HTML5 + WebRTC JS (auto-hosted on local network)

#pragma once

#include "CastingDevice.h"
#include <memory>
#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <queue>

namespace AYS2::Casting {

struct WebRTCStats {
    uint64_t bytesSent = 0;
    uint64_t bytesReceived = 0;
    uint32_t framesSent = 0;
    uint32_t framesDropped = 0;
    uint32_t connectionAttempts = 0;
    float latencyMs = 0.0f;
    float jitterMs = 0.0f;
    std::string iceConnectionState;
};

class WebRTCManager {
public:
    static WebRTCManager& getInstance();
    
    // Lifecycle
    void initialize();
    void shutdown();
    
    // Discovery of local WebRTC signaling servers
    void discoverDevices(CastingDeviceList& outDevices);
    
    // Start local signaling/STUN server (for browser discovery)
    bool startSignalingServer(int wsPort = 8081);
    void stopSignalingServer();
    bool isSignalingServerRunning() const { return signalingRunning_.load(); }
    
    // Connection management
    bool connect(const CastingDevicePtr& device);
    void disconnect();
    bool isConnected() const { return isConnected_.load(); }
    
    // Media streaming via DataChannel
    void submitVideoFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe);
    void submitAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    // Generate receiver URL + QR code
    std::string getReceiverURL() const;
    std::string generateReceiverQRCode() const;
    
    // Status
    int getLatencyMs() const;
    std::string getConnectionStatus() const;
    WebRTCStats getStats() const { return stats_; }
    
    // Get receiver HTML for serving
    std::string getReceiverHTML() const;
    
private:
    WebRTCManager();
    ~WebRTCManager();
    
    WebRTCManager(const WebRTCManager&) = delete;
    WebRTCManager& operator=(const WebRTCManager&) = delete;
    
    // Signaling server (WebSocket for SDP + ICE)
    void runSignalingServer();
    void handleSignalingConnection(const std::string& clientMessage);
    void sendSDP();
    void processICECandidate(const std::string& candidate);
    
    // Receiver page generation
    std::string generateReceiverHTML() const;
    
    // Frame buffering for WebRTC DataChannel streaming
    void flushVideoFrameBuffer();
    
    std::atomic<bool> isInitialized_{false};
    std::atomic<bool> isConnected_{false};
    std::atomic<bool> signalingRunning_{false};
    
    // Signaling server state
    int wsPort_ = 0;
    std::thread signalingThread_;
    std::string signalingServerURL_;
    
    // Receiver state
    std::string receiverURL_;
    std::string receiverQRCodeData_;
    
    // Video encoding params
    int frameWidth_ = 1280;
    int frameHeight_ = 720;
    int frameRate_ = 30;
    
    // Frame buffering
    std::queue<std::pair<std::vector<uint8_t>, int64_t>> videoFrameBuffer_;
    
    // Statistics
    WebRTCStats stats_;
    
    // Connected device info
    std::string connectedDeviceId_;
};

} // namespace AYS2::Casting

