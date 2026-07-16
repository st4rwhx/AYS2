# AYS2 ← ARMSX2 core migration plan

## Why
Our tree is an **old snapshot of ARMSX2 + ~3000 lines of hand-patches** (Counters.cpp
×6.8, iR5900.cpp ×2.6, recVTLB.cpp ×2.1, vtlb.cpp ×1.5, DarwinMisc.cpp ×1.5 vs
ARMSX2's clean files). The device log (iPhone 15, iOS 26.3) confirms: JIT works
(CS_DEBUGGED, dual-map+TXM `brk #0x69`), recompiler active, but heavy fastmem
faults on TLB-using games (GTA SA) → demote-to-slow → ~37–50 fps, degrading. The
36 fastmem bypasses + 210 per-address hacks are ours; ARMSX2's fastmem is clean.

## Verified facts (research)
- ARMSX2 (`github.com/ARMSX2/ARMSX2`, GPL-3.0) is the **upstream our whole app forked
  from** — same C++ core AND same iOS Swift shell (`SwiftUIHost/EmulatorBridge/
  AppState/SettingsStore/FileImportHandler/PadLayoutStore...`).
- Current ARMSX2 = **2.4.1 (build 241)**. iOS frontend = SwiftUI, Metal-only.
- iOS build = `platforms/ios/app/src/main/cpp/CMakeLists.txt`, CMake **Xcode**
  generator, unsigned IPA (same as our SideStore flow).
- **Bundle id is a CMake cache var** `ARMSX2_BUNDLE_IDENTIFIER` (default
  `com.armsx2.ios`). We set it to `com.ayano.aysx2` → HARD constraint kept.
- Entitlements: `com.apple.security.cs.allow-jit`,
  `allow-unsigned-executable-memory`, `get-task-allow`. iOS deploy target 17.0.
- iOS 26 killed MAP_JIT for everyone → dual-map+TXM is the only path; ARMSX2 has a
  newer **universal `brk #0xf00d` (JIT26)** registration with timeout→`brk #0x69`
  fallback that our older DarwinMisc lacks.

## Strategy: adopt ARMSX2 2.4.1 tree, re-skin as AYS2
Least-error path = base on their **tested** tree/build verbatim, change only what's
ours. Do NOT hand-merge their code into our old diverged layout (header/struct
mismatches = cascade of breakage).

### Hard constraints (never break)
1. Bundle id **stays `com.ayano.aysx2`** (user cannot reinstall / would lose app data).
2. Same Documents/ layout so existing games/BIOS/saves survive an in-place update.
3. Keep SideStore distribution (unsigned IPA, versioned URL, source.json) + our CI.
4. Keep JIT entitlements (StikDebug flow).

### Phases (each: CI-green by me → device-test by user before relying on it)
- **P1 – Baseline**: import ARMSX2 iOSv2.3.0 clean core, set bundle id
  `com.ayano.aysx2`, app name AYS2. Get CI to build an unsigned IPA.
  ✅ **DONE — CI GREEN on `7ea136d` (2026-07-14), 18.2 MB IPA produced.**
  Bundle id `com.ayano.aysx2` + name AYS2 verified in the built
  product (CI `-DARMSX2_BUNDLE_IDENTIFIER`, CMake `XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER`,
  Info.plist `CFBundleIdentifier=$(PRODUCT_BUNDLE_IDENTIFIER)`, `CFBundleDisplayName=AYS2`).
  Fixes it took: cmake modules, discord-rpc(iOS), 3rdparty/include sync,
  imgui 1.91.9b→1.92.8, rcheevos v11.5.0→v12.3.0, TARGET_OS_IPHONE via both PCHs,
  Swift onPreferenceChange main-actor hop. Core `pcsx2/`+`common/` proven
  byte-identical to iOSv2.3.0 except the two intentional PCH lines; all other
  3rdparty diffs audited and confirmed benign. NEXT: device-test by user.
- **P2 – Branding**: our icon (IMG_4570), splash (prism), LaunchBackgroundColor,
  display name. Verify bundle id + data-dir compatibility on device.
- **P3 – SideStore/CI**: fold our `build-ios.yml` niceties (version pin
  `0.1.${RUN}`, versioned immutable IPA URL, checksums, rolling release,
  source.json publish to st4rwhx/AYS2) onto their build.
- **P4 – UI**: decide — adopt ARMSX2's richer SwiftUI frontend and just recolor to
  our PlayStation-blue NXE, OR port our DashboardView/RetroKit over their bridge.
  (ARMSX2's frontend is more complete than ours now: skins, patches, covers.)
- **P5 – Attribution**: NOTICE crediting ARMSX2 (GPL), keep their COPYING.GPLv3.

### Rollback
Last known-good installable build = run #101 (`6465644`). The migration lands on
the same branch but the user only installs a build after it goes CI-green AND they
device-test it. Any red/staged commit is never the "ship" build.

## Decisions locked
- **P4 (UI): keep OUR DashboardView/RetroKit as the top-level menu**, layered over
  ARMSX2's frontend + bridge. We ADOPT all their machinery (core, settings stores,
  skins/patches/covers, native bridge) but our NXE PlayStation-blue dashboard is
  the front door, wired to their EmulatorBridge/AppState.
- **Base: `iOSv2.3.0`** (ARMSX2's latest SHIPPING iOS release, 2026-06-20;
  commit will be pinned). NOT master, NOT the `v2.5.x` tags.
  - `v2.5.x` tags = desktop/core only, NO iOS app.
  - master = mid monorepo-refactor, iOS CI marked non-blocking (may be red);
    its "clean" core (vtlb 1605) is the DESKTOP core WITHOUT the iOS-necessary
    fastmem workarounds — not what ships on iPhone.
  - `iOSv2.3.0` = same layout as our fork (`app/src/main/{cpp,swift}`, vendored
    core + 3rdparty), proven buildable/shipped, and is ~5 weeks newer than our
    2026-05-14 fork base.

## CORRECTION to the diagnosis (verified against iOSv2.3.0, the RIGHT upstream)
- **Fastmem is NOT our divergence.** Our `vtlb.cpp` (2389) ≈ ARMSX2 iOS release
  (2369). The dual-map/TXM fastmem workarounds are ARMSX2's iOS *standard*
  (needed on real devices). The earlier "clean 1605" was master's DESKTOP core.
- **Our real bloat vs the iOS release**: `Counters.cpp` 7179 vs 1073 (×6.7),
  `iR5900.cpp` 7135 vs 2738 (×2.6), `recVTLB.cpp` 2253 vs 1072 (×2.1),
  `DarwinMisc.cpp` 2172 vs 1265 (×1.7). These are our own debug probes +
  per-address hacks, added AFTER forking instead of tracking ARMSX2's fixes.
- So the migration to iOSv2.3.0 removes OUR ~9000 lines of accumulated
  hand-debugging and picks up 5 weeks of their upstream fixes, while keeping the
  same (correct) iOS fastmem approach.
- **Data-dir compatibility CONFIRMED**: ARMSX2 uses the same EmuFolders subdirs
  (`bios`, `sstates`, `memcards`) → same-bundle-id update keeps games/BIOS/saves.
  (Re-verify the `iso`/games dir in P2.)

## Practical note
Full tree migration is a large, multi-build effort; CI (compile) verified by the
assistant, runtime verified on-device by the user. Build #101 (`6465644`) stays the
installable build until the migrated tree is CI-green AND device-tested. Disk in a
single session is limited — the ARMSX2 base may need a shallow/pinned checkout.
