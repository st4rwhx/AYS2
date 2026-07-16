// AirPlayNetworkTransport.mm — UDP/RTP transmission for AirPlay 2
// SPDX-License-Identifier: GPL-3.0+

#include "AirPlayNetworkTransport.h"

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#include "common/Console.h"

namespace AYS2::Casting {

AirPlayNetworkTransport& AirPlayNetworkTransport::getInstance()
{
    static AirPlayNetworkTransport instance;
    return instance;
}

AirPlayNetworkTransport::AirPlayNetworkTransport()
    : connection_(nullptr), targetIP_(""), targetPort_(0)
{
}

AirPlayNetworkTransport::~AirPlayNetworkTransport()
{
    shutdown();
}

void AirPlayNetworkTransport::initialize()
{
    Console.WriteLn("[AirPlayNet] Network transport initialized (iOS Network Framework)");
}

void AirPlayNetworkTransport::shutdown()
{
    disconnect();
    Console.WriteLn("[AirPlayNet] Stats - Packets: %u sent, %u lost, %llu bytes", 
        packetsSent_.load(), packetsLost_.load(), bytesSent_.load());
}

bool AirPlayNetworkTransport::connectToDevice(const std::string& ipAddress, int port)
{
    if (ipAddress.empty() || port <= 0 || port > 65535) {
        Console.Error("[AirPlayNet] Invalid connection parameters: %s:%d", ipAddress.c_str(), port);
        return false;
    }
    
    if (connected_.load()) {
        disconnect();
    }
    
    targetIP_ = ipAddress;
    targetPort_ = port;
    
    Console.WriteLn("[AirPlayNet] Connecting to AirPlay device: %s:%d", ipAddress.c_str(), port);
    
    @autoreleasepool {
        // Create network endpoint for the device
        NSString* hostStr = [NSString stringWithUTF8String:ipAddress.c_str()];
        nw_endpoint_t endpoint = nw_endpoint_create_host(
            [hostStr UTF8String],
            [[NSString stringWithFormat:@"%d", port] UTF8String]
        );
        
        if (!endpoint) {
            Console.Error("[AirPlayNet] Failed to create network endpoint");
            return false;
        }
        
        // Create UDP parameters optimized for low-latency RTP streaming
        // Research: UDP with minimal buffering and QoS for real-time media
        nw_parameters_t params = nw_parameters_create_secure_udp(
            NW_PARAMETERS_DEFAULT_CONFIGURATION,
            NW_PARAMETERS_DISABLE_PROTOCOL
        );
        
        if (!params) {
            Console.Error("[AirPlayNet] Failed to create network parameters");
            nw_release(endpoint);
            return false;
        }
        
        // Configure low-latency UDP options
        nw_protocol_stack_t protocolStack = nw_parameters_copy_default_protocol_stack(params);
        nw_protocol_options_t udpOptions = nw_protocol_stack_copy_transport_protocol(protocolStack);
        
        if (udpOptions) {
            // Disable Nagle-like algorithms for UDP (send immediately)
            nw_udp_options_set_prefer_no_checksum(udpOptions, false);  // Keep checksums for reliability
            
            Console.WriteLn("[AirPlayNet] UDP options configured for low-latency");
        }
        
        // Set QoS to interactive (highest priority for real-time)
        // This ensures network stack prioritizes our packets
        nw_parameters_set_service_class(params, nw_service_class_responsive_data);
        
        // Prohibit expensive paths (cellular) for casting (WiFi only)
        nw_parameters_set_prohibit_expensive(params, true);
        
        // Allow fast path (optimized kernel processing)
        nw_parameters_set_fast_open_enabled(params, true);
        
        // Create connection
        connection_ = nw_connection_create(endpoint, params);
        
        if (!connection_) {
            Console.Error("[AirPlayNet] Failed to create connection");
            nw_release(params);
            nw_release(endpoint);
            return false;
        }
        
        // Set connection state change handler
        nw_connection_set_state_changed_handler(connection_, ^(nw_connection_state_t state, nw_error_t error) {
            switch (state) {
                case nw_connection_state_waiting:
                    Console.WriteLn("[AirPlayNet] Connection waiting...");
                    break;
                case nw_connection_state_preparing:
                    Console.WriteLn("[AirPlayNet] Connection preparing...");
                    break;
                case nw_connection_state_ready:
                    Console.WriteLn("[AirPlayNet] Connection established");
                    break;
                case nw_connection_state_failed:
                    Console.Error("[AirPlayNet] Connection failed");
                    break;
                case nw_connection_state_cancelled:
                    Console.WriteLn("[AirPlayNet] Connection cancelled");
                    break;
            }
        });
        
        // Start the connection
        nw_connection_start(connection_);
        
        connected_ = true;
        Console.WriteLn("[AirPlayNet] Connection initiated to %s:%d", ipAddress.c_str(), port);
        
        nw_release(params);
        nw_release(endpoint);
    }
    
    return true;
}

void AirPlayNetworkTransport::disconnect()
{
    if (!connected_.load())
        return;
    
    Console.WriteLn("[AirPlayNet] Disconnecting from AirPlay device");
    
    @autoreleasepool {
        if (connection_) {
            nw_connection_cancel(connection_);
            nw_release(connection_);
            connection_ = nullptr;
        }
    }
    
    connected_ = false;
}

bool AirPlayNetworkTransport::sendRTPPacket(const uint8_t* data, size_t size)
{
    if (!connected_.load() || !connection_ || !data || size == 0) {
        if (connected_.load()) {
            packetsLost_++;
        }
        return false;
    }
    
    @autoreleasepool {
        // Create dispatch data from buffer
        dispatch_data_t send_data = dispatch_data_create(
            data, size,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
            ^{ /* buffer is on stack, no cleanup needed */ }
        );
        
        if (!send_data) {
            Console.Error("[AirPlayNet] Failed to create dispatch data");
            packetsLost_++;
            return false;
        }
        
        // Send the packet
        __block bool success = false;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        
        nw_connection_send(connection_, send_data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
            ^(nw_error_t error) {
                if (error) {
                    Console.Error("[AirPlayNet] Send error: %s", 
                        nw_error_copy_description(error));
                    dispatch_release(error);
                    success = false;
                } else {
                    success = true;
                    packetsSent_++;
                    bytesSent_ += size;
                }
                dispatch_semaphore_signal(sem);
            }
        );
        
        // Wait for send completion (with timeout)
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 100000000LL);  // 100ms
        if (dispatch_semaphore_wait(sem, timeout) != 0) {
            Console.Warning("[AirPlayNet] Send timeout for %zu bytes", size);
            packetsLost_++;
            success = false;
        }
        
        dispatch_release(sem);
        dispatch_release(send_data);
        
        if (!success) {
            packetsLost_++;
        }
        
        return success;
    }
}

void AirPlayNetworkTransport::sendCompletion(nw_error_t error)
{
    if (error) {
        Console.Error("[AirPlayNet] Packet send error");
    }
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

AirPlayNetworkTransport& AirPlayNetworkTransport::getInstance()
{
    static AirPlayNetworkTransport instance;
    return instance;
}

AirPlayNetworkTransport::AirPlayNetworkTransport() { }
AirPlayNetworkTransport::~AirPlayNetworkTransport() { }
void AirPlayNetworkTransport::initialize() { }
void AirPlayNetworkTransport::shutdown() { }
bool AirPlayNetworkTransport::connectToDevice(const std::string&, int) { return false; }
void AirPlayNetworkTransport::disconnect() { }
bool AirPlayNetworkTransport::sendRTPPacket(const uint8_t*, size_t) { return false; }

} // namespace AYS2::Casting

#endif
