# AYS2 Multi-Platform Casting Feature - Architecture Options

**Status**: Ready for Architecture Decision  
**Date**: 2026-07-16  
**Task**: Implement gameplay streaming to Apple TV, Android TV, Chromecast, and mobile devices

---

## ⚠️ IMPORTANT: AirPlay Discrepancy Found

ARMSX2 iOS v2.2.2 release notes claim "Added Apple Airplay support", but **iOS 2.4.1 (our migrated version) has no AirPlay code**. 

**Next Step Required**: Check ARMSX2 master branch to verify if AirPlay was:
- Removed in later versions?
- Refactored/abstracted differently?
- Not included in iOS source tree?

This doesn't block feature implementation, but we may be able to port existing code rather than rebuild from scratch.

---

## INVESTIGATION RESULTS

### ⚠️ CRITICAL FINDING

**ARMSX2 iOS v2.2.2 release notes explicitly state**: "Added Apple Airplay support, ARMSX2 iOS can now be played on a TV!"

However:
- ✅ iOS 2.4.1 (current version) is **newer** than v2.2.2
- ❌ No direct AirPlay code found in iOS 2.4.1 source
- ⚠️ Found `allowsExternalPlayback = false` in VideoBackgroundView (deliberately disabled)

**Hypothesis**: AirPlay support was either:
1. Removed in 2.4.1 (needs investigation in upstream PCSX2)
2. Abstracted/refactored (code exists but structured differently)
3. Not included in the iOS 2.4.1 source we migrated

### ✅ Code Analysis
- **iOS 2.4.1 Base**: No explicit AirPlay APIs found
- **Available APIs in ARMSX2Bridge**:
  - Audio control: `emulatorVolumePercent()`, `setEmulatorVolumePercent(value)`
  - Game rendering: `gameRenderView()` (Metal-rendered Metal view)
  - No external device detection or routing APIs
- **AVKit Framework**: Imported in VideoBackgroundView but `allowsExternalPlayback` disabled
- **Conclusion**: Feature likely needs to be rebuilt or re-enabled from scratch

---

## ARCHITECTURE OPTIONS

### **OPTION 1: AirPlay 2 (Apple Ecosystem Only)**

**Supported Devices:**
- Apple TV 4K (2nd gen+)
- iPad (7th gen+)
- iPhone (XS+)

**Pros:**
- ✅ **Native** - Built into iOS/tvOS
- ✅ **Zero external dependencies** - No third-party SDK
- ✅ **Sub-200ms latency** - Excellent for gaming
- ✅ **Automatic device discovery** - System handles connection UI
- ✅ **Audio + video sync guaranteed** - Native support

**Cons:**
- ❌ **Apple only** - No Android support
- ❌ **User must enable AirPlay** - Not programmable (Apple restriction)
- ❌ **Limited to official AirPlay devices**

**Implementation Complexity**: Medium (40-60 hours)  
**Tech Stack**:
- `AVAudioSession` - Audio routing management
- `UIScreen.screens` - External display detection
- Custom Metal render target for AirPlay

**Integration Points:**
- New C++ bridge: `ARMSX2AirPlayManager.mm/h`
- Swift UI: AirPlay device picker in DashboardView
- ARMSX2Bridge additions:
  - `startAirPlayStreaming()`
  - `stopAirPlayStreaming()`
  - `availableAirPlayDevices()`
  - `isAirPlayActive()`

---

### **OPTION 2: Google Cast SDK (Chromecast + Android TV)**

**Supported Devices:**
- Chromecast (all gen, including Chromecast with Google TV)
- Android TV devices (Sony, Nvidia Shield, etc.)
- Android phones/tablets (via Chromecast receiver app)
- Smart TVs (LG, Samsung with Chromecast built-in)

**Pros:**
- ✅ **Cross-platform** - Works iOS + Android (future-proof)
- ✅ **Widest device compatibility** - Any Chromecast/Android TV
- ✅ **Network-based** - Works over WiFi anywhere in home/office
- ✅ **Sub-100ms latency** - Excellent for gaming
- ✅ **Built-in device discovery** - Google Cast framework

**Cons:**
- ❌ **Third-party dependency** - Adds ~50MB to app
- ❌ **Requires WiFi** - No local Bluetooth fallback
- ❌ **No Apple TV support** - Exclusive to Chromecast ecosystem
- ⚠️ **Licensing** - Free but requires Google API setup

**Implementation Complexity**: High (80-120 hours)  
**Tech Stack**:
- Google Cast SDK for iOS (Objective-C++)
- Custom Receiver app (or use generic video receiver)
- WebRTC for video streaming

**Integration Points:**
- New C++ bridge: `ARMSX2CastManager.mm/h`
- Swift UI: Cast device picker, connection state
- ARMSX2Bridge additions:
  - `startCasting(deviceId)`
  - `stopCasting()`
  - `availableCastDevices()`
  - `isCastActive()`

---

### **OPTION 3: WebRTC (Universal - All Platforms)**

**Supported Devices:**
- Any device with Chrome, Firefox, Safari
- Apple TV (via AirPlay + browser)
- Android TV (native support)
- Smart TVs (WebRTC-capable models)
- Mobile browsers
- **Truly universal** - Works everywhere with a web browser

**Pros:**
- ✅ **Universal** - Works iOS, Android, Web, Smart TVs
- ✅ **Sub-500ms latency** - Good for gaming
- ✅ **No vendor lock-in** - Open standard
- ✅ **Scalable** - Can support multiple receivers
- ✅ **Future-proof** - Industry standard

**Cons:**
- ❌ **Requires signaling server** - Infrastructure cost
- ❌ **Higher latency** - ~500ms (streaming overhead)
- ❌ **Complex setup** - Needs STUN/TURN servers for NAT traversal
- ❌ **Browser fallback needed** - Not native performance

**Implementation Complexity**: Very High (150-200 hours)  
**Tech Stack**:
- WebRTC SDK (libwebrtc or wrapper)
- Signaling server (Node.js, Python, or cloud service)
- TURN server (AWS, Coturn, or cloud provider)
- Browser-based receiver frontend

**Integration Points:**
- New C++ bridge: `ARMSX2WebRTCManager.mm/h`
- Swift UI: WebRTC connection state, receiver URL display
- Backend: Signaling server infrastructure
- ARMSX2Bridge additions:
  - `startWebRTCStream(receiverUrl)`
  - `stopWebRTCStream()`
  - `getWebRTCConnectionState()`

---

### **OPTION 4: DLNA/UPnP (Legacy - Widest Compatibility)**

**Supported Devices:**
- Samsung, LG, Sony TV models
- Xiaomi, Huawei devices
- Routers, NAS devices
- Older Smart TVs
- Generic DLNA renderers

**Pros:**
- ✅ **Widest device support** - Works with almost any TV from last 10 years
- ✅ **No external services** - Fully local network
- ✅ **Open standard** - No vendor lock-in
- ✅ **Simple protocol** - Well-documented

**Cons:**
- ❌ **Legacy technology** - Old protocol (2003)
- ⚠️ **Variable latency** - 1-3 seconds (not ideal for gaming)
- ❌ **Discovery unreliable** - Devices sometimes don't advertise properly
- ❌ **Limited control** - Basic play/pause/seek only

**Implementation Complexity**: Medium (50-80 hours)  
**Tech Stack**:
- libupnp C++ library
- DLNA media server implementation
- HTTP streaming server

**Note**: Better for video/demo streaming than live gameplay

---

### **OPTION 5: HYBRID APPROACH (Recommended)**

Combine multiple technologies for maximum coverage:

1. **Primary: AirPlay 2** (Apple devices)
   - Highest latency and performance for iOS users
   
2. **Secondary: Google Cast** (Chromecast + Android TV)
   - Broadest Android/TV ecosystem coverage
   
3. **Fallback: WebRTC** (Universal receiver)
   - Works with any browser

**Pros:**
- ✅ **Best user experience** - Uses native tech for each platform
- ✅ **Maximum device support** - Works everywhere
- ✅ **Graceful degradation** - Falls back if primary unavailable

**Cons:**
- ❌ **Highest complexity** - 3x implementation, testing, maintenance
- ❌ **Largest codebase** - Multiple SDKs integrated

**Implementation Complexity**: Very High (200-300 hours)  
**Estimated Timeline**: 4-6 weeks with careful phasing

---

## TECHNICAL REQUIREMENTS (All Options)

### Video Capture
- Extract Metal render target from game view
- Encode to H.264 (hardware accelerated)
- Stream at 30-60 FPS

### Audio Capture
- Intercept emulator audio output
- Mix with game audio
- Encode to AAC
- Sync with video

### Networking
- Local network discovery
- WiFi + cellular support
- Graceful disconnect/reconnect
- Buffer management

### Swift Integration
- **NO CHANGES** to existing Views (DashboardView, RetroKit, etc.)
- New casting options in game menu
- Device picker UI overlay
- Connection status indicator

---

## RECOMMENDATION

**Start with OPTION 2 (Google Cast SDK)**:
- Covers most device types (Android TV, Chromecast, smart TVs)
- Medium-high complexity (not as complex as full WebRTC)
- Works for iOS now, Android (future)
- Google SDK is well-maintained and documented
- Can add AirPlay 2 (Option 1) later with less effort

**Alternative**: If Apple-first priority → **OPTION 1 (AirPlay 2)** then add Cast

---

## NEXT STEPS

**User Decision Required:**
1. Which architecture to implement first?
2. Timeline expectations (1 week? 1 month?)
3. Priority device types?

**Once Decided:**
1. Create detailed implementation spec
2. Design audio/video capture pipeline
3. Build device discovery UI
4. Implement streaming codec selection
5. Test on physical devices (ATV, Android TV, iPhone)

---

## GIT STATE

- **Branch**: `migrate/ios-v2.4.1-correct`
- **Status**: Ready for feature implementation
- All iOS 2.4.1 migration complete ✅
- Ready to start casting feature work

