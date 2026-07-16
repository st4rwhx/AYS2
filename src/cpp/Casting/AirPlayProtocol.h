// AirPlayProtocol.h — AirPlay 2 protocol encoder for H.264 RTP streaming
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include <cstdint>
#include <vector>
#include <memory>
#include <queue>
#include <mutex>

namespace AYS2::Casting {

// AirPlay 2 Frame structure for transmission
struct AirPlayFrame {
    uint32_t sequenceNumber;      // RTP sequence number
    uint32_t timestamp;            // RTP timestamp (90kHz clock)
    uint8_t payloadType;          // RTP payload type (97 for H.264)
    std::vector<uint8_t> payload; // Encoded H.264 data (one or more NAL units)
    bool isKeyFrame;              // True if frame contains IDR (I-frame)
    int64_t captureTimeUs;        // Capture timestamp for latency calculation
};

using AirPlayFramePtr = std::shared_ptr<AirPlayFrame>;

// H.264 NAL Unit types
enum class H264NALUnitType : uint8_t {
    Unspecified = 0,
    Slice = 1,
    DPA = 2,
    DPB = 3,
    DPC = 4,
    IDRSlice = 5,  // Keyframe
    SEI = 6,
    SPS = 7,       // Sequence Parameter Set
    PPS = 8,       // Picture Parameter Set
    AUD = 9,
    EOSeq = 10,
    EOStream = 11,
    Filler = 12,
    SPSExt = 13,
    PrefixNAL = 14,
    SubsetSPS = 15,
    DPS = 16,
    Reserved17 = 17,
    Reserved18 = 18,
    SLAux = 19,
    SLExt = 20,
    SLWithoutPartitioning = 21,
    CodedSliceInCodingTypeC = 22,
};

// RTP Header (first 12 bytes minimum)
struct RTPHeader {
    uint8_t version : 2;          // RTP version (2)
    uint8_t padding : 1;          // Padding flag
    uint8_t extension : 1;        // Extension flag
    uint8_t csrcCount : 4;        // CSRC count
    
    uint8_t marker : 1;           // Marker bit
    uint8_t payloadType : 7;      // Payload type (97 for H.264)
    
    uint16_t sequenceNumber;      // Sequence number
    uint32_t timestamp;           // Timestamp (90kHz for video)
    uint32_t ssrc;                // Synchronization source
    // CSRC list follows if csrcCount > 0
};

class AirPlayProtocol {
public:
    AirPlayProtocol();
    ~AirPlayProtocol();
    
    // Initialize protocol (set up SSRC, initial sequence number, etc.)
    void initialize();
    
    // Process encoded H.264 frame and create AirPlay frame for transmission
    // Input: raw H.264 data from VideoToolbox encoder
    // Output: AirPlayFrame ready for RTP transmission
    AirPlayFramePtr encodeFrame(const uint8_t* h264Data, size_t dataSize, 
                                int64_t timestampUs, bool isKeyFrame);
    
    // Get the next frame to send (respects fragmentation if needed)
    AirPlayFramePtr getNextTransmissionFrame();
    
    // Check if there are frames queued for transmission
    bool hasPendingFrames() const;
    
    // Frame statistics
    uint32_t getTotalFramesSent() const { return framesSent_; }
    int getQueuedFrameCount() const;
    
    // Reset protocol state (e.g., on connection loss)
    void reset();
    
private:
    // Parse H.264 stream and extract NAL units
    struct NALUnit {
        H264NALUnitType type;
        uint8_t* data;
        size_t length;
    };
    std::vector<NALUnit> parseH264Stream(const uint8_t* data, size_t length);
    
    // Check if frame contains keyframe (IDR NAL unit)
    bool containsKeyFrame(const std::vector<NALUnit>& nalUnits) const;
    
    // Create RTP packet for H.264 (handles STAP-A, FU-A fragmentation if needed)
    std::vector<uint8_t> createRTPPacket(const uint8_t* payload, size_t payloadSize,
                                        bool isMarker, uint32_t timestamp);
    
    // Single-Time Aggregation Packet (STAP-A) for multiple NAL units
    std::vector<uint8_t> createSTAPA(const std::vector<NALUnit>& nalUnits,
                                    uint32_t timestamp);
    
    // Fragmentation Unit (FU-A) for large NAL units (>1400 bytes)
    std::vector<AirPlayFramePtr> createFUA(const NALUnit& nalUnit,
                                          uint32_t timestamp, int64_t captureTimeUs);
    
    // Member variables
    uint32_t ssrc_;                              // Synchronization source
    uint32_t sequenceNumber_;                    // Current sequence number
    uint32_t rtpTimestampBase_;                  // RTP timestamp base (90kHz)
    int64_t captureTimeBase_;                    // Capture time reference
    
    std::queue<AirPlayFramePtr> transmissionQueue_;
    mutable std::mutex queueMutex_;
    
    uint32_t framesSent_;
    uint32_t packetsSent_;
    
    static constexpr size_t MAX_RTP_PAYLOAD = 1400;  // Keep under MTU (1500)
    static constexpr uint32_t RTP_CLOCK_RATE = 90000; // H.264 uses 90kHz
};

} // namespace AYS2::Casting
