// CastingBridge.h — ObjC bridge for Swift UI to access Casting system
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#import <Foundation/Foundation.h>

// Forward declarations
typedef NS_ENUM(NSInteger, AYS2CastingProtocol) {
    AYS2CastingProtocolUnknown = 0,
    AYS2CastingProtocolAirPlay2 = 1,
    AYS2CastingProtocolNetworkFramework = 2,
    AYS2CastingProtocolGoogleCast = 3,
    AYS2CastingProtocolDLNA = 4,
    AYS2CastingProtocolWebRTC = 5,
};

typedef NS_ENUM(NSInteger, AYS2CastingState) {
    AYS2CastingStateDiscovered = 0,
    AYS2CastingStateConnecting = 1,
    AYS2CastingStateConnected = 2,
    AYS2CastingStateDisconnecting = 3,
    AYS2CastingStateError = 4,
    AYS2CastingStateUnavailable = 5,
};

@interface AYS2CastingDeviceInfo : NSObject
@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *modelName;
@property (nonatomic, assign) AYS2CastingProtocol protocol;
@property (nonatomic, assign) AYS2CastingState state;
@property (nonatomic, assign) int estimatedLatencyMs;
@property (nonatomic, assign) BOOL isAvailable;
@property (nonatomic, assign) BOOL supportsGameStreaming;
@end

@interface AYS2Casting : NSObject

// Lifecycle
+ (void)initialize;
+ (void)shutdown;

// Device Discovery
+ (void)startDeviceDiscovery;
+ (void)stopDeviceDiscovery;
+ (BOOL)isDiscovering;
+ (nonnull NSArray<AYS2CastingDeviceInfo *> *)discoveredDevices;

// Casting Control
+ (BOOL)startCastingToDevice:(nonnull AYS2CastingDeviceInfo *)device;
+ (void)stopCasting;
+ (BOOL)isCasting;
+ (nullable AYS2CastingDeviceInfo *)activeCastingDevice;

// Status
+ (int)estimatedLatencyMs;
+ (nonnull NSString *)castingStatusDescription;

// Frame Submission (called by game rendering engine)
+ (void)submitVideoFrame:(nonnull const uint8_t *)frameData width:(int)width height:(int)height timestampUs:(long long)timestampUs;
+ (void)submitAudioFrame:(nonnull const float *)audioData sampleCount:(int)sampleCount sampleRate:(int)sampleRate;

@end
