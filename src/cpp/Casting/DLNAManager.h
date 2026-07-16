// DLNAManager.h — DLNA/UPnP streaming for legacy smart TVs
// SPDX-License-Identifier: GPL-3.0+
//
// Provides SSDP device discovery and HTTP progressive streaming
// for Samsung/LG/Sony/Panasonic smart TVs and legacy devices.
//
// DLNA Latency: 1-3 seconds (not suitable for gaming, demos/slideshows only)
// Protocol: UPnP v1.0, SSDP multicast, HTTP progressive download

#pragma once

#include "CastingDevice.h"
#include <memory>
#include <atomic>
#include <thread>
#include <queue>
#include <string>
#include <vector>
#include <upnp.h>

namespace AYS2::Casting {

struct DLNADeviceInfo {
    std::string UDN;                    // Unique Device Name
    std::string friendlyName;
    std::string modelName;
    std::string manufacturer;
    std::string deviceType;
    std::string descriptionURL;
    std::string serviceType;
    std::string controlURL;
    std::string eventSubURL;
};

class DLNAManager {
public:
    static DLNAManager& getInstance();
    
    // Lifecycle
    void initialize();
    void shutdown();
    
    // Device discovery via SSDP multicast
    void discoverDevices(CastingDeviceList& outDevices);
    
    // Server management (hosts the media on HTTP)
    bool startDLNAServer(int httpPort = 8080);
    void stopDLNAServer();
    bool isDLNAServerRunning() const { return serverRunning_.load(); }
    
    // Connection management
    // For DLNA, "connection" means telling device where to pull media from
    bool connect(const CastingDevicePtr& device);
    void disconnect();
    bool isConnected() const { return isConnected_.load(); }
    
    // Get current connected device info
    DLNADeviceInfo getConnectedDeviceInfo() const;
    
    // Status
    int getLatencyMs() const { return 1500; }  // Typical DLNA latency
    std::string getConnectionStatus() const;
    
    // Statistics
    struct DLNAStats {
        uint64_t bytesServed = 0;
        uint32_t httpRequests = 0;
        uint32_t ssdpDiscoveries = 0;
    };
    DLNAStats getStats() const { return stats_; }
    
private:
    DLNAManager();
    ~DLNAManager();
    
    DLNAManager(const DLNAManager&) = delete;
    DLNAManager& operator=(const DLNAManager&) = delete;
    
    // SSDP device discovery using libupnp
    void ssdpDiscoveryThread();
    void processSSDPResponse(const std::string& deviceDescriptionURL);
    std::vector<DLNADeviceInfo> parseSSDPDeviceDescription(const std::string& descriptionXML);
    
    // HTTP server for media serving
    void startHTTPServer(int port);
    void stopHTTPServer();
    static int handleHTTPRequest(struct upnp_connmgr_vars* service, 
                                  struct upnp_action* action);
    
    // Device parsing
    DLNADeviceInfo extractDeviceInfo(const std::string& descriptionXML);
    
    // Frame buffering for HTTP streaming
    std::queue<std::vector<uint8_t>> frameBuffer_;
    
    std::atomic<bool> isInitialized_{false};
    std::atomic<bool> isConnected_{false};
    std::atomic<bool> serverRunning_{false};
    
    // Discovery state
    std::thread discoveryThread_;
    std::atomic<bool> discoveryRunning_{false};
    
    // UPnP handle
    UpnpClient_Handle upnpHandle_ = -1;
    
    // Server state
    int httpServerPort_ = 0;
    std::string serverBaseURL_;
    std::string hostIP_;
    
    // Connected device info
    DLNADeviceInfo connectedDevice_;
    
    // Statistics
    DLNAStats stats_;
};

} // namespace AYS2::Casting

