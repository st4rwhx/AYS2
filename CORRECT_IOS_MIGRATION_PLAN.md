# Correct iOS Migration Plan - v2.4.1

**Date:** July 16, 2026  
**Status:** 🎯 READY TO EXECUTE  
**Target:** iOS 2.4.1 (NOT Android 2.6.0.5!)  
**Source Commit:** `3467e72dba` in ARMSX2 master

---

## What We're Fixing

**Problem:** Current migrate/v2.6.0.5-clean branch used **ANDROID 2.6.7** code  
**Solution:** Use **iOS 2.4.1** code from ARMSX2 `platforms/ios/`

---

## Source Analysis - iOS 2.4.1

### Commit Details
```bash
commit 3467e72dba
iOS: bump version to 2.4.1, activate NEON SPU2 mixing, and port EE recompiler zero-register folds
```

### Version Info (from CMakeLists.txt)
```cmake
set(ARMSX2_VERSION_MAJOR 2)
set(ARMSX2_VERSION_MINOR 4)
set(ARMSX2_VERSION_PATCH 1)
set(ARMSX2_VERSION "2.4.1")
set(ARMSX2_BUILD_NUMBER 241)
```

### iOS Structure in ARMSX2
```
ARMSX2/
├── platforms/ios/app/src/main/cpp/
│   ├── CMakeLists.txt          ← iOS build configuration
│   ├── Info.plist.in           ← iOS template (correct!)
│   ├── Entitlements.plist      ← JIT entitlements
│   ├── ARMSX2Bridge.h/mm       ← ObjC-C++ bridge
│   ├── ios_main.mm             ← iOS entry point
│   ├── IOS/                    ← iOS-specific ObjC files
│   │   ├── AppDelegate.mm
│   │   ├── SceneDelegate.mm
│   │   ├── HostImpls.mm
│   │   ├── GamepadHaptics.mm
│   │   └── PlaySoundAsync.mm
│   └── cmake/                  ← iOS-aware CMake modules
├── pcsx2/                      ← Shared core (at root!)
├── common/                     ← Shared utilities (at root!)
└── 3rdparty/                   ← Dependencies (at root!)
```

**Key Point:** iOS does NOT vendor pcsx2/common - it references them from repo root!

---

## Step-by-Step Migration

### Phase 1: Preparation (30 min)

1. **Backup Current State**
   ```bash
   cd ~/Documents/AYS2/AYS2
   git checkout migrate/v2.6.0.5-clean
   git branch backup/android-mistake
   ```

2. **Create Clean iOS Branch**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b migrate/ios-v2.4.1-clean
   ```

3. **Verify ARMSX2 Clone**
   ```bash
   cd scratchpad/armsx2-master
   git log --oneline platforms/ios/ | head -10
   # Should see: 3467e72dba iOS: bump version to 2.4.1...
   ```

---

### Phase 2: Copy iOS-Specific Files (1 hour)

#### 2.1 CMakeLists.txt (Adapt for Flat Structure)

**Source:** `platforms/ios/app/src/main/cpp/CMakeLists.txt`  
**Destination:** `src/cpp/CMakeLists.txt`

**Changes needed:**
- Remove monorepo root reference (`get_filename_component(ARMSX2_ROOT ...)`)
- Change `add_subdirectory(${ARMSX2_ROOT}/pcsx2 ...)` to `add_subdirectory(pcsx2)`
- Change `add_subdirectory(${ARMSX2_ROOT}/common ...)` to `add_subdirectory(common)`
- Update include paths from `${ARMSX2_ROOT}/...` to relative paths
- Keep AYS2 Bundle ID: `com.ayano.aysx2`
- Change app name: `ARMSX2 iOS` → `AYS2`

#### 2.2 Info.plist.in (iOS Template)

**Source:** `platforms/ios/app/src/main/cpp/Info.plist.in`  
**Destination:** `src/cpp/Info.plist.in`

**Changes needed:**
- Change `<string>ARMSX2 iOS</string>` → `<string>AYS2</string>`
- Change URL schemes to `aysx2` / `aysx2ios`
- Keep iOS-specific structure (alternate icons, document types, etc.)

#### 2.3 iOS Bridge Files

**Copy these files as-is:**
```bash
# From armsx2-master
cp platforms/ios/app/src/main/cpp/ARMSX2Bridge.h src/cpp/
cp platforms/ios/app/src/main/cpp/ARMSX2Bridge.mm src/cpp/
cp platforms/ios/app/src/main/cpp/ARMSX2-Bridging-Header.h src/cpp/
cp platforms/ios/app/src/main/cpp/ios_main.mm src/cpp/
cp platforms/ios/app/src/main/cpp/Entitlements.plist src/cpp/
```

#### 2.4 iOS-Specific ObjC Files

```bash
# Create IOS directory
mkdir -p src/cpp/IOS

# Copy iOS runtime files
cp platforms/ios/app/src/main/cpp/IOS/*.mm src/cpp/IOS/
cp platforms/ios/app/src/main/cpp/IOS/*.h src/cpp/IOS/
```

#### 2.5 iOS CMake Modules

```bash
# Create cmake directory
mkdir -p src/cpp/cmake

# Copy iOS-aware modules
cp -r platforms/ios/app/src/main/cpp/cmake/* src/cpp/cmake/
```

---

### Phase 3: Copy Core at iOS 2.4.1 Commit (2 hours)

#### 3.1 Checkout iOS 2.4.1 Commit

```bash
cd scratchpad/armsx2-master
git checkout 3467e72dba  # iOS 2.4.1 commit
```

#### 3.2 Copy pcsx2 Core

```bash
# Remove old Android core
rm -rf ~/Documents/AYS2/AYS2/src/cpp/pcsx2

# Copy iOS-compatible core
cp -r pcsx2 ~/Documents/AYS2/AYS2/src/cpp/
```

#### 3.3 Copy common Utilities

```bash
# Remove old Android common
rm -rf ~/Documents/AYS2/AYS2/src/cpp/common

# Copy iOS-compatible common
cp -r common ~/Documents/AYS2/AYS2/src/cpp/
```

#### 3.4 Copy 3rdparty Dependencies

```bash
# Remove old Android 3rdparty
rm -rf ~/Documents/AYS2/AYS2/src/cpp/3rdparty

# Copy iOS-compatible 3rdparty
cp -r 3rdparty ~/Documents/AYS2/AYS2/src/cpp/
```

---

### Phase 4: Apply AYS2 Seams (1-2 hours)

#### 4.1 CMakeLists.txt Seams

**Location:** `src/cpp/CMakeLists.txt`

```cmake
# AYS2: Bundle identifier (CRITICAL - never change)
set(ARMSX2_DEFAULT_BUNDLE_IDENTIFIER "com.ayano.aysx2")

# AYS2: App name branding
set(MACOSX_BUNDLE_BUNDLE_NAME "AYS2")
set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.ayano.aysx2")
```

#### 4.2 Info.plist.in Seams

**Location:** `src/cpp/Info.plist.in`

```xml
<!-- AYS2: App name -->
<key>CFBundleDisplayName</key>
<string>AYS2</string>

<!-- AYS2: URL schemes -->
<key>CFBundleURLSchemes</key>
<array>
    <string>aysx2</string>
    <string>aysx2-ios</string>
    <string>aysx2ios</string>
</array>
```

#### 4.3 ARMSX2Bridge.mm Seams

**Location:** `src/cpp/ARMSX2Bridge.mm`

Add at top:
```cpp
// AYS2: Version string override
#ifndef ARMSX2_VERSION_STR
#define ARMSX2_VERSION_STR "2.4.1-ays2"
#endif
```

#### 4.4 ImGuiOverlays.cpp Seams

**Location:** `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp`

Find ARMSX2 branding strings and replace with AYS2:
```cpp
// AYS2: In-game OSD branding
const char* app_name = "AYS2";  // was "ARMSX2"
```

#### 4.5 FullscreenUI.cpp Seams

**Location:** `src/cpp/pcsx2/ImGui/FullscreenUI.cpp`

Find About dialog:
```cpp
// AYS2: About dialog branding
ImGui::Text("AYS2 %s", ARMSX2_VERSION_STR);
ImGui::Text("Based on ARMSX2 and PCSX2");
```

---

### Phase 5: Adapt CMakeLists for Flat Structure (2-3 hours)

**Key Changes in `src/cpp/CMakeLists.txt`:**

#### 5.1 Remove Monorepo Root Reference

**Replace:**
```cmake
get_filename_component(ARMSX2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../.." ABSOLUTE)
```

**With:**
```cmake
# AYS2: Flat structure - core is local
set(ARMSX2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
```

#### 5.2 Fix add_subdirectory Calls

**Replace:**
```cmake
add_subdirectory(${ARMSX2_ROOT}/common ${CMAKE_BINARY_DIR}/common)
add_subdirectory(${ARMSX2_ROOT}/pcsx2 ${CMAKE_BINARY_DIR}/pcsx2)
```

**With:**
```cmake
# AYS2: Flat structure - direct subdirectories
add_subdirectory(common)
add_subdirectory(pcsx2)
```

#### 5.3 Fix Include Paths

**Replace all `${ARMSX2_ROOT}/...` with relative paths:**
```cmake
# Before (monorepo style):
${ARMSX2_ROOT}/pcsx2
${ARMSX2_ROOT}/common
${ARMSX2_ROOT}/3rdparty/fmt/include

# After (flat structure):
${CMAKE_CURRENT_SOURCE_DIR}/pcsx2
${CMAKE_CURRENT_SOURCE_DIR}/common
${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/fmt/include
```

#### 5.4 Fix Swift Sources Path

**Replace:**
```cmake
file(GLOB_RECURSE SWIFT_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_SOURCE_DIR}/../swift/*.swift
)
```

**With:**
```cmake
# AYS2: Swift sources are in src/swift (sibling to src/cpp)
file(GLOB_RECURSE SWIFT_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_SOURCE_DIR}/../swift/*.swift
)
# (Keep this - it's correct for AYS2 structure)
```

#### 5.5 Fix Asset Paths

**Replace all `${CMAKE_SOURCE_DIR}/../assets/` with AYS2 asset paths:**
```cmake
# Before (ARMSX2 structure):
"${CMAKE_SOURCE_DIR}/../assets/Assets.xcassets/..."

# After (AYS2 structure):
"${CMAKE_SOURCE_DIR}/../assets/Assets.xcassets/..."
# (Actually check if AYS2 uses same structure or different)
```

---

### Phase 6: iOS Platform Guards (1 hour)

These should already be in iOS 2.4.1 code, but verify:

#### 6.1 IOCtlSrc.cpp (Darwin CD/DVD)

**Location:** `src/cpp/pcsx2/CDVD/Darwin/IOCtlSrc.cpp`

```cpp
#include <TargetConditionals.h>

#if defined(__APPLE__) && !TARGET_OS_IPHONE
// IOKit code here (macOS only)
#else
// Empty stubs for iOS
#endif
```

#### 6.2 DriveUtility.cpp (Darwin CD/DVD)

**Location:** `src/cpp/pcsx2/CDVD/Darwin/DriveUtility.cpp`

```cpp
#include <TargetConditionals.h>

#if defined(__APPLE__) && !TARGET_OS_IPHONE
// IOKit code here (macOS only)
#else
// Empty stubs for iOS
#endif
```

#### 6.3 GSCapture.cpp (FFmpeg)

**Location:** `src/cpp/pcsx2/GS/GSCapture.cpp`

```cpp
#include <TargetConditionals.h>

#if !TARGET_OS_IPHONE
#include <libavcodec/avcodec.h>
// FFmpeg code
#else
// No-op stubs for iOS
#endif
```

#### 6.4 CubebAudioStream.cpp (Device Enumeration)

**Location:** `src/cpp/pcsx2/Host/CubebAudioStream.cpp`

```cpp
#include <TargetConditionals.h>

#if !TARGET_OS_IPHONE
// Device enumeration with cubeb_get_backend_names()
#else
// Return defaults only for iOS
#endif
```

**These should already be correct in iOS 2.4.1!** Just verify.

---

### Phase 7: Update Build Workflow (30 min)

**Location:** `.github/workflows/build-ios.yml`

**No changes needed!** The workflow already targets iOS correctly. Just ensure:
- CMake args point to `src/cpp`
- Bundle ID stays `com.ayano.aysx2`
- App name stays `AYS2`

---

### Phase 8: Test & Validate (2-3 hours)

#### 8.1 Local CMake Configure

```bash
cmake -B build -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DARMSX2_REAL_DEVICE=ON \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DARMSX2_BUNDLE_IDENTIFIER="com.ayano.aysx2" \
  src/cpp
```

**Expected:** No errors, Info.plist generated correctly

#### 8.2 Local Xcode Build

```bash
xcodebuild -project build/ARMSX2iOS.xcodeproj \
  -scheme ARMSX2iOS \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO
```

**Expected:** Build succeeds, .app generated

#### 8.3 Check Diagnostics

```bash
# No iOS-incompatible code
grep -r "IOKit" src/cpp/pcsx2/ --include="*.cpp"
# Should only find Darwin files with guards

# No FFmpeg without guards  
grep -r "libavcodec" src/cpp/pcsx2/ --include="*.cpp"
# Should only find GSCapture.cpp with guard

# Verify version
grep "ARMSX2_VERSION" build/Info.plist
# Should show 2.4.1
```

#### 8.4 CI Build

```bash
git add -A
git commit -m "Migrate to iOS 2.4.1 from ARMSX2 (correct platform)"
git push origin migrate/ios-v2.4.1-clean
```

Watch GitHub Actions build #180+ - should succeed!

---

## Success Criteria

✅ **CMake configures** without errors  
✅ **Info.plist generated** in correct location  
✅ **Xcode build succeeds** - IPA created  
✅ **Version is 2.4.1** - not 2.6.0.5  
✅ **Platform guards work** - no iOS-incompatible code  
✅ **Bundle ID correct** - `com.ayano.aysx2`  
✅ **App name correct** - `AYS2`  
✅ **CI green** - GitHub Actions build succeeds  
✅ **Device test** - app launches on iPhone  

---

## Files Changed

### New/Replaced Files
- `src/cpp/CMakeLists.txt` ← Adapted from iOS
- `src/cpp/Info.plist.in` ← iOS template
- `src/cpp/ARMSX2Bridge.h` ← iOS bridge
- `src/cpp/ARMSX2Bridge.mm` ← iOS bridge impl
- `src/cpp/ARMSX2-Bridging-Header.h` ← Swift-ObjC bridge
- `src/cpp/ios_main.mm` ← iOS entry point
- `src/cpp/Entitlements.plist` ← JIT entitlements
- `src/cpp/IOS/*.mm` ← iOS runtime files
- `src/cpp/cmake/*` ← iOS CMake modules
- `src/cpp/pcsx2/` ← iOS 2.4.1 core
- `src/cpp/common/` ← iOS 2.4.1 utilities
- `src/cpp/3rdparty/` ← iOS 2.4.1 dependencies

### Modified Files (AYS2 Seams)
- `src/cpp/CMakeLists.txt` - Bundle ID, app name
- `src/cpp/Info.plist.in` - App name, URL schemes
- `src/cpp/ARMSX2Bridge.mm` - Version string
- `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` - OSD branding
- `src/cpp/pcsx2/ImGui/FullscreenUI.cpp` - About dialog

---

## Timeline

| Phase | Duration | Task |
|-------|----------|------|
| 1 | 30 min | Backup & branch setup |
| 2 | 1 hour | Copy iOS files |
| 3 | 2 hours | Copy core at iOS 2.4.1 |
| 4 | 1-2 hours | Apply AYS2 seams |
| 5 | 2-3 hours | Adapt CMake for flat structure |
| 6 | 1 hour | Verify platform guards |
| 7 | 30 min | Update workflow (if needed) |
| 8 | 2-3 hours | Test & validate |
| **TOTAL** | **10-14 hours** | **1-2 days** |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| CMake adaptation errors | Reference iOS CMakeLists closely, test incrementally |
| Missing iOS guards | iOS 2.4.1 already has them, just verify |
| Asset path mismatches | Check AYS2 vs ARMSX2 asset structure |
| Swift bridge errors | Use exact bridging header from iOS |
| Version conflicts | Use iOS 2.4.1 commit exactly, no mixing |

---

## Next Action

**START NOW:**
```bash
cd ~/Documents/AYS2/AYS2
git checkout main
git checkout -b migrate/ios-v2.4.1-clean
```

Then follow phases 2-8 above.

---

**Status:** READY TO EXECUTE  
**Target:** iOS 2.4.1 (commit 3467e72dba)  
**Confidence:** HIGH (using correct iOS code this time!)
