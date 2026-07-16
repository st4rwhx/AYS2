// DLNAManager.cpp — DLNA/UPnP streaming implementation
// SPDX-License-Identifier: GPL-3.0+

#include "DLNAManager.h"
#include <iostream>
#include <sstream>
#include <algorithm>
#include <cstring>
#include <upnp.h>
#include <upnptools.h>

// Simple XML parser helper for SSDP device descriptions
namespace {
    std::string extractXMLValue(const std::string& xml, const std::string& tag) {
        std::string openTag = "<" + tag + ">";
        std::string closeTag = "</" + tag + ">";
        
        size_t start = xml.find(openTag);
        if (start == std::string::npos) return "";
        
        start += openTag.length();
        size_t end = xml.find(closeTag, start);
        if (end == std::string::npos) return "";
        
        return xml.substr(start, end - start);
    }
    
    std::string getHostIP() {
        // On iOS/macOS, get the primary network interface IP
        // For now, return placeholder - will be set at runtime
        return "127.0.0.1";
    }
}

namespace AYS2::Casting {

DLNAManager& DLNAManager::getInstance() {
    static DLNAManager instance;
    return instance;
}

DLNAManager::DLNAManager() 
    : upnpHandle_(-1), httpServerPort_(0) {
}

DLNAManager::~DLNAManager() {
    shutdown();
}

void DLNAManager::initialize() {
    if (isInitialized_.exchange(true)) {
        return;
    }
    
    // Initialize libupnp
    // This starts the UPnP SDK, which handles SSDP multicasting
    int retval = UpnpInit(nullptr, 0);
    if (retval != UPNP_E_SUCCESS) {
        std::cerr << "[DLNA] Failed to initialize libupnp: " << UpnpGetErrorMessage(retval) << "\n";
        isInitialized_ = false;
        return;
    }
    
    // Get local IP for server binding
    hostIP_ = getHostIP();
    
    std::cout << "[DLNA] Initialized (Host IP: " << hostIP_ << ")\n";
}

void DLNAManager::shutdown() {
    if (!isInitialized_.load()) {
        return;
    }
    
    disconnect();
    stopDLNAServer();
    discoveryRunning_ = false;
    
    if (discoveryThread_.joinable()) {
        discoveryThread_.join();
    }
    
    if (upnpHandle_ != -1) {
        UpnpFinish();
        upnpHandle_ = -1;
    }
    
    isInitialized_ = false;
    std::cout << "[DLNA] Shutdown complete\n";
}

void DLNAManager::discoverDevices(CastingDeviceList& outDevices) {
    if (!isInitialized_.load()) {
        std::cerr << "[DLNA] Not initialized\n";
        return;
    }
    
    // Start discovery thread if not already running
    if (!discoveryRunning_.exchange(true)) {
        discoveryThread_ = std::thread(&DLNAManager::ssdpDiscoveryThread, this);
    }
    
    std::cout << "[DLNA] Starting SSDP device discovery...\n";
}

void DLNAManager::ssdpDiscoveryThread() {
    // Send SSDP M-SEARCH request to multicast group 239.255.255.250:1900
    // This discovers UPnP devices on the local network
    
    const char* searchTarget = "ssdp:all";  // Search for all UPnP devices
    int timeoutSecs = 3;  // Wait 3 seconds for responses
    
    std::cout << "[DLNA] Sending SSDP M-SEARCH (timeout: " << timeoutSecs << "s)\n";
    
    int retval = UpnpSearchAsync(upnpHandle_, timeoutSecs, searchTarget, nullptr);
    if (retval != UPNP_E_SUCCESS) {
        std::cerr << "[DLNA] SSDP search failed: " << UpnpGetErrorMessage(retval) << "\n";
        discoveryRunning_ = false;
        return;
    }
    
    // Wait for responses
    std::this_thread::sleep_for(std::chrono::seconds(timeoutSecs + 1));
    
    stats_.ssdpDiscoveries++;
    discoveryRunning_ = false;
    std::cout << "[DLNA] SSDP discovery complete\n";
}

void DLNAManager::processSSDPResponse(const std::string& deviceDescriptionURL) {
    // Parse device description XML from remote device
    // Extract friendly name, model, manufacturer, etc.
    
    std::cout << "[DLNA] Processing device description from: " << deviceDescriptionURL << "\n";
    
    // In production, would HTTP GET the description URL
    // For now, we'll create a placeholder device entry
    
    DLNADeviceInfo devInfo;
    devInfo.descriptionURL = deviceDescriptionURL;
    devInfo.friendlyName = "Smart TV";
    devInfo.manufacturer = "Unknown";
    devInfo.modelName = "DLNA Device";
    devInfo.deviceType = "urn:schemas-upnp-org:device:MediaRenderer:1";
    
    std::cout << "[DLNA] Discovered: " << devInfo.friendlyName << " (" << devInfo.manufacturer << ")\n";
}

bool DLNAManager::startDLNAServer(int httpPort) {
    if (serverRunning_.load()) {
        return true;
    }
    
    httpServerPort_ = httpPort;
    serverBaseURL_ = "http://" + hostIP_ + ":" + std::to_string(httpPort);
    
    std::cout << "[DLNA] Starting HTTP media server on port " << httpPort << "\n";
    std::cout << "[DLNA] Base URL: " << serverBaseURL_ << "\n";
    
    // Register HTTP request handler with libupnp
    // The server will serve video frames as HTTP progressive download
    
    serverRunning_ = true;
    return true;
}

void DLNAManager::stopDLNAServer() {
    if (!serverRunning_.exchange(false)) {
        return;
    }
    
    std::cout << "[DLNA] Stopped HTTP media server\n";
    
    // Clear frame buffer
    while (!frameBuffer_.empty()) {
        frameBuffer_.pop();
    }
}

bool DLNAManager::connect(const CastingDevicePtr& device) {
    if (!isInitialized_.load()) {
        return false;
    }
    
    if (!startDLNAServer()) {
        return false;
    }
    
    // Extract DLNA device info from casting device
    connectedDevice_.friendlyName = device->info.displayName;
    connectedDevice_.manufacturer = "Smart TV";
    connectedDevice_.UDN = device->info.deviceId;
    
    std::cout << "[DLNA] Connected to: " << connectedDevice_.friendlyName << "\n";
    std::cout << "[DLNA] Streaming from: " << serverBaseURL_ << "\n";
    
    isConnected_ = true;
    return true;
}

void DLNAManager::disconnect() {
    if (!isConnected_.exchange(false)) {
        return;
    }
    
    stopDLNAServer();
    std::cout << "[DLNA] Disconnected\n";
}

DLNADeviceInfo DLNAManager::getConnectedDeviceInfo() const {
    return connectedDevice_;
}

std::string DLNAManager::getConnectionStatus() const {
    if (!isInitialized_.load()) {
        return "Not initialized";
    }
    if (!isConnected_.load()) {
        return "Idle (server not running)";
    }
    return "Connected to " + connectedDevice_.friendlyName + " at " + serverBaseURL_;
}

std::vector<DLNADeviceInfo> DLNAManager::parseSSDPDeviceDescription(const std::string& descriptionXML) {
    std::vector<DLNADeviceInfo> devices;
    
    // Parse root device
    DLNADeviceInfo rootDevice;
    rootDevice.friendlyName = extractXMLValue(descriptionXML, "friendlyName");
    rootDevice.manufacturer = extractXMLValue(descriptionXML, "manufacturer");
    rootDevice.modelName = extractXMLValue(descriptionXML, "modelName");
    rootDevice.UDN = extractXMLValue(descriptionXML, "UDN");
    
    if (!rootDevice.UDN.empty()) {
        devices.push_back(rootDevice);
    }
    
    return devices;
}

DLNADeviceInfo DLNAManager::extractDeviceInfo(const std::string& descriptionXML) {
    DLNADeviceInfo info;
    
    info.friendlyName = extractXMLValue(descriptionXML, "friendlyName");
    info.manufacturer = extractXMLValue(descriptionXML, "manufacturer");
    info.modelName = extractXMLValue(descriptionXML, "modelName");
    info.UDN = extractXMLValue(descriptionXML, "UDN");
    info.deviceType = extractXMLValue(descriptionXML, "deviceType");
    
    // Extract service info
    std::string serviceType = extractXMLValue(descriptionXML, "serviceType");
    if (!serviceType.empty()) {
        info.serviceType = serviceType;
    }
    
    return info;
}

} // namespace AYS2::Casting

