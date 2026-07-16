# AYS2 ← ARMSX2 v2.6.0.5 Master Branch Migration Checklist

**Status:** Ready to Execute  
**Target Version:** ARMSX2 Master v2.6.0.5 (July 14, 2026)  
**Current Version:** ARMSX2 iOSv2.3.0  
**Bundle ID Constraint:** `com.ayano.aysx2` (HARD — preserves user data)  
**Estimated Effort:** 2–4 days (careful rebase + device testing)

---

## 🎯 Key Improvements in v2.6.0.5

✅ **JIT Resilience** — New keepalive + fallback system (better than our legacy brk #0x69)  
✅ **Zero-register EE Optimization** — ~1–2% perf boost in EE recompiler  
✅ **Better GS/Metal Stability** — Cleaner Metal driver integration  
✅ **MetalFX Spatial Upscaler** — Optional new feature for performance/quality trade-offs  
⚠️ **Breaking Change** — `setGameSettings()` now requires `upscaleMultiplier` parameter  
⚠️ **Monorepo Layout Shift** — Paths moved to `platforms/ios/app/src/main/cpp/`  
⚠️ **EE Recompiler** — Phase 6 still (70% stubs), no major changes since iOSv2.3.0  
⚠️ **VU Recompiler** — Still Phase 6, no updates

---

## 📋 Execution Plan — 8 Phases

### **Phase 0: Preparation** ✓ (You are here)

- [ ] Commit current state to `main` (clean baseline)
- [ ] Create feature branch: `git checkout -b migrate/v2.6.0.5-master`
- [ ] Document all AYS2 custom seams before migration (run `grep -rn "AYS2:" src/` to capture)
- [ ] Take screenshot of current working state on device

**Files to read before starting:**
- `docs/ELORIS_OVERLAY.md` — Seam strategy (already read ✓)
- `docs/ARMSX2_MIGRATION.md` — Previous migration context (already read ✓)

---

### **Phase 1: Layout Analysis & Path Mapping**

The master branch uses new monorepo layout. Map the old paths to new ones:

```
OLD (iOSv2.3.0):
  src/cpp/CMakeLists.txt
  src/cpp/pcsx2/
  src/cpp/common/
  src/cpp/3rdparty/
  src/cpp/Info.plist.in
  src/cpp/Entitlements.plist
  src/cpp/ARMSX2Bridge.mm
  src/cpp/DarwinMisc.h

NEW (v2.6.0.5 master):
  platforms/ios/app/src/main/cpp/CMakeLists.txt
  platforms/ios/app/src/main/cpp/pcsx2/
  platforms/ios/app/src/main/cpp/common/
  [root]/3rdparty/  ← MOVED to root
  [root]/pcsx2/Info.plist.in  ← MOVED
  platforms/ios/app/src/main/cpp/Entitlements.plist
  platforms/ios/app/src/main/cpp/ARMSX2Bridge.mm
  platforms/ios/app/src/main/cpp/DarwinMisc.h
```

**Action:**
- [ ] Clone fresh ARMSX2 master to `scratchpad/armsx2-v2.6.0.5/`
- [ ] Compare file layout: `git -C scratchpad/armsx2-v2.6.0.5 log --oneline iOSv2.3.0..HEAD | head -20`
- [ ] Document exact path changes in this checklist

---

### **Phase 2: Core C++ Rebase** (Seams only)

Replace our `src/cpp/{pcsx2,common}` wholesale with master's version, but **preserve all marked AYS2 edits**.

**Steps:**

1. **Export AYS2 seams from current tree:**
   ```bash
   grep -rn "AYS2:" src/cpp/ > /tmp/ays2_seams_current.log
   ```
   This captures:
   - `src/cpp/CMakeLists.txt` — Bundle ID, app name, Swift sources
   - `src/cpp/Info.plist.in` — Display name
   - `src/cpp/ImGuiOverlays.cpp` — In-game OSD brand
   - `src/cpp/FullscreenUI.cpp` — Fullscreen brand
   - `src/cpp/ARMSX2Bridge.mm` — Version string
   - `src/cpp/PrecompiledHeader.h` — TargetConditionals include
   - `src/cpp/common/PrecompiledHeader.h` — TargetConditionals include
   - `src/cpp/ios_main.mm` — JIT protocol default + V2 migration

2. **Delete old core:**
   ```bash
   rm -rf src/cpp/pcsx2 src/cpp/common
   ```

3. **Copy master's core (accounting for new monorepo path):**
   ```bash
   cp -r scratchpad/armsx2-v2.6.0.5/platforms/ios/app/src/main/cpp/pcsx2 src/cpp/
   cp -r scratchpad/armsx2-v2.6.0.5/platforms/ios/app/src/main/cpp/common src/cpp/
   ```

4. **Update CMakeLists.txt paths** (from new monorepo layout to our flat layout):
   - [ ] Replace all `${CMAKE_SOURCE_DIR}/pcsx2/` → `${CMAKE_SOURCE_DIR}/pcsx2/` (no change, we keep our layout)
   - [ ] Handle 3rdparty references: master moved 3rdparty to root; adjust includes
   - [ ] Re-apply bundle ID + app name seams (marked `AYS2:`)
   - [ ] Re-apply SWIFT_SOURCES seams (additive files: DashboardView, RetroKit, etc.)

5. **Re-apply PrecompiledHeader seams:**
   - [ ] `src/cpp/PrecompiledHeader.h` — add `#include <TargetConditionals.h>`
   - [ ] `src/cpp/common/PrecompiledHeader.h` — add `#include <TargetConditionals.h>`

6. **Re-apply ImGui branding seams:**
   - [ ] `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` — replace ARMSX2 brand with AYS2
   - [ ] `src/cpp/pcsx2/ImGui/FullscreenUI.cpp` — replace ARMSX2 brand with AYS2

7. **Re-apply Info.plist.in seam:**
   - [ ] Update `CFBundleDisplayName` → `AYS2`
   - [ ] Verify bundle ID remains `${PRODUCT_BUNDLE_IDENTIFIER}`

8. **Re-apply ARMSX2Bridge seam:**
   - [ ] `src/cpp/ARMSX2Bridge.mm` — update `buildVersion()` to return `AYS2 v…` format

9. **Re-apply ios_main.mm seams:**
   - [ ] JIT protocol default → `legacy` (brk #0x69)
   - [ ] V2 migration code (one-time user upgrade flag)

---

### **Phase 3: setGameSettings() API Update**

The new master requires `upscaleMultiplier` parameter. Find and fix all call sites.

**Action:**
- [ ] Grep for all `setGameSettings(` calls:
  ```bash
  grep -rn "setGameSettings(" src/swift/
  ```
- [ ] Update each call to include `upscaleMultiplier: 1.0` (or user's saved preference)
- [ ] **Files likely affected:**
  - [ ] `src/swift/Models/SettingsStore.swift` — Game settings storage
  - [ ] `src/swift/Views/GameScreenView.swift` — Per-game UI
  - [ ] `src/swift/Views/Settings/GraphicsSettingsView.swift` — Graphics settings

**Example migration:**
```swift
// OLD
setGameSettings(gameId: "SLUS_123.456", videoMode: .progressive)

// NEW
setGameSettings(
  gameId: "SLUS_123.456", 
  videoMode: .progressive,
  upscaleMultiplier: 1.0  // ← ADD THIS
)
```

---

### **Phase 4: 3rdparty Dependency Audit**

Master may have updated critical 3rdparty libraries. Verify compatibility:

- [ ] **libzip** — Check version in master
- [ ] **imgui** — Verify API compatibility (we had to update to 1.92.8 in iOSv2.3.0)
- [ ] **rcheevos** — Verify version (we updated to v12.3.0)
- [ ] **libchdr** — Check if present/needed
- [ ] **Discord SDK** — Verify iOS support (optional feature)

**Action:**
- [ ] Compare `CMakeLists.txt` 3rdparty includes between old and new
- [ ] If any version mismatch causes build failure, update in-place
- [ ] Log any version changes in the build log

---

### **Phase 5: Swift Bridge Update**

ARMSX2Bridge.mm may have new MetalFX methods or other iOS-specific APIs.

**Action:**
- [ ] Read `src/cpp/ARMSX2Bridge.mm` from master
- [ ] Check for new method signatures (especially upscaler-related)
- [ ] Update Swift models (`EmulatorBridge.swift`) if needed
- [ ] Verify no breaking changes to existing Swift callsites

**Files to check:**
- [ ] `src/swift/Models/EmulatorBridge.swift` — C++ bridge interface
- [ ] `src/swift/Models/SettingsStore.swift` — Settings passed to bridge
- [ ] `src/swift/Views/GameScreenView.swift` — Game screen interactions

---

### **Phase 6: CMake & Build Configuration**

Adapt CMakeLists.txt for the new monorepo structure but keep our flat layout.

**Action:**
- [ ] Update CMakeLists.txt to reference 3rdparty at root (if master moved it)
- [ ] Verify all include paths resolve correctly
- [ ] Test CMake configuration:
  ```bash
  cmake -B build -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DARMSX2_REAL_DEVICE=ON \
    -DARMSX2_BUNDLE_IDENTIFIER=com.ayano.aysx2 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    src/cpp
  ```
- [ ] Verify no CMake errors

---

### **Phase 7: CI/CD Update**

Update `.github/workflows/build-ios.yml` for new monorepo paths.

**Action:**
- [ ] Update CMake configure step to use new paths
- [ ] Verify version pin in `source.json` is ready
- [ ] Ensure IPA versioning follows `0.1.<run>` pattern
- [ ] Test dry-run of CI workflow locally

---

### **Phase 8: Build & Device Testing**

Build green in CI, then test on real iPhone 15.

**Action:**
- [ ] Push to feature branch, verify GitHub Actions build succeeds
- [ ] Download built IPA from release
- [ ] Sideload to iPhone 15 via SideStore
- [ ] **Device tests to run:**
  - [ ] Launch app → verify bundle ID is `com.ayano.aysx2`
  - [ ] Verify app name is `AYS2`
  - [ ] Existing games/BIOS still visible (data migration check)
  - [ ] Launch a game → JIT activates (check device log: `CS_DEBUGGED`)
  - [ ] Frame times stable (no JIT timeout crashes)
  - [ ] MetalFX toggle works (if exposed in UI)
  - [ ] Pause menu → in-game OSD shows `AYS2` branding
  - [ ] Settings → verify new graphics options present
- [ ] Capture device logs during gameplay:
  ```bash
  log stream --predicate 'eventMessage CONTAINS "AYS2" or eventMessage CONTAINS "JIT"' --level debug
  ```
- [ ] If all tests pass → merge to `main` and tag release

---

## 🔍 Seam Locations (Quick Reference)

Run this to find all AYS2 customizations:

```bash
grep -rn "AYS2:" src/cpp src/swift docs --include="*.cpp" --include="*.swift" --include="*.mm" --include="*.h" --include="*.md"
```

**Current seams to re-apply:**
1. `src/cpp/CMakeLists.txt` — Bundle ID, app name, SWIFT_SOURCES
2. `src/cpp/Info.plist.in` — Display name
3. `src/cpp/PrecompiledHeader.h` — TargetConditionals include
4. `src/cpp/common/PrecompiledHeader.h` — TargetConditionals include
5. `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` — OSD branding
6. `src/cpp/pcsx2/ImGui/FullscreenUI.cpp` — UI branding
7. `src/cpp/ARMSX2Bridge.mm` — Version string
8. `src/cpp/ios_main.mm` — JIT protocol default, V2 migration

---

## 💾 Rollback Plan

If migration fails:
1. Last known-good build: Run #157 (iOSv2.3.0)
2. Rollback: `git reset --hard HEAD~1` (or revert feature branch)
3. No user data lost (bundle ID unchanged)
4. Redeploy known-good build from releases

---

## 📊 Success Criteria

✅ CI builds without errors  
✅ IPA produced and signed  
✅ App launches on iPhone 15 (both simulator + real device)  
✅ All games/BIOS preserved from previous install  
✅ JIT activates (device log shows `CS_DEBUGGED`)  
✅ Frame times stable at 60 FPS (no regressions vs iOSv2.3.0)  
✅ New MetalFX option visible in graphics settings  
✅ No branding showing ARMSX2 (all says AYS2)  
✅ Bundle ID confirmed as `com.ayano.aysx2`  

---

## 🚀 Next Steps

1. **Clone master branch** — `git clone --depth=1 https://github.com/ARMSX2/ARMSX2.git scratchpad/armsx2-v2.6.0.5`
2. **Create migration branch** — `git checkout -b migrate/v2.6.0.5-master`
3. **Execute Phase 1** — Map out new monorepo layout and paths
4. **Proceed phase-by-phase** — Each phase is CI-gated before next

Ready? Let's start Phase 1 🚀

