// CastingDevice.h — Universal casting device model
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <string>
#include <vector>
#include <memory>

namespace AYS2::Casting {

enum class CastingProtocol {
    Unknown,
    AirPlay2,                      // Apple TV, iPad, iPhone
    NetworkFramework,              // iOS 16+ mDNS/Bonjour
    GoogleCast,                    // Chromecast, Android TV
    DLNA_UPnP,                    // Smart TVs (Samsung, LG, Sony)
    WebRTC,                        // Browser receiver (universal fallback)
};

enum class DeviceType {
    Unknown,
    AppleTV,
    iPad,
    iPhone,
    Mac,
    Chromecast,
    AndroidTV,
    SmartTV,
    Computer,
    Phone,
};

enum class CastingState {
    Discovered,                    // Found but not connected
    Connecting,                    // Connection in progress
    Connected,                     // Actively streaming
    Disconnecting,                 // Disconnection in progress
    Error,                         // Connection error
    Unavailable,                   // Device went offline
};

struct CastingDeviceInfo {
    std::string id;                // Unique device ID
    std::string name;              // Display name (e.g., "Living Room TV")
    std::string model;             // Device model (e.g., "Apple TV 4K")
    DeviceType type;               // Device category
    
    std::string ipAddress;         // IP address on network
    int port;                      // Port number (if applicable)
    
    std::vector<CastingProtocol> supportedProtocols;
    CastingProtocol preferredProtocol;
    
    bool isLocal;                  // On same WiFi network
    bool isAvailable;              // Currently reachable
    
    // Device capabilities
    bool supportsVideo;
    bool supportsAudio;
    bool supportsGameStreaming;
    
    int estimatedLatencyMs;        // Expected latency for this device
    std::string lastSeenTimestamp;
    
    // Metadata
    std::string macAddress;
    std::string manufacturer;
    std::string firmwareVersion;
    
    // WebRTC receiver URL (for browser-based receivers)
    std::string receiverURL;
    
    // DLNA/UPnP descriptor URL (for smart TVs)
    std::string descriptorURL;
};

class CastingDevice {
public:
    explicit CastingDevice(const CastingDeviceInfo& info);
    
    // Getters
    const std::string& getId() const { return info_.id; }
    const std::string& getName() const { return info_.name; }
    DeviceType getType() const { return info_.type; }
    CastingState getState() const { return state_; }
    const CastingDeviceInfo& getInfo() const { return info_; }
    
    CastingProtocol getSelectedProtocol() const { return selectedProtocol_; }
    bool supports(CastingProtocol protocol) const;
    
    // WebRTC/DLNA URLs
    std::string getReceiverURL() const { return info_.receiverURL; }
    std::string getDescriptorURL() const { return info_.descriptorURL; }
    
    // State management
    void setState(CastingState state) { state_ = state; }
    void setProtocol(CastingProtocol protocol) { selectedProtocol_ = protocol; }
    
    // Metadata
    bool isGameStreamingSuitable() const;
    bool isVideoPlaybackSuitable() const;
    
    std::string getStateString() const;
    std::string getProtocolString() const;
    
private:
    CastingDeviceInfo info_;
    CastingState state_;
    CastingProtocol selectedProtocol_;
};

using CastingDevicePtr = std::shared_ptr<CastingDevice>;
using CastingDeviceList = std::vector<CastingDevicePtr>;

} // namespace AYS2::Casting
