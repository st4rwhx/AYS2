// VideoEncoder.mm — H.264 video encoding via VideoToolbox (iOS/macOS)
// SPDX-License-Identifier: GPL-3.0+

#include "VideoEncoder.h"

#ifdef __APPLE__

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include "common/Console.h"
#include <atomic>
#include <chrono>
#include <queue>

namespace AYS2::Casting {

std::shared_ptr<VideoEncoder> VideoEncoder::create(const VideoEncodingConfig& config)
{
    if (config.codec == VideoCodec::H264) {
        auto encoder = std::make_shared<VideoEncoderH264>(config);
        if (encoder && encoder->initialize()) {
            return encoder;
        }
    }
    
    // TODO: Support H.265, VP8, VP9 codecs
    Console.Error("[VideoEncoder] Unsupported codec: %d", static_cast<int>(config.codec));
    return nullptr;
}

// ============================================================================
// VideoEncoderH264 Implementation
// ============================================================================

VideoEncoderH264::VideoEncoderH264(const VideoEncodingConfig& config)
    : VideoEncoder(config), 
      compressionSession_(nullptr),
      framesEncoded_(0), framesDropped_(0), bytesEncoded_(0)
{
}

VideoEncoderH264::~VideoEncoderH264()
{
    shutdown();
}

bool VideoEncoderH264::initialize()
{
    if (compressionSession_) {
        Console.WriteLn("[VideoEncoder] Already initialized");
        return true;
    }
    
    Console.WriteLn("[VideoEncoder] Initializing H.264 encoder (HW-accelerated VideoToolbox)");
    Console.WriteLn("[VideoEncoder] Resolution: %dx%d, FPS: %d, Bitrate: %d Mbps", 
        config_.width, config_.height, config_.frameRate, config_.bitrateMbps);
    
    @autoreleasepool {
        // Create encoder specification dictionary
        CFDictionaryRef encoderSpec = nullptr;  // Use default hardware encoder
        
        // Create compression session
        OSStatus status = VTCompressionSessionCreate(
            kCFAllocatorDefault,
            config_.width,                      // width
            config_.height,                     // height
            kCMVideoCodecType_H264,             // codec (H.264)
            encoderSpec,                        // encoderSpecification (hardware if available)
            nullptr,                            // sourcePixelBufferAttributes
            kCFAllocatorDefault,                // compressedDataAllocator
            &VideoEncoderH264::compressionOutputCallback,  // outputCallback
            (void*)this,                        // refcon (passes 'this')
            &compressionSession_
        );
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to create VTCompressionSession: OSStatus %d", status);
            return false;
        }
        
        if (!compressionSession_) {
            Console.Error("[VideoEncoder] Compression session is null");
            return false;
        }
        
        // Configure real-time encoding for streaming
        if (config_.preset == EncodingPreset::RealTime) {
            VTSessionSetProperty(compressionSession_, kVTCompressionPropertyKey_RealTime, 
                kCFBooleanTrue);
            Console.WriteLn("[VideoEncoder] Real-time encoding enabled (low latency mode)");
        }
        
        // Set maximum frame delay (OPTIMIZED for ultra-low latency)
        // Research: MaxFrameDelayCount = 0 gives absolute minimum latency
        // WWDC 2021: Setting to 0 eliminates encoder buffering entirely
        int maxFrameDelay = 0;  // 0 frame delay = immediate encoding (<2ms)
        if (config_.preset == EncodingPreset::Balanced) {
            maxFrameDelay = 1;  // 1 frame = ~17ms at 60fps
        } else if (config_.preset == EncodingPreset::Quality) {
            maxFrameDelay = 2;  // 2 frames = ~33ms at 60fps
        }
        
        status = VTSessionSetProperty(compressionSession_, 
            kVTCompressionPropertyKey_MaximumFrameDelayCount,
            (__bridge CFTypeRef)@(maxFrameDelay));
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to set max frame delay: %d", status);
        } else {
            Console.WriteLn("[VideoEncoder] Max frame delay set to %d frames", maxFrameDelay);
        }
        
        // Enable low-latency rate control (iOS 16+)
        // This optimizes bitrate control for minimal buffering
        if (@available(iOS 16.0, *)) {
            CFMutableDictionaryRef encoderSpec = CFDictionaryCreateMutable(
                kCFAllocatorDefault, 1,
                &kCFTypeDictionaryKeyCallBacks,
                &kCFTypeDictionaryValueCallBacks
            );
            CFDictionarySetValue(encoderSpec, 
                kVTVideoEncoderSpecification_EnableLowLatencyRateControl, 
                kCFBooleanTrue);
            
            status = VTSessionSetProperty(compressionSession_, 
                kVTCompressionPropertyKey_EncoderID, 
                encoderSpec);
            
            if (status == noErr) {
                Console.WriteLn("[VideoEncoder] Low-latency rate control enabled (iOS 16+)");
            }
            
            CFRelease(encoderSpec);
        }
        
        // Set average bitrate (Mbps -> bits/s)
        int bitrateTarget = config_.bitrateMbps * 1000000;
        status = VTSessionSetProperty(compressionSession_, 
            kVTCompressionPropertyKey_AverageBitrate,
            (__bridge CFTypeRef)@(bitrateTarget));
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to set bitrate: %d", status);
        }
        
        Console.WriteLn("[VideoEncoder] Target bitrate: %d Mbps", config_.bitrateMbps);
        
        // Set frame rate
        status = VTSessionSetProperty(compressionSession_, 
            kVTCompressionPropertyKey_ExpectedFrameRate,
            (__bridge CFTypeRef)@(config_.frameRate));
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to set frame rate: %d", status);
        }
        
        // Set H.264 profile level (Main Profile 4.0 supports 1080p60)
        status = VTSessionSetProperty(compressionSession_, 
            kVTCompressionPropertyKey_ProfileLevel,
            kVTProfileLevel_H264_Main_4_0);
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to set profile level: %d", status);
        }
        
        // Disable B-frames for lower latency
        status = VTSessionSetProperty(compressionSession_, 
            kVTCompressionPropertyKey_AllowFrameReordering,
            kCFBooleanFalse);
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] Failed to disable B-frames: %d", status);
        }
        
        Console.WriteLn("[VideoEncoder] H.264 encoder initialized successfully");
        return true;
    }
}

void VideoEncoderH264::shutdown()
{
    if (!compressionSession_) {
        return;
    }
    
    Console.WriteLn("[VideoEncoder] Shutting down H.264 encoder");
    Console.WriteLn("[VideoEncoder] Stats - Frames: %d encoded, %d dropped, %.2f Mbps average",
        framesEncoded_, framesDropped_, getAverageBitrateMbps());
    
    // Flush any pending frames
    VTCompressionSessionCompleteFrames(compressionSession_, kCMTimeInvalid);
    
    // Invalidate and release
    VTCompressionSessionInvalidate(compressionSession_);
    CFRelease(compressionSession_);
    compressionSession_ = nullptr;
    
    framesEncoded_ = 0;
    framesDropped_ = 0;
    bytesEncoded_ = 0;
}

bool VideoEncoderH264::encodeFrame(const uint8_t* frameData, int width, int height, 
                                  int64_t timestampUs, bool forceKeyframe)
{
    if (!compressionSession_ || !frameData) {
        return false;
    }
    
    if (width != config_.width || height != config_.height) {
        Console.Warning("[VideoEncoder] Frame resolution mismatch: got %dx%d, expected %dx%d",
            width, height, config_.width, config_.height);
        return false;
    }
    
    @autoreleasepool {
        // Create CVPixelBuffer from raw frame data
        CVPixelBufferRef pixelBuffer = createPixelBuffer(frameData, width, height);
        
        if (!pixelBuffer) {
            framesDropped_++;
            return false;
        }
        
        // Create presentation timestamp
        // Convert microseconds to CMTime (1us = 1/1,000,000 seconds)
        CMTime presentationTimeStamp = CMTimeMake(timestampUs, 1000000);
        
        // Create frame properties for keyframe request
        CFDictionaryRef frameProperties = nullptr;
        
        if (forceKeyframe) {
            const void* keys[] = { kVTEncodeFrameOptionKey_ForceKeyFrame };
            const void* values[] = { kCFBooleanTrue };
            frameProperties = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1,
                &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        }
        
        // Submit frame to encoder (asynchronous)
        OSStatus status = VTCompressionSessionEncodeFrame(
            compressionSession_,
            pixelBuffer,
            presentationTimeStamp,
            kCMTimeInvalid,          // duration (can be invalid)
            frameProperties,         // frame properties (keyframe request)
            nullptr,                 // sourceTrackID
            nullptr                  // infoFlagsOut
        );
        
        if (frameProperties) {
            CFRelease(frameProperties);
        }
        
        CVPixelBufferRelease(pixelBuffer);
        
        if (status != noErr) {
            Console.Error("[VideoEncoder] VTCompressionSessionEncodeFrame failed: %d", status);
            framesDropped_++;
            return false;
        }
        
        framesEncoded_++;
        return true;
    }
}

CVPixelBufferRef VideoEncoderH264::createPixelBuffer(const uint8_t* frameData, int width, int height)
{
    if (!frameData || width <= 0 || height <= 0) {
        return nullptr;
    }
    
    @autoreleasepool {
        // Create CVPixelBuffer from raw frame data
        // Assuming BGRA format (4 bytes per pixel)
        
        CVPixelBufferRef pixelBuffer = nullptr;
        size_t bytesPerRow = width * 4;  // BGRA: 4 bytes per pixel
        size_t dataSize = bytesPerRow * height;
        
        // Create mutable buffer
        void* pixelData = malloc(dataSize);
        if (!pixelData) {
            return nullptr;
        }
        
        // Copy frame data
        memcpy(pixelData, frameData, dataSize);
        
        // Create pixel buffer from this data
        CVReturn status = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,  // BGRA format
            pixelData,
            bytesPerRow,
            [](void* releaseRefCon, const void* baseAddress) {
                free((void*)baseAddress);
            },
            pixelData,
            nullptr,  // attributes
            &pixelBuffer
        );
        
        if (status != kCVReturnSuccess) {
            Console.Error("[VideoEncoder] Failed to create CVPixelBuffer: %d", status);
            free(pixelData);
            return nullptr;
        }
        
        return pixelBuffer;
    }
}

// Static callback for VideoToolbox encoder output
void VideoEncoderH264::compressionOutputCallback(void* refCon, void* sourceFrameRefCon,
                                                OSStatus status, VTEncodeInfoFlags infoFlags,
                                                CMSampleBufferRef sampleBuffer)
{
    if (!refCon) return;
    
    VideoEncoderH264* self = static_cast<VideoEncoderH264*>(refCon);
    
    if (status != noErr) {
        Console.Error("[VideoEncoder] Encoder callback error: %d", status);
        return;
    }
    
    if (!sampleBuffer) {
        return;
    }
    
    @autoreleasepool {
        // Get encoded data
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        if (!blockBuffer) {
            return;
        }
        
        size_t dataLength = 0;
        char* dataPtr = nullptr;
        OSStatus bufStatus = CMBlockBufferGetDataPointer(blockBuffer, 0, nullptr, &dataLength, &dataPtr);
        
        if (bufStatus != noErr || !dataPtr || dataLength == 0) {
            Console.Error("[VideoEncoder] Failed to get block buffer data: %d", bufStatus);
            return;
        }
        
        // Get presentation timestamp
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        int64_t timestampUs = (int64_t)presentationTime.value * 1000000 / presentationTime.timescale;
        
        // Check if keyframe
        bool isKeyFrame = false;
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, FALSE);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            if (dict) {
                isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
            }
        }
        
        // Update statistics
        self->bytesEncoded_ += dataLength;
        
        // Call the user callback if set
        if (self->encodedFrameCallback_) {
            self->encodedFrameCallback_((const uint8_t*)dataPtr, dataLength, timestampUs, isKeyFrame);
        }
    }
}

int VideoEncoderH264::getEstimatedLatencyMs() const
{
    if (!compressionSession_) return 0;
    
    // Estimate based on frame delay and framerate
    // With MaximumFrameDelayCount=1 and 60fps: ~17ms
    // With MaximumFrameDelayCount=2 and 60fps: ~33ms
    // Plus VideoToolbox processing: ~5-10ms
    
    switch (config_.preset) {
        case EncodingPreset::RealTime:
            return 20;   // 17ms frame delay + 3ms processing
        case EncodingPreset::Balanced:
            return 35;   // 33ms frame delay + 2ms processing
        case EncodingPreset::Quality:
            return 50;   // 50ms frame delay + 0ms processing
    }
    
    return 20;
}

double VideoEncoderH264::getAverageBitrateMbps() const
{
    if (framesEncoded_ == 0) return 0.0;
    
    // Average bitrate = total bytes * 8 / (framerate * number of frames)
    // In Mbps: (bytesEncoded * 8 / 1000000) / (framesEncoded / frameRate)
    
    double secondsElapsed = (double)framesEncoded_ / config_.frameRate;
    if (secondsElapsed <= 0) return 0.0;
    
    double bitsEncoded = (double)bytesEncoded_ * 8.0;
    return bitsEncoded / (secondsElapsed * 1000000.0);
}

} // namespace AYS2::Casting

#else

// Non-Apple stub implementations
namespace AYS2::Casting {

std::shared_ptr<VideoEncoder> VideoEncoder::create(const VideoEncodingConfig& config)
{
    return nullptr;
}

VideoEncoderH264::VideoEncoderH264(const VideoEncodingConfig& config) : VideoEncoder(config) { }
VideoEncoderH264::~VideoEncoderH264() { }
bool VideoEncoderH264::initialize() { return false; }
void VideoEncoderH264::shutdown() { }
bool VideoEncoderH264::encodeFrame(const uint8_t*, int, int, int64_t, bool) { return false; }
int VideoEncoderH264::getEstimatedLatencyMs() const { return 0; }
double VideoEncoderH264::getAverageBitrateMbps() const { return 0.0; }
CVPixelBufferRef VideoEncoderH264::createPixelBuffer(const uint8_t*, int, int) { return nullptr; }

} // namespace AYS2::Casting

#endif
