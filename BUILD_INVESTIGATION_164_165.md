# 🔍 BUILD INVESTIGATION - Runs #162-165

**Investigation Date**: 2026-07-16  
**Status**: Build #165 IN PROGRESS (with iOS IOKit fix)

---

## 📊 Build Timeline

| Run | Status | Error | Fix Applied |
|-----|--------|-------|-------------|
| #162 | ❌ FAILED | YAML.cpp: `EventHandlerTree` missing | RapidYAML v0.11+ API |
| #163 | ❌ FAILED | YAML.cpp: `EventHandlerTree` missing | (same fix) |
| #164 | ❌ FAILED | IOCtlSrc.cpp: `IOKit/...h` not found | iOS IOKit issue |
| #165 | ⏳ IN PROGRESS | None yet | iOS IOKit exclusion |

---

## 🔴 Build #164 Error Details

**Error**:
```
/Users/runner/work/AYS2/AYS2/src/cpp/pcsx2/CDVD/Darwin/IOCtlSrc.cpp:11:10: 
fatal error: 'IOKit/storage/IOCDMediaBSDClient.h' file not found
```

**Root Cause**: 
- IOKit is **macOS-only**, not available on iOS
- CMakeLists.txt was adding `pcsx2OSXSources` (containing IOCtlSrc.cpp) for ALL Apple systems
- `if(APPLE)` includes both macOS and iOS, but IOKit doesn't exist on iOS

---

## ✅ Fixes Applied for Build #165

### 1. **CMakeLists.txt** (src/cpp/pcsx2/CMakeLists.txt)

**BEFORE** (included IOCtlSrc.cpp on iOS):
```cmake
if(APPLE OR BSD)
    if(APPLE)
        target_sources(PCSX2 PRIVATE
            ${pcsx2OSXSources})  # ← Includes IOCtlSrc.cpp on iOS!
    else()
        target_sources(PCSX2 PRIVATE
            ${pcsx2FreeBSDSources})
    endif()
```

**AFTER** (exclude IOCtlSrc.cpp on iOS):
```cmake
if(APPLE OR BSD)
    # AYS2: Exclude IOCtlSrc.cpp on iOS - it requires macOS IOKit which doesn't exist on iOS
    if(APPLE AND NOT IOS)  # ← Now only on macOS, not iOS
        target_sources(PCSX2 PRIVATE
            ${pcsx2OSXSources})
    elseif(BSD)
        target_sources(PCSX2 PRIVATE
            ${pcsx2FreeBSDSources})
    endif()
```

### 2. **IOCtlSrc.cpp** (src/cpp/pcsx2/CDVD/Darwin/IOCtlSrc.cpp)

**Added protection** for IOKit includes:
```cpp
#ifdef __APPLE__
// AYS2: IOKit is macOS-only, not available on iOS
#if !TARGET_OS_IPHONE
#include <IOKit/storage/IOCDMediaBSDClient.h>
#include <IOKit/storage/IODVDMediaBSDClient.h>
#endif
#endif
```

### 3. **DriveUtility.cpp** (src/cpp/pcsx2/CDVD/Darwin/DriveUtility.cpp)

**Added protection** for all IOKit includes:
```cpp
#ifdef __APPLE__
// AYS2: IOKit is macOS-only, not available on iOS
#if !TARGET_OS_IPHONE
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDMedia.h>
#include <IOKit/storage/IODVDMedia.h>
#include <IOKit/IOBSD.h>
#include <IOKit/IOKitLib.h>
#endif
#endif
```

---

## 🎯 Commit Details

**Commit**: `8cbfba91`  
**Message**: "Fix: Exclude IOKit-dependent files from iOS build"

**Changes**:
- 3 files modified
- 9 insertions, 2 deletions
- Full history preserved on branch `migrate/v2.6.0.5-clean`

---

## 🚀 Build #165 Status

**Started**: 2026-07-16T02:01:13Z  
**Status**: ⏳ IN PROGRESS  
**Expected Duration**: 15-30 minutes  
**URL**: https://github.com/st4rwhx/AYS2/actions  

**What Should Compile**:
- ✅ CMake configure (without IOCtlSrc.cpp in iOS target)
- ✅ C++ compilation (IOCtlSrc.cpp excluded, DriveUtility.cpp protected)
- ✅ Swift compilation (no changes)
- ✅ IPA generation (no IOKit missing headers)
- ✅ Release upload

---

## 📝 Investigation Process

### Step 1: Analyzed Build #164 Logs
- Used: `gh run view --log` to extract full build logs
- Searched for: `error:` pattern
- Found: IOKit header not found error

### Step 2: Root Cause Analysis
- Verified: IOKit only exists on macOS, not iOS
- Searched: `grep -r "IOKit"` in codebase
- Found: IOCtlSrc.cpp, DriveUtility.cpp reference IOKit
- Checked: ARMSX2 master has same files

### Step 3: Discovered Platform Distinction
- Found: `.backup` files had `#if !TARGET_OS_IPHONE` guards
- Found: `DarwinMisc.cpp` uses `TARGET_OS_IPHONE` condition
- Conclusion: Platform-specific compilation required

### Step 4: Applied Fixes
- Modified: CMakeLists.txt to exclude `pcsx2OSXSources` on iOS
- Protected: IOKit includes with `#if !TARGET_OS_IPHONE` guards
- Preserved: AYS2 seam markers for documentation

---

## ✅ Verification Steps Completed

- [x] Identified root cause (IOKit macOS-only)
- [x] Located affected files (IOCtlSrc.cpp, DriveUtility.cpp)
- [x] Applied CMakeLists.txt fix
- [x] Added compile-time guards in source files
- [x] Created commit with clear message
- [x] Pushed to GitHub
- [x] Verified Build #165 triggered
- [ ] Wait for Build #165 to complete
- [ ] Check for other compilation errors
- [ ] Verify IPA generation
- [ ] Proceed to device testing

---

## 🔍 How to Monitor Build #165

```bash
# Watch build status
gh run view 29465061424 --repo st4rwhx/AYS2 --json status,conclusion

# Get full logs (when complete)
gh run view 29465061424 --repo st4rwhx/AYS2 --log > build165.log

# Search for errors
grep -E "(error:|FAILED|fatal)" build165.log
```

---

## 📌 Key Learnings

1. **Platform Distinction**: `if(APPLE)` in CMake includes BOTH macOS and iOS
   - Must use `if(APPLE AND NOT IOS)` for macOS-only code

2. **Compile-Time Guards**: Use `TARGET_OS_IPHONE` macro in C++ code
   - `#if !TARGET_OS_IPHONE` excludes iOS
   - Already used in other files (DarwinMisc.cpp, backups)

3. **AYS2 Seam Strategy**: Clearly mark platform fixes with comments
   - Helps future migrations understand platform differences
   - Keeps code maintainable and documented

---

**Next**: Monitor Build #165 completion (expected by ~02:30 UTC)

