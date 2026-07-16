// AirPlayNetworkTransport.h — UDP/RTP transmission for AirPlay 2
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <string>
#include <memory>
#include <atomic>
#include <cstdint>

#ifdef __APPLE__
#include <Network/Network.h>
#endif

namespace AYS2::Casting {

class AirPlayNetworkTransport {
public:
    static AirPlayNetworkTransport& getInstance();
    
    // Initialize network stack
    void initialize();
    void shutdown();
    
    // Connect to AirPlay device
    bool connectToDevice(const std::string& ipAddress, int port);
    void disconnect();
    bool isConnected() const { return connected_.load(); }
    
    // Send RTP packet data
    bool sendRTPPacket(const uint8_t* data, size_t size);
    
    // Statistics
    uint32_t getPacketsSent() const { return packetsSent_; }
    uint32_t getPacketsLost() const { return packetsLost_; }
    uint64_t getBytesSent() const { return bytesSent_; }
    
private:
    AirPlayNetworkTransport();
    ~AirPlayNetworkTransport();
    
    AirPlayNetworkTransport(const AirPlayNetworkTransport&) = delete;
    AirPlayNetworkTransport& operator=(const AirPlayNetworkTransport&) = delete;
    
#ifdef __APPLE__
    // Network Framework connection
    nw_connection_t connection_ = nullptr;
    
    // Completion handler for sends
    static void sendCompletion(nw_error_t error);
#endif
    
    std::atomic<bool> connected_{false};
    std::atomic<uint32_t> packetsSent_{0};
    std::atomic<uint32_t> packetsLost_{0};
    std::atomic<uint64_t> bytesSent_{0};
    
    std::string targetIP_;
    int targetPort_ = 0;
};

} // namespace AYS2::Casting

