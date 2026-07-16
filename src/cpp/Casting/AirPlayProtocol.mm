// AirPlayProtocol.mm — AirPlay 2 protocol implementation for H.264 streaming
// SPDX-License-Identifier: GPL-3.0+

#include "AirPlayProtocol.h"
#include "common/Console.h"
#include <cstring>
#include <random>
#include <chrono>

namespace AYS2::Casting {

AirPlayProtocol::AirPlayProtocol()
    : ssrc_(0), sequenceNumber_(0), rtpTimestampBase_(0),
      captureTimeBase_(0), framesSent_(0), packetsSent_(0)
{
    initialize();
}

AirPlayProtocol::~AirPlayProtocol()
{
    reset();
}

void AirPlayProtocol::initialize()
{
    // Generate random SSRC (Synchronization Source)
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<uint32_t> dis(0, 0xFFFFFFFF);
    
    ssrc_ = dis(gen);
    sequenceNumber_ = dis(gen);
    rtpTimestampBase_ = dis(gen);
    captureTimeBase_ = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    Console.WriteLn("[AirPlayProtocol] Initialized: SSRC=0x%08X, initial seq=%u", 
        ssrc_, sequenceNumber_);
}

void AirPlayProtocol::reset()
{
    std::lock_guard<std::mutex> lock(queueMutex_);
    while (!transmissionQueue_.empty()) {
        transmissionQueue_.pop();
    }
    framesSent_ = 0;
    packetsSent_ = 0;
}

AirPlayFramePtr AirPlayProtocol::encodeFrame(const uint8_t* h264Data, size_t dataSize,
                                            int64_t timestampUs, bool isKeyFrame)
{
    if (!h264Data || dataSize == 0) {
        Console.Error("[AirPlayProtocol] Invalid H.264 data");
        return nullptr;
    }
    
    // Parse H.264 stream to extract NAL units
    std::vector<NALUnit> nalUnits = parseH264Stream(h264Data, dataSize);
    
    if (nalUnits.empty()) {
        Console.Error("[AirPlayProtocol] No NAL units found in H.264 data");
        return nullptr;
    }
    
    // Determine if frame is keyframe
    bool frameHasKeyframe = isKeyFrame || containsKeyFrame(nalUnits);
    
    // Calculate RTP timestamp (90kHz clock)
    // Assuming 60 FPS: each frame = 1500 RTP timestamp units (90000 / 60)
    int64_t timeElapsedUs = timestampUs - captureTimeBase_;
    uint32_t rtpTimestamp = rtpTimestampBase_ + (uint32_t)((timeElapsedUs * RTP_CLOCK_RATE) / 1000000LL);
    
    // Create RTP packets
    std::vector<AirPlayFramePtr> frames;
    
    // Check if we can fit all NAL units in a single STAP-A packet
    size_t totalSize = 0;
    for (const auto& nalu : nalUnits) {
        totalSize += nalu.length + 2;  // +2 for size field in STAP-A
    }
    
    if (totalSize + 12 < MAX_RTP_PAYLOAD) {
        // Use Single-Time Aggregation Packet
        auto frameData = createSTAPA(nalUnits, rtpTimestamp);
        
        auto frame = std::make_shared<AirPlayFrame>();
        frame->sequenceNumber = sequenceNumber_++;
        frame->timestamp = rtpTimestamp;
        frame->payloadType = 97;  // H.264
        frame->payload = frameData;
        frame->isKeyFrame = frameHasKeyframe;
        frame->captureTimeUs = timestampUs;
        
        frames.push_back(frame);
        
    } else {
        // Use Fragmentation Unit for each NAL unit
        for (const auto& nalu : nalUnits) {
            auto framedUnits = createFUA(nalu, rtpTimestamp, timestampUs);
            frames.insert(frames.end(), framedUnits.begin(), framedUnits.end());
        }
    }
    
    // Queue all frames for transmission
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        for (auto& frame : frames) {
            transmissionQueue_.push(frame);
        }
    }
    
    framesSent_++;
    packetsSent_ += frames.size();
    
    Console.WriteLn("[AirPlayProtocol] Encoded frame: %zu NAL units → %zu packets, keyframe=%s",
        nalUnits.size(), frames.size(), frameHasKeyframe ? "yes" : "no");
    
    // Return first frame or nullptr
    return frames.empty() ? nullptr : frames[0];
}

AirPlayFramePtr AirPlayProtocol::getNextTransmissionFrame()
{
    std::lock_guard<std::mutex> lock(queueMutex_);
    
    if (transmissionQueue_.empty())
        return nullptr;
    
    auto frame = transmissionQueue_.front();
    transmissionQueue_.pop();
    
    return frame;
}

bool AirPlayProtocol::hasPendingFrames() const
{
    std::lock_guard<std::mutex> lock(queueMutex_);
    return !transmissionQueue_.empty();
}

int AirPlayProtocol::getQueuedFrameCount() const
{
    std::lock_guard<std::mutex> lock(queueMutex_);
    return (int)transmissionQueue_.size();
}

std::vector<AirPlayProtocol::NALUnit> AirPlayProtocol::parseH264Stream(const uint8_t* data, 
                                                                       size_t length)
{
    std::vector<NALUnit> nalUnits;
    
    size_t offset = 0;
    while (offset < length) {
        // Find NAL unit start code (0x000001 or 0x00000001)
        size_t startCodeSize = 0;
        
        if (offset + 3 <= length && data[offset] == 0x00 && 
            data[offset+1] == 0x00 && data[offset+2] == 0x01) {
            startCodeSize = 3;
        } else if (offset + 4 <= length && data[offset] == 0x00 && 
                   data[offset+1] == 0x00 && data[offset+2] == 0x00 && 
                   data[offset+3] == 0x01) {
            startCodeSize = 4;
        } else {
            offset++;
            continue;
        }
        
        offset += startCodeSize;
        
        // Find next start code
        size_t nextOffset = offset;
        while (nextOffset + 3 <= length) {
            if (data[nextOffset] == 0x00 && data[nextOffset+1] == 0x00 &&
                (data[nextOffset+2] == 0x01 || 
                 (nextOffset + 4 <= length && data[nextOffset+3] == 0x01))) {
                break;
            }
            nextOffset++;
        }
        
        if (nextOffset > offset) {
            // Extract NAL unit type
            uint8_t nalByte = data[offset];
            H264NALUnitType type = (H264NALUnitType)(nalByte & 0x1F);
            
            NALUnit nalu;
            nalu.type = type;
            nalu.data = const_cast<uint8_t*>(data) + offset;
            nalu.length = nextOffset - offset;
            
            nalUnits.push_back(nalu);
        }
        
        offset = nextOffset;
    }
    
    return nalUnits;
}

bool AirPlayProtocol::containsKeyFrame(const std::vector<NALUnit>& nalUnits) const
{
    for (const auto& nalu : nalUnits) {
        if (nalu.type == H264NALUnitType::IDRSlice) {
            return true;
        }
    }
    return false;
}

std::vector<uint8_t> AirPlayProtocol::createSTAPA(const std::vector<NALUnit>& nalUnits,
                                                   uint32_t timestamp)
{
    std::vector<uint8_t> packet;
    
    // RTP header (12 bytes)
    RTPHeader rtp;
    rtp.version = 2;
    rtp.padding = 0;
    rtp.extension = 0;
    rtp.csrcCount = 0;
    rtp.marker = 1;  // Last packet of frame
    rtp.payloadType = 97;  // H.264
    rtp.sequenceNumber = sequenceNumber_++;
    rtp.timestamp = timestamp;
    rtp.ssrc = ssrc_;
    
    // Pack RTP header
    packet.push_back((rtp.version << 6) | (rtp.padding << 5) | (rtp.extension << 4) | rtp.csrcCount);
    packet.push_back((rtp.marker << 7) | rtp.payloadType);
    packet.push_back((rtp.sequenceNumber >> 8) & 0xFF);
    packet.push_back(rtp.sequenceNumber & 0xFF);
    packet.push_back((rtp.timestamp >> 24) & 0xFF);
    packet.push_back((rtp.timestamp >> 16) & 0xFF);
    packet.push_back((rtp.timestamp >> 8) & 0xFF);
    packet.push_back(rtp.timestamp & 0xFF);
    packet.push_back((rtp.ssrc >> 24) & 0xFF);
    packet.push_back((rtp.ssrc >> 16) & 0xFF);
    packet.push_back((rtp.ssrc >> 8) & 0xFF);
    packet.push_back(rtp.ssrc & 0xFF);
    
    // STAP-A payload (NAL header + aggregated units)
    uint8_t stapaHeader = 0x18;  // Type 24 (STAP-A) with F=0, NRI=0
    packet.push_back(stapaHeader);
    
    // Add each NAL unit with 2-byte size prefix
    for (const auto& nalu : nalUnits) {
        uint16_t naluSize = nalu.length;
        packet.push_back((naluSize >> 8) & 0xFF);
        packet.push_back(naluSize & 0xFF);
        packet.insert(packet.end(), nalu.data, nalu.data + nalu.length);
    }
    
    return packet;
}

std::vector<AirPlayFramePtr> AirPlayProtocol::createFUA(const NALUnit& nalUnit,
                                                        uint32_t timestamp,
                                                        int64_t captureTimeUs)
{
    std::vector<AirPlayFramePtr> frames;
    
    size_t offset = 1;  // Skip NAL header byte
    size_t payloadSize = MAX_RTP_PAYLOAD - 14;  // RTP header (12) + FU-A header (2)
    
    bool isFirstFragment = true;
    
    while (offset < nalUnit.length) {
        size_t fragmentSize = std::min(payloadSize, nalUnit.length - offset);
        
        // Create RTP packet
        auto frame = std::make_shared<AirPlayFrame>();
        frame->sequenceNumber = sequenceNumber_++;
        frame->timestamp = timestamp;
        frame->payloadType = 97;  // H.264
        frame->captureTimeUs = captureTimeUs;
        
        // FU-A header
        std::vector<uint8_t> payload;
        
        // FU indicator byte
        uint8_t fuIndicator = 0x1C;  // Type 28 (FU-A), NRI = 0
        payload.push_back(fuIndicator);
        
        // FU header byte
        uint8_t fuHeader = nalUnit.type & 0x1F;
        if (isFirstFragment) {
            fuHeader |= 0x80;  // Start bit
        }
        if (offset + fragmentSize >= nalUnit.length) {
            fuHeader |= 0x40;  // End bit
            frame->isKeyFrame = false;  // Last fragment
        }
        if (isFirstFragment) {
            frame->isKeyFrame = (nalUnit.type == H264NALUnitType::IDRSlice);
        }
        
        payload.push_back(fuHeader);
        
        // Add fragment data
        payload.insert(payload.end(), 
                      nalUnit.data + offset, 
                      nalUnit.data + offset + fragmentSize);
        
        frame->payload = payload;
        frames.push_back(frame);
        
        offset += fragmentSize;
        isFirstFragment = false;
    }
    
    return frames;
}

} // namespace AYS2::Casting
