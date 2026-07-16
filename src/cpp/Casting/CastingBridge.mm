// CastingBridge.mm — ObjC++ bridge implementation for Swift
// SPDX-License-Identifier: GPL-3.0+

#import "CastingBridge.h"
#include "CastingManager.h"
#include "AirPlayManager.h"
#include "GoogleCastManager.h"

using namespace AYS2::Casting;

@implementation AYS2CastingDeviceInfo
@end

@implementation AYS2Casting {
    static DeviceDiscoveryCallback discoveryCallback;
    static ConnectionStatusCallback statusCallback;
}

+ (void)initialize
{
    CastingManager::getInstance().initialize();
}

+ (void)shutdown
{
    CastingManager::getInstance().shutdown();
}

+ (void)startDeviceDiscovery
{
    CastingManager::getInstance().startDeviceDiscovery();
}

+ (void)stopDeviceDiscovery
{
    CastingManager::getInstance().stopDeviceDiscovery();
}

+ (BOOL)isDiscovering
{
    return CastingManager::getInstance().isDiscovering() ? YES : NO;
}

+ (nonnull NSArray<AYS2CastingDeviceInfo *> *)discoveredDevices
{
    NSMutableArray<AYS2CastingDeviceInfo *> *result = [NSMutableArray array];
    
    const auto& devices = CastingManager::getInstance().getDiscoveredDevices();
    for (const auto& device : devices) {
        AYS2CastingDeviceInfo *info = [[AYS2CastingDeviceInfo alloc] init];
        info.deviceId = [NSString stringWithUTF8String:device->getId().c_str()];
        info.deviceName = [NSString stringWithUTF8String:device->getName().c_str()];
        info.modelName = [NSString stringWithUTF8String:device->getInfo().model.c_str()];
        
        // Convert protocol
        AYS2CastingProtocol proto = AYS2CastingProtocolUnknown;
        switch (device->getSelectedProtocol()) {
            case CastingProtocol::AirPlay2:
                proto = AYS2CastingProtocolAirPlay2;
                break;
            case CastingProtocol::NetworkFramework:
                proto = AYS2CastingProtocolNetworkFramework;
                break;
            case CastingProtocol::GoogleCast:
                proto = AYS2CastingProtocolGoogleCast;
                break;
            case CastingProtocol::DLNA_UPnP:
                proto = AYS2CastingProtocolDLNA;
                break;
            case CastingProtocol::WebRTC:
                proto = AYS2CastingProtocolWebRTC;
                break;
            default:
                break;
        }
        info.protocol = proto;
        
        // Convert state
        AYS2CastingState state = AYS2CastingStateDiscovered;
        switch (device->getState()) {
            case CastingState::Connected:
                state = AYS2CastingStateConnected;
                break;
            case CastingState::Connecting:
                state = AYS2CastingStateConnecting;
                break;
            case CastingState::Disconnecting:
                state = AYS2CastingStateDisconnecting;
                break;
            case CastingState::Error:
                state = AYS2CastingStateError;
                break;
            case CastingState::Unavailable:
                state = AYS2CastingStateUnavailable;
                break;
            default:
                break;
        }
        info.state = state;
        
        info.estimatedLatencyMs = device->getInfo().estimatedLatencyMs;
        info.isAvailable = device->getInfo().isAvailable;
        info.supportsGameStreaming = device->getInfo().supportsGameStreaming;
        
        [result addObject:info];
    }
    
    return result;
}

+ (BOOL)startCastingToDevice:(nonnull AYS2CastingDeviceInfo *)device
{
    if (!device) {
        return NO;
    }
    
    // Find the C++ device object by ID
    NSString *deviceId = device.deviceId;
    auto cppDevice = CastingManager::getInstance().getDeviceById(std::string([deviceId UTF8String]));
    
    if (!cppDevice) {
        return NO;
    }
    
    return CastingManager::getInstance().startCasting(cppDevice) ? YES : NO;
}

+ (void)stopCasting
{
    CastingManager::getInstance().stopCasting();
}

+ (BOOL)isCasting
{
    return CastingManager::getInstance().isCasting() ? YES : NO;
}

+ (nullable AYS2CastingDeviceInfo *)activeCastingDevice
{
    auto device = CastingManager::getInstance().getActiveCastingDevice();
    if (!device) {
        return nil;
    }
    
    AYS2CastingDeviceInfo *info = [[AYS2CastingDeviceInfo alloc] init];
    info.deviceId = [NSString stringWithUTF8String:device->getId().c_str()];
    info.deviceName = [NSString stringWithUTF8String:device->getName().c_str()];
    info.modelName = [NSString stringWithUTF8String:device->getInfo().model.c_str()];
    info.estimatedLatencyMs = device->getInfo().estimatedLatencyMs;
    info.isAvailable = device->getInfo().isAvailable;
    
    return info;
}

+ (int)estimatedLatencyMs
{
    return CastingManager::getInstance().getEstimatedLatencyMs();
}

+ (nonnull NSString *)castingStatusDescription
{
    if (!CastingManager::getInstance().isCasting()) {
        return @"Not casting";
    }
    
    auto device = CastingManager::getInstance().getActiveCastingDevice();
    if (!device) {
        return @"No device selected";
    }
    
    NSString *deviceName = [NSString stringWithUTF8String:device->getName().c_str()];
    int latency = device->getInfo().estimatedLatencyMs;
    
    return [NSString stringWithFormat:@"Casting to %@ (%dms)", deviceName, latency];
}

+ (void)submitVideoFrame:(nonnull const uint8_t *)frameData width:(int)width height:(int)height timestampUs:(long long)timestampUs
{
    CastingManager::getInstance().submitVideoFrame(frameData, width, height, timestampUs);
}

+ (void)submitAudioFrame:(nonnull const float *)audioData sampleCount:(int)sampleCount sampleRate:(int)sampleRate
{
    CastingManager::getInstance().submitAudioFrame(audioData, sampleCount, sampleRate);
}

@end
