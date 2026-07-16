# Hybrid Casting System - Implementation Checklist

## 📋 Quick Reference

**Phase 1 Status**: ✅ COMPLETE  
**Phase 2 Start**: Whenever ready  
**Total Phases**: 6  
**Estimated Duration**: 5-6 weeks (full team) or 10-12 weeks (1 person)

---

## 🔨 PHASE 1: Infrastructure (COMPLETE ✅)

### C++ Core
- [x] CastingDevice.h - Device model
- [x] CastingDevice.cpp - Device implementation
- [x] CastingManager.h - Manager interface
- [x] CastingManager.cpp - Manager implementation
- [x] Protocol manager headers (AirPlay, Cast, DLNA, WebRTC)
- [x] Basic implementations for all managers
- [x] CMakeLists.txt - Build configuration

### Swift Bridge
- [x] CastingBridge.h - ObjC bridge header
- [x] CastingBridge.mm - ObjC++ implementation
- [x] Type conversions (protocol, state, device)
- [x] Callback handlers
- [x] Frame submission methods

### Swift UI
- [x] CastingDevicePickerView.swift - Device selection
- [x] CastingStatusBar.swift - In-game status
- [x] Device row component
- [x] Protocol indicators
- [x] Latency display

### Documentation
- [x] Architecture overview
- [x] Implementation guide
- [x] Phase 1 status
- [x] This checklist

---

## 🎯 PHASE 2: AirPlay 2 Implementation (START HERE)

### Prerequisites
- [ ] Apple TV 4K (2nd generation or newer)
- [ ] Test iPhone 13+
- [ ] Test iPad Pro
- [ ] VideoToolbox framework documentation studied
- [ ] Metal rendering pipeline understood

### Implementation Tasks
- [ ] Implement `AirPlayManager::captureGameRenderTarget()`
  - [ ] Get Metal render target from game engine
  - [ ] Convert Metal texture to CVPixelBuffer
  - [ ] Handle different texture formats
  - [ ] Test with real game frames

- [ ] Implement `AirPlayManager::encodeVideoFrame()`
  - [ ] Create VTCompressionSession
  - [ ] Configure H.264 encoding parameters
  - [ ] Set bitrate (5-10 Mbps target)
  - [ ] Submit frames to encoder
  - [ ] Handle completion callbacks

- [ ] Implement `AirPlayManager::submitVideoFrame()`
  - [ ] Route frames to encoder
  - [ ] Handle frame drops gracefully
  - [ ] Monitor encoding queue depth
  - [ ] Add frame timing info

- [ ] Implement `AirPlayManager::submitAudioFrame()`
  - [ ] PCM → AAC encoding
  - [ ] Sync with video frames
  - [ ] Handle sample rate conversion
  - [ ] Test audio quality

- [ ] AirPlay 2 Transport
  - [ ] Research AirPlay 2 protocol
  - [ ] Implement network transmission
  - [ ] Handle device discovery updates
  - [ ] Implement connection retry logic

### Testing
- [ ] Compile without errors
- [ ] Apple TV device discovery works
- [ ] Connection succeeds
- [ ] Video appears on Apple TV
- [ ] Audio plays correctly
- [ ] Latency < 40ms confirmed
- [ ] Handle disconnection gracefully
- [ ] Test iPad external display
- [ ] Test iPhone screen recording

### Estimated Time: 7-10 days (one developer)

**When This Phase Completes**: Core casting feature works for Apple ecosystem ✨

---

## 🎯 PHASE 3: Google Cast Implementation

### Prerequisites
- [ ] Google Cast SDK for iOS installed (CocoaPod)
- [ ] Chromecast device
- [ ] Android TV device (if available)
- [ ] Google Cast documentation reviewed

### Tasks
- [ ] Setup Google Cast SDK
  - [ ] Add cocoapod dependency
  - [ ] Configure GCKCastContext
  - [ ] Add Cast button to UI
  - [ ] Test device discovery

- [ ] Implement `GoogleCastManager::discoverDevices()`
  - [ ] Setup GCKDiscoveryManager
  - [ ] Handle device found/lost events
  - [ ] Create device list
  - [ ] Filter for game-suitable devices

- [ ] Implement `GoogleCastManager::connect()`
  - [ ] Create GCKSession
  - [ ] Start media channel
  - [ ] Configure media transport
  - [ ] Test connection reliability

- [ ] Implement video streaming
  - [ ] Encode video (H.264)
  - [ ] Create custom receiver
  - [ ] Send encoded frames
  - [ ] Verify on Chromecast

- [ ] Implement audio streaming
  - [ ] Encode audio (AAC/Opus)
  - [ ] Sync with video
  - [ ] Test audio quality

### Testing
- [ ] Compile without SDK errors
- [ ] Chromecast discovery works
- [ ] Connection to Chromecast succeeds
- [ ] Video streams to Chromecast
- [ ] Audio plays on TV speakers
- [ ] Latency 80-120ms acceptable
- [ ] Test Android TV
- [ ] Graceful disconnection

### Estimated Time: 7-10 days

**When This Phase Completes**: Chromecast + Android TV support ✨

---

## 🎯 PHASE 4: DLNA/UPnP Server

### Prerequisites
- [ ] libupnp library reviewed (already in 3rdparty)
- [ ] SSDP protocol understood
- [ ] HTTP media server architecture designed
- [ ] DLNA device types documented

### Tasks
- [ ] Implement SSDP device discovery
  - [ ] Scan for DLNA devices
  - [ ] Parse SSDP responses
  - [ ] Create device list
  - [ ] Handle device expiration

- [ ] Create local DLNA server
  - [ ] HTTP server on localhost
  - [ ] Generate device descriptor XML
  - [ ] Generate service descriptions
  - [ ] Advertise via SSDP

- [ ] Implement video streaming
  - [ ] Convert frames to H.264
  - [ ] Create media container
  - [ ] Stream over HTTP
  - [ ] Handle seek/pause

- [ ] Handle client connections
  - [ ] Detect connected DLNA clients
  - [ ] Send media metadata
  - [ ] Handle control commands
  - [ ] Manage connection lifetime

### Testing
- [ ] Compile with libupnp
- [ ] Server starts and advertises
- [ ] Samsung TV finds device
- [ ] LG TV finds device
- [ ] Video plays on TV
- [ ] Latency acceptable for demos (1-3s ok)
- [ ] Multiple device support

### Estimated Time: 4-5 days

**When This Phase Completes**: Support for legacy smart TVs ✨

---

## 🎯 PHASE 5: WebRTC Fallback

### Prerequisites
- [ ] libdatachannel library reviewed
- [ ] WebRTC architecture understood
- [ ] Signaling protocol designed
- [ ] Browser receiver framework designed

### Tasks
- [ ] Setup libdatachannel
  - [ ] Add dependency
  - [ ] Create PeerConnection
  - [ ] Configure ICE servers
  - [ ] Test data channels

- [ ] Implement video streaming
  - [ ] Encode frames to H.264/VP8
  - [ ] Send via media channel
  - [ ] Handle bitrate adaptation
  - [ ] Monitor connection quality

- [ ] Implement signaling
  - [ ] Connect to signaling server
  - [ ] Exchange SDP
  - [ ] Process ICE candidates
  - [ ] Handle connection state

- [ ] Create browser receiver
  - [ ] HTML5 canvas for video
  - [ ] WebRTC peer connection
  - [ ] Audio playback
  - [ ] Connection status UI
  - [ ] QR code generator for easy access

- [ ] Docker container for signaling server
  - [ ] Node.js signaling server
  - [ ] Docker configuration
  - [ ] Local network only
  - [ ] Easy deployment

### Testing
- [ ] Compile without errors
- [ ] PeerConnection established
- [ ] Video received in browser
- [ ] Audio plays
- [ ] Latency < 500ms
- [ ] Test on macOS browser
- [ ] Test on Windows browser
- [ ] QR code works
- [ ] Multiple receiver support

### Estimated Time: 10-12 days

**When This Phase Completes**: Universal browser-based fallback ✨

---

## 🎯 PHASE 6: Integration + Polish

### Integration Tasks
- [ ] Hook frame submission into renderer
  - [ ] Modify ios_main.mm or equivalent
  - [ ] Call submitVideoFrame() after render
  - [ ] Call submitAudioFrame() from audio

- [ ] Add to game UI
  - [ ] CastingStatusBar in GameScreenView
  - [ ] CastingStatusBar in QuickMenuView
  - [ ] Device picker integration
  - [ ] Settings panel additions

- [ ] Lifecycle management
  - [ ] Start casting on app init
  - [ ] Stop on app terminate
  - [ ] Handle app backgrounding
  - [ ] Reconnect on resume

### Polish Tasks
- [ ] Audio/video sync tuning
  - [ ] Frame timing calibration
  - [ ] Audio buffer timing
  - [ ] Latency measurement accuracy

- [ ] UI refinements
  - [ ] Animation polish
  - [ ] Error messages
  - [ ] Connection transitions
  - [ ] Dark mode support

- [ ] Performance optimization
  - [ ] Memory usage tuning
  - [ ] CPU usage optimization
  - [ ] Battery impact minimization
  - [ ] Network bandwidth optimization

- [ ] Documentation completion
  - [ ] User guide
  - [ ] Troubleshooting guide
  - [ ] FAQ
  - [ ] Developer docs

### Testing
- [ ] Full end-to-end test on all device types
- [ ] Performance testing (memory, CPU, battery)
- [ ] Stress testing (long sessions)
- [ ] Error recovery testing
- [ ] Multi-protocol simultaneous testing

### Estimated Time: 7-10 days

**When This Phase Completes**: Production-ready casting system ✨

---

## 📊 Overall Progress Tracking

| Phase | Component | Status | % Complete | Target Date |
|-------|-----------|--------|------------|------------|
| 1 | Infrastructure | ✅ DONE | 100% | 2026-07-16 ✅ |
| 2 | AirPlay 2 | ⏳ TODO | 0% | 2026-07-23 |
| 3 | Google Cast | ⏳ TODO | 0% | 2026-07-30 |
| 4 | DLNA/UPnP | ⏳ TODO | 0% | 2026-08-04 |
| 5 | WebRTC | ⏳ TODO | 0% | 2026-08-16 |
| 6 | Polish+Test | ⏳ TODO | 0% | 2026-08-27 |

---

## 🎮 Device Testing Matrix

### AirPlay 2 (Phase 2)
- [ ] Apple TV 4K (2nd gen)
- [ ] Apple TV 4K (3rd gen)
- [ ] iPad Pro 12.9"
- [ ] iPad Air
- [ ] iPhone 13
- [ ] iPhone 14
- [ ] iPhone 15

### Google Cast (Phase 3)
- [ ] Chromecast (3rd gen)
- [ ] Chromecast with Google TV
- [ ] Sony Android TV
- [ ] Nvidia Shield
- [ ] Samsung Smart TV (with Cast support)

### DLNA (Phase 4)
- [ ] Samsung Smart TV
- [ ] LG Smart TV
- [ ] Sony Smart TV
- [ ] Panasonic Smart TV

### WebRTC (Phase 5)
- [ ] Chrome on macOS
- [ ] Safari on macOS
- [ ] Edge on Windows
- [ ] Firefox on Linux

---

## ✅ Pre-Launch Checklist

Before releasing to production:

- [ ] All phases complete
- [ ] All test devices pass
- [ ] Performance benchmarks met (<100MB RAM usage)
- [ ] Documentation complete and reviewed
- [ ] Security review passed
- [ ] Accessibility testing (VoiceOver)
- [ ] Localization strings extracted
- [ ] Release notes written
- [ ] Beta testing with users
- [ ] App Store submission ready

---

## 🚀 Ready to Start?

**Next Action**: Choose priority protocol and begin Phase 2

**Recommendation**: Start with AirPlay 2 (Phase 2) because:
1. No external SDK needed
2. Fastest path to working feature
3. Unblocks testing on real devices
4. Foundation for other protocols

---

**Last Updated**: 2026-07-16  
**Next Update**: When Phase 2 begins

