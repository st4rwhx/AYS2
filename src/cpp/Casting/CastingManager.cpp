// CastingManager.cpp — Unified casting system implementation
// SPDX-License-Identifier: GPL-3.0+

#include "CastingManager.h"
#include "AirPlayFrameCapture.h"
#include "GoogleCastManager.h"
#include "DLNAManager.h"
#include "WebRTCManager.h"
#include "common/Console.h"
#include <algorithm>
#include <chrono>

namespace AYS2::Casting {

CastingManager& CastingManager::getInstance()
{
    static CastingManager instance;
    return instance;
}

CastingManager::CastingManager()
    : airplayManager_(nullptr), googlecastManager_(nullptr), 
      dlnaManager_(nullptr), webrtcManager_(nullptr)
{
}

CastingManager::~CastingManager()
{
    shutdown();
}

void CastingManager::initialize()
{
    if (isInitialized_.load())
        return;
    
    Console.WriteLn("[Casting] Initializing casting system...");
    
#ifdef __APPLE__
    // Initialize frame capture for Metal rendering
    AirPlayFrameCapture::getInstance().initialize();
#endif
    
    isInitialized_ = true;
    
    // Initialize protocol managers lazily when needed
    // Protocol managers will be created on first use
}

void CastingManager::shutdown()
{
    if (!isInitialized_.load())
        return;
    
    Console.WriteLn("[Casting] Shutting down casting system...");
    
    stopDeviceDiscovery();
    stopCasting();
    
    isInitialized_ = false;
}

void CastingManager::startDeviceDiscovery()
{
    if (isDiscovering_.load()) {
        Console.Warning("[Casting] Device discovery already in progress");
        return;
    }
    
    Console.WriteLn("[Casting] Starting device discovery...");
    isDiscovering_ = true;
    shouldStopDiscovery_ = false;
    
    discoveryThread_ = std::thread(&CastingManager::discoveryThreadFunc, this);
}

void CastingManager::stopDeviceDiscovery()
{
    if (!isDiscovering_.load())
        return;
    
    Console.WriteLn("[Casting] Stopping device discovery...");
    shouldStopDiscovery_ = true;
    isDiscovering_ = false;
    
    if (discoveryThread_.joinable())
        discoveryThread_.join();
}

void CastingManager::discoveryThreadFunc()
{
    while (!shouldStopDiscovery_.load()) {
        try {
            // Tier 1: Fast discovery methods (native APIs)
#ifdef __APPLE__
            discoverAirPlay2Devices();
            discoverNetworkFrameworkDevices();
#endif
            
            // Tier 2: Cross-platform discovery
            discoverGoogleCastDevices();
            discoverDLNADevices();
            
            // Tier 3: Universal fallback
            discoverWebRTCReceivers();
            
            // Update device availability
            updateDeviceAvailability();
            
            // Notify about discovered devices
            {
                std::lock_guard<std::mutex> lock(devicesMutex_);
                if (onDeviceDiscovery_)
                    onDeviceDiscovery_(discoveredDevices_);
            }
        }
        catch (const std::exception& e) {
            Console.Error("[Casting] Exception during device discovery: %s", e.what());
        }
        
        // Wait before next discovery round (2 seconds)
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
}

const CastingDeviceList& CastingManager::getDiscoveredDevices() const
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    return discoveredDevices_;
}

CastingDevicePtr CastingManager::getDeviceById(const std::string& id) const
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    
    auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
        [&id](const CastingDevicePtr& dev) { return dev->getId() == id; });
    
    return (it != discoveredDevices_.end()) ? *it : nullptr;
}

CastingDevicePtr CastingManager::getDeviceByName(const std::string& name) const
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    
    auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
        [&name](const CastingDevicePtr& dev) { return dev->getName() == name; });
    
    return (it != discoveredDevices_.end()) ? *it : nullptr;
}

void CastingManager::addDiscoveredDevice(const CastingDevicePtr& device)
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    
    // Check if device already exists
    auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
        [device](const CastingDevicePtr& dev) { return dev->getId() == device->getId(); });
    
    if (it == discoveredDevices_.end()) {
        discoveredDevices_.push_back(device);
        Console.WriteLn("[Casting] Added device: %s (%s)", 
            device->getName().c_str(), device->getProtocolString().c_str());
    }
}

void CastingManager::removeDiscoveredDevice(const std::string& deviceId)
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    
    auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
        [&deviceId](const CastingDevicePtr& dev) { return dev->getId() == deviceId; });
    
    if (it != discoveredDevices_.end()) {
        Console.WriteLn("[Casting] Removed device: %s", (*it)->getName().c_str());
        discoveredDevices_.erase(it);
    }
}

CastingProtocol CastingManager::selectBestProtocol(const CastingDevicePtr& device) const
{
    if (!device)
        return CastingProtocol::Unknown;
    
    const auto& protocols = device->getInfo().supportedProtocols;
    
    // Tier 1: Fastest protocols (<40ms)
    if (std::find(protocols.begin(), protocols.end(), CastingProtocol::AirPlay2) != protocols.end())
        return CastingProtocol::AirPlay2;
    
    if (std::find(protocols.begin(), protocols.end(), CastingProtocol::NetworkFramework) != protocols.end())
        return CastingProtocol::NetworkFramework;
    
    // Tier 2: Good protocols (80-120ms)
    if (std::find(protocols.begin(), protocols.end(), CastingProtocol::GoogleCast) != protocols.end())
        return CastingProtocol::GoogleCast;
    
    // Tier 3: Acceptable protocols (<500ms)
    if (std::find(protocols.begin(), protocols.end(), CastingProtocol::WebRTC) != protocols.end())
        return CastingProtocol::WebRTC;
    
    // Tier 4: Slow protocols (legacy only)
    if (std::find(protocols.begin(), protocols.end(), CastingProtocol::DLNA_UPnP) != protocols.end())
        return CastingProtocol::DLNA_UPnP;
    
    return CastingProtocol::Unknown;
}

bool CastingManager::startCasting(const CastingDevicePtr& device)
{
    if (!device) {
        Console.Error("[Casting] Cannot start casting: device is null");
        return false;
    }
    
    std::lock_guard<std::mutex> lock(activeCastingMutex_);
    
    if (activeCastingDevice_) {
        Console.Warning("[Casting] Already casting to device: %s", activeCastingDevice_->getName().c_str());
        return false;
    }
    
    Console.WriteLn("[Casting] Starting cast to device: %s", device->getName().c_str());
    
    // Select best protocol automatically
    CastingProtocol protocol = selectBestProtocol(device);
    if (protocol == CastingProtocol::Unknown) {
        Console.Error("[Casting] Device supports no casting protocols");
        if (onConnectionStatus_)
            onConnectionStatus_(device, CastingState::Error, "No supported protocols");
        return false;
    }
    
    device->setProtocol(protocol);
    device->setState(CastingState::Connecting);
    
    if (onConnectionStatus_)
        onConnectionStatus_(device, CastingState::Connecting, "");
    
    // Establish connection based on protocol
    if (establishConnection(device)) {
        activeCastingDevice_ = device;
        device->setState(CastingState::Connected);
        
        // Enable frame capture for Metal rendering
        AirPlayFrameCapture::getInstance().setEnabled(true);
        
        if (onConnectionStatus_)
            onConnectionStatus_(device, CastingState::Connected, "");
        
        Console.WriteLn("[Casting] Successfully connected to: %s", device->getName().c_str());
        return true;
    } else {
        device->setState(CastingState::Error);
        
        if (onConnectionStatus_)
            onConnectionStatus_(device, CastingState::Error, "Failed to establish connection");
        
        Console.Error("[Casting] Failed to connect to device: %s", device->getName().c_str());
        return false;
    }
}

void CastingManager::stopCasting()
{
    std::lock_guard<std::mutex> lock(activeCastingMutex_);
    
    if (!activeCastingDevice_) {
        Console.Warning("[Casting] No active casting session");
        return;
    }
    
    Console.WriteLn("[Casting] Stopping cast from device: %s", activeCastingDevice_->getName().c_str());
    
    // Disable frame capture when stopping casting
    AirPlayFrameCapture::getInstance().setEnabled(false);
    
    terminateConnection();
    
    activeCastingDevice_->setState(CastingState::Disconnecting);
    if (onConnectionStatus_)
        onConnectionStatus_(activeCastingDevice_, CastingState::Disconnecting, "");
    
    activeCastingDevice_ = nullptr;
}

void CastingManager::submitVideoFrame(const uint8_t* frameData, int width, int height, int64_t timestampUs)
{
    std::lock_guard<std::mutex> lock(activeCastingMutex_);
    
    if (!activeCastingDevice_ || !isConnected())
        return;
    
    // Route to appropriate protocol handler based on active device's protocol
    // Implementation in protocol-specific managers
}

void CastingManager::submitAudioFrame(const float* audioData, int sampleCount, int sampleRate)
{
    std::lock_guard<std::mutex> lock(activeCastingMutex_);
    
    if (!activeCastingDevice_ || !isConnected())
        return;
    
    // Route to appropriate protocol handler
}

int CastingManager::getEstimatedLatencyMs() const
{
    std::lock_guard<std::mutex> lock(activeCastingMutex_);
    
    if (!activeCastingDevice_)
        return 0;
    
    return activeCastingDevice_->getInfo().estimatedLatencyMs;
}

// Placeholder implementations for discovery methods
// These will be filled in by protocol-specific managers

void CastingManager::discoverAirPlay2Devices()
{
    // Implementation will use AVAudioSession routing APIs
}

void CastingManager::discoverNetworkFrameworkDevices()
{
    // Implementation will use Network.framework DeviceDiscoveryUI
}

void CastingManager::discoverGoogleCastDevices()
{
#ifdef __APPLE__
    GoogleCastManager& googleCast = GoogleCastManager::getInstance();
    CastingDeviceList googleCastDevices;
    googleCast.discoverDevices(googleCastDevices);
    
    std::lock_guard<std::mutex> lock(devicesMutex_);
    discoveredDevices_.insert(discoveredDevices_.end(),
        googleCastDevices.begin(), googleCastDevices.end());
#endif
}

void CastingManager::discoverDLNADevices()
{
    // Initialize DLNA manager if needed
    DLNAManager& dlna = DLNAManager::getInstance();
    dlna.initialize();
    
    CastingDeviceList dlnaDevices;
    dlna.discoverDevices(dlnaDevices);
    
    std::lock_guard<std::mutex> lock(devicesMutex_);
    for (const auto& device : dlnaDevices) {
        auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
            [device](const CastingDevicePtr& dev) { return dev->getId() == device->getId(); });
        
        if (it == discoveredDevices_.end()) {
            discoveredDevices_.push_back(device);
            Console.WriteLn("[Casting] Discovered DLNA device: %s", device->getName().c_str());
        }
    }
}

void CastingManager::discoverWebRTCReceivers()
{
    // Initialize WebRTC manager if needed
    WebRTCManager& webrtc = WebRTCManager::getInstance();
    webrtc.initialize();
    
    CastingDeviceList webrtcDevices;
    webrtc.discoverDevices(webrtcDevices);
    
    std::lock_guard<std::mutex> lock(devicesMutex_);
    for (const auto& device : webrtcDevices) {
        auto it = std::find_if(discoveredDevices_.begin(), discoveredDevices_.end(),
            [device](const CastingDevicePtr& dev) { return dev->getId() == device->getId(); });
        
        if (it == discoveredDevices_.end()) {
            discoveredDevices_.push_back(device);
            Console.WriteLn("[Casting] Discovered WebRTC receiver: %s (%s)", 
                device->getName().c_str(), device->getReceiverURL().c_str());
        }
    }
}

void CastingManager::updateDeviceAvailability()
{
    std::lock_guard<std::mutex> lock(devicesMutex_);
    
    // Check each device for availability (ping, etc.)
    for (auto& device : discoveredDevices_) {
        // TODO: Implement availability check
    }
}

bool CastingManager::establishConnection(const CastingDevicePtr& device)
{
    // TODO: Implement protocol-specific connection logic
    return true;
}

void CastingManager::terminateConnection()
{
    // TODO: Implement protocol-specific disconnection logic
}

} // namespace AYS2::Casting
