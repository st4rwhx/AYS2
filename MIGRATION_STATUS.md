# AYS2 Migration Status Report

**Date:** July 16, 2026  
**Status:** 🟢 READY FOR EXECUTION  
**Migration Target:** ARMSX2 Master v2.6.0.5 (July 14, 2026)  
**Current Version:** ARMSX2 iOSv2.3.0  
**Estimated Timeline:** 2–4 days (phased approach)

---

## ✅ Completed: Pre-Migration Documentation

### Documentation Created

1. **`docs/MASTER_MIGRATION_CHECKLIST.md`** (3000+ words)
   - 8-phase execution plan with checkboxes
   - Phase-by-phase breakdown of seam re-application
   - API change details (`setGameSettings()` → add `upscaleMultiplier`)
   - Hard constraints and success criteria
   - Rollback procedures

2. **`docs/MIGRATION_STRATEGY_V2.6.0.5.md`** (2500+ words)
   - Strategic overview of why this migration matters
   - Comparison table: v2.3.0 vs v2.6.0.5 features
   - Explanation of seam strategy (why you won't lose work)
   - 3-step migration path (capture → replace → re-inject)
   - Timeline estimate with blocker risks
   - Troubleshooting guide for 5 common failure modes

3. **`docs/QUICK_START_MIGRATION.md`** (1500+ words)
   - One-page TL;DR overview
   - Phase 0–7 condensed commands (copy-paste ready)
   - Validation checklist (build + device tests)
   - Symptom → cause → fix table
   - Ready-to-execute bash snippets

4. **README.md Badge Updates** ✅ COMPLETED
   - Reorganized badges into 3 sections: **Specifications**, **Release & Stats**, **Community**
   - Added missing **Architecture** badge (ARM64)
   - Fixed alignment with section headers and bold text
   - Updated all badge URLs and colors for consistency
   - Now renders cleanly in center-aligned div

---

## 🎯 Key Findings: What's New in v2.6.0.5

| Feature | Status | Impact | Notes |
|---------|--------|--------|-------|
| **JIT Resilience** | ✅ New | Critical | Keepalive + fallback protocol replaces legacy brk #0x69 → more stable under load |
| **EE Zero-Register Opt** | ✅ New | Performance | +1–2% CPU efficiency, transparent to user |
| **Metal/GS Stability** | ✅ Improved | Stability | Cleaner Metal driver integration |
| **MetalFX Upscaler** | ✅ New | Optional | Spatial upscaling for perf/quality trade-offs (optional UI toggle) |
| **API Breaking Change** | ⚠️ Required | Update | `setGameSettings()` now requires `upscaleMultiplier: 1.0` parameter |
| **Monorepo Layout** | ⚠️ Structural | Remap | Paths moved to `platforms/ios/app/src/main/cpp/` |
| **3rdparty Location** | ⚠️ Structural | Remap | Moved to repository root (was `src/cpp/3rdparty/`) |
| **EE/VU Recompilers** | ℹ️ No change | Reference | Still Phase 6 (70% stubs), no performance breakthrough yet |

---

## 🛡️ Your Seam Strategy: Why This Is Safe

Your `ELORIS_OVERLAY` pattern means:

✅ **Additive files (100% yours):**
- DashboardView, RetroKit, CommunityView (UI)
- SoundManager, custom assets
- App icon, splash video
- **Action:** Copy forward untouched

✅ **Minimal marked edits (greppable via `AYS2:`):**
- Bundle ID enforcement
- App name branding
- JIT defaults
- In-game OSD branding
- TargetConditionals includes
- **Action:** Re-inject into new upstream files

**Result:** Each rebase is mechanical, no hand-merging of logic. Every `AYS2:` marker is findable in one grep command.

---

## 📋 Migration Phases (Quick Overview)

| Phase | Duration | Action | Checkpoint |
|-------|----------|--------|------------|
| **Phase 0** | 30 min | Capture seams, create branch, commit baseline | `git branch -vv` shows new branch |
| **Phase 1** | 1 hour | Clone master, compare paths, document layout | Layout mapping complete |
| **Phase 2** | 3–4 hours | Replace core, re-inject seams (8 locations) | `grep -rn "AYS2:" src/` shows all re-applied |
| **Phase 3** | 1–2 hours | Update Swift API: add `upscaleMultiplier` param | `grep setGameSettings` finds no old-format calls |
| **Phase 4** | 1 hour | Audit 3rdparty versions vs master | Version list compared, no conflicts |
| **Phase 5** | 1 hour | Update Swift bridge for new MetalFX methods | ARMSX2Bridge.mm methods ported |
| **Phase 6** | 1–2 hours | CMake paths adapted, config succeeds | `cmake -B build ...` runs without errors |
| **Phase 7** | 30 min | CI/CD workflow updated | `.github/workflows/build-ios.yml` path-correct |
| **Phase 8** | 2–4 hours | Build CI-green, sideload to iPhone 15, device test | Build succeeds, app launches, JIT works, frame stable |

---

## 📞 How to Start

### Immediate Next Steps

1. **Read the docs in order:**
   ```
   1. This file (MIGRATION_STATUS.md) — Overview ← You are here
   2. docs/MIGRATION_STRATEGY_V2.6.0.5.md — Strategic context
   3. docs/MASTER_MIGRATION_CHECKLIST.md — Detailed playbook
   4. docs/QUICK_START_MIGRATION.md — Copy-paste commands
   ```

2. **Create migration branch:**
   ```bash
   cd ~/Documents/AYS2/AYS2
   git checkout -b migrate/v2.6.0.5-master
   ```

3. **Start Phase 0 (Preparation):**
   ```bash
   # Capture current seams
   grep -rn "AYS2:" src/ > /tmp/ays2_seams_current.log
   
   # Commit baseline
   git add -A
   git commit -m "Pre-migration snapshot (v2.3.0)"
   ```

4. **Clone ARMSX2 master for analysis:**
   ```bash
   cd scratchpad
   git clone --depth=1 https://github.com/ARMSX2/ARMSX2.git armsx2-v2.6.0.5
   cd armsx2-v2.6.0.5
   git log --oneline | head -5  # Verify we're on master
   ```

5. **Proceed through Phase 1 in `docs/QUICK_START_MIGRATION.md`**

### Documentation Structure

- **Strategic (Why):** `MIGRATION_STRATEGY_V2.6.0.5.md` — reasoning, timeline, constraints
- **Tactical (How):** `MASTER_MIGRATION_CHECKLIST.md` — step-by-step with checkboxes
- **Operational (What):** `QUICK_START_MIGRATION.md` — copy-paste commands, validation tests

---

## 🚀 Success Criteria (Post-Merge)

**Build Level:**
- ✅ CI/CD green (CMake, C++, Swift compile)
- ✅ IPA generated 18–20 MB
- ✅ Source version updated in `source.json`

**Device Level:**
- ✅ App launches (no crash)
- ✅ Bundle ID: `com.ayano.aysx2`
- ✅ App name: `AYS2`
- ✅ Old games/BIOS visible (data preserved)
- ✅ JIT activates (device log: `CS_DEBUGGED`)
- ✅ Framerate stable 60 FPS (no regressions)
- ✅ In-game OSD says `AYS2` (not ARMSX2)
- ✅ New graphics settings visible
- ✅ Pause menu functional

**Regression Testing:**
- ✅ High-load game (GT3): stable framerate
- ✅ TLB-heavy game (GTA SA): no excessive faults
- ✅ Save/load state: works
- ✅ Virtual controller remapping: works

---

## 🛑 Hard Constraints (Never Violate)

1. **Bundle ID:** Always `com.ayano.aysx2` (user data loss if changed)
2. **App name:** Always `AYS2` (branding requirement)
3. **iOS deployment:** Stay at 17.0+ (don't lower)
4. **JIT entitlements:** Must be enabled (performance requirement)
5. **SideStore URL:** Stay as `https://aysx2.ayanokiyotakaxpsycoworld.workers.dev`

---

## 📊 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| CMake paths conflict | Medium | 4–6 hours debug | Clear phase-by-phase docs, path mapping upfront |
| Swift API breaking | Medium | 2–4 hours debug | API change documented, call sites listed |
| 3rdparty version conflict | Medium | 2–4 hours debug | Audit phase planned, common version issues listed |
| JIT doesn't activate on device | Low | 2–4 hours debug | Device log inspection guide, troubleshooting section |
| Performance regression | Low | Rollback to v2.3.0 | CI-gated, device testing validates before merge |

---

## 💾 Rollback Safety

**If something goes wrong:**
- Feature branch abandoned (no impact to users)
- `main` stays on v2.3.0 (fully functional, deployable)
- If merged and regret: `git revert <commit>` (one commit undoes entire migration)
- Bundle ID unchanged → no user data loss in either case

---

## 📚 Reference Files

All migration docs located in `docs/`:

```
docs/
├── ELORIS_OVERLAY.md                    ← How we stay thin on ARMSX2
├── ARMSX2_MIGRATION.md                  ← Previous v2.3.0 integration notes
├── MASTER_MIGRATION_CHECKLIST.md        ← Detailed 8-phase playbook (START HERE NEXT)
├── MIGRATION_STRATEGY_V2.6.0.5.md       ← Strategic overview & decisions
└── QUICK_START_MIGRATION.md             ← Copy-paste commands & validation
```

Core files that will change:
```
src/cpp/
├── CMakeLists.txt                       ← Bundle ID, app name seams
├── Info.plist.in                        ← Display name seam
├── PrecompiledHeader.h                  ← TargetConditionals seam
├── ARMSX2Bridge.mm                      ← Version string seam
├── ios_main.mm                          ← JIT protocol seam
├── pcsx2/                               ← Entire core replaced
├── common/                              ← Entire core replaced
└── 3rdparty/                            ← Audit & update versions as needed

src/swift/
└── Models/SettingsStore.swift           ← Add upscaleMultiplier param
```

---

## ✅ Status Summary

| Area | Status | Notes |
|------|--------|-------|
| **Documentation** | ✅ Complete | 3 guide docs + quick-start + this status |
| **README Badges** | ✅ Fixed | Reorganized into 3 sections, added Architecture badge |
| **Seam Strategy** | ✅ Ready | Documented, grep-ready, low-touch |
| **Pre-migration prep** | ✅ Ready | Just need to create branch and start Phase 0 |
| **Migration branch** | ⏳ Ready when you start | `migrate/v2.6.0.5-master` |
| **CI/CD update** | ⏳ Phase 7 | Workflow path updates planned |
| **Device testing** | ⏳ Phase 8 | iPhone 15 validation + regression suite |

---

## 🎬 Action: Start Migration Now

```bash
# 1. Read strategic overview
cat docs/MIGRATION_STRATEGY_V2.6.0.5.md | less

# 2. Read detailed checklist  
cat docs/MASTER_MIGRATION_CHECKLIST.md | less

# 3. Start Phase 0
git checkout -b migrate/v2.6.0.5-master
grep -rn "AYS2:" src/ > /tmp/ays2_seams_current.log
git add -A
git commit -m "Pre-migration snapshot (v2.3.0)"

# 4. Continue with Phase 1
cat docs/QUICK_START_MIGRATION.md | grep -A 20 "Phase 1"
```

---

## 📞 Questions?

- **Why this approach?** → Read `ELORIS_OVERLAY.md`
- **What exactly changes?** → Read `MIGRATION_STRATEGY_V2.6.0.5.md` (tables section)
- **Step-by-step?** → Read `MASTER_MIGRATION_CHECKLIST.md` (phase-by-phase)
- **Just show me commands?** → Read `QUICK_START_MIGRATION.md` (copy-paste)

---

**🚀 Ready to migrate? Start with Phase 0!**

