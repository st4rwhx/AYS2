// CastingManager.h — Unified casting system for all platforms
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include <functional>
#include <memory>
#include <thread>
#include <atomic>
#include <mutex>

namespace AYS2::Casting {

using DeviceDiscoveryCallback = std::function<void(const CastingDeviceList& devices)>;
using ConnectionStatusCallback = std::function<void(CastingDevicePtr device, CastingState newState, const std::string& errorMessage)>;

class CastingManager {
public:
    static CastingManager& getInstance();
    
    // Lifecycle
    void initialize();
    void shutdown();
    
    // Device Discovery
    void startDeviceDiscovery();
    void stopDeviceDiscovery();
    bool isDiscovering() const { return isDiscovering_.load(); }
    
    // Device queries
    const CastingDeviceList& getDiscoveredDevices() const;
    CastingDevicePtr getDeviceById(const std::string& id) const;
    CastingDevicePtr getDeviceByName(const std::string& name) const;
    
    // Casting operations
    bool startCasting(const CastingDevicePtr& device);
    void stopCasting();
    bool isCasting() const { return activeCastingDevice_ != nullptr; }
    CastingDevicePtr getActiveCastingDevice() const { return activeCastingDevice_; }
    
    // Callbacks
    void setDeviceDiscoveryCallback(DeviceDiscoveryCallback callback) { onDeviceDiscovery_ = callback; }
    void setConnectionStatusCallback(ConnectionStatusCallback callback) { onConnectionStatus_ = callback; }
    
    // Video frame submission
    void submitVideoFrame(const uint8_t* frameData, int width, int height, int64_t timestampUs);
    
    // Audio submission
    void submitAudioFrame(const float* audioData, int sampleCount, int sampleRate);
    
    // Protocol selection
    CastingProtocol selectBestProtocol(const CastingDevicePtr& device) const;
    
    // State queries
    int getEstimatedLatencyMs() const;
    bool isConnected() const { return activeCastingDevice_ != nullptr && 
                                      activeCastingDevice_->getState() == CastingState::Connected; }
    
private:
    CastingManager();
    ~CastingManager();
    
    CastingManager(const CastingManager&) = delete;
    CastingManager& operator=(const CastingManager&) = delete;
    
    // Discovery backends
    void discoverAirPlay2Devices();
    void discoverNetworkFrameworkDevices();
    void discoverGoogleCastDevices();
    void discoverDLNADevices();
    void discoverWebRTCReceivers();
    
    // Device management
    void addDiscoveredDevice(const CastingDevicePtr& device);
    void removeDiscoveredDevice(const std::string& deviceId);
    void updateDeviceAvailability();
    
    // Connection management
    bool establishConnection(const CastingDevicePtr& device);
    void terminateConnection();
    
    // Discovery thread
    void discoveryThreadFunc();
    
    // Member variables
    std::vector<CastingDevicePtr> discoveredDevices_;
    mutable std::mutex devicesMutex_;
    
    CastingDevicePtr activeCastingDevice_;
    std::mutex activeCastingMutex_;
    
    std::atomic<bool> isDiscovering_{false};
    std::atomic<bool> isInitialized_{false};
    
    std::thread discoveryThread_;
    std::atomic<bool> shouldStopDiscovery_{false};
    
    // Callbacks
    DeviceDiscoveryCallback onDeviceDiscovery_;
    ConnectionStatusCallback onConnectionStatus_;
    
    // Protocol-specific managers (will be lazily initialized)
    class AirPlayManager* airplayManager_;
    class GoogleCastManager* googlecastManager_;
    class DLNAManager* dlnaManager_;
    class WebRTCManager* webrtcManager_;
};

} // namespace AYS2::Casting
