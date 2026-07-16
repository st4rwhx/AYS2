# Action Plan: Fix AYS2 iOS Build

**Status:** 🔴 CRITICAL - Build currently using ANDROID code  
**Date:** July 16, 2026  
**Context:** User theory confirmed - v2.6.0.5 is Android, not iOS

---

## IMMEDIATE ACTIONS REQUIRED

### 1. Stop All Migration Attempts ⛔

**DO NOT:**
- Continue fixing Info.plist errors (symptom, not cause)
- Try more CMake workarounds
- Push more commits to `migrate/v2.6.0.5-clean`

**Reason:** We're trying to build iOS with ANDROID 2.6.7 code!

---

## CORRECT APPROACH

### Phase 1: Understand Current ARMSX2 iOS State

The ARMSX2 repo at `scratchpad/armsx2-master/` is a **monorepo** with:

```
ARMSX2/
├── platforms/
│   ├── android/   ← Version 2.6.7 (tag: 2.6.0.5)
│   └── ios/       ← Version 2.4.1 (build: 241)
├── pcsx2/         ← Shared emulator core
├── common/        ← Shared utilities  
└── 3rdparty/      ← Dependencies
```

**Key Finding:**
- iOS version = **2.4.1** (build 241)
- Android version = **2.6.7** (tag 2.6.0.5)
- They are DIFFERENT versions!
- iOS does NOT vendor pcsx2/common - it references them from repo root

---

### Phase 2: Clone Full ARMSX2 History

Current clone is shallow (`--depth=1`), need full history:

```bash
cd scratchpad
rm -rf armsx2-master
git clone https://github.com/ARMSX2/ARMSX2.git armsx2-full-history
cd armsx2-full-history

# Find iOS-specific commits
git log --oneline platforms/ios/ | head -30

# Find latest iOS version/tag
git tag -l | grep -i ios
git log --all --grep="iOS" --grep="ios" -i | head -50
```

---

### Phase 3: Identify Correct iOS Source

**Questions to answer:**
1. What is the latest stable iOS version?
2. What commit does iOS 2.4.1 correspond to?
3. Are there any iOS-specific tags/branches?
4. What files are iOS-specific vs shared?

**Files to check:**
- `platforms/ios/app/src/main/cpp/CMakeLists.txt` - iOS version definition
- `platforms/ios/README.md` - iOS documentation
- `platforms/ios/CHANGELOG.md` (if exists) - iOS changes
- Root `pcsx2/` and `common/` - shared core at what commit?

---

### Phase 4: Decision Point

#### Option A: Use iOS 2.4.1 (RECOMMENDED)

**Pros:**
- Official iOS version from ARMSX2
- Known to work on iOS
- Proper iOS platform guards
- Maintained by ARMSX2 team

**Cons:**
- Older than Android 2.6.7
- May miss Android-only features (but we don't need them!)

**How to implement:**
1. Find commit for iOS 2.4.1
2. Copy `platforms/ios/app/src/main/cpp/` files
3. Copy corresponding `pcsx2/` and `common/` from same commit
4. Adapt to AYS2 flat structure
5. Re-apply AYS2 seams (Bundle ID, branding, etc.)

#### Option B: Wait for iOS to Catch Up

**Pros:**
- Eventually get latest features

**Cons:**
- No timeline for iOS 2.6.x release
- Can't ship AYS2 until then
- Android and iOS may never be version-aligned

---

### Phase 5: Revert Current Bad Migration

```bash
cd ~/Documents/AYS2/AYS2

# Create backup of current state
git branch backup/migrate-v2.6.0.5-android-mistake

# Revert to last known good state (before Android import)
git revert 2a944d58 --no-commit

# Or reset hard if needed
git reset --hard 5288d521  # Back to main before migration

# Re-create migration branch
git checkout -b migrate/ios-v2.4.1-clean
```

---

### Phase 6: Import Correct iOS Code

**Strategy: Hybrid Approach**

Since AYS2 uses **flat structure** but ARMSX2 iOS uses **monorepo references**, we need to:

1. **Copy iOS-specific files:**
   ```
   platforms/ios/app/src/main/cpp/
   ├── ARMSX2Bridge.mm         → AYS2's src/cpp/
   ├── ios_main.mm             → AYS2's src/cpp/
   ├── CMakeLists.txt          → Adapt for flat structure
   ├── Info.plist.in           → Copy as-is
   └── Entitlements.plist      → Copy as-is
   ```

2. **Copy shared core at iOS 2.4.1 commit:**
   ```bash
   # In armsx2-full-history repo
   git checkout <iOS-2.4.1-commit>
   
   # Copy to AYS2
   cp -r pcsx2/ ~/Documents/AYS2/AYS2/src/cpp/pcsx2/
   cp -r common/ ~/Documents/AYS2/AYS2/src/cpp/common/
   cp -r 3rdparty/ ~/Documents/AYS2/AYS2/src/cpp/3rdparty/
   ```

3. **Re-apply AYS2 seams:**
   - Bundle ID: `com.ayano.aysx2`
   - App name: `AYS2`
   - JIT defaults
   - Branding in UI

4. **Adapt CMakeLists.txt:**
   - Change paths from monorepo references to flat structure
   - Keep iOS-specific options (ARMSX2_REAL_DEVICE, etc.)
   - Ensure Info.plist handling is iOS-specific

---

### Phase 7: Test & Validate

1. **CMake configure:**
   ```bash
   cmake -B build -G Xcode \
     -DCMAKE_SYSTEM_NAME=iOS \
     -DARMSX2_REAL_DEVICE=ON \
     -DCMAKE_OSX_ARCHITECTURES=arm64 \
     src/cpp
   ```

2. **Build:**
   ```bash
   xcodebuild -project build/ARMSX2iOS.xcodeproj \
     -scheme ARMSX2iOS \
     -configuration Release
   ```

3. **Expected outcomes:**
   - CMake succeeds without path errors
   - Info.plist generated in correct location
   - No Android-specific code compiled
   - All iOS platform guards work
   - Build completes successfully

---

## Timeline Estimate

| Phase | Time | Status |
|-------|------|--------|
| 1. Stop current attempts | ✅ Done | Immediately |
| 2. Clone full history | 30 min | Next |
| 3. Identify iOS source | 1-2 hours | Research |
| 4. Decision | 15 min | Discussion |
| 5. Revert bad migration | 30 min | Git ops |
| 6. Import iOS code | 3-4 hours | Implementation |
| 7. Test & validate | 2-3 hours | Verification |
| **TOTAL** | **7-11 hours** | 1-2 days |

---

## Success Criteria

✅ **Build succeeds** - CI green, IPA generated  
✅ **Version is iOS 2.4.1** - not Android 2.6.7  
✅ **Info.plist correct** - no path errors  
✅ **Platform guards work** - iOS-specific code only  
✅ **AYS2 seams preserved** - branding intact  
✅ **Device test passes** - app launches on iPhone  

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| iOS 2.4.1 has breaking bugs | Low | High | Test before full integration |
| CMake adaptation difficult | Medium | Medium | Reference iOS CMakeLists closely |
| Seams conflict with iOS code | Low | Low | Seams are minimal and marked |
| Full history clone takes long | Low | Low | Use shallow clone with more depth |

---

## Questions for User

Before proceeding, confirm:

1. **Are you OK using iOS 2.4.1 instead of 2.6.x?**
   - It's older but actually for iOS
   - Android 2.6.7 features won't matter for iOS build

2. **Should we revert commit 2a944d58 entirely?**
   - Clean slate approach
   - Or cherry-pick iOS-compatible parts?

3. **Keep backup/migrate-v2.6.0.5-clean branch?**
   - For reference or delete?

4. **Timeline acceptable?**
   - 1-2 days to do this correctly
   - Or prefer quick hack? (not recommended)

---

## Next Immediate Steps

**Right Now:**

1. ✅ Read this action plan
2. ⏸️ Pause any current build attempts
3. ✅ Read ROOT_CAUSE_ANALYSIS.md
4. ❓ Confirm approach with user
5. ▶️ Clone full ARMSX2 history
6. 🔍 Identify iOS 2.4.1 commit

**After User Confirmation:**

7. 🔄 Revert Android code
8. 📥 Import iOS code
9. 🔧 Adapt to AYS2 structure
10. ✅ Test and validate

---

**Status:** WAITING FOR USER CONFIRMATION  
**Recommended:** Proceed with Phase 2 (clone full history) to gather info
