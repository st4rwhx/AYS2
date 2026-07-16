// PlatformImpl.h — Platform-specific casting implementations
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include <string>
#include <vector>
#include <memory>

namespace AYS2::Casting {

#ifdef __APPLE__

// iOS-specific networking utilities
class iOSNetworkUtils {
public:
    static std::string getLocalIPAddress();
    static std::string getDeviceModel();
    static std::string getDeviceUDID();
    static bool isConnectedToWiFi();
    static std::string getWiFiSSID();
    static int getWiFiSignalStrength();
};

// iOS Bonjour/mDNS service discovery
class BonjourServiceDiscovery {
public:
    static BonjourServiceDiscovery& getInstance();
    
    void startDiscovery();
    void stopDiscovery();
    
    std::vector<CastingDevicePtr> getDiscoveredServices();
    
private:
    BonjourServiceDiscovery();
    ~BonjourServiceDiscovery();
};

// iOS Network.framework for AirPlay 2 device discovery
class NetworkFrameworkDiscovery {
public:
    static NetworkFrameworkDiscovery& getInstance();
    
    void startDiscovery();
    void stopDiscovery();
    
    std::vector<CastingDevicePtr> getDiscoveredDevices();
    
private:
    NetworkFrameworkDiscovery();
    ~NetworkFrameworkDiscovery();
};

#endif // __APPLE__

// Generic platform detection
class PlatformInfo {
public:
    enum class OSType {
        iOS,
        tvOS,
        macOS,
        Android,
        Windows,
        Linux,
        Unknown
    };
    
    static OSType getOS();
    static std::string getOSName();
    static std::string getDeviceName();
    static std::string getDeviceModel();
    static int getScreenWidth();
    static int getScreenHeight();
    static bool supportsMetalRendering();
};

} // namespace AYS2::Casting

