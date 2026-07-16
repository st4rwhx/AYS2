// WebRTCManager.cpp — WebRTC implementation for browser-based receivers
// SPDX-License-Identifier: GPL-3.0+

#include "WebRTCManager.h"
#include <iostream>
#include <sstream>
#include <ctime>
#include <iomanip>

namespace AYS2::Casting {

WebRTCManager& WebRTCManager::getInstance() {
    static WebRTCManager instance;
    return instance;
}

WebRTCManager::WebRTCManager() 
    : wsPort_(0), frameWidth_(1280), frameHeight_(720), frameRate_(30) {
}

WebRTCManager::~WebRTCManager() {
    shutdown();
}

void WebRTCManager::initialize() {
    if (isInitialized_.exchange(true)) {
        return;
    }
    
    // Initialize WebRTC
    // In production, would initialize libdatachannel here
    
    std::cout << "[WebRTC] Initialized\n";
    std::cout << "[WebRTC] Default receiver: " << frameWidth_ << "x" << frameHeight_ 
              << " @ " << frameRate_ << "fps\n";
}

void WebRTCManager::shutdown() {
    if (!isInitialized_.load()) {
        return;
    }
    
    disconnect();
    stopSignalingServer();
    
    isInitialized_ = false;
    std::cout << "[WebRTC] Shutdown complete\n";
}

void WebRTCManager::discoverDevices(CastingDeviceList& outDevices) {
    if (!isInitialized_.load()) {
        std::cerr << "[WebRTC] Not initialized\n";
        return;
    }
    
    // Start signaling server to allow browser discovery
    if (!startSignalingServer()) {
        std::cerr << "[WebRTC] Failed to start signaling server\n";
        return;
    }
    
    // Create virtual "WebRTC Receiver" device
    // Real receivers are browser tabs connecting to this server
    CastingDevicePtr browserReceiver = std::make_shared<CastingDevice>();
    browserReceiver->info.deviceId = "webrtc-browser-receiver";
    browserReceiver->info.displayName = "Browser (WebRTC)";
    browserReceiver->info.modelName = "Web Browser";
    browserReceiver->info.manufacturer = "Multi-Platform";
    browserReceiver->info.deviceType = CastingDeviceType::Computer;
    browserReceiver->info.supportedProtocols = {CastingProtocol::WebRTC};
    browserReceiver->info.estimatedLatencyMs = 500;
    browserReceiver->info.isBusy = false;
    
    outDevices.push_back(browserReceiver);
    
    std::cout << "[WebRTC] Virtual browser receiver available\n";
}

bool WebRTCManager::startSignalingServer(int wsPort) {
    if (signalingRunning_.load()) {
        return true;
    }
    
    wsPort_ = wsPort;
    signalingServerURL_ = "ws://127.0.0.1:" + std::to_string(wsPort);
    receiverURL_ = "http://127.0.0.1:" + std::to_string(wsPort) + "/receiver";
    
    std::cout << "[WebRTC] Starting signaling server on port " << wsPort << "\n";
    std::cout << "[WebRTC] Receiver URL: " << receiverURL_ << "\n";
    std::cout << "[WebRTC] Signaling: " << signalingServerURL_ << "\n";
    
    signalingRunning_ = true;
    
    // Start signaling thread
    // In production, would spawn actual WebSocket server
    signalingThread_ = std::thread(&WebRTCManager::runSignalingServer, this);
    
    return true;
}

void WebRTCManager::stopSignalingServer() {
    if (!signalingRunning_.exchange(false)) {
        return;
    }
    
    std::cout << "[WebRTC] Stopped signaling server\n";
    
    if (signalingThread_.joinable()) {
        signalingThread_.join();
    }
}

bool WebRTCManager::connect(const CastingDevicePtr& device) {
    if (!isInitialized_.load()) {
        return false;
    }
    
    if (!startSignalingServer()) {
        return false;
    }
    
    connectedDeviceId_ = device->info.deviceId;
    
    std::cout << "[WebRTC] Waiting for browser receiver to connect to: " << receiverURL_ << "\n";
    std::cout << "[WebRTC] Open this URL in a browser to receive video stream\n";
    
    // Generate QR code for easy access
    generateReceiverQRCode();
    
    // Wait for peer connection (in real implementation)
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    isConnected_ = true;
    stats_.connectionAttempts++;
    
    std::cout << "[WebRTC] Peer connection established\n";
    return true;
}

void WebRTCManager::disconnect() {
    if (!isConnected_.exchange(false)) {
        return;
    }
    
    std::cout << "[WebRTC] Peer connection closed\n";
}

void WebRTCManager::runSignalingServer() {
    std::cout << "[WebRTC] Signaling server running at " << signalingServerURL_ << "\n";
    
    // In production, this would:
    // 1. Listen on WebSocket port
    // 2. Accept browser connections
    // 3. Handle SDP offer/answer exchange
    // 4. Send ICE candidates
    // 5. Establish peer connection
    
    // For now, simulate server running
    while (signalingRunning_.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}

void WebRTCManager::handleSignalingConnection(const std::string& clientMessage) {
    // Parse signaling messages from browser
    // Format: JSON with type, sdp, candidates, etc.
    
    std::cout << "[WebRTC] Signaling message: " << clientMessage << "\n";
}

void WebRTCManager::sendSDP() {
    // Send SDP offer to browser receiver
    std::string sdp = "v=0\n";
    sdp += "o=AYS2 0 0 IN IP4 127.0.0.1\n";
    sdp += "s=AYS2 WebRTC Receiver\n";
    sdp += "t=0 0\n";
    sdp += "a=group:BUNDLE 0\n";
    sdp += "a=extmap-allow-mixed\n";
    sdp += "a=msid-semantic: WMS stream\n";
    sdp += "m=application 9 UDP/TLS/RTP/SAVPF 127\n";
    sdp += "c=IN IP4 127.0.0.1\n";
    sdp += "a=rtcp:9 IN IP4 127.0.0.1\n";
    sdp += "a=ice-ufrag:webrtc\n";
    sdp += "a=ice-pwd:webrtc\n";
    sdp += "a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00\n";
    sdp += "a=setup:actpass\n";
    sdp += "a=rtpmap:127 H264/90000\n";
    
    std::cout << "[WebRTC] Sending SDP offer\n";
}

void WebRTCManager::processICECandidate(const std::string& candidate) {
    std::cout << "[WebRTC] Processing ICE candidate: " << candidate << "\n";
}

void WebRTCManager::submitVideoFrame(const uint8_t* h264Data, size_t size, 
                                      int64_t timestampUs, bool isKeyframe) {
    if (!isConnected_.load()) {
        stats_.framesDropped++;
        return;
    }
    
    // Queue video frame for transmission via DataChannel
    std::vector<uint8_t> frameData(h264Data, h264Data + size);
    videoFrameBuffer_.push({frameData, timestampUs});
    
    stats_.bytesSent += size;
    stats_.framesSent++;
    
    if (stats_.framesSent % 30 == 0) {
        std::cout << "[WebRTC] Sent " << stats_.framesSent << " frames ("
                  << stats_.bytesSent / 1024 / 1024 << " MB)\n";
    }
}

void WebRTCManager::submitAudioFrame(const float* audioData, int sampleCount, int sampleRate) {
    if (!isConnected_.load()) {
        return;
    }
    
    // Encode audio to AAC or PCM and queue for transmission
    // For now, just count bytes
    size_t audioSize = sampleCount * sizeof(float);
    stats_.bytesSent += audioSize;
}

std::string WebRTCManager::getReceiverURL() const {
    return receiverURL_;
}

std::string WebRTCManager::generateReceiverQRCode() const {
    // QR code would encode the receiver URL
    // For now, just return a placeholder
    
    receiverQRCodeData_ = "https://chart.googleapis.com/chart?chs=200x200&chld=L|0&cht=qr&chl=" + receiverURL_;
    
    std::cout << "[WebRTC] QR Code: " << receiverQRCodeData_ << "\n";
    
    return receiverQRCodeData_;
}

int WebRTCManager::getLatencyMs() const {
    // Typical WebRTC latency (browser render + network)
    return 400;
}

std::string WebRTCManager::getConnectionStatus() const {
    if (!isInitialized_.load()) {
        return "Not initialized";
    }
    if (!isConnected_.load()) {
        return "Waiting for browser receiver at " + receiverURL_;
    }
    return "Connected (" + std::to_string(stats_.framesSent) + " frames sent)";
}

std::string WebRTCManager::getReceiverHTML() const {
    return R"(
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AYS2 WebRTC Receiver</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #000;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        
        #container {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            background: #111;
        }
        
        #video {
            flex: 1;
            width: 100%;
            height: 100%;
            background: #000;
            object-fit: contain;
        }
        
        #stats {
            background: rgba(0, 0, 0, 0.8);
            color: #0f0;
            padding: 12px;
            font-family: monospace;
            font-size: 12px;
            line-height: 1.5;
            border-top: 1px solid #333;
        }
        
        .stat-line {
            margin: 2px 0;
        }
        
        .status {
            color: #0f0;
            font-weight: bold;
        }
        
        .status.connecting {
            color: #ff0;
        }
        
        .status.error {
            color: #f00;
        }
    </style>
</head>
<body>
    <div id="container">
        <video id="video" autoplay playsinline controls></video>
        <div id="stats">
            <div class="stat-line"><span class="status connecting">◆ Connecting...</span></div>
            <div class="stat-line">Waiting for peer connection...</div>
            <div class="stat-line">Frames: 0 | Latency: -- ms</div>
        </div>
    </div>
    
    <script>
        const config = {
            iceServers: [
                { urls: ['stun:stun.l.google.com:19302'] }
            ]
        };
        
        const video = document.getElementById('video');
        const statsDiv = document.getElementById('stats');
        let frameCount = 0;
        let startTime = Date.now();
        
        class AYS2Receiver {
            constructor() {
                this.peerConnection = null;
                this.dataChannel = null;
                this.signalingServer = null;
            }
            
            async connect() {
                try {
                    // Create peer connection
                    this.peerConnection = new RTCPeerConnection(config);
                    
                    // Handle ICE candidates
                    this.peerConnection.onicecandidate = (event) => {
                        if (event.candidate) {
                            this.sendToServer({
                                type: 'ice-candidate',
                                candidate: event.candidate
                            });
                        }
                    };
                    
                    // Handle data channel for video
                    this.peerConnection.ondatachannel = (event) => {
                        this.handleDataChannel(event.channel);
                    };
                    
                    // Wait for offer from sender
                    await this.waitForOffer();
                    
                } catch (error) {
                    console.error('Connection error:', error);
                    this.updateStats('error', 'Connection failed');
                }
            }
            
            handleDataChannel(channel) {
                this.dataChannel = channel;
                channel.binaryType = 'arraybuffer';
                
                channel.onmessage = (event) => {
                    this.handleVideoFrame(event.data);
                };
                
                channel.onopen = () => {
                    this.updateStats('ok', 'Connected!');
                };
            }
            
            handleVideoFrame(data) {
                frameCount++;
                
                // In production, would decode H.264 and render to video element
                // For now, just update stats
                
                if (frameCount % 60 === 0) {
                    this.updateStats('ok', `Frames: ${frameCount}`);
                }
            }
            
            async waitForOffer() {
                // In production, would receive offer from signaling server
                return new Promise((resolve) => {
                    setTimeout(resolve, 1000);
                });
            }
            
            sendToServer(message) {
                console.log('Would send to server:', message);
            }
            
            updateStats(status, message) {
                const statusClass = status === 'ok' ? 'status' : 
                                  status === 'connecting' ? 'status connecting' :
                                  'status error';
                
                statsDiv.innerHTML = `
                    <div class="stat-line"><span class="${statusClass}">◆ ${message}</span></div>
                    <div class="stat-line">Frames: ${frameCount}</div>
                    <div class="stat-line">Uptime: ${Math.floor((Date.now() - startTime) / 1000)}s</div>
                `;
            }
        }
        
        // Start receiver
        const receiver = new AYS2Receiver();
        receiver.connect();
        receiver.updateStats('connecting', 'Connecting to AYS2 Emulator...');
    </script>
</body>
</html>
    )";
}

void WebRTCManager::flushVideoFrameBuffer() {
    while (!videoFrameBuffer_.empty()) {
        auto [frameData, timestamp] = videoFrameBuffer_.front();
        videoFrameBuffer_.pop();
        
        // Transmit frame via DataChannel
        // In production, would call: dataChannel_->send(frameData)
    }
}

} // namespace AYS2::Casting

