// AirPlayFrameCapture.mm — Metal frame capture implementation for iOS/macOS
// Uses IOSurface for zero-copy GPU access
// SPDX-License-Identifier: GPL-3.0+

#include "AirPlayFrameCapture.h"
#include "AirPlayManager.h"
#include "CVPixelBufferPoolManager.h"
#include "FramePacingController.h"

#ifdef __APPLE__

#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#include "common/Console.h"

namespace AYS2::Casting {

AirPlayFrameCapture& AirPlayFrameCapture::getInstance()
{
    static AirPlayFrameCapture instance;
    return instance;
}

AirPlayFrameCapture::AirPlayFrameCapture()
    : enabled_(false), framesCaptured_(0), framesDropped_(0)
{
}

AirPlayFrameCapture::~AirPlayFrameCapture()
{
    shutdown();
}

void AirPlayFrameCapture::initialize()
{
    Console.WriteLn("[FrameCapture] Initializing with IOSurface zero-copy (GPU memory sharing)");
    
    // Initialize pixel buffer pool (IOSurface-backed, zero-copy)
    CVPixelBufferPoolManager::getInstance().initialize(1920, 1080, kCVPixelFormatType_32BGRA);
    
    // Initialize frame pacing controller
    FramePacingController::getInstance().initialize(60);
    
    enabled_ = false;
}

void AirPlayFrameCapture::shutdown()
{
    Console.WriteLn("[FrameCapture] Stats - Captured: %u, Dropped: %u, Jitter: %.2f ms", 
        framesCaptured_, framesDropped_, getAverageJitterMs());
    
    CVPixelBufferPoolManager::getInstance().shutdown();
    enabled_ = false;
}

void AirPlayFrameCapture::setEnabled(bool enabled)
{
    if (enabled == enabled_)
        return;
    
    enabled_ = enabled;
    if (enabled) {
        Console.WriteLn("[FrameCapture] Frame capture ENABLED - zero-copy IOSurface mode");
        framesCaptured_ = 0;
        framesDropped_ = 0;
    } else {
        Console.WriteLn("[FrameCapture] Frame capture DISABLED");
    }
}

CVPixelBufferRef AirPlayFrameCapture::createIOSurfacePixelBuffer(id<MTLTexture> texture)
{
    if (!texture) {
        return nullptr;
    }
    
    @autoreleasepool {
        // OPTIMIZED: Direct IOSurface access from Metal texture
        // Research: IOSurface is the backing store for Metal textures, no CPU involvement
        IOSurfaceRef ioSurface = (__bridge IOSurfaceRef)[texture iosurface];
        if (!ioSurface) {
            // Fallback: If texture isn't IOSurface-backed, get from pool
            Console.Warning("[FrameCapture] Metal texture not IOSurface-backed, using pool");
            CVPixelBufferRef poolBuffer = nullptr;
            if (CVPixelBufferPoolManager::getInstance().acquireBuffer(&poolBuffer)) {
                return poolBuffer;
            }
            return nullptr;
        }
        
        // Create CVPixelBuffer wrapping the IOSurface (zero-copy, no memory allocation)
        // This is the fastest path: Metal GPU memory → CVPixelBuffer reference → VideoToolbox
        CVPixelBufferRef pixelBuffer = nullptr;
        
        // Attachment dictionary ensures VideoToolbox compatibility
        NSDictionary* attachments = @{
            (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey: @(YES),
            (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{}
        };
        
        CVReturn status = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            ioSurface,
            (__bridge CFDictionaryRef)attachments,
            &pixelBuffer
        );
            nullptr,  // attributes (use IOSurface defaults)
            &pixelBuffer
        );
        
        if (status != kCVReturnSuccess) {
            Console.Error("[FrameCapture] Failed to create CVPixelBuffer from IOSurface: %d", status);
            return nullptr;
        }
        
        return pixelBuffer;
    }
}

void AirPlayFrameCapture::captureRenderTarget(void* metalTexture, int width, int height, int64_t timestampUs)
{
    if (!enabled_ || !metalTexture) {
        if (enabled_) {
            framesDropped_++;
        }
        return;
    }
    
    // Track frame timing for jitter detection
    FramePacingController& pacing = FramePacingController::getInstance();
    pacing.onFrameCompleted();
    
    @autoreleasepool {
        id<MTLTexture> texture = (__bridge id<MTLTexture>)metalTexture;
        if (!texture) {
            framesDropped_++;
            return;
        }
        
        // Create IOSurface-backed CVPixelBuffer (zero-copy - GPU memory sharing)
        CVPixelBufferRef pixelBuffer = createIOSurfacePixelBuffer(texture);
        
        if (!pixelBuffer) {
            framesDropped_++;
            return;
        }
        
        // Get accurate timestamp synchronized to display
        int64_t syncedTimestampUs = pacing.getCurrentFrameTimestampUs();
        
        // Submit to AirPlay manager for encoding (passes pixelBuffer, not raw data)
        AirPlayManager& airplayMgr = AirPlayManager::getInstance();
        if (airplayMgr.isConnected()) {
            // Use IOSurface pixel buffer directly (no CPU copy needed)
            airplayMgr.submitVideoFrame((const uint8_t*)pixelBuffer, width, height, syncedTimestampUs);
            framesCaptured_++;
        } else {
            framesDropped_++;
        }
        
        // Release pixel buffer (IOSurface stays in GPU memory)
        CVPixelBufferRelease(pixelBuffer);
    }
}

double AirPlayFrameCapture::getAverageJitterMs() const
{
    return FramePacingController::getInstance().getFrameJitterMs();
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

AirPlayFrameCapture& AirPlayFrameCapture::getInstance()
{
    static AirPlayFrameCapture instance;
    return instance;
}

AirPlayFrameCapture::AirPlayFrameCapture() { }
AirPlayFrameCapture::~AirPlayFrameCapture() { }
void AirPlayFrameCapture::initialize() { }
void AirPlayFrameCapture::shutdown() { }
void AirPlayFrameCapture::setEnabled(bool) { }
bool AirPlayFrameCapture::isEnabled() const { return false; }
void AirPlayFrameCapture::captureRenderTarget(void*, int, int, int64_t) { }
double AirPlayFrameCapture::getAverageJitterMs() const { return 0.0; }

} // namespace AYS2::Casting

#endif
