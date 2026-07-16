# Phase 2: AirPlay 2 Video Streaming Implementation

**Status**: ACTIVE  
**Date Started**: July 16, 2026  
**Target Completion**: July 26, 2026 (7-10 days)  
**Priority**: P0 - Unblocks all testing

---

## 🎯 Objective

Complete H.264 video encoding and AirPlay 2 frame transport to enable real-time PS2 game streaming to Apple TV with **<40ms latency**.

---

## ✅ COMPLETED (Phase 2 Progress)

### 1. VideoToolbox Integration ✅
- [x] VTCompressionSession creation with proper configuration
- [x] H.264 encoder setup with real-time parameters
- [x] Callback handler for encoded frame output
- [x] Bitrate and frame rate configuration (5 Mbps, 60 FPS)
- [x] Profile level set to Main 4.0 (1080p60 support)

**File**: `src/cpp/Casting/AirPlayManager.mm` - `connect()` method

**What Works**:
```cpp
VTCompressionSessionCreate() called with:
- Codec: H.264
- Resolution: 1920x1080
- Bitrate: 5 Mbps  
- Frame rate: 60 FPS
- Real-time mode: Enabled
- Frame delay: 2 frames (~33ms)
- Callback: encodeCallbackHandler()
```

### 2. Frame Encoding Pipeline ✅
- [x] CVPixelBuffer creation from raw frame data
- [x] Frame submission to encoder via VTCompressionSessionEncodeFrame()
- [x] Timestamp handling (CMTime conversion)
- [x] Encoded frame callback handler infrastructure

**File**: `src/cpp/Casting/AirPlayManager.mm` - `submitVideoFrame()` method

**What Works**:
```cpp
submitVideoFrame(frameData, 1920, 1080, timestamp_us)
  ↓
CVPixelBuffer creation (BGRA format)
  ↓
CMTime timestamp conversion
  ↓
VTCompressionSessionEncodeFrame()
  ↓
encodeCallbackHandler() receives encoded H.264 NAL units
```

### 3. Encoded Frame Capture ✅
- [x] Static callback handler for VideoToolbox
- [x] Frame data extraction from CMSampleBuffer
- [x] Key frame detection (I-frame identification)
- [x] Sample buffer block buffer retrieval

**File**: `src/cpp/Casting/AirPlayManager.mm` - `handleEncodedFrame()` method

**What Works**:
```cpp
encodeCallbackHandler() receives CMSampleBufferRef
  ↓
Extract CMBlockBuffer from sample
  ↓
Get raw H.264 data pointer + length
  ↓
Detect keyframe status
  ↓
handleEncodedFrame() processes result
```

### 4. Error Handling & Logging ✅
- [x] Comprehensive error checking at each step
- [x] Console logging for debugging
- [x] Status verification

---

## 🔧 TODO: AirPlay 2 Network Transport

### Phase 2A: Network Stack (NEXT)

**File**: `src/cpp/Casting/AirPlayManager.mm` (new methods needed)

**Tasks**:

#### 1. TCP/UDP Connection to AirPlay Device
```cpp
// Add to AirPlayManager::connect()
nw_connection_t createAirPlayConnection(std::string ipAddress, uint16_t port);
{
    // Create Network Framework connection
    // AirPlay 2 uses port 7000 (TCP) or custom RTSP port
    // Connection state handling
}
```

**Subtasks**:
- [ ] Initialize nw_connection_t with AirPlay device IP/port
- [ ] Configure connection parameters (TCP + TLS)
- [ ] Add state change handlers
- [ ] Implement connection retry logic
- [ ] Handle connection timeouts

**Resources**:
```objc
// Import needed
#import <Network/Network.h>

// Connection setup pattern
dispatch_queue_t queue = dispatch_queue_create("com.ayano.airplay", DISPATCH_QUEUE_SERIAL);
nw_connection_t conn = nw_connection_create(endpoint, parameters);
nw_connection_set_queue(conn, queue);
nw_connection_set_state_changed_handler(conn, ^(nw_connection_state_t state, nw_error_t error) {
    // Handle connection state
});
nw_connection_start(conn);
```

#### 2. AirPlay 2 Protocol Handler
```cpp
// New class: AirPlayProtocol (AirPlayProtocol.h/mm)
class AirPlayProtocol {
public:
    // Frame packaging for AirPlay 2
    void encodeFrame(uint8_t* h264Data, size_t dataSize, bool isKeyFrame);
    
    // Send to device
    void transmitFrame(nw_connection_t connection, AirPlayFrame& frame);
    
private:
    // AirPlay 2 frame structure with timing/metadata
    struct AirPlayFrame {
        uint32_t sequenceNumber;
        uint32_t timestamp;
        uint8_t* payload;
        size_t payloadSize;
        bool isKeyFrame;
    };
};
```

**Subtasks**:
- [ ] Research AirPlay 2 protocol (H.264 RTP payload format)
- [ ] Implement frame packaging (sequence numbers, timestamps)
- [ ] Add frame headers for AirPlay 2
- [ ] Implement payload fragmentation if needed (>1500 bytes)

#### 3. Asynchronous Frame Transmission
```cpp
void AirPlayManager::handleEncodedFrame(CMSampleBufferRef sampleBuffer)
{
    // Extract H.264 data
    // Package as AirPlay frame
    // Queue for transmission
    // Send via Network Framework
}
```

**Subtasks**:
- [ ] Create frame queue (thread-safe)
- [ ] Implement frame transmission thread
- [ ] Add frame timing info to packets
- [ ] Handle frame drops if queue overflows
- [ ] Monitor transmission latency

### Phase 2B: Testing & Optimization (AFTER 2A)

#### 1. Apple TV Testing
- [ ] Deploy app to Apple TV 4K (physical device)
- [ ] Start device discovery (should find TV on network)
- [ ] Select Apple TV as target
- [ ] Launch game and start casting
- [ ] Verify video appears on TV
- [ ] Measure latency with frame counter

**Equipment Needed**:
- Apple TV 4K (2nd gen or newer) on same WiFi network
- Test game with visible frame counter
- Network latency measurement tool

**Acceptance Criteria**:
- ✅ Video streams to Apple TV
- ✅ <40ms latency confirmed
- ✅ No major frame drops
- ✅ Audio synced with video

#### 2. iPad/iPhone External Display Testing
- [ ] Test with iPad connected to external display
- [ ] Test with iPhone using external monitor via USB-C
- [ ] Verify lower latency than AirPlay (Native Framework preferred)

#### 3. Performance Optimization
- [ ] Measure CPU usage during encoding
- [ ] Measure GPU usage (Metal)
- [ ] Monitor memory allocation
- [ ] Check battery drain
- [ ] Optimize bitrate vs quality tradeoff

#### 4. Error Recovery
- [ ] Test network interruption handling
- [ ] Auto-reconnect on connection loss
- [ ] Frame buffer underrun recovery
- [ ] Graceful degradation if bitrate drops

---

## 📋 Implementation Checklist (Phase 2 TODO)

### Network Transport Layer
- [ ] Implement `AirPlayManager::createConnection()`
  - [ ] TCP connection setup to device port 7000
  - [ ] TLS certificate validation
  - [ ] Connection state handlers
  - [ ] Reconnection logic

- [ ] Implement AirPlay 2 protocol encoder
  - [ ] H.264 RTP payload format per RFC 3984
  - [ ] Frame sequencing
  - [ ] Timestamp calculation
  - [ ] Keyframe identification

- [ ] Implement frame transmission queue
  - [ ] Thread-safe queue (STL compatible)
  - [ ] Background transmission thread
  - [ ] Flow control (bitrate adaptation)
  - [ ] Frame drop detection

- [ ] Update `handleEncodedFrame()` to transmit
  - [ ] Extract NAL units from H.264 stream
  - [ ] Package into AirPlay frames
  - [ ] Queue for transmission
  - [ ] Update latency tracking

### Device Discovery Enhancement
- [ ] Discover Apple TV on network via Bonjour/mDNS
- [ ] Query device capabilities
- [ ] Get IP address + port
- [ ] Handle device coming/going offline
- [ ] Update device list in real-time

### Testing & Validation
- [ ] Compile without errors on iOS
- [ ] Run on simulator (will show errors but no TV)
- [ ] Deploy to physical iPhone/iPad
- [ ] Connect iPhone to external display
- [ ] Deploy to Apple TV 4K
- [ ] Test casting workflow
- [ ] Measure latency with frame markers
- [ ] Test reconnection after network loss

---

## 🔍 Key Implementation Details

### H.264 to AirPlay 2 Transmission

**AirPlay 2 Protocol Stack**:
```
Layer 4: AirPlay 2 Protocol (our implementation)
         ├─ Frame sequencing
         ├─ Timestamp synchronization
         └─ Device control

Layer 3: RTP/RTCP (H.264 payload)
         ├─ RFC 3984 H.264 over RTP
         └─ Packet fragmentation

Layer 2: UDP Transport
         └─ Port 7000 or alternate RTSP

Layer 1: WiFi (802.11)
         └─ Apple TV same local network
```

### VideoToolbox H.264 Output Format

VideoToolbox encoder produces:
```
AVCC Format (typical):
[NAL1][NAL2][NAL3]...
  │     │     │
  └─────┴─────┴─ H.264 Network Abstraction Layer (NAL) units
        ├─ Type 1: Slice (frame data)
        ├─ Type 5: IDR (keyframe)
        ├─ Type 7: SPS (sequence parameter set)
        └─ Type 8: PPS (picture parameter set)

For AirPlay transmission:
Need to extract individual NAL units
Add RTP headers
Sequence and timestamp them
Send via UDP to device
```

### Latency Budget

```
Game Rendering:        ~16ms (60 FPS)
H.264 Encoding:        ~10ms (VideoToolbox hardware)
Frame Transport:       ~5-10ms (WiFi network)
Apple TV Decoding:     ~5-10ms
Display Rendering:     ~16ms
─────────────────────────────────
TOTAL:                 <40ms TARGET ✅
```

---

## 🚀 Getting Started (Next Steps)

### Step 1: Network Connection (Days 1-2)
1. Research AirPlay 2 protocol documentation
2. Implement Network Framework connection to Apple TV
3. Add connection state handlers
4. Test TCP handshake

### Step 2: Frame Transport (Days 3-4)
1. Create AirPlayProtocol class
2. Implement H.264 RTP packetization
3. Add frame queuing
4. Implement async transmission thread

### Step 3: Integration (Days 5-6)
1. Wire `handleEncodedFrame()` to transmit
2. Add latency tracking
3. Implement frame drop detection
4. Add comprehensive logging

### Step 4: Testing (Days 7-10)
1. Deploy to physical device
2. Find Apple TV on network
3. Connect and start streaming
4. Measure latency
5. Optimize parameters
6. Error recovery testing

---

## 📚 Resources & References

### Apple Documentation
- AVFoundation Framework
- VideoToolbox Framework  
- Network Framework
- Core Media Framework

### RTP/H.264 Streaming
- RFC 3984 - RTP Payload Format for H.264 Video
- RFC 3550 - RTP: A Transport Protocol for Real-Time Applications

### AirPlay 2 Protocol (Community Research)
- Shairport-sync project (open-source AirPlay receiver)
- AirPlay 2 protocol reverse engineering
- Device discovery via Bonjour

### Performance Tuning
- H.264 profile levels and constraints
- Bitrate vs latency tradeoffs
- Frame buffering strategies
- Network QoS handling

---

## ✨ Success Criteria

### Phase 2 Complete When:
1. ✅ H.264 encoding working (confirmed via debug logs)
2. ✅ Network transmission implemented
3. ✅ Frame appears on physical Apple TV
4. ✅ Latency <40ms measured
5. ✅ Audio synchronized with video
6. ✅ Can select device and start/stop casting
7. ✅ Error handling for disconnections
8. ✅ Comprehensive logging for debugging

---

## 📝 Files to Modify/Create

```
MODIFIED:
├── src/cpp/Casting/AirPlayManager.h
│   └── Added: encodeCallbackHandler(), handleEncodedFrame()
│   └── Added: EncodedFrame structure

├── src/cpp/Casting/AirPlayManager.mm
│   ├── Enhanced: connect() with callback setup
│   ├── Implemented: submitVideoFrame()
│   ├── Implemented: submitAudioFrame()
│   └── Implemented: handleEncodedFrame()

NEW FILES (TODO):
├── src/cpp/Casting/AirPlayProtocol.h
│   └── AirPlay 2 protocol encoder (NAL→RTP)

└── src/cpp/Casting/AirPlayProtocol.mm
    └── RTP packetization + transmission logic
```

---

## 🎬 Phase 2 Completion Timeline

```
Week 1 (July 16-20)
├─ Day 1-2: Network connection setup + mDNS discovery
├─ Day 3-4: AirPlay 2 protocol implementation
└─ Day 5: Integration and initial testing

Week 2 (July 21-26)
├─ Day 6-7: Physical device testing + optimization
├─ Day 8-9: Error handling + latency tuning
└─ Day 10: Final validation and documentation

DELIVERABLE: AirPlay 2 video streaming working end-to-end ✨
```

---

**Last Updated**: July 16, 2026  
**Next Phase**: Phase 3 (Google Cast SDK integration)  
**Status**: 🟢 Ready to begin network implementation

