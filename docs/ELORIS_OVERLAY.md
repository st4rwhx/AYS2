# ELORIS-PRISM Overlay — how we ride on top of ARMSX2 without breaking

ELORIS-PRISM is a **downstream skin + hardening layer** on top of the ARMSX2 iOS
emulator core. ARMSX2 moves fast (native ARM64 recompiler landing phase by phase,
NEON audio, Metal GS work). We want **every ARMSX2 update for free**, without our
own UI/branding/JIT fixes getting clobbered — and we want to be able to **spot
their gaps and beat them where it counts**.

This file is the contract that makes both possible. Keep it accurate: if you add
or move a divergence, update this file in the same commit.

---

## 1. The golden rule

> **Everything ELORIS is either (a) a NEW file the upstream never touches, or
> (b) a MINIMAL, MARKED edit inside an upstream file.**

The smaller and more marked our footprint, the more mechanical every rebase is.
Every hand-edit we make inside an upstream file MUST carry the marker

```
ELORIS-PRISM:
```

so the entire seam surface is greppable in one command:

```sh
grep -rn "ELORIS-PRISM:" src/
```

If a change can live in a new file instead of editing an upstream file, it MUST.

---

## 2. The overlay manifest (current)

### 2a. Additive files — 100% ours, upstream never has them
Copied forward untouched on every rebase.

| File | What |
|---|---|
| `src/swift/Views/DashboardView.swift` | NXE dashboard shell, cover carousel, settings-tile hub, community bar |
| `src/swift/Views/RetroKit.swift` | Light/dark NXE design system (colors, TopNav chrome, PS glyphs, HintBar) |
| `src/swift/Views/CommunityView.swift` | Discord/GitHub welcome sheet + floating community bar |
| `src/swift/Views/DiscordLogoShape.swift` | Discord logo drawn natively as a SwiftUI Shape |
| `src/swift/Models/SoundManager.swift` | UI sounds |
| `src/swift/Views/TermsOfUseView.swift` | Terms of use / privacy screen |
| `src/assets/Assets.xcassets/AppIcon.appiconset/*` | Our app icon (13 sizes) |

### 2b. Seams — upstream files we edit (keep MINIMAL + MARKED)

| File | Seam (what we change) |
|---|---|
| `src/swift/Views/RootView.swift` | show `DashboardView()` instead of the tab menu; app color-scheme apply; community welcome sheet |
| `src/swift/Views/GameScreenView.swift` | pause button icon → pause; pause menu redesigned as tile grid |
| `src/swift/Models/SettingsStore.swift` | `AppColorScheme` (system/light/dark) setting |
| `src/swift/Views/Settings/AppearanceSettingsView.swift` | Theme picker |
| `src/swift/Views/GameListView.swift` | cover-flow carousel enabled in portrait (drop landscape-only gate) |
| `src/cpp/ios_main.mm` | JIT protocol default → `legacy` (brk #0x69) + one-time V2 migration |
| `src/cpp/pcsx2/PrecompiledHeader.h` | `#include <TargetConditionals.h>` so `TARGET_OS_IPHONE` resolves |
| `src/cpp/common/PrecompiledHeader.h` | same TargetConditionals include |
| `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` | in-game OSD brand → `ELORIS-PRISM` |
| `src/cpp/pcsx2/ImGui/FullscreenUI.cpp` | fullscreen heading brand → `ELORIS-PRISM` |
| `src/cpp/ARMSX2Bridge.mm` | `buildVersion()` → `ELORIS-PRISM v…` |
| `src/cpp/CMakeLists.txt` | bundle id `com.balaj.elorisprism`, app name, our SWIFT_SOURCES additions |
| `src/cpp/Info.plist.in` | `CFBundleDisplayName` → ELORIS-PRISM |
| `.github/workflows/build-ios.yml` | pin IPA version to `0.1.<run>`, SideStore publish, checksums |

### 2c. Hard constraints (never violate on any rebase)
- **Bundle id stays `com.balaj.elorisprism`** — changing it loses the user's install/data.
- Keep the JIT default = `legacy` (brk #0x69 / StikDebug) on iOS.
- Keep `TargetConditionals.h` in both PCHs (our vendored zlib doesn't pull it).
- SideStore IPA version must equal `source.json` version (`0.1.<run>`).

---

## 3. Rebase playbook — moving to a newer ARMSX2 iOS tag

Upstream layout is `app/src/main/{cpp,swift,assets}`; ours is `src/{cpp,swift,assets}`.
Upstream is a partial clone at `scratchpad/armsx2` with `origin =
ARMSX2/ARMSX2`. iOS tags look like `iOSvX.Y.Z` (NOT the `2.4.x`/`v2.5.x` Android
tags).

1. **Pick the tag.** `git -C scratchpad/armsx2 ls-remote --tags origin | grep iOSv | sort -V | tail`. Fetch it.
2. **See what changed** (learn first): `git -C armsx2 log --oneline OLDTAG..NEWTAG`
   and `git -C armsx2 diff --stat OLDTAG..NEWTAG -- app/src/main/cpp/pcsx2 app/src/main/cpp/common`.
   Note recompiler/GS/SPU2 progress and anything that touches a seam file.
3. **Replace the core wholesale** from the new tag: `pcsx2/`, `common/`, and any
   changed `3rdparty/` (diff each; only imgui/rcheevos have been real couplings).
4. **Re-apply the additive files** (§2a) — they're ours, copy forward as-is.
5. **Re-apply each seam** (§2b). For upstream files that changed between tags,
   3-way it: take upstream's new version, then re-insert our marked edit. Grep
   `ELORIS-PRISM:` on the OLD tree to see exactly what to re-insert.
6. **Re-verify the hard constraints** (§2c).
7. **Build green in CI**, fixing 3rdparty version couplings as they surface
   (the pattern is always: find the exact cause in the new tree → minimal fix).
8. **Update this manifest** if any seam moved.

Conflict expectation: ARMSX2 sometimes rebuilds the very things we skin (they
"rebuilt the in-game pause menu" and "redesigned per-game settings" in iOSv2.4.0).
When that happens, **decide per feature**: keep ours, take theirs, or merge —
and record the decision here.

---

## 4. How we SURPASS them, not just track them

Because our core is kept byte-identical to upstream (except marked seams), we can
diff every release and **read their work like an open book**. Use that.

1. **Mine each release diff** (`log OLDTAG..NEWTAG`) for:
   - **Stubs / "Phase N" / TODO / skeleton** — the ARM64 EE recompiler (`pcsx2/arm64/aR5900*`, `aVU*`) is explicitly *incremental*; its own header says "skeleton, stubs, interpreter is ground truth until functional." That is a **map of what's not done yet**.
   - Files touched repeatedly across releases = their current hot area = where the perf/compat is still being won.
2. **Track the gaps** in `docs/ELORIS_GAPS.md` (create as needed): for each known
   incomplete area, note where it is, why it's slow/broken, and whether we can
   help (a targeted fix upstream) or route around it (per-game setting, iOS tuning).
3. **Win on iOS-specific ground they under-invest in** — this is our edge:
   - **JIT resilience**: they default to the fragile universal protocol on iOS 26; we already default to legacy (brk #0x69). Keep hardening the StikDebug handshake and fallbacks.
   - **Frame pacing / thermals / Metal**: iOS-specific tuning (present-skip, cap60, adaptive backoff, resolution scaling under thermal pressure).
   - **UX**: our NXE dashboard, carousel, community — things a core team doesn't prioritize.
4. **Contribute the small wins upstream** (a recompiler bug fix, an iOS entitlement
   fix). It's GPL — upstreaming keeps our fork thin and earns goodwill.
5. **Do our own measurements.** Don't guess perf — capture the `@@…@@` device
   probes (JIT mode, frame times, fastmem faults) and compare before/after each
   rebase and each tuning change.

The honest ceiling: matching AetherSX2-class speed needs the **native ARM64
recompiler to be finished** — which is exactly what ARMSX2 is building. We beat
them by (a) always shipping their newest core fast and clean, and (b) owning the
iOS layer (JIT robustness, pacing, UX) better than they do.
