// CVPixelBufferPoolManager.mm — Zero-copy pixel buffer pool implementation
// SPDX-License-Identifier: GPL-3.0+

#include "CVPixelBufferPoolManager.h"

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#include "common/Console.h"

namespace AYS2::Casting {

CVPixelBufferPoolManager& CVPixelBufferPoolManager::getInstance()
{
    static CVPixelBufferPoolManager instance;
    return instance;
}

CVPixelBufferPoolManager::CVPixelBufferPoolManager()
    : pool_(nullptr), poolSize_(4), allocatedBuffers_(0)
{
}

CVPixelBufferPoolManager::~CVPixelBufferPoolManager()
{
    shutdown();
}

bool CVPixelBufferPoolManager::initialize(int width, int height, int pixelFormat)
{
    if (width <= 0 || height <= 0) {
        Console.Error("[CVPixelBufferPool] Invalid dimensions: %dx%d", width, height);
        return false;
    }
    
    width_ = width;
    height_ = height;
    
    Console.WriteLn("[CVPixelBufferPool] Initializing pool for %dx%d (format: %d, size: %d)",
        width, height, pixelFormat, poolSize_);
    
    @autoreleasepool {
        // Create pixel buffer pool attributes
        // IOSurface-backed buffers allow zero-copy GPU access
        NSDictionary* poolAttrs = @{
            (__bridge NSString*)kCVPixelBufferPoolMinimumBufferCountKey: @(poolSize_),
            (__bridge NSString*)kCVPixelBufferPoolMaximumBufferAgeKey: @(0.0)
        };
        
        // Create pixel buffer attributes with IOSurface backing
        // Research: IOSurface allows zero-copy GPU<->CPU<->VideoToolbox sharing
        // Must include Metal compatibility AND proper IOSurface properties
        NSDictionary* ioSurfaceProps = @{
            (__bridge NSString*)kIOSurfaceIsGlobal: @(YES),  // Allow cross-process sharing
            (__bridge NSString*)kIOSurfaceCacheMode: @(kIOMapWriteCombineCache)  // Optimize for GPU writes
        };
        
        NSDictionary* pbAttrs = @{
            (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey: @(pixelFormat),
            (__bridge NSString*)kCVPixelBufferWidthKey: @(width),
            (__bridge NSString*)kCVPixelBufferHeightKey: @(height),
            (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey: ioSurfaceProps,  // Enable IOSurface with props
            (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey: @(YES),  // Metal texture compatibility
            (__bridge NSString*)kCVPixelBufferOpenGLESCompatibilityKey: @(NO),  // Don't need OpenGL (Metal only)
            // CRITICAL: These attachments ensure VideoToolbox can use the buffer directly
            (__bridge NSString*)kCVPixelBufferExtendedPixelsLeftKey: @(0),
            (__bridge NSString*)kCVPixelBufferExtendedPixelsRightKey: @(0),
            (__bridge NSString*)kCVPixelBufferExtendedPixelsTopKey: @(0),
            (__bridge NSString*)kCVPixelBufferExtendedPixelsBottomKey: @(0),
            (__bridge NSString*)kCVPixelBufferBytesPerRowAlignmentKey: @(16)  // 16-byte alignment for hardware
        };
        
        // Create the pool
        CVReturn status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            (__bridge CFDictionaryRef)poolAttrs,
            (__bridge CFDictionaryRef)pbAttrs,
            &pool_
        );
        
        if (status != kCVReturnSuccess) {
            Console.Error("[CVPixelBufferPool] Failed to create pool: %d", status);
            return false;
        }
        
        // Pre-allocate buffers to warm up the pool
        CVPixelBufferRef warmupBuffer = nullptr;
        for (int i = 0; i < poolSize_; i++) {
            status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool_, &warmupBuffer);
            if (status != kCVReturnSuccess) {
                Console.Error("[CVPixelBufferPool] Failed to pre-allocate buffer %d: %d", i, status);
                if (warmupBuffer) CVPixelBufferRelease(warmupBuffer);
                CVPixelBufferPoolRelease(pool_);
                pool_ = nullptr;
                return false;
            }
            CVPixelBufferRelease(warmupBuffer);
        }
        
        allocatedBuffers_ = poolSize_;
        Console.WriteLn("[CVPixelBufferPool] Pool created with %d buffers (IOSurface-backed, zero-copy)",
            poolSize_);
    }
    
    return true;
}

void CVPixelBufferPoolManager::shutdown()
{
    if (!pool_) {
        return;
    }
    
    Console.WriteLn("[CVPixelBufferPool] Shutting down (allocated: %d)", allocatedBuffers_);
    
    @autoreleasepool {
        CVPixelBufferPoolFlush(pool_, kCVPixelBufferPoolFlushExcessBuffers);
        CVPixelBufferPoolRelease(pool_);
        pool_ = nullptr;
        allocatedBuffers_ = 0;
    }
}

CVPixelBufferRef CVPixelBufferPoolManager::acquirePixelBuffer()
{
    if (!pool_) {
        Console.Error("[CVPixelBufferPool] Pool not initialized");
        return nullptr;
    }
    
    @autoreleasepool {
        CVPixelBufferRef pixelBuffer = nullptr;
        
        // Create with fast allocation from pool (zero-copy since IOSurface-backed)
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool_,
            &pixelBuffer
        );
        
        if (status != kCVReturnSuccess) {
            Console.Error("[CVPixelBufferPool] Failed to acquire buffer: %d", status);
            return nullptr;
        }
        
        // Zero the buffer (critical for clean frame initialization)
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        memset(baseAddress, 0, bytesPerRow * height_);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        return pixelBuffer;
    }
}

void CVPixelBufferPoolManager::releasePixelBuffer(CVPixelBufferRef pixelBuffer)
{
    if (pixelBuffer) {
        CVPixelBufferRelease(pixelBuffer);
    }
}

IOSurfaceRef CVPixelBufferPoolManager::getIOSurface(CVPixelBufferRef pixelBuffer)
{
    if (!pixelBuffer) {
        return nullptr;
    }
    
    @autoreleasepool {
        // IOSurface is attached to the pixel buffer
        IOSurfaceRef ioSurface = CVPixelBufferGetIOSurface(pixelBuffer);
        return ioSurface;
    }
}

id<MTLTexture> CVPixelBufferPoolManager::createMetalTexture(CVPixelBufferRef pixelBuffer, id<MTLDevice> device)
{
    if (!pixelBuffer || !device) {
        return nullptr;
    }
    
    @autoreleasepool {
        IOSurfaceRef ioSurface = CVPixelBufferGetIOSurface(pixelBuffer);
        if (!ioSurface) {
            Console.Error("[CVPixelBufferPool] Pixel buffer has no IOSurface");
            return nullptr;
        }
        
        // Create Metal texture from IOSurface (zero-copy GPU access)
        MTLTextureDescriptor* texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                             width:width_
                                                                                            height:height_
                                                                                         mipmapped:NO];
        texDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        texDesc.storageMode = MTLStorageModeShared;
        
        id<MTLTexture> texture = [device newTextureWithDescriptor:texDesc iosurface:ioSurface plane:0];
        
        if (!texture) {
            Console.Error("[CVPixelBufferPool] Failed to create Metal texture from IOSurface");
            return nullptr;
        }
        
        return texture;
    }
}

int CVPixelBufferPoolManager::getAvailableBuffers() const
{
    if (!pool_) {
        return 0;
    }
    
    @autoreleasepool {
        // Try to acquire a buffer to check pool status
        CVPixelBufferRef testBuffer = nullptr;
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool_, &testBuffer);
        
        if (testBuffer) {
            CVPixelBufferRelease(testBuffer);
            return poolSize_;  // At least one available
        }
        
        return 0;  // Pool exhausted
    }
}

} // namespace AYS2::Casting

#else

namespace AYS2::Casting {

CVPixelBufferPoolManager& CVPixelBufferPoolManager::getInstance()
{
    static CVPixelBufferPoolManager instance;
    return instance;
}

CVPixelBufferPoolManager::CVPixelBufferPoolManager() { }
CVPixelBufferPoolManager::~CVPixelBufferPoolManager() { }
bool CVPixelBufferPoolManager::initialize(int, int, int) { return false; }
void CVPixelBufferPoolManager::shutdown() { }
CVPixelBufferRef CVPixelBufferPoolManager::acquirePixelBuffer() { return nullptr; }
void CVPixelBufferPoolManager::releasePixelBuffer(CVPixelBufferRef) { }
IOSurfaceRef CVPixelBufferPoolManager::getIOSurface(CVPixelBufferRef) { return nullptr; }
id<MTLTexture> CVPixelBufferPoolManager::createMetalTexture(CVPixelBufferRef, id<MTLDevice>) { return nullptr; }
int CVPixelBufferPoolManager::getAvailableBuffers() const { return 0; }

} // namespace AYS2::Casting

#endif
