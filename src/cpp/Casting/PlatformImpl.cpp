// PlatformImpl.cpp — Platform implementations
// SPDX-License-Identifier: GPL-3.0+

#include "PlatformImpl.h"
#include <iostream>

#ifdef __APPLE__
#include <Foundation/Foundation.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <UIKit/UIKit.h>
#import <NetworkExtension/NetworkExtension.h>
#endif

namespace AYS2::Casting {

#ifdef __APPLE__

std::string iOSNetworkUtils::getLocalIPAddress() {
    // Get local WiFi IP address
    NSString* localIP = nil;
    
    struct ifaddrs *ifaddr, *ifa;
    if (getifaddrs(&ifaddr) == -1) {
        perror("getifaddrs");
        return "127.0.0.1";
    }
    
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) continue;
        
        int family = ifa->ifa_addr->sa_family;
        if (family == AF_INET) {
            char host[NI_MAXHOST];
            getnameinfo(ifa->ifa_addr, sizeof(struct sockaddr_in),
                       host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
            
            // Skip loopback
            if (strncmp(ifa->ifa_name, "lo", 2) != 0) {
                localIP = [NSString stringWithUTF8String:host];
                break;
            }
        }
    }
    
    freeifaddrs(ifaddr);
    
    return localIP ? std::string([localIP UTF8String]) : "127.0.0.1";
}

std::string iOSNetworkUtils::getDeviceModel() {
#if TARGET_OS_TV
    return "Apple TV";
#else
    UIDevice* device = [UIDevice currentDevice];
    return std::string([[device model] UTF8String]);
#endif
}

std::string iOSNetworkUtils::getDeviceUDID() {
    // On iOS 16+, use identifierForVendor
    UIDevice* device = [UIDevice currentDevice];
    NSUUID* vendorID = [device identifierForVendor];
    return std::string([[vendorID UUIDString] UTF8String]);
}

bool iOSNetworkUtils::isConnectedToWiFi() {
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityRef reachability = 
        SCNetworkReachabilityCreateWithName(NULL, "8.8.8.8");
    
    if (!SCNetworkReachabilityGetFlags(reachability, &flags)) {
        CFRelease(reachability);
        return false;
    }
    
    CFRelease(reachability);
    
    return flags & kSCNetworkReachabilityFlagsReachable &&
           !(flags & kSCNetworkReachabilityFlagsTransientConnection);
}

std::string iOSNetworkUtils::getWiFiSSID() {
    // Requires Network.framework or NEHotspotNetwork
    // For now, return placeholder
    return "AYS2 WiFi";
}

int iOSNetworkUtils::getWiFiSignalStrength() {
    // Would require private APIs or Network.framework
    return 0;
}

BonjourServiceDiscovery& BonjourServiceDiscovery::getInstance() {
    static BonjourServiceDiscovery instance;
    return instance;
}

BonjourServiceDiscovery::BonjourServiceDiscovery() {
}

BonjourServiceDiscovery::~BonjourServiceDiscovery() {
    stopDiscovery();
}

void BonjourServiceDiscovery::startDiscovery() {
    std::cout << "[Bonjour] Starting mDNS service discovery\n";
    // Implementation uses NSNetServiceBrowser
}

void BonjourServiceDiscovery::stopDiscovery() {
    std::cout << "[Bonjour] Stopped\n";
}

std::vector<CastingDevicePtr> BonjourServiceDiscovery::getDiscoveredServices() {
    std::vector<CastingDevicePtr> devices;
    // Implementation would enumerate discovered services
    return devices;
}

NetworkFrameworkDiscovery& NetworkFrameworkDiscovery::getInstance() {
    static NetworkFrameworkDiscovery instance;
    return instance;
}

NetworkFrameworkDiscovery::NetworkFrameworkDiscovery() {
}

NetworkFrameworkDiscovery::~NetworkFrameworkDiscovery() {
    stopDiscovery();
}

void NetworkFrameworkDiscovery::startDiscovery() {
    std::cout << "[NetworkFramework] Starting device discovery (iOS 16+)\n";
    // Implementation uses Network.framework NWBrowser
}

void NetworkFrameworkDiscovery::stopDiscovery() {
    std::cout << "[NetworkFramework] Stopped\n";
}

std::vector<CastingDevicePtr> NetworkFrameworkDiscovery::getDiscoveredDevices() {
    std::vector<CastingDevicePtr> devices;
    // Implementation would enumerate discovered devices
    return devices;
}

#endif // __APPLE__

PlatformInfo::OSType PlatformInfo::getOS() {
#ifdef __APPLE__
#if TARGET_OS_TV
    return OSType::tvOS;
#else
    return OSType::iOS;
#endif
#else
    return OSType::Unknown;
#endif
}

std::string PlatformInfo::getOSName() {
    switch (getOS()) {
        case OSType::iOS: return "iOS";
        case OSType::tvOS: return "tvOS";
        case OSType::macOS: return "macOS";
        case OSType::Android: return "Android";
        case OSType::Windows: return "Windows";
        case OSType::Linux: return "Linux";
        default: return "Unknown";
    }
}

std::string PlatformInfo::getDeviceName() {
#ifdef __APPLE__
    return std::string([UIDevice.currentDevice.name UTF8String]);
#else
    return "Device";
#endif
}

std::string PlatformInfo::getDeviceModel() {
#ifdef __APPLE__
#if TARGET_OS_TV
    return "Apple TV";
#else
    return std::string([UIDevice.currentDevice.model UTF8String]);
#endif
#else
    return "Unknown";
#endif
}

int PlatformInfo::getScreenWidth() {
#ifdef __APPLE__
    CGRect bounds = UIScreen.mainScreen.bounds;
    return static_cast<int>(bounds.size.width);
#else
    return 1280;
#endif
}

int PlatformInfo::getScreenHeight() {
#ifdef __APPLE__
    CGRect bounds = UIScreen.mainScreen.bounds;
    return static_cast<int>(bounds.size.height);
#else
    return 720;
#endif
}

bool PlatformInfo::supportsMetalRendering() {
#ifdef __APPLE__
    // All modern iOS devices support Metal
    return true;
#else
    return false;
#endif
}

} // namespace AYS2::Casting

