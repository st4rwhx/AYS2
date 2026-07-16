# 🚀 START HERE: AYS2 → ARMSX2 v2.6.0.5 Migration

**Status:** ✅ **ALL DOCUMENTATION READY — Start Migration Anytime**  
**Date:** July 16, 2026  
**Next Action:** Read this file, then follow the 3-minute quick-start below

---

## 📖 What Was Completed

### ✅ Migration Strategy Documents (4 comprehensive guides)
1. **`MIGRATION_STRATEGY_V2.6.0.5.md`** — Why, when, and strategic context
2. **`MASTER_MIGRATION_CHECKLIST.md`** — Detailed 8-phase playbook (main reference)
3. **`QUICK_START_MIGRATION.md`** — Copy-paste commands and quick validation
4. **`MIGRATION_STATUS.md`** — Complete status report

### ✅ README.md Badges Fixed
- Reorganized into **3 clear sections**: Specifications, Release & Stats, Community
- Added missing **Architecture badge** (ARM64)
- Fixed alignment issues — now renders cleanly centered
- 13 total badges, all working and properly colored

### ✅ Your Seam Strategy Documented
- All 8 seam locations mapped
- Grep-ready: `grep -rn "AYS2:" src/`
- Explained why your approach is safe (thin fork pattern)

---

## ⚡ 3-Minute Quick Start

```bash
# Step 1: Read (5 min)
cat docs/MIGRATION_STRATEGY_V2.6.0.5.md

# Step 2: Create branch
git checkout -b migrate/v2.6.0.5-master

# Step 3: Capture current seams
grep -rn "AYS2:" src/ > /tmp/ays2_seams.log

# Step 4: Commit baseline
git add -A
git commit -m "Pre-migration snapshot (v2.3.0)"

# Step 5: Start Phase 0 (detailed)
cat docs/QUICK_START_MIGRATION.md | grep -A 50 "Phase 0"
```

**Done.** You're now in migration mode, ready to execute Phase 1.

---

## 📚 What to Read (In Order)

### 1️⃣ **FIRST: Strategic Overview** (15 min)
📄 `docs/MIGRATION_STRATEGY_V2.6.0.5.md`

**Why:** Understand the big picture before diving in
- What's new in v2.6.0.5 (performance gains, API changes)
- Your seam strategy (why it's safe, how it works)
- Timeline estimate and risk factors
- Hard constraints to never violate

### 2️⃣ **SECOND: Detailed Playbook** (30 min read, reference during execution)
📄 `docs/MASTER_MIGRATION_CHECKLIST.md`

**Why:** Phase-by-phase guide with checkboxes
- Phase 0 (prep): 30 min
- Phase 1 (layout): 1 hour
- Phase 2 (rebase): 3–4 hours
- Phases 3–7: 2–3 hours
- Phase 8 (test): 2–4 hours
- **Total:** 2–4 days

### 3️⃣ **THIRD: Quick Commands** (5 min, reference during execution)
📄 `docs/QUICK_START_MIGRATION.md`

**Why:** Copy-paste ready bash commands for each phase
- Phase 0–7 condensed commands
- Validation checklist
- Troubleshooting table
- Success state

### 4️⃣ **REFERENCE: Session Status**
📄 `MIGRATION_STATUS.md` — What was done this session, key findings, next steps

📄 `WORK_COMPLETED.md` — Detailed breakdown of all work

---

## 🎯 What Happens in Each Phase

| Phase | Time | What You Do | Checkpoint |
|-------|------|-----------|------------|
| **Phase 0** | 30 min | Create branch, capture seams, commit baseline | New branch created, seams listed |
| **Phase 1** | 1 hour | Clone master, analyze new monorepo layout | Layout mapping complete |
| **Phase 2** | 3–4 hours | Replace core C++ (pcsx2, common), re-apply 8 seams | `grep AYS2:` shows all seams re-applied |
| **Phase 3** | 1–2 hours | Update Swift API: add `upscaleMultiplier` to setGameSettings() | All call sites updated |
| **Phase 4** | 1 hour | Audit 3rdparty versions vs master | Version conflicts resolved |
| **Phase 5** | 1 hour | Update Swift bridge for new MetalFX methods | Bridge methods ported |
| **Phase 6** | 1–2 hours | CMake paths adapted for new monorepo | `cmake -B build` succeeds |
| **Phase 7** | 30 min | Update CI/CD workflow paths | `.github/workflows/build-ios.yml` updated |
| **Phase 8** | 2–4 hours | Build CI-green, sideload to iPhone 15, validate | CI passes, app launches, JIT works |

---

## 🛡️ Safety Guarantees

✅ **Bundle ID stays `com.ayano.aysx2`** — User data preserved  
✅ **App name stays `AYS2`** — Branding consistent  
✅ **Feature branch approach** — `main` stays safe, merge only after validation  
✅ **Rollback documented** — If something goes wrong, one commit reverts  
✅ **Thin seam strategy** — Minimal divergence, mechanical rebasing  
✅ **No code changes until Phase 1** — Safe initial steps only

---

## 📊 The Migration at a Glance

```
Current State (v2.3.0, June 20)
    ↓
    | Phase 0: Prep (30 min) — create branch, capture seams
    ↓
    | Phase 1: Layout (1 hour) — analyze new monorepo structure
    ↓
    | Phases 2–3: Core (4–6 hours) — replace C++, update Swift API
    ↓
    | Phases 4–6: Config (3–4 hours) — 3rdparty, bridge, CMake
    ↓
    | Phase 7: CI/CD (30 min) — update workflow
    ↓
    | Phase 8: Test (2–4 hours) — CI-green + device validation
    ↓
New State (v2.6.0.5, July 14)
    ↓
    | All games/BIOS preserved
    | JIT activated and stable
    | +1–2% performance from EE optimization
    | Optional MetalFX upscaler available
    | In-game OSD says AYS2
```

---

## 🎬 Start Now: The Commands

### Immediate (Right Now)

```bash
# Read strategic overview (15 min)
cd ~/Documents/AYS2/AYS2
cat docs/MIGRATION_STRATEGY_V2.6.0.5.md | less
```

### When Ready for Phase 0

```bash
# Create branch
git checkout -b migrate/v2.6.0.5-master

# Capture seams
grep -rn "AYS2:" src/ > /tmp/ays2_seams_current.log
echo "Seams captured in /tmp/ays2_seams_current.log"

# Commit baseline
git add -A
git commit -m "Pre-migration snapshot (v2.3.0)"

# Verify
git log --oneline | head -3
git branch -vv  # Should show new branch in red
```

### Then Phase 1

```bash
# Read quick start for Phase 1 commands
cat docs/QUICK_START_MIGRATION.md | grep -A 20 "Phase 1"
```

---

## ✅ Pre-Migration Checklist

Before you start Phase 0, verify:

- [ ] You've read `docs/MIGRATION_STRATEGY_V2.6.0.5.md`
- [ ] You understand the 8 seams (greppable via `AYS2:`)
- [ ] You have the 4 docs bookmarked
- [ ] You have `git` configured (for commits)
- [ ] You have ~4 GB free disk space (for scratchpad clone)
- [ ] You have Xcode + CMake available (for Phase 6+)
- [ ] You have an iPhone 15 on iOS 17+ ready (for Phase 8)

---

## 🆘 Stuck Somewhere?

| Problem | Solution |
|---------|----------|
| "What do I do first?" | Read `MIGRATION_STRATEGY_V2.6.0.5.md` (strategic overview) |
| "How do I execute Phase X?" | Look in `MASTER_MIGRATION_CHECKLIST.md` (detailed playbook) |
| "What's the bash command for Phase Y?" | Look in `QUICK_START_MIGRATION.md` (quick commands) |
| "Why is my code safe?" | Read `docs/ELORIS_OVERLAY.md` (seam strategy) |
| "What if something breaks?" | Read "Rollback Plan" in `MASTER_MIGRATION_CHECKLIST.md` |
| "How long will this take?" | Read "Timeline Estimate" in `MIGRATION_STRATEGY_V2.6.0.5.md` |

---

## 📞 Reference All Docs

```
Root Level:
  ✓ START_HERE_MIGRATION.md ← You are here
  ✓ MIGRATION_STATUS.md ← What was done this session
  ✓ WORK_COMPLETED.md ← Detailed breakdown

Migration Guides (docs/):
  ✓ MIGRATION_STRATEGY_V2.6.0.5.md ← Strategic overview (READ FIRST)
  ✓ MASTER_MIGRATION_CHECKLIST.md ← Detailed playbook (REFERENCE DURING)
  ✓ QUICK_START_MIGRATION.md ← Copy-paste commands (USE FOR EXECUTION)

Reference Docs (already in place):
  ✓ ELORIS_OVERLAY.md ← Your seam strategy
  ✓ ARMSX2_MIGRATION.md ← Previous migration (v2.3.0) context

Enhanced:
  ✓ README.md ← Badges reorganized into 3 sections + Architecture badge
```

---

## 🎯 Success Looks Like This

**After Phase 8 (migration complete):**

```bash
$ git log --oneline | head -1
a1b2c3d Merge branch 'migrate/v2.6.0.5-master' into main

$ xcodebuild -project build/ARMSX2iOS.xcodeproj -scheme ARMSX2iOS -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
    PRODUCT_BUNDLE_IDENTIFIER = com.ayano.aysx2

$ cat source.json | jq .version
"0.1.200"  # or next version number

$ # On iPhone 15:
$ # - App launches with name "AYS2"
$ # - Old games/BIOS visible
$ # - JIT activates (device log: "CS_DEBUGGED")
$ # - Framerate stable at 60 FPS
$ # - In-game OSD says "AYS2"
```

---

## 🚀 Final Words

Your AYS2 fork uses a **proven thin-overlay pattern** (`ELORIS_OVERLAY.md`). This migration is **mechanical and low-risk**:

1. **Capture seams** (what you've customized)
2. **Replace core** (take master's new version)
3. **Re-inject seams** (put your customizations back)
4. **Test & merge** (CI-green, device-valid, then merge)

Everything is documented. Phases are gated. Rollback is safe. You've got this.

---

**Ready?**

```bash
cat docs/MIGRATION_STRATEGY_V2.6.0.5.md  # Read strategic overview
```

**Then:**

```bash
git checkout -b migrate/v2.6.0.5-master  # Start Phase 0
```

**Go!** 🚀

