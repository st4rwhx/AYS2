# Quick Start: v2.6.0.5 Migration

**TL;DR:** Your seam strategy means this is mechanical. Three steps: capture seams → replace core → re-inject seams.

---

## 🎯 One-Page Overview

| What | Old (v2.3.0) | New (v2.6.0.5) | Your Action |
|-----|--------|----------|------------|
| **Bundle ID** | `com.ayano.aysx2` | (inherited) | Keep in CMakeLists.txt seam |
| **App Name** | AYS2 | (inherited) | Keep in CMakeLists.txt seam |
| **JIT Protocol** | legacy brk #0x69 | keepalive + fallback | Keep legacy default in ios_main.mm |
| **Core Layout** | `src/cpp/pcsx2` | `platforms/ios/app/src/main/cpp/pcsx2` | Copy + remap paths |
| **3rdparty** | `src/cpp/3rdparty` | `[root]/3rdparty` | Adjust CMakeLists includes |
| **setGameSettings()** | No param | Needs `upscaleMultiplier: 1.0` | Update ~5 Swift call sites |
| **MetalFX** | Not available | Optional | Expose toggle in Settings UI (optional) |

---

## 🚀 Phase 0: Prep (30 min)

```bash
# 1. Save current seams
grep -rn "AYS2:" src/ > /tmp/ays2_seams.log

# 2. Create branch
git checkout -b migrate/v2.6.0.5-master

# 3. Commit baseline
git add -A
git commit -m "Pre-migration snapshot (v2.3.0)"
```

---

## 📝 Phase 1: Clone & Layout Map (1 hour)

```bash
# 1. Clone master
cd scratchpad
git clone --depth=1 https://github.com/ARMSX2/ARMSX2.git armsx2-v2.6.0.5
cd armsx2-v2.6.0.5

# 2. Check monorepo layout
ls -la platforms/ios/app/src/main/cpp/
ls -la 3rdparty/ | head -20

# 3. Compare paths (back in AYS2 repo)
cd ../..
diff -r src/cpp/pcsx2 scratchpad/armsx2-v2.6.0.5/platforms/ios/app/src/main/cpp/pcsx2 | head -20
```

---

## 🔧 Phase 2: Replace Core (3–4 hours)

```bash
# 1. Backup current
cp -r src/cpp/pcsx2 src/cpp/pcsx2.backup
cp -r src/cpp/common src/cpp/common.backup

# 2. Replace with master's version
rm -rf src/cpp/pcsx2 src/cpp/common
cp -r scratchpad/armsx2-v2.6.0.5/platforms/ios/app/src/main/cpp/pcsx2 src/cpp/
cp -r scratchpad/armsx2-v2.6.0.5/platforms/ios/app/src/main/cpp/common src/cpp/

# 3. Check what files changed
git status | grep "deleted\|new file" | head -30

# 4. Re-apply AYS2 seams using grep list from Phase 0
# For each file in /tmp/ays2_seams.log:
#   - Open the NEW version of that file
#   - Find the line number where the seam goes
#   - Re-insert the "AYS2:" marked edit
```

**Seam injection template (for each file):**

- `src/cpp/CMakeLists.txt` — Bundle ID on line ~35, app name on line ~42, SWIFT_SOURCES on line ~89
- `src/cpp/Info.plist.in` — CFBundleDisplayName seam
- `src/cpp/PrecompiledHeader.h` + `src/cpp/common/PrecompiledHeader.h` — TargetConditionals include
- `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` + `FullscreenUI.cpp` — Brand name replacements
- `src/cpp/ARMSX2Bridge.mm` — buildVersion() method
- `src/cpp/ios_main.mm` — JIT protocol default

---

## 🔄 Phase 3: Swift API Update (1–2 hours)

```bash
# 1. Find all setGameSettings() calls
grep -rn "setGameSettings(" src/swift/

# 2. For each result, add parameter:
#    OLD: setGameSettings(gameId: "...", videoMode: .progressive, resolution: .native)
#    NEW: setGameSettings(gameId: "...", videoMode: .progressive, resolution: .native, upscaleMultiplier: 1.0)

# 3. Files likely affected:
#    - src/swift/Models/SettingsStore.swift
#    - src/swift/Views/GameScreenView.swift
#    - src/swift/Views/Settings/GraphicsSettingsView.swift
```

---

## 🔨 Phase 4–6: Build Setup (3–4 hours)

```bash
# 1. Test CMake configure
cmake -B build -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DARMSX2_REAL_DEVICE=ON \
  -DARMSX2_BUNDLE_IDENTIFIER=com.ayano.aysx2 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  src/cpp

# If errors:
#   - Check 3rdparty include paths (may need adjustment for master's monorepo)
#   - Read error messages carefully (usually missing file/header)
#   - Re-check CMakeLists.txt for any master-specific path assumptions

# 2. Update .github/workflows/build-ios.yml
#    - Change cmake configure paths if needed
#    - Verify IPA version pin

# 3. Commit this phase
git add -A
git commit -m "Phase 2–6: core rebase, API updates, CMake adapted"
```

---

## ✅ Phase 7: CI & Device Test (2–4 hours)

```bash
# 1. Push to feature branch
git push -u origin migrate/v2.6.0.5-master

# 2. Watch GitHub Actions build
#    - Go to https://github.com/st4rwhx/AYS2/actions
#    - Watch build-ios.yml run
#    - If fails: read error, fix, re-push

# 3. Download IPA from release (once build succeeds)

# 4. Sideload to iPhone 15
#    - Use SideStore or Xcode to install the built IPA

# 5. Device tests (critical)
#    Launch app → Settings → About
#    - ✓ Bundle ID is com.ayano.aysx2
#    - ✓ App name is AYS2
#    - ✓ Old games/BIOS still visible
#    
#    Launch a game
#    - ✓ JIT activates (check device log: "CS_DEBUGGED")
#    - ✓ Frame times stable (60 FPS, no crashes)
#    - ✓ In-game OSD says AYS2, not ARMSX2
#    
#    Pause menu
#    - ✓ Menu structure unchanged
#    - ✓ New graphics options visible (MetalFX toggle, etc.)
#    
#    Logs to capture:
#    log stream --predicate 'eventMessage CONTAINS "AYS2"'

# 6. If all tests pass → merge to main
git checkout main
git merge --no-ff migrate/v2.6.0.5-master -m "Migrate to ARMSX2 v2.6.0.5"
git tag v0.1.200  # or appropriate version
git push origin main main:latest

# 7. If tests fail → roll back
git reset --hard HEAD~1  # undo the merge
# OR fix the issue in the feature branch, re-test, re-merge
```

---

## 🎯 Validation Checklist

**Build Level:**
- [ ] CMake configures without errors
- [ ] C++ compiles (no red squiggles in Xcode)
- [ ] Swift compiles (no type errors)
- [ ] IPA generated (18–20 MB expected)
- [ ] version in source.json updated

**Device Level:**
- [ ] App launches (no crash on boot)
- [ ] Bundle ID correct: `com.ayano.aysx2`
- [ ] App name displayed: `AYS2`
- [ ] Old games/BIOS intact (data migration ✓)
- [ ] JIT activates (device log: `CS_DEBUGGED`)
- [ ] Frame times stable (60 FPS no regressions vs v2.3.0)
- [ ] In-game OSD branded `AYS2` (not ARMSX2)
- [ ] Pause menu works
- [ ] Settings visible (including new MetalFX option if exposed)

**Regression Testing:**
- [ ] Play GT3 or similar high-load game → stable framerate
- [ ] Play GTA SA (uses TLB/fastmem heavily) → no excessive faults
- [ ] Save/load state → works
- [ ] Virtual controller → remapping works

---

## 🆘 If Something Breaks

| Symptom | Likely Cause | Fix |
|---------|--------|-----|
| CMake config fails | 3rdparty paths wrong | Adjust CMakeLists.txt to point to correct 3rdparty location |
| Swift compile errors: `EmulatorBridge` undefined | Bridge refactored in master | Check `ARMSX2Bridge.mm` for new signatures, update Swift calls |
| IPA bloated (45+ MB) | Debug symbols included | Check CMake Release flags, add `-DCMAKE_BUILD_TYPE=Release` |
| App won't launch | Code sign issue | Re-sign IPA via Xcode, verify Entitlements.plist has `com.apple.security.cs.allow-jit` |
| JIT won't activate (20 FPS gameplay) | Entitlements not signed | Check device log for JIT errors, verify provisioning profile allows JIT |
| Games at 20 FPS (regression) | Interpreter-only fallback | Check device log for timeout errors, verify new keepalive protocol working |
| "No release or repo found" badge errors | GitHub API lag | Badges auto-refresh; wait 5 min, reload README |

---

## 📞 Need Help?

1. **Read the full docs:** `docs/MASTER_MIGRATION_CHECKLIST.md` (detailed breakdown)
2. **Strategy guide:** `docs/MIGRATION_STRATEGY_V2.6.0.5.md` (why we do each step)
3. **Overlay pattern:** `docs/ELORIS_OVERLAY.md` (understanding seams)

---

## 🏁 Success = This State

```bash
$ git log --oneline | head -5
a1b2c3d Merge branch 'migrate/v2.6.0.5-master' into main
1f2e3d4 Phase 2–6: core rebase, API updates, CMake adapted
9d8e7f6 Pre-migration snapshot (v2.3.0)

$ cat source.json | jq .version
"0.1.200"

$ grep -n "AYS2:" src/cpp/CMakeLists.txt
35: # AYS2: bundle id (seam)
42: # AYS2: app name

$ xcodebuild -project build/ARMSX2iOS.xcodeproj -scheme ARMSX2iOS -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
    PRODUCT_BUNDLE_IDENTIFIER = com.ayano.aysx2
```

---

## ✨ Ready?

```bash
# Start Phase 0 now
git checkout -b migrate/v2.6.0.5-master
echo "Starting migration! 🚀"
```

