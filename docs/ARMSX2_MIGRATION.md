# ELORIS-PRISM ← ARMSX2 core migration plan

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
  `com.armsx2.ios`). We set it to `com.balaj.elorisprism` → HARD constraint kept.
- Entitlements: `com.apple.security.cs.allow-jit`,
  `allow-unsigned-executable-memory`, `get-task-allow`. iOS deploy target 17.0.
- iOS 26 killed MAP_JIT for everyone → dual-map+TXM is the only path; ARMSX2 has a
  newer **universal `brk #0xf00d` (JIT26)** registration with timeout→`brk #0x69`
  fallback that our older DarwinMisc lacks.

## Strategy: adopt ARMSX2 2.4.1 tree, re-skin as ELORIS-PRISM
Least-error path = base on their **tested** tree/build verbatim, change only what's
ours. Do NOT hand-merge their code into our old diverged layout (header/struct
mismatches = cascade of breakage).

### Hard constraints (never break)
1. Bundle id **stays `com.balaj.elorisprism`** (user cannot reinstall / would lose app data).
2. Same Documents/ layout so existing games/BIOS/saves survive an in-place update.
3. Keep SideStore distribution (unsigned IPA, versioned URL, source.json) + our CI.
4. Keep JIT entitlements (StikDebug flow).

### Phases (each: CI-green by me → device-test by user before relying on it)
- **P1 – Baseline**: import ARMSX2 2.4.1 tree (root core + `platforms/ios`), set
  bundle id `com.balaj.elorisprism`, app name ELORIS-PRISM. Get CI to build an
  unsigned IPA. (Their build verbatim first — prove it compiles green in our CI.)
- **P2 – Branding**: our icon (IMG_4570), splash (prism), LaunchBackgroundColor,
  display name. Verify bundle id + data-dir compatibility on device.
- **P3 – SideStore/CI**: fold our `build-ios.yml` niceties (version pin
  `0.1.${RUN}`, versioned immutable IPA URL, checksums, rolling release,
  source.json publish to ayanodeath/ELORIS-PRISM) onto their build.
- **P4 – UI**: decide — adopt ARMSX2's richer SwiftUI frontend and just recolor to
  our PlayStation-blue NXE, OR port our DashboardView/RetroKit over their bridge.
  (ARMSX2's frontend is more complete than ours now: skins, patches, covers.)
- **P5 – Attribution**: NOTICE crediting ARMSX2 (GPL), keep their COPYING.GPLv3.

### Rollback
Last known-good installable build = run #101 (`6465644`). The migration lands on
the same branch but the user only installs a build after it goes CI-green AND they
device-test it. Any red/staged commit is never the "ship" build.

## Open questions for the user
- P4: adopt ARMSX2's frontend (recolor) vs re-port our custom dashboard?
- Confirm the app data dir path matches so an in-place update keeps their games.
