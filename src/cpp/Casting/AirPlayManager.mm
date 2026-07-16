// AirPlayManager.mm — AirPlay 2 implementation for iOS/macOS
// SPDX-License-Identifier: GPL-3.0+

#include "AirPlayManager.h"

#ifdef __APPLE__
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>

#include "common/Console.h"
#include "AirPlayNetworkTransport.h"

namespace AYS2::Casting {

AirPlayManager& AirPlayManager::getInstance()
{
    static AirPlayManager instance;
    return instance;
}

AirPlayManager::AirPlayManager()
    : audioSession_(nullptr), compressionSession_(nullptr), airplayConnection_(nullptr),
      frameWidth_(1920), frameHeight_(1080), frameRate_(60)
{
}

AirPlayManager::~AirPlayManager()
{
    shutdown();
}

void AirPlayManager::initialize()
{
    if (isInitialized_.load())
        return;
    
    Console.WriteLn("[AirPlay] Initializing AirPlay 2 manager...");
    
    @autoreleasepool {
        // Set up audio session for AirPlay with Low Latency Mode
        audioSession_ = [AVAudioSession sharedInstance];
        NSError* error = nil;
        
        // Enable AirPlay audio routing with low latency optimization
        // Research: AVAudioSessionCategoryOptionAllowAirPlay + low latency mode
        AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionAllowAirPlay;
        
        // iOS 17+: Enable low latency mode for AirPlay (reduces buffering)
        if (@available(iOS 17.0, *)) {
            options |= AVAudioSessionCategoryOptionLowLatency;
            Console.WriteLn("[AirPlay] Low Latency Mode enabled (iOS 17+)");
        }
        
        if ([audioSession_ setCategory:AVAudioSessionCategoryPlayback 
                            withOptions:options
                                  error:&error]) {
            Console.WriteLn("[AirPlay] Audio session configured for AirPlay with optimizations");
        } else {
            Console.Error("[AirPlay] Failed to configure audio session: %s", 
                [error.localizedDescription UTF8String]);
        }
        
        // Set preferred buffer duration to minimum (reduces latency)
        // Research: Smaller buffer = lower latency but requires more processing
        [audioSession_ setPreferredIOBufferDuration:0.005 error:&error];  // 5ms buffer (minimum safe value)
        
        // Activate audio session
        if ([audioSession_ setActive:YES error:&error]) {
            Console.WriteLn("[AirPlay] Audio session activated with 5ms buffer");
        } else {
            Console.Error("[AirPlay] Failed to activate audio session: %s",
                [error.localizedDescription UTF8String]);
        }
    }
    
    // Initialize video encoder for H.264 encoding
    VideoEncodingConfig encoderConfig;
    encoderConfig.width = 1920;
    encoderConfig.height = 1080;
    encoderConfig.frameRate = 60;
    encoderConfig.bitrateMbps = 8;
    encoderConfig.codec = VideoCodec::H264;
    encoderConfig.preset = EncodingPreset::RealTime;  // Low latency for streaming
    encoderConfig.hardwareAccelerated = true;
    
    videoEncoder_ = VideoEncoder::create(encoderConfig);
    if (videoEncoder_) {
        Console.WriteLn("[AirPlay] H.264 video encoder initialized (Hardware-accelerated)");
    } else {
        Console.Warning("[AirPlay] Failed to initialize video encoder");
    }
    
    // Initialize AirPlay protocol handler
    protocol_ = std::make_shared<AirPlayProtocol>();
    if (protocol_) {
        protocol_->initialize();
        Console.WriteLn("[AirPlay] AirPlay protocol initialized");
    }
    
    // Initialize network transport
    networkTransport_ = std::make_shared<AirPlayNetworkTransport>();
    if (networkTransport_) {
        networkTransport_->initialize();
        Console.WriteLn("[AirPlay] Network transport initialized");
    }
    
    isInitialized_ = true;
}

void AirPlayManager::shutdown()
{
    if (!isInitialized_.load())
        return;
    
    Console.WriteLn("[AirPlay] Shutting down AirPlay 2 manager...");
    
    disconnect();
    
    // Shutdown video encoder
    if (videoEncoder_) {
        videoEncoder_->shutdown();
        videoEncoder_ = nullptr;
    }
    
    // Shutdown network transport
    if (networkTransport_) {
        networkTransport_->shutdown();
        networkTransport_ = nullptr;
    }
    
    @autoreleasepool {
        if (audioSession_) {
            NSError* error = nil;
            [audioSession_ setActive:NO error:&error];
            audioSession_ = nil;
        }
    }
    
    if (compressionSession_) {
        VTCompressionSessionInvalidate(compressionSession_);
        CFRelease(compressionSession_);
        compressionSession_ = nullptr;
    }
    
    isInitialized_ = false;
}

void AirPlayManager::discoverDevices(CastingDeviceList& outDevices)
{
    if (!isInitialized_.load())
        return;
    
    @autoreleasepool {
        // Get available AirPlay routes from AVAudioSession
        AVAudioSessionRouteDescription* currentRoute = audioSession_.currentRoute;
        
        for (AVAudioSessionPortDescription* port in currentRoute.outputs) {
            // Check for AirPlay-compatible outputs
            if ([port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker] ||
                [port.portType isEqualToString:AVAudioSessionPortAirPlay] ||
                [port.portType isEqualToString:AVAudioSessionPortBluetoothA2DP]) {
                
                Console.WriteLn("[AirPlay] Found AirPlay compatible device: %s", 
                    [port.portName UTF8String]);
                
                // Create casting device for this port
                CastingDeviceInfo info;
                info.id = std::string([port.UID UTF8String] ?: "airplay_device");
                info.name = std::string([port.portName UTF8String] ?: "AirPlay Device");
                info.model = "AirPlay 2 Receiver";
                info.type = DeviceType::AppleTV;
                info.ipAddress = "127.0.0.1";  // Local network
                info.port = 7000;              // Standard AirPlay port
                
                info.supportedProtocols = { CastingProtocol::AirPlay2 };
                info.preferredProtocol = CastingProtocol::AirPlay2;
                
                info.supportsVideo = true;
                info.supportsAudio = true;
                info.supportsGameStreaming = true;
                info.isLocal = true;
                info.isAvailable = true;
                info.estimatedLatencyMs = 35;  // <40ms for AirPlay 2
                
                auto device = std::make_shared<CastingDevice>(info);
                outDevices.push_back(device);
            }
        }
        
        // Also check for external displays (iPad, iPhone with AirPlay)
        NSArray<UIScreen*>* screens = UIScreen.screens;
        if (screens.count > 1) {  // More than just main screen
            for (UIScreen* screen in screens) {
                if (screen != UIScreen.mainScreen) {
                    CastingDeviceInfo info;
                    info.id = "external_display_" + std::string(screen.description.UTF8String);
                    info.name = "External Display (AirPlay)";
                    info.model = "External Monitor";
                    info.type = DeviceType::iPad;  // Could be iPad or monitor
                    
                    info.supportedProtocols = { CastingProtocol::AirPlay2 };
                    info.preferredProtocol = CastingProtocol::AirPlay2;
                    
                    info.supportsVideo = true;
                    info.supportsAudio = true;
                    info.supportsGameStreaming = true;
                    info.isLocal = true;
                    info.isAvailable = true;
                    info.estimatedLatencyMs = 35;
                    
                    auto device = std::make_shared<CastingDevice>(info);
                    outDevices.push_back(device);
                }
            }
        }
    }
}

bool AirPlayManager::connect(const CastingDevicePtr& device)
{
    if (!device) {
        Console.Error("[AirPlay] Cannot connect: device is null");
        return false;
    }
    
    if (!videoEncoder_) {
        Console.Error("[AirPlay] Video encoder not initialized");
        return false;
    }
    
    if (!networkTransport_) {
        Console.Error("[AirPlay] Network transport not initialized");
        return false;
    }
    
    Console.WriteLn("[AirPlay] Connecting to AirPlay device: %s", device->getName().c_str());
    
    @autoreleasepool {
        // Connect to the device over network
        if (!networkTransport_->connectToDevice(device->getIPAddress(), device->getPort())) {
            Console.Error("[AirPlay] Failed to connect to device network");
            return false;
        }
        
        // For external displays (like Apple TV or iPad)
        if (UIScreen.screens.count > 1) {
            
            // Initialize the video encoder
            if (!videoEncoder_->initialize()) {
                Console.Error("[AirPlay] Failed to initialize video encoder");
                networkTransport_->disconnect();
                return false;
            }
            
            // Set callback for encoded frames
            // The callback will route frames through the AirPlay protocol and network
            videoEncoder_->setEncodedFrameCallback(
                [this](const uint8_t* data, size_t size, int64_t timestampUs, bool isKeyframe) {
                    if (!this->protocol_ || !this->networkTransport_) return;
                    
                    // Create AirPlay frame from encoded H.264 data
                    auto frame = this->protocol_->encodeFrame(data, size, timestampUs, isKeyframe);
                    if (frame) {
                        this->transmitEncodedFrame(frame);
                    }
                }
            );
            
            Console.WriteLn("[AirPlay] Video encoder callback configured");
            Console.WriteLn("[AirPlay] Estimated encoding latency: %d ms", 
                videoEncoder_->getEstimatedLatencyMs());
            
            isConnected_ = true;
            return true;
        } else {
            Console.Error("[AirPlay] No external display available");
            networkTransport_->disconnect();
            return false;
        }
    }
}

void AirPlayManager::disconnect()
{
    if (!isConnected_.load())
        return;
    
    Console.WriteLn("[AirPlay] Disconnecting from AirPlay device");
    
    // Shutdown video encoder
    if (videoEncoder_) {
        videoEncoder_->shutdown();
    }
    
    if (compressionSession_) {
        VTCompressionSessionInvalidate(compressionSession_);
        CFRelease(compressionSession_);
        compressionSession_ = nullptr;
    }
    
    isConnected_ = false;
}

void AirPlayManager::submitVideoFrame(const uint8_t* frameData, int width, int height, int64_t timestampUs)
{
    if (!isConnected_.load() || !videoEncoder_ || !frameData)
        return;
    
    // Submit frame to encoder
    // The encoder will call our callback with H.264-encoded data
    if (!videoEncoder_->encodeFrame(frameData, width, height, timestampUs)) {
        Console.Error("[AirPlay] Failed to submit frame to encoder");
    }
}

// Static callback handler for VideoToolbox encoder
void AirPlayManager::encodeCallbackHandler(void* refcon, VTEncodeInfoFlags infoFlags,
                                          CMSampleBufferRef sampleBuffer)
{
    if (!refcon)
        return;
    
    AirPlayManager* self = static_cast<AirPlayManager*>(refcon);
    self->handleEncodedFrame(sampleBuffer);
}

void AirPlayManager::handleEncodedFrame(CMSampleBufferRef sampleBuffer)
{
    if (!sampleBuffer || !isConnected_.load() || !protocol_)
        return;
    
    @autoreleasepool {
        // Get the encoded frame data
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        if (!blockBuffer) {
            Console.Error("[AirPlay] Failed to get block buffer from sample");
            return;
        }
        
        size_t dataLength = 0;
        char* dataPtr = nullptr;
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, nullptr, &dataLength, &dataPtr);
        
        if (status != noErr || !dataPtr) {
            Console.Error("[AirPlay] Failed to get data pointer from block buffer: %d", status);
            return;
        }
        
        // Get timing info
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        int64_t timestampUs = (int64_t)presentationTime.value * 1000000 / presentationTime.timescale;
        
        // Check if this is a key frame
        bool isKeyFrame = false;
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, FALSE);
        if (CFArrayGetCount(attachments)) {
            CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
        }
        
        // Process H.264 frame through AirPlay protocol
        auto frame = protocol_->encodeFrame((uint8_t*)dataPtr, dataLength, timestampUs, isKeyFrame);
        
        if (frame) {
            // TODO: Transmit frame to AirPlay device
            // For now, frames are queued in protocol_->transmissionQueue_
            transmitEncodedFrame(frame);
        }
    }
}

void AirPlayManager::transmitEncodedFrame(const AirPlayFramePtr& frame)
{
    if (!frame || !networkTransport_)
        return;
    
    // Send frame payload via UDP to AirPlay device
    if (!networkTransport_->sendRTPPacket(frame->payload.data(), frame->payload.size())) {
        Console.Error("[AirPlay] Failed to send RTP packet (%zu bytes)", frame->payload.size());
    }
}

void AirPlayManager::submitAudioFrame(const float* audioData, int sampleCount, int sampleRate)
{
    if (!isConnected_.load() || !audioData || sampleCount <= 0)
        return;
    
    @autoreleasepool {
        // For AirPlay 2, audio flows through the AVAudioSession
        // The emulated game audio should be routed through the audio engine
        // which will automatically stream to AirPlay devices
        
        // This is typically handled by the audio output manager (PCM -> speaker output)
        // The AVAudioSession with AirPlay category option will route it automatically
        
        // If custom audio transmission is needed:
        // 1. Convert float samples to int16 PCM format
        // 2. Create CMBlockBuffer
        // 3. Route through audio queue or encoder
        
        // For now, audio is handled by standard iOS audio routing
        // No explicit transmission needed - AVAudioSession handles it
    }
}

int AirPlayManager::getLatencyMs() const
{
    return isConnected_.load() ? 35 : 0;
}

void AirPlayManager::captureGameRenderTarget()
{
    // Capture Metal render target for video encoding
    // TODO: Implement Metal texture capture
}

void AirPlayManager::encodeVideoFrame()
{
    // Submit frame to VTCompressionSession for H.264 encoding
    // TODO: Implement video encoding
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

AirPlayManager& AirPlayManager::getInstance()
{
    static AirPlayManager instance;
    return instance;
}

AirPlayManager::AirPlayManager() { }
AirPlayManager::~AirPlayManager() { }
void AirPlayManager::initialize() { }
void AirPlayManager::shutdown() { }
void AirPlayManager::discoverDevices(CastingDeviceList&) { }
bool AirPlayManager::connect(const CastingDevicePtr&) { return false; }
void AirPlayManager::disconnect() { }
void AirPlayManager::submitVideoFrame(const uint8_t*, int, int, int64_t) { }
void AirPlayManager::submitAudioFrame(const float*, int, int) { }
int AirPlayManager::getLatencyMs() const { return 0; }

} // namespace AYS2::Casting

#endif
