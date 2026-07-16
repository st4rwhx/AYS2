# Migration Strategy: AYS2 → ARMSX2 v2.6.0.5 Master Branch

**Document Status:** Ready for Execution  
**Version Target:** ARMSX2 Master v2.6.0.5 (July 14, 2026)  
**Current Version:** ARMSX2 iOSv2.3.0 (P1 completed)  
**Migration Branch:** `migrate/v2.6.0.5-master`  
**Date:** July 16, 2026

---

## 📖 Why This Migration Matters

Your current AYS2 fork (`v2.3.0` from June 20, 2026) works well, but ARMSX2 master has moved forward **25 days** with significant improvements that directly benefit iOS performance and stability:

| Feature | Current (v2.3.0) | Master (v2.6.0.5) | Impact |
|---------|------------------|-------------------|--------|
| **JIT Resilience** | Legacy brk #0x69 only | Keepalive + fallback protocol | More stable on high-load games |
| **EE Optimization** | Standard recompile | Zero-register folding | +1–2% CPU efficiency |
| **Metal Driver** | Baseline | Improved GS/Metal integration | Better frame stability |
| **MetalFX Upscaler** | Not available | Optional spatial upscaling | Quality/perf trade-offs |
| **API Breaking** | `setGameSettings()` simple | Requires `upscaleMultiplier` param | Need Swift code updates |
| **Monorepo Layout** | Flat `src/cpp/` | New `platforms/ios/app/src/main/cpp/` | Need path remapping |

---

## 🎯 Our Seam Strategy (Why You Won't Lose Your Work)

You built AYS2 as a **thin downstream skin** on ARMSX2. The overlay pattern (documented in `docs/ELORIS_OVERLAY.md`) means:

✅ **Additive files stay 100% ours** (never touched by upstream):
- `DashboardView.swift` — NXE dashboard
- `RetroKit.swift` — Design system
- `CommunityView.swift` — Discord integration
- `SoundManager.swift` — UI sounds
- All your app icons and custom assets

✅ **Edits are minimal and marked with `AYS2:` comments** (greppable):
- Bundle ID enforcement
- App name branding
- JIT defaults (legacy protocol)
- In-game OSD branding
- TargetConditionals includes for iOS SDK resolution

This means every rebase is **mechanical**: take upstream's new version, re-insert our marked edits, done. No hand-merging of logic, no architectural conflicts.

---

## 📊 What Changes Between v2.3.0 → v2.6.0.5

**Code moved from flat layout to monorepo:**

```
OLD LAYOUT (v2.3.0):
  AYS2/
    src/cpp/
      CMakeLists.txt
      pcsx2/             ← Core emulator
      common/            ← Common utilities
      3rdparty/          ← Dependencies

NEW LAYOUT (v2.6.0.5):
  ARMSX2/
    platforms/ios/app/src/main/cpp/
      CMakeLists.txt     ← iOS-specific CMake
      pcsx2/             ← Core emulator
      common/            ← Common utilities
      Entitlements.plist
      ARMSX2Bridge.mm
      ios_main.mm
    3rdparty/            ← MOVED to root
```

**Breaking API change:**

```swift
// OLD (v2.3.0) — works fine
setGameSettings(
  gameId: "SLUS_123.456",
  videoMode: .progressive,
  resolution: .native
)

// NEW (v2.6.0.5) — requires upscaleMultiplier
setGameSettings(
  gameId: "SLUS_123.456",
  videoMode: .progressive,
  resolution: .native,
  upscaleMultiplier: 1.0  // ← NEW PARAMETER
)
```

**EE Recompiler improvement:**

The new `zero-register folding` optimization in `pcsx2/R5900/aR5900.cpp` reduces unnecessary register saves/restores. It's transparent to you (no API changes), but games will run ~1–2% faster with less thermal load.

---

## 🔄 The Migration Path (3-Step Approach)

### Step 1: **Capture Current Seams**

Before touching anything, document exactly what we've customized:

```bash
grep -rn "AYS2:" src/cpp src/swift docs --include="*.cpp" --include="*.mm" --include="*.h" --include="*.swift"
```

This produces a list of all our custom points. When we rebase, we'll re-inject these into the new upstream files.

### Step 2: **Replace Core with Master's Version**

1. Clone fresh ARMSX2 master → `scratchpad/armsx2-v2.6.0.5/`
2. Copy `platforms/ios/app/src/main/cpp/{pcsx2,common}/` → our `src/cpp/`
3. Copy/adapt `platforms/ios/app/src/main/cpp/CMakeLists.txt` → our `src/cpp/CMakeLists.txt`
4. Map 3rdparty includes (they moved to root, we keep them local)

### Step 3: **Re-Apply Our Seams**

Using the grep list from Step 1, inject our customizations into the new files:
- Bundle ID: `com.ayano.aysx2`
- App name: `AYS2`
- JIT protocol: legacy `brk #0x69` default
- Branding in ImGuiOverlays.cpp + FullscreenUI.cpp
- TargetConditionals includes in both PrecompiledHeaders
- Version string in ARMSX2Bridge.mm

---

## ⚙️ Detailed Execution Plan

See **`docs/MASTER_MIGRATION_CHECKLIST.md`** for the full 8-phase breakdown:

1. **Phase 0** — Preparation (capture seams, create branch)
2. **Phase 1** — Layout analysis (map old → new paths)
3. **Phase 2** — Core C++ rebase (replace + re-apply seams)
4. **Phase 3** — setGameSettings() API update (add upscaleMultiplier)
5. **Phase 4** — 3rdparty audit (check lib versions)
6. **Phase 5** — Swift bridge update (new MetalFX methods)
7. **Phase 6** — CMake adaptation (new monorepo paths)
8. **Phase 7** — CI/CD update (GitHub Actions workflow)
9. **Phase 8** — Build & device testing (CI-green + iPhone 15 test)

Each phase is **checkpoint-gated**: finish phase N, verify no breakage, commit, move to N+1.

---

## 🧪 Testing & Validation

**CI Tests (automatic):**
- ✅ CMake configuration succeeds
- ✅ C++ compiles without errors
- ✅ Swift compiles without errors
- ✅ IPA signed and ready to distribute
- ✅ version pinned correctly in `source.json`

**Device Tests (manual, on iPhone 15):**
1. **Data preservation** — Existing games/BIOS still visible (bundle ID unchanged ✓)
2. **JIT activation** — Device log shows `CS_DEBUGGED` (JIT entitlements work)
3. **Frame stability** — 60 FPS stable, no JIT timeout crashes
4. **Branding** — In-game OSD says `AYS2`, not ARMSX2
5. **New features** — MetalFX toggle appears in settings (if exposed)
6. **Regression testing** — Play 2–3 known-good games, verify frame times vs v2.3.0

---

## 🛡️ Rollback Safety

If something breaks:

**Option A (safe):**
- Keep `main` branch unchanged (iOSv2.3.0 still deployable)
- Feature branch `migrate/v2.6.0.5-master` abandoned (no harm)
- Users stay on last known-good build

**Option B (if we merge and regret):**
- `git revert <merge-commit>` (one commit rolls back the entire rebase)
- No data loss (bundle ID unchanged)
- CI can re-deploy iOSv2.3.0 from the revert

**Option C (if a mid-phase seam is wrong):**
- Fix the offending seam in the migration branch
- Re-run the affected phase's tests
- Commit and re-push

---

## 📌 Hard Constraints (Never Violate)

1. **Bundle ID stays `com.ayano.aysx2`** — Changing it = user loses app data/saves
2. **App name stays `AYS2`** — In-game OSD, menus, Xcode target all say AYS2
3. **JIT entitlements enabled** — iOS 26+ requires `com.apple.security.cs.allow-jit`
4. **iOS 17.0+ deployment target** — Don't lower (breaks newer iPhone hardware)
5. **No external PAT/secrets in CI** — Use GitHub's native `github.token` only
6. **SideStore source URL** — `https://aysx2.ayanokiyotakaxpsycoworld.workers.dev` immutable

---

## 🚀 Timeline Estimate

| Phase | Effort | Blocker Risk | Notes |
|-------|--------|--------------|-------|
| P0 (Prep) | 30 min | None | Quick snapshot of current seams |
| P1 (Layout) | 1 hour | Low | Just grep + compare paths |
| P2 (C++ Rebase) | 3–4 hours | Medium | Bulk copy + re-apply 8 seams |
| P3 (API Update) | 1–2 hours | Medium | Grep + update ~5 call sites |
| P4 (3rdparty) | 1 hour | Medium-high | If version conflicts → debug build issues |
| P5 (Swift Bridge) | 1 hour | Low | Read master's bridge, port changes |
| P6 (CMake) | 1–2 hours | High | If 3rdparty layout wrong → config fails |
| P7 (CI/CD) | 30 min | Low | Update paths in workflow YAML |
| P8 (Test) | 2–4 hours | High | Build must succeed, device must behave |

**Total estimate: 2–4 days** (accounting for debug time if any phase hits a blocker)

---

## 📝 How to Use This Document

1. **Before starting** — Read this document + `MASTER_MIGRATION_CHECKLIST.md`
2. **For each phase** — Follow the checklist boxes
3. **If you hit an error** — Check the troubleshooting section (below)
4. **When done** — Update this document's status → "Migration Complete ✓"

---

## 🆘 Troubleshooting (Common Issues)

### "CMake configure fails: 3rdparty not found"
**Cause:** Master's CMakeLists.txt references `${CMAKE_SOURCE_DIR}/3rdparty` (moved to root)  
**Fix:** Manually adjust the 3rdparty path in `src/cpp/CMakeLists.txt` to point to our layout

### "Swift compilation fails: `EmulatorBridge.buildVersion()` not found"
**Cause:** New master may have refactored the bridge  
**Fix:** Read master's `ARMSX2Bridge.mm` → check for method rename or signature change → update Swift callsites

### "IPA size exploded from 18 MB → 45 MB"
**Cause:** Likely included debug symbols or unnecessary 3rdparty libs  
**Fix:** Check CMake build flags; ensure `Release` config is used; strip unnecessary libs

### "Device test: JIT won't activate (no `CS_DEBUGGED` in log)"
**Cause:** Entitlements not signed properly, or wrong iOS version  
**Fix:** Verify `Entitlements.plist` has `com.apple.security.cs.allow-jit`, re-sign IPA via Xcode

### "Game launches but runs at 20 FPS (regression from v2.3.0)"
**Cause:** JIT isn't working, falling back to interpreter  
**Fix:** Check device log for JIT errors; verify new keepalive protocol isn't timing out

---

## 📚 Reference Files

- **Overlay pattern:** `docs/ELORIS_OVERLAY.md` — How we stay thin on top of ARMSX2
- **Previous migration:** `docs/ARMSX2_MIGRATION.md` — Notes from v2.3.0 integration
- **Checklist:** `docs/MASTER_MIGRATION_CHECKLIST.md` — Step-by-step execution guide
- **Current CMake:** `src/cpp/CMakeLists.txt` — Existing build config (study it first)
- **Build workflow:** `.github/workflows/build-ios.yml` — CI/CD pipeline

---

## ✅ Sign-Off

**Document created:** July 16, 2026  
**Status:** Ready for Phase 0 (Preparation)  
**Next action:** Commit current state, create migration branch, capture seams

Let's build it! 🚀

