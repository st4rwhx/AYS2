# AYS2 Hybrid Multi-Device Casting Architecture
## Universal Support: Apple TV, Android TV, Chromecast, Smart TVs, Mobile Devices

**Status**: Architecture Finalized (Research Complete)  
**Date**: 2026-07-16  
**Complexity**: High (250+ hours)  
**Timeline**: 6-8 weeks with phased implementation

---

## 🎯 EXECUTIVE SUMMARY

**Goal**: Single casting system that works on **ALL devices and platforms**
- ✅ Apple TV (via AirPlay 2 + Network Framework)
- ✅ Chromecast (via Google Cast SDK)
- ✅ Android TV (via Google Cast SDK + mDNS)
- ✅ Smart TVs (DLNA/UPnP discovery + custom receiver)
- ✅ Mobile phones/tablets (WebRTC browser receiver)
- ✅ macOS/Linux (WebRTC browser receiver)

**Key Finding**: Use a **hybrid stack** where each platform gets its native optimal protocol, with graceful fallback to WebRTC universal receiver.

---

## 🏗️ HYBRID ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────┐
│     AYS2 iOS/Android App            │
│     (Casting Manager Abstraction)    │
└──────────────────┬──────────────────┘
                   │
        ┌──────────┼──────────┬──────────┬──────────┐
        │          │          │          │          │
   ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌──▼────┐ ┌──▼────────┐
   │ AirPlay│ │ Google │ │  DLNA  │ │ mDNS  │ │ WebRTC   │
   │   2    │ │ Cast   │ │ /UPnP  │ │Device │ │Signaling │
   │        │ │ SDK    │ │ Server │ │Picker │ │ Server   │
   └────┬───┘ └────┬───┘ └───┬────┘ └──┬────┘ └──┬────────┘
        │          │          │         │         │
   ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌──▼────┐ ┌──▼────────┐
   │ Apple  │ │Chrome- │ │  DLNA  │ │ Apple │ │ Browser  │
   │   TV   │ │ cast   │ │Renderer│ │  TV   │ │ Receiver │
   │        │ │& Andoid│ │(custom)│ │ (iOS) │ │ (Web)    │
   │ 4K     │ │  TV    │ │        │ │ 16+   │ │          │
   │        │ │        │ │        │ │       │ │ Desktop/ │
   │ <40ms  │ │<80ms   │ │ 1-3s   │ │<40ms  │ │<500ms    │
   └────────┘ └────────┘ └────────┘ └───────┘ └──────────┘
   (Native)   (Native)   (Network)  (Native) (Universal)
```

---

## 📊 COMPARATIVE ANALYSIS

| Feature | AirPlay 2 | Google Cast | DLNA/UPnP | mDNS/Bonjour | WebRTC |
|---------|-----------|-------------|-----------|--------------|--------|
| **Supported Devices** | Apple TV, iPad, iPhone | Chromecast, Android TV, Smart TVs | Samsung, LG, Sony, etc. | iOS, macOS, Linux | All browsers |
| **Latency** | <40ms | 80-120ms | 1-3s | <40ms | <500ms |
| **Setup Complexity** | Native iOS only | Medium (iOS+Android) | Low (discovery) | Low | High (server needed) |
| **Device Discovery** | System UI | Google Cast Discovery | SSDP/UPnP | mDNS/DNS-SD | Manual entry |
| **Video Codec** | H.264/HEVC | H.264 | H.264 (custom) | H.264/HEVC | VP8/VP9/H.264 |
| **Audio Quality** | AAC, PCM | AAC, Opus | Depends | AAC, PCM | Opus, AAC |
| **Gaming Viable?** | ✅ Yes (<40ms) | ⚠️ Limited (80ms) | ❌ No (1-3s) | ✅ Yes (<40ms) | ⚠️ Limited (500ms) |
| **Infrastructure** | None | Google servers | None | None | Signaling server |
| **Cross-Platform** | Apple only | iOS + Android | Varies | iOS + Android | Universal |
| **Reliability** | Excellent | Very Good | Good | Excellent | Good |

---

## 🎮 GAMING LATENCY REQUIREMENTS

**For responsive gameplay**:
- **Rhythm games** (Beat Saber, osu!): <40ms mandatory
- **Fast-paced games** (Monster Hunter, FPS): 40-80ms acceptable
- **Turn-based games** (RPG, Strategy): <500ms acceptable

**Our architecture**:
- **Tier 1 (Fast)**: AirPlay 2, Network Framework, mDNS → <40ms ✅ BEST
- **Tier 2 (Medium)**: Google Cast → 80-120ms ✅ PLAYABLE
- **Tier 3 (Acceptable)**: WebRTC → <500ms ✅ FALLBACK
- **Tier 4 (Slow)**: DLNA → 1-3s ⚠️ NOT FOR GAMING

---

## 🔧 IMPLEMENTATION PHASES

### **PHASE 1: Device Discovery & Routing Layer (2-3 weeks)**

**Goal**: Unified device discovery across all platforms

**Components**:
1. **Abstraction Layer** (`CastingManager.mm/h`)
   - Single interface for all casting backends
   - Automatic protocol selection based on device type
   - Fallback chain: Native → Fastest Available → WebRTC

2. **Device Discovery**
   - **iOS/macOS**: Use `Network.framework` + `DeviceDiscoveryUI` (iOS 16+)
   - **Android**: `MediaRouter2` API (modern) + `NSD` (Network Service Discovery)
   - **mDNS/Bonjour**: Implement via `jmDNS` (cross-platform Java/Kotlin library)
   - **SSDP/UPnP**: Use `libupnp` C library (platform-agnostic)

3. **Device Registry**
   - Cache discovered devices with metadata (name, IP, port, protocol)
   - Persistent storage for recently used devices
   - Automatic reconnect logic

**Files to Create**:
```
src/cpp/Casting/
├── CastingManager.h              (abstraction interface)
├── CastingManager.mm             (iOS implementation)
├── DeviceDiscovery.h             (discovery abstraction)
├── DeviceDiscovery.mm            (mDNS + Network Framework)
├── CastingDevice.h               (device model)
└── CastingSession.h              (session state)
```

**Dependencies**:
- iOS: Network.framework (built-in)
- Cross-platform: `apple/mDNSResponder` (already in SDL3)

---

### **PHASE 2: AirPlay 2 & Network Framework Support (2-3 weeks)**

**Goal**: Native Apple TV casting with <40ms latency

**Components**:
1. **AirPlay 2 Manager** (`AirPlayManager.mm`)
   - Extend existing audio AirPlay support to video
   - `AVAudioSession` routing (audio already exists)
   - Metal render target capture
   - H.264 hardware encoding via `VideoToolbox`

2. **External Display Handling**
   - Monitor `UIScreen.screens` for connected displays
   - Dual render path: primary display + AirPlay
   - Screen rotation/resolution changes

3. **Video Capture Pipeline**
   ```
   Game Metal Render → MTLCommandBuffer → Texture Copy
                                      ↓
                              VideoToolbox H.264 Encoder
                                      ↓
                              AirPlay 2 Transport Layer
   ```

**Files to Create**:
```
src/cpp/IOS/
├── AirPlayManager.mm             (AirPlay 2 video + audio)
├── VideoCapture.mm               (Metal render target capture)
└── VideoEncoder.mm               (H.264 encoding)
```

**API Additions to ARMSX2Bridge**:
```objc
+ (BOOL)startAirPlay2Streaming;
+ (void)stopAirPlay2Streaming;
+ (NSArray<NSString*>*)availableAirPlayDevices;
+ (BOOL)isAirPlayStreamingActive;
```

**Testing**: Apple TV 4K (2nd+ gen), iPad Pro, iPhone 13+

---

### **PHASE 3: Google Cast SDK Integration (2-3 weeks)**

**Goal**: Chromecast + Android TV support

**Components**:
1. **Google Cast Manager** (`GoogleCastManager.mm` for iOS)
   - Integrate Google Cast SDK (already available for iOS)
   - Device discovery via `GCKCastContext`
   - Session management

2. **Custom Receiver App**
   - Browser-based receiver for generic Chromecast
   - Receives video stream via WebRTC or HTTP
   - Handles playback controls

3. **iOS Implementation**
   ```swift
   GCKCastContext initialization
   ↓
   GCKDiscoveryManager scans for Cast devices
   ↓
   User selects device from picker
   ↓
   GCKSession established
   ↓
   Video stream sent (WebRTC P2P or HTTP)
   ```

**Files to Create**:
```
src/cpp/Casting/
├── GoogleCastManager.mm           (Google Cast integration)
├── CastReceiverApp.js             (HTML5 receiver)
└── CastStreamingManager.mm        (video streaming)
```

**Dependencies**:
- `GoogleCastSDK-ios` (CocoaPod)

**Testing**: Chromecast 3+, Android TV devices, Sony Smart TVs

---

### **PHASE 4: DLNA/UPnP Server (1-2 weeks)**

**Goal**: Support older smart TVs (Samsung, LG, Sony from 2015+)

**Components**:
1. **Local DLNA Media Server**
   - Implement minimal UPnP/DLNA server
   - Use `libupnp` (C library, already in 3rdparty)
   - Advertise via SSDP (Simple Service Discovery Protocol)

2. **Video Serving**
   - Stream via HTTP Progressive Download
   - Support MPEG-TS or MP4 containers
   - Device automatically detects server on network

3. **Note**: DLNA has 1-3s latency → NOT suitable for gaming, only demos/video playback

**Files to Create**:
```
src/cpp/Casting/
├── DLNAServer.mm                 (DLNA/UPnP server)
├── UPnPAdvertiser.mm             (SSDP advertisements)
└── StreamingServer.mm            (HTTP video server)
```

**Dependencies**:
- `libupnp` (already in 3rdparty)

**Testing**: Samsung Smart TV, LG, Sony models with DLNA support

---

### **PHASE 5: WebRTC Universal Fallback (2-3 weeks)**

**Goal**: Browser-based receiver for any device with a web browser

**Components**:
1. **WebRTC Signaling Server** (Node.js or Python)
   - Handles SDP offer/answer exchanges
   - ICE candidate gathering
   - Runs on user's home network (Docker container recommended)

2. **iOS/Android WebRTC Client**
   - Capture game frames → VP8/H.264 codec
   - Send via WebRTC data channels + media tracks
   - Use `libdatachannel` or native WebRTC API

3. **Browser Receiver**
   - HTML5 canvas or video element
   - Automatically generated receiver page
   - QR code for easy mobile receiver access

4. **Architecture**:
   ```
   AYS2 App (iOS)           Signaling Server        Web Browser (TV/PC)
         │                       │                       │
         │─ Register & Get SDP ──│                       │
         │◄─ Server URL/QR ──────│                       │
         │                       │                       │
         │◄──────────────────────┤─ Notify receiver ───→│
         │                       │                       │
         │ WebRTC P2P Connection (once ICE candidates gathered)
         │◄─────────────────────────────────────────────→│
         │ Send H.264 stream + game audio                │
         │──────────────────────────────────────────────→│
   ```

**Files to Create**:
```
src/cpp/Casting/
├── WebRTCManager.mm              (WebRTC client)
├── RTCSignaling.mm               (signaling protocol)
├── FrameCapture.mm               (H.264 encoding)
└── WebRTCReceiver/
    ├── index.html                (browser receiver UI)
    ├── receiver.js               (WebRTC receiver logic)
    └── style.css
```

**Dependencies**:
- `libdatachannel` (C++ WebRTC library)
- Node.js signaling server (provided as Docker container)

**Testing**: Any browser (Chrome, Firefox, Safari, Edge)

---

### **PHASE 6: Swift UI Integration & Device Picker (1-2 weeks)**

**Goal**: Polish UX with device picker, connection status, etc.

**Components**:
1. **Device Picker View** (SwiftUI)
   - List all discovered devices grouped by type
   - Icon/thumbnail for each device
   - Connection status indicator
   - Recently used section

2. **Casting Menu** (in-game overlay)
   - Start/stop casting button
   - Device switcher
   - Stream quality settings
   - Latency monitor

3. **Connection Status** (persistent)
   - Active device badge
   - Network quality indicator
   - Auto-reconnect notifications

**Files to Modify**:
```
src/swift/Views/
├── GameOverlayContainer.swift    (add casting status)
├── QuickMenuView.swift           (add casting controls)
└── CastingDevicePickerView.swift (new)
```

**API Additions to ARMSX2Bridge**:
```objc
+ (NSArray<CastingDevice*>*)discoverCastingDevices;
+ (void)startCasting:(CastingDevice*)device;
+ (void)stopCasting;
+ (CastingDevice*)currentCastingDevice;
+ (int)castingLatencyMs;
```

---

## 📋 PROTOCOL SELECTION ALGORITHM

```cpp
// Pseudocode for automatic protocol selection
CastingProtocol selectProtocol(DiscoveredDevice device) {
    // Tier 1: Native fast protocols (<40ms)
    if (device.type == AIRPLAY_2) {
        return AIRPLAY_2;  // <40ms, iOS only
    }
    if (device.type == MCAST_BONJOUR) {
        return NETWORK_FRAMEWORK;  // <40ms, iOS/macOS
    }
    if (device.isAppleTV) {
        return AIRPLAY_2_FALLBACK_TO_NETWORK;
    }
    
    // Tier 2: Good protocols (80-120ms)
    if (device.hasGoogleCast) {
        return GOOGLE_CAST;  // 80-120ms, universal
    }
    
    // Tier 3: Acceptable protocols (500ms)
    if (userPreferencesAllow(WEBRTC)) {
        return WEBRTC;  // <500ms, universal fallback
    }
    
    // Tier 4: Slow protocols (1-3s, not for gaming)
    if (device.supportsDLNA) {
        return DLNA;  // 1-3s, legacy TVs only
    }
    
    return NONE;
}
```

---

## 🧪 TESTING MATRIX

| Device Type | Protocol | Latency | Status | Priority |
|-------------|----------|---------|--------|----------|
| Apple TV 4K (2nd+) | AirPlay 2 | <40ms | Phase 2 | P0 |
| iPad | Network Framework | <40ms | Phase 2 | P1 |
| iPhone 13+ | AirPlay 2 | <40ms | Phase 2 | P0 |
| Chromecast 3+ | Google Cast | 80ms | Phase 3 | P0 |
| Chromecast with Google TV | Google Cast | 80ms | Phase 3 | P0 |
| Android TV | Google Cast + mDNS | 80ms | Phase 3 | P0 |
| Samsung Smart TV (2015+) | DLNA or WebRTC | 1-3s / <500ms | Phase 4/5 | P1 |
| LG Smart TV (2015+) | DLNA or WebRTC | 1-3s / <500ms | Phase 4/5 | P1 |
| Sony Smart TV (2015+) | DLNA or WebRTC | 1-3s / <500ms | Phase 4/5 | P1 |
| macOS via Browser | WebRTC | <500ms | Phase 5 | P1 |
| Windows via Browser | WebRTC | <500ms | Phase 5 | P1 |
| Linux via Browser | WebRTC | <500ms | Phase 5 | P1 |

---

## 🔐 SECURITY CONSIDERATIONS

1. **AirPlay 2**: Built-in Apple security, TLS 1.2+ required
2. **Google Cast**: Requires developer SDK registration, device authentication
3. **DLNA/UPnP**: Local network only (no internet exposure)
4. **mDNS**: Local network multicast, no external access
5. **WebRTC**: 
   - Signaling server must be on home network only
   - Or use authentication token for remote access
   - DTLS/SRTP encryption for media streams
   - Recommend Docker container + reverse proxy

---

## 📦 DEPENDENCIES TO ADD

```json
{
  "ios": {
    "frameworks": ["Network", "AVKit", "VideoToolbox", "AVFoundation"],
    "cocoapods": ["google-cast-sdk"],
    "system": "iOS 14+ (earlier phase support possible)"
  },
  "android": {
    "gradle": ["com.google.android.gms:play-services-cast"],
    "native": ["libdatachannel"]
  },
  "crossplatform": {
    "cpp": ["libupnp", "libdatachannel"],
    "services": ["mDNSResponder (already in SDL3)"]
  },
  "external_services": {
    "signaling_server": "Node.js app (provided as Docker image)"
  }
}
```

---

## 📊 ESTIMATED EFFORT BREAKDOWN

| Phase | Component | Hours | Developer | Start | End |
|-------|-----------|-------|-----------|-------|-----|
| 1 | Discovery Layer | 80 | Eng | Week 1 | Week 2.5 |
| 2 | AirPlay 2 + Network Framework | 120 | Eng | Week 3 | Week 5 |
| 3 | Google Cast SDK | 100 | Eng | Week 5 | Week 7 |
| 4 | DLNA/UPnP | 60 | Eng | Week 7 | Week 7.5 |
| 5 | WebRTC Fallback | 120 | Eng | Week 7.5 | Week 10 |
| 6 | Swift UI + Polish | 80 | Eng | Week 10 | Week 11 |
| - | Testing + Bug Fixes | 100 | QA | Week 2 → Week 12 | - |
| **TOTAL** | **All Phases** | **~660** | - | - | **12 weeks** |

**With 2 engineers**: ~6 weeks  
**With 3 engineers**: ~4 weeks  
**With 1 engineer**: ~12 weeks

---

## 🎯 SUCCESS CRITERIA

- ✅ AirPlay 2 works on Apple TV with <40ms latency
- ✅ Google Cast works on Chromecast + Android TV with <120ms latency
- ✅ mDNS discovery works on iOS + Android for local devices
- ✅ WebRTC fallback works on any browser (PC/Mac/Linux)
- ✅ DLNA works on legacy smart TVs (video playback, not gaming)
- ✅ All protocols coexist without conflicts
- ✅ Automatic protocol selection works (user doesn't choose protocol)
- ✅ Connection recovery + retry logic works
- ✅ <5 second average connection time
- ✅ Clean SwiftUI device picker + casting controls

---

## 🚀 NEXT STEP

Once you approve this architecture, I will:
1. Create detailed implementation specs for Phase 1 (Discovery Layer)
2. Set up folder structure and CMake integration
3. Begin Phase 1 development (2-3 weeks)

**Questions before starting?**

