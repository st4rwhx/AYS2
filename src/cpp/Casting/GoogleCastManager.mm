// GoogleCastManager.mm — Google Cast implementation for iOS/macOS
// SPDX-License-Identifier: GPL-3.0+

#include "GoogleCastManager.h"

#ifdef __APPLE__

#import <GoogleCast/GoogleCast.h>
#include "common/Console.h"

namespace AYS2::Casting {

GoogleCastManager& GoogleCastManager::getInstance()
{
    static GoogleCastManager instance;
    return instance;
}

GoogleCastManager::GoogleCastManager()
    : castSession_(nullptr), mediaChannel_(nullptr), deviceScanner_(nullptr),
      receiverAppId_("AYS2_CAST_RECEIVER"), deviceName_("")
{
}

GoogleCastManager::~GoogleCastManager()
{
    shutdown();
}

void GoogleCastManager::initialize()
{
    if (isInitialized_.load())
        return;
    
    Console.WriteLn("[GoogleCast] Initializing Google Cast manager for Chromecast + Android TV");
    
    @autoreleasepool {
        // Initialize Cast context with default session options
        GCKCastOptions* castOptions = [[GCKCastOptions alloc] initWithReceiverApplicationID:
            [NSString stringWithUTF8String:receiverAppId_.c_str()]];
        
        castOptions.mediaNotificationEnabled = YES;
        castOptions.stopReceiverApplicationWhenEndingSession = YES;
        castOptions.disablePhysicalSettingsUI = NO;
        
        [[GCKCastContext sharedInstance] setOptions:castOptions];
        
        // Setup device scanner
        setupDeviceScanner();
        
        Console.WriteLn("[GoogleCast] Cast context initialized with app ID: %s", receiverAppId_.c_str());
    }
    
    isInitialized_ = true;
}

void GoogleCastManager::shutdown()
{
    if (!isInitialized_.load())
        return;
    
    Console.WriteLn("[GoogleCast] Shutting down Google Cast manager");
    
    disconnect();
    
    @autoreleasepool {
        if (deviceScanner_) {
            [deviceScanner_ stop];
            deviceScanner_ = nil;
        }
    }
    
    isInitialized_ = false;
}

void GoogleCastManager::setupDeviceScanner()
{
    @autoreleasepool {
        // Create device scanner for discovering Cast devices
        deviceScanner_ = [[GCKDeviceScanner alloc] initWithFilter:
            [GCKFilterCriteria criteriaWithReceiverApplicationID:
                [NSString stringWithUTF8String:receiverAppId_.c_str()]]];
        
        if (!deviceScanner_) {
            Console.Error("[GoogleCast] Failed to create device scanner");
            return;
        }
        
        // Start scanning for devices
        [deviceScanner_ startScan];
        
        Console.WriteLn("[GoogleCast] Device scanner started (scanning for Chromecast/Android TV)");
    }
}

void GoogleCastManager::discoverDevices(CastingDeviceList& outDevices)
{
    if (!isInitialized_.load())
        return;
    
    @autoreleasepool {
        if (!deviceScanner_) {
            Console.Warning("[GoogleCast] Device scanner not initialized");
            return;
        }
        
        // Get list of discovered devices
        NSArray<GCKDevice*>* devices = deviceScanner_.devices;
        
        for (GCKDevice* device in devices) {
            if (!device.isOnline) {
                continue;  // Skip offline devices
            }
            
            Console.WriteLn("[GoogleCast] Found device: %s (model: %s)",
                [device.friendlyName UTF8String],
                [device.modelName UTF8String]);
            
            // Create casting device entry
            CastingDeviceInfo info;
            info.id = std::string([[device deviceID] UTF8String]);
            info.name = std::string([device.friendlyName UTF8String]);
            info.model = std::string([device.modelName UTF8String]);
            
            // Determine device type
            if ([device.deviceCategory isEqualToString:@"Chromecast"]) {
                info.type = DeviceType::Chromecast;
            } else if ([device.deviceCategory isEqualToString:@"AndroidTV"]) {
                info.type = DeviceType::AndroidTV;
            } else {
                info.type = DeviceType::Unknown;
            }
            
            // Extract IP address if available
            info.ipAddress = device.ipAddress ? std::string([device.ipAddress UTF8String]) : "unknown";
            info.port = 8009;  // Standard Cast port
            
            // Google Cast protocol
            info.supportedProtocols = { CastingProtocol::GoogleCast };
            info.preferredProtocol = CastingProtocol::GoogleCast;
            
            // Capabilities
            info.supportsVideo = YES;
            info.supportsAudio = YES;
            info.supportsGameStreaming = YES;
            info.isLocal = YES;
            info.isAvailable = device.isOnline;
            
            // Google Cast latency: 80-120ms
            info.estimatedLatencyMs = 100;
            
            auto castDevice = std::make_shared<CastingDevice>(info);
            outDevices.push_back(castDevice);
        }
        
        Console.WriteLn("[GoogleCast] Discovered %lu Cast devices", devices.count);
    }
}

bool GoogleCastManager::connect(const CastingDevicePtr& device)
{
    if (!device) {
        Console.Error("[GoogleCast] Cannot connect: device is null");
        return false;
    }
    
    if (!deviceScanner_) {
        Console.Error("[GoogleCast] Device scanner not initialized");
        return false;
    }
    
    Console.WriteLn("[GoogleCast] Connecting to Cast device: %s", device->getName().c_str());
    
    @autoreleasepool {
        // Find the GCK device by ID
        NSString* deviceID = [NSString stringWithUTF8String:device->getID().c_str()];
        GCKDevice* gckDevice = nil;
        
        for (GCKDevice* d in deviceScanner_.devices) {
            if ([[d deviceID] isEqualToString:deviceID]) {
                gckDevice = d;
                break;
            }
        }
        
        if (!gckDevice) {
            Console.Error("[GoogleCast] Device not found in scanner");
            return false;
        }
        
        // Create session with the device
        GCKSessionManager* sessionManager = [GCKCastContext sharedInstance].sessionManager;
        
        [sessionManager startSessionWithDevice:gckDevice];
        
        Console.WriteLn("[GoogleCast] Session initiated with device: %s", 
            [gckDevice.friendlyName UTF8String]);
        
        deviceName_ = device->getName();
        isConnected_ = true;
        
        // Setup media channel for custom streaming
        setupChannels();
        
        return true;
    }
}

void GoogleCastManager::setupChannels()
{
    @autoreleasepool {
        GCKCastContext* castContext = [GCKCastContext sharedInstance];
        if (!castContext.sessionManager.hasConnectedCastSession) {
            Console.Warning("[GoogleCast] No active Cast session");
            return;
        }
        
        castSession_ = castContext.sessionManager.currentCastSession;
        if (!castSession_) {
            Console.Error("[GoogleCast] Failed to get current Cast session");
            return;
        }
        
        // Create custom message channel for raw video/audio streaming
        mediaChannel_ = [[GCKGenericChannel alloc] initWithNamespace:@"urn:x-cast:ays2.media"];
        
        if (!mediaChannel_) {
            Console.Error("[GoogleCast] Failed to create media channel");
            return;
        }
        
        // Add channel to session
        [castSession_ addChannel:mediaChannel_];
        
        Console.WriteLn("[GoogleCast] Media streaming channel established");
        
        // Send initialization message to receiver
        NSDictionary* initMsg = @{
            @"type": @"INIT",
            @"encoding": @"H264",
            @"audio": @"AAC",
            @"fps": @60,
            @"width": @1920,
            @"height": @1080
        };
        
        NSError* error = nil;
        [mediaChannel_ sendMessage:initMsg error:&error];
        
        if (error) {
            Console.Error("[GoogleCast] Failed to send init message: %s",
                [[error localizedDescription] UTF8String]);
        }
    }
}

void GoogleCastManager::disconnect()
{
    if (!isConnected_.load())
        return;
    
    Console.WriteLn("[GoogleCast] Disconnecting from Cast device");
    
    @autoreleasepool {
        GCKCastContext* castContext = [GCKCastContext sharedInstance];
        if (castContext.sessionManager.hasConnectedCastSession) {
            [castContext.sessionManager endSession];
        }
        
        mediaChannel_ = nil;
        castSession_ = nil;
    }
    
    isConnected_ = false;
}

void GoogleCastManager::submitVideoFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe)
{
    if (!isConnected_.load() || !mediaChannel_ || !h264Data || size == 0)
        return;
    
    @autoreleasepool {
        // Create frame message for streaming
        NSMutableDictionary* frameMsg = [@{
            @"type": @"VIDEO_FRAME",
            @"timestamp": @(timestampUs),
            @"keyframe": @(isKeyframe),
            @"size": @(size)
        } mutableCopy];
        
        // Add H.264 data as base64-encoded string (for smaller messages)
        NSData* h264Bytes = [NSData dataWithBytes:h264Data length:size];
        NSString* base64Data = [h264Bytes base64EncodedStringWithOptions:0];
        frameMsg[@"data"] = base64Data;
        
        // Send to receiver
        NSError* error = nil;
        [mediaChannel_ sendMessage:frameMsg error:&error];
        
        if (error) {
            Console.Error("[GoogleCast] Failed to send video frame: %s",
                [[error localizedDescription] UTF8String]);
        } else {
            framesSent_++;
        }
    }
}

void GoogleCastManager::submitAudioFrame(const float* audioData, int sampleCount, int sampleRate)
{
    if (!isConnected_.load() || !mediaChannel_ || !audioData || sampleCount <= 0)
        return;
    
    @autoreleasepool {
        // Convert float audio to int16 PCM
        NSMutableData* pcmData = [NSMutableData dataWithCapacity:sampleCount * 2];
        int16_t* pcmBuffer = (int16_t*)pcmData.mutableBytes;
        
        for (int i = 0; i < sampleCount; i++) {
            int32_t sample = (int32_t)(audioData[i] * 32767.0f);
            sample = std::max(-32768, std::min(32767, sample));
            pcmBuffer[i] = (int16_t)sample;
        }
        
        // Create audio frame message
        NSMutableDictionary* audioMsg = [@{
            @"type": @"AUDIO_FRAME",
            @"sampleRate": @(sampleRate),
            @"samples": @(sampleCount),
            @"channels": @2
        } mutableCopy];
        
        NSString* base64Audio = [pcmData base64EncodedStringWithOptions:0];
        audioMsg[@"data"] = base64Audio;
        
        // Send to receiver
        NSError* error = nil;
        [mediaChannel_ sendMessage:audioMsg error:&error];
        
        if (error) {
            Console.Warning("[GoogleCast] Failed to send audio frame: %s",
                [[error localizedDescription] UTF8String]);
        }
    }
}

int GoogleCastManager::getLatencyMs() const
{
    return isConnected_.load() ? 100 : 0;  // Google Cast typical: 80-120ms
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

GoogleCastManager& GoogleCastManager::getInstance()
{
    static GoogleCastManager instance;
    return instance;
}

GoogleCastManager::GoogleCastManager() { }
GoogleCastManager::~GoogleCastManager() { }
void GoogleCastManager::initialize() { }
void GoogleCastManager::shutdown() { }
void GoogleCastManager::discoverDevices(CastingDeviceList&) { }
bool GoogleCastManager::connect(const CastingDevicePtr&) { return false; }
void GoogleCastManager::disconnect() { }
void GoogleCastManager::submitVideoFrame(const uint8_t*, size_t, int64_t, bool) { }
void GoogleCastManager::submitAudioFrame(const float*, int, int) { }
int GoogleCastManager::getLatencyMs() const { return 0; }

} // namespace AYS2::Casting

#endif
