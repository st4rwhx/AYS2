// VideoEncoder.h — H.264 video encoding via VideoToolbox
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <cstdint>
#include <cstddef>
#include <functional>
#include <memory>

#ifdef __APPLE__
#include <VideoToolbox/VideoToolbox.h>
#endif

namespace AYS2::Casting {

enum class VideoCodec {
    H264,
    H265,
    VP8,
    VP9,
};

enum class EncodingPreset {
    RealTime,      // Low latency, lower quality
    Balanced,      // Medium latency, medium quality
    Quality,       // Higher latency, higher quality
};

struct VideoEncodingConfig {
    int width = 1920;
    int height = 1080;
    int frameRate = 60;
    int bitrateMbps = 8;
    VideoCodec codec = VideoCodec::H264;
    EncodingPreset preset = EncodingPreset::RealTime;
    bool hardwareAccelerated = true;
};

// Frame timing info for synchronization
struct VideoFrameTiming {
    int64_t presentationTimeUs;  // Accurate presentation timestamp
    int64_t captureTimeUs;       // When frame was captured
    double frameTimeMs;          // Actual frame interval
    double jitterMs;             // Frame timing jitter
};

using EncodedFrameCallback = std::function<void(const uint8_t* data, size_t size, int64_t timestampUs, bool isKeyframe)>;

class VideoEncoder {
public:
    static std::shared_ptr<VideoEncoder> create(const VideoEncodingConfig& config);
    
    virtual ~VideoEncoder() = default;
    
    // Configuration
    virtual bool initialize() = 0;
    virtual void shutdown() = 0;
    virtual bool isInitialized() const = 0;
    
    // Encoding
    virtual bool encodeFrame(const uint8_t* frameData, int width, int height, 
                            int64_t timestampUs, bool forceKeyframe = false) = 0;
    
    // Callbacks
    virtual void setEncodedFrameCallback(EncodedFrameCallback callback) = 0;
    
    // Status
    virtual int getEstimatedLatencyMs() const = 0;
    virtual int getFramesEncoded() const = 0;
    virtual int getFramesDropped() const = 0;
    virtual double getAverageBitrateMbps() const = 0;
    
protected:
    VideoEncoder(const VideoEncodingConfig& config) : config_(config) {}
    
    VideoEncodingConfig config_;
};

#ifdef __APPLE__
class VideoEncoderH264 : public VideoEncoder {
public:
    explicit VideoEncoderH264(const VideoEncodingConfig& config);
    ~VideoEncoderH264() override;
    
    bool initialize() override;
    void shutdown() override;
    bool isInitialized() const override { return compressionSession_ != nullptr; }
    
    bool encodeFrame(const uint8_t* frameData, int width, int height, 
                    int64_t timestampUs, bool forceKeyframe = false) override;
    
    void setEncodedFrameCallback(EncodedFrameCallback callback) override {
        encodedFrameCallback_ = callback;
    }
    
    int getEstimatedLatencyMs() const override;
    int getFramesEncoded() const override { return framesEncoded_; }
    int getFramesDropped() const override { return framesDropped_; }
    double getAverageBitrateMbps() const override;
    
private:
    VTCompressionSessionRef compressionSession_ = nullptr;
    EncodedFrameCallback encodedFrameCallback_;
    
    int framesEncoded_ = 0;
    int framesDropped_ = 0;
    uint64_t bytesEncoded_ = 0;
    
    static void compressionOutputCallback(void* refCon, void* sourceFrameRefCon,
                                         OSStatus status, VTEncodeInfoFlags infoFlags,
                                         CMSampleBufferRef sampleBuffer);
    
    void handleEncodedFrame(OSStatus status, CMSampleBufferRef sampleBuffer);
    CVPixelBufferRef createPixelBuffer(const uint8_t* frameData, int width, int height);
};
#endif

} // namespace AYS2::Casting
