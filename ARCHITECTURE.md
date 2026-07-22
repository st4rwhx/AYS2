# AYS2 Architecture

Technical documentation of AYS2's design and implementation.

## Overview

AYS2 is a PlayStation 2 emulator for iOS built on ARMSX2, which itself is built on PCSX2. It brings high-performance PS2 emulation to iPhone and iPad via JIT recompilation.

```
┌─────────────────────────────────────┐
│         iOS User Interface          │
│     (SwiftUI, Metal Rendering)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      AYS2 Emulation Core            │
│   (ARMSX2 fork + iOS customizations)│
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    CPU/EE Recompiler (MIPS→arm64)   │
│    GPU Renderer (Metal)              │
│    Sound Engine                      │
│    Memory Management                 │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         iOS Framework Stack         │
│ (GameController, AVFoundation, etc) │
└─────────────────────────────────────┘
```

## Directory Structure

```
AYS2/
├── README.md                       # Main documentation
├── ARCHITECTURE.md                 # This file
├── LICENSE                         # GPL-3.0 license
├── CHANGELOG.md                    # Version history
├── ROADMAP.md                      # Future plans
├── CONTRIBUTING.md                 # Contributing guidelines
├── SECURITY.md                     # Security policy
│
├── .github/
│   ├── workflows/
│   │   └── build-ios.yml          # CI/CD pipeline
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── compatibility_report.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
│
├── src/                            # Source code
│   ├── cpp/                        # C++ emulation core
│   │   ├── CMakeLists.txt
│   │   ├── Info.plist.in
│   │   ├── ARMSX2Bridge.mm        # C++ ↔ Swift interface
│   │   ├── pcsx2/                 # PCSX2 core components
│   │   ├── common/                # Shared utilities
│   │   └── 3rdparty/              # External dependencies
│   │
│   └── swift/                      # iOS app & UI
│       ├── Views/
│       │   ├── RootView.swift
│       │   ├── GameListView.swift
│       │   ├── EmulatorView.swift
│       │   ├── VirtualControllerView.swift
│       │   └── Settings/
│       ├── Models/
│       │   ├── EmulatorBridge.swift
│       │   ├── AppState.swift
│       │   ├── SettingsStore.swift
│       │   └── PadLayoutStore.swift
│       └── Shaders/
│
├── source/                         # SideStore feed infrastructure
│   └── worker/
│       ├── worker.js              # Cloudflare Worker
│       ├── wrangler.toml
│       └── README.md
│
├── analytics/                      # Telemetry worker
│   └── worker/
│
├── cmake/                          # CMake configuration
│   ├── BuildParameters.cmake
│   ├── SearchForStuff.cmake
│   └── Pcsx2Utils.cmake
│
├── docs/                           # Documentation
│   ├── ARMSX2_MIGRATION.md
│   └── AYS2_OVERLAY.md
│
├── assets/                         # UI assets
│   ├── app_icons/
│   └── resources/
│
└── scripts/                        # Utility scripts
    └── ays2-overlay.sh
```

## Core Components

### 1. Emulation Engine (C++)

**File:** `src/cpp/`

**Purpose:** PlayStation 2 hardware emulation

**Key Components:**
- **CPU/EE (Emotion Engine):** native MIPS (R5900/VU) → arm64 JIT recompiler
- **Graphics (GS):** Metal renderer with shader compilation
- **Sound (SPU):** PCM audio engine with effects
- **Memory:** Page-based memory management
- **I/O:** Game controller, memory card, disc interface

**Design Pattern:** PCSX2-based architecture adapted for ARM

### 2. iOS Application (Swift)

**File:** `src/swift/`

**Purpose:** User interface and app lifecycle

**Key Views:**
- **RootView:** Main navigation
- **GameListView:** Library management
- **EmulatorView:** Game execution
- **VirtualControllerView:** On-screen gamepad
- **SettingsView:** Configuration UI

**Design Pattern:** MVVM with SwiftUI, state management via AppState

### 3. Emulator Bridge

**File:** `src/cpp/ARMSX2Bridge.mm`

**Purpose:** C++ ↔ Swift interop

**Key Functions:**
- Swift callbacks into C++ emulation
- Memory-mapped texture passing
- Controller input relay
- Save state management

**Language:** Objective-C++ (allows C++ in iOS Objective-C runtime)

### 4. SideStore Integration

**File:** `source/worker/`

**Purpose:** One-tap installation and feed management

**Technology:** Cloudflare Worker (serverless)

**Responsibilities:**
- Proxy `source.json` from GitHub Releases
- Serve install redirect page
- Cache management (5-minute TTL)

---

## Data Flow

### Game Launch

```
User taps game
    ↓
GameListView → EmulatorView
    ↓
Swift calls EmulatorBridge.startGame()
    ↓
C++ loads game ISO/CHD
    ↓
CPU recompiler JIT-compiles MIPS → arm64
    ↓
GPU renders frame to Metal texture
    ↓
SwiftUI displays texture
    ↓
GameController input → C++ input handler
    ↓
Repeat until game exits
```

### Save State Management

```
User presses Save
    ↓
SwiftUI → SettingsStore
    ↓
EmulatorBridge.saveSaveState(slot)
    ↓
C++ serializes memory state
    ↓
Write to app sandbox (iCloud backup capable)
    ↓
Update UI with timestamp
```

---

## Performance Considerations

### CPU Recompilation

- **Block-level JIT:** Compile code blocks as needed
- **Cache invalidation:** Clear cache on boot
- **Hot code paths:** Profile-guided optimization

### GPU Rendering

- **Deferred rendering:** Collect draw calls, submit batch
- **Texture atlasing:** Reduce state changes
- **MRT (Multi-Render Target):** Screen-space effects

### Memory Management

- **Page faulting:** Lazy allocation
- **Compression:** Game memory compression on low RAM
- **Streaming:** Load assets on-demand

---

## Threading Model

```
Main Thread (SwiftUI)
├── User input handling
├── View updates
└── Metal rendering commands

Background Thread (Emulation)
├── CPU recompilation
├── Game logic execution
├── Audio processing
└── Save state serialization
```

**Thread Safety:** Atomic operations for frame syncing, memory barriers for texture handoff

---

## Dependencies

### Internal
- **PCSX2:** PS2 emulation core
- **ARMSX2:** ARM64 adaptations

### External (3rd Party)
- **SDL3:** Input/window abstraction
- **Metal:** iOS GPU API
- **SwiftUI:** iOS UI framework

### Build Tools
- **CMake:** Build configuration (`-G Xcode` generator on iOS)
- **xcodebuild:** Actual compile step, driven by CI (`.github/workflows/build-ios.yml`)

---

## Security Model

- **App Sandbox:** Isolated file access (app container only)
- **Code Signing:** Required on real device
- **Memory Protection:** iOS ASLR, DEP enabled
- **Input Validation:** All user files validated before loading

---

## Testing Strategy

There is currently no automated test suite (no `add_test()`/`enable_testing()`
wired into the CMake build). What exists today:

- **CI (`build-ios.yml`):** compiles the app and packages an unsigned IPA on
  every push. This catches build breaks, not runtime/behavioral bugs.
- **Manual device testing:** the actual verification step for anything
  runtime-related (JIT behavior, rendering, input, save states) — real
  hardware, real iOS versions, real games.

Automated unit/integration tests (recompiler correctness, save-state
integrity, compatibility regression suite) are not implemented. If you're
looking for a place to contribute, this is one.

---

## Future Architectural Improvements

- [ ] Modular plugin system for custom renderers
- [ ] Network replication for lag reduction
- [ ] WebRTC streaming for remote play
- [ ] Machine learning for game detection
- [ ] Vulkan/OpenGL fallback renderers

---

## Contributing to Architecture

When contributing:

1. **Respect separation of concerns** — Keep C++ and Swift layers separate
2. **Thread safety** — No data races or deadlocks
3. **Performance** — Profile before and after changes
4. **Compatibility** — Test on multiple devices/iOS versions
5. **Documentation** — Update this file if architecture changes

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

---

**Last Updated:** July 2026  
**Maintainer:** @st4rwhx  
**Questions:** https://github.com/st4rwhx/AYS2/discussions
