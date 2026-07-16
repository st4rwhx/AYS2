// CVPixelBufferPoolManager.h — Zero-copy CVPixelBuffer pool with IOSurface backing
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <cstdint>
#include <memory>

#ifdef __APPLE__
#include <CoreVideo/CoreVideo.h>
#include <IOSurface/IOSurface.h>
#include <Metal/Metal.h>
#endif

namespace AYS2::Casting {

class CVPixelBufferPoolManager {
public:
    static CVPixelBufferPoolManager& getInstance();
    
    // Initialize pool with target resolution and pixel format
    bool initialize(int width, int height, int pixelFormat = kCVPixelFormatType_32BGRA);
    void shutdown();
    
    // Get a pixel buffer from pool (zero-copy allocation)
    CVPixelBufferRef acquirePixelBuffer();
    
    // Release pixel buffer back to pool
    void releasePixelBuffer(CVPixelBufferRef pixelBuffer);
    
    // Get underlying IOSurface from pixel buffer (for Metal texture creation)
    IOSurfaceRef getIOSurface(CVPixelBufferRef pixelBuffer);
    
    // Create Metal texture from pixel buffer (zero-copy)
    id<MTLTexture> createMetalTexture(CVPixelBufferRef pixelBuffer, id<MTLDevice> device);
    
    // Statistics
    int getAvailableBuffers() const;
    int getAllocatedBuffers() const { return allocatedBuffers_; }
    
private:
    CVPixelBufferPoolManager();
    ~CVPixelBufferPoolManager();
    
    CVPixelBufferPoolManager(const CVPixelBufferPoolManager&) = delete;
    CVPixelBufferPoolManager& operator=(const CVPixelBufferPoolManager&) = delete;
    
#ifdef __APPLE__
    CVPixelBufferPoolRef pool_ = nullptr;
    CFDictionaryRef poolAttributes_ = nullptr;
    CFDictionaryRef pixelBufferAttributes_ = nullptr;
#endif
    
    int poolSize_ = 4;  // Number of buffers in pool
    int allocatedBuffers_ = 0;
    int width_ = 1920;
    int height_ = 1080;
};

} // namespace AYS2::Casting

