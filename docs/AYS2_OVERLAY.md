# AYS2 Overlay — how we ride on top of ARMSX2 without breaking

AYS2 is a **downstream skin + hardening layer** on top of the ARMSX2 iOS
emulator core. ARMSX2 moves fast (native ARM64 recompiler landing phase by phase,
NEON audio, Metal GS work). We want **every ARMSX2 update for free**, without our
own UI/branding/JIT fixes getting clobbered — and we want to be able to **spot
their gaps and beat them where it counts**.

This file is the contract that makes both possible. Keep it accurate: if you add
or move a divergence, update this file in the same commit.

---

## 1. The golden rule

> **Everything AYS2 is either (a) a NEW file the upstream never touches, or
> (b) a MINIMAL, MARKED edit inside an upstream file.**

The smaller and more marked our footprint, the more mechanical every rebase is.
Every hand-edit we make inside an upstream file MUST carry the marker

```
AYS2:
```

so the entire seam surface is greppable in one command:

```sh
grep -rn "AYS2:" src/
```

If a change can live in a new file instead of editing an upstream file, it MUST.

---

## 2. The overlay manifest (current)

**Last synced to upstream: ARMSX2 iOSv2.4.0** (app version 2.4.0 / build 240).

### 2a. Additive files — 100% ours, upstream never has them
Copied forward untouched on every rebase.

| File | What |
|---|---|
| `src/swift/Views/DashboardView.swift` | NXE dashboard shell, cover carousel, settings-tile hub, community bar |
| `src/swift/Views/RetroKit.swift` | Light/dark NXE design system (colors, TopNav chrome, PS glyphs, HintBar) |
| `src/swift/Views/CommunityView.swift` | Discord/GitHub welcome sheet + floating community bar |
| `src/swift/Views/DiscordLogoShape.swift` | Discord logo drawn natively as a SwiftUI Shape |
| `src/swift/Models/SoundManager.swift` | UI sounds |
| `src/swift/Models/CoreAccessStore.swift` | CORE ACCESS membership: entitlement via our worker, upsell cadence |
| `src/swift/Views/CoreAccessView.swift` | CORE ACCESS storefront + post-game upsell sheet |
| `coreaccess/worker/*` | Stripe checkout redirect + entitlement API (Cloudflare Worker) |
| `src/swift/Views/TermsOfUseView.swift` | Terms of use / privacy screen |
| `src/assets/Assets.xcassets/AppIcon.appiconset/*` | Our app icon (13 sizes) |
| `src/swift/Views/ShadeBoostPreviewView.swift` | Live Shade Boost preview: decodes the bundled clip, drives it through the shader below |
| `src/swift/Shaders/ShadeBoostPreview.metal` | SwiftUI `.colorEffect` mirror of `ps_shadeboost` (convert.metal) for the preview above |
| `src/assets/resources/shadeboost_preview.gif` | Bundled gameplay clip for the Shade Boost preview (user-supplied capture) |

### 2b. Seams — upstream files we edit (keep MINIMAL + MARKED)

| File | Seam (what we change) |
|---|---|
| `src/swift/Views/RootView.swift` | show `DashboardView()` instead of the tab menu; app color-scheme apply; community welcome sheet; post-game CORE ACCESS upsell |
| `src/swift/Views/GameScreenView.swift` | pause button icon → `pause.fill` (menu itself is upstream's QuickMenuView; tile-grid redesign deferred) |
| `src/swift/Models/SettingsStore.swift` | `AppColorScheme` (system/light/dark) setting; live-apply (`requestGraphicsApply()`) wired to the 7 advanced-upscaling-hack properties, which upstream leaves reset-only |
| `src/swift/Views/Settings/AppearanceSettingsView.swift` | Theme picker |
| `src/swift/Views/Settings/GraphicsSettingsView.swift` | `ShadeBoostPreviewView` inserted above the Shade Boost sliders; corrected two hack captions that no longer require reset/relaunch |
| `src/swift/Views/GameListView.swift` | cover-flow carousel enabled in portrait (drop landscape-only gate) |
| `src/cpp/ios_main.mm` | JIT protocol default → `legacy` (brk #0x69) + one-time V2 migration; JIT keepalive timer (12s, idle-only) + boot watchdog (15s), ported early from ARMSX2's iOS JIT resilience layer (their `platforms/ios` commit "add JIT resilience layer with keepalive, interpreter fallback, and boot watchdog") ahead of a full rebase — see §3 note below |
| `src/cpp/common/Darwin/DarwinMisc.h` / `.cpp` | `DarwinMisc::ValidateJITAlive()` (CS_DEBUGGED + JIT RW alias canary re-check, called by the keepalive timer); 8s worker-thread timeout on the Universal TXM path in `MmapCodeDualMap`, falling back to Legacy `brk #0x69` on hang — same upstream JIT resilience layer |
| `src/cpp/pcsx2/PrecompiledHeader.h` | `#include <TargetConditionals.h>` so `TARGET_OS_IPHONE` resolves |
| `src/cpp/common/PrecompiledHeader.h` | same TargetConditionals include |
| `src/cpp/pcsx2/ImGui/ImGuiOverlays.cpp` | in-game OSD brand → `AYS2` |
| `src/cpp/pcsx2/ImGui/FullscreenUI.cpp` | fullscreen heading brand → `AYS2` |
| `src/cpp/ARMSX2Bridge.mm` | `buildVersion()` → `AYS2 v…` |
| `src/cpp/CMakeLists.txt` | bundle id `com.ayano.aysx2`, app name, our SWIFT_SOURCES additions |
| `src/cpp/Info.plist.in` | `CFBundleDisplayName` → AYS2 |
| `.github/workflows/build-ios.yml` | pin IPA version to `0.1.<run>`, SideStore publish, checksums |

### 2c. Hard constraints (never violate on any rebase)
- **Bundle id stays `com.ayano.aysx2`** — changing it loses the user's install/data.
- Keep the JIT default = `legacy` (brk #0x69 / StikDebug) on iOS.
- Keep `TargetConditionals.h` in both PCHs (our vendored zlib doesn't pull it).
- SideStore IPA version must equal `source.json` version (`0.1.<run>`).

---

## 3. Rebase playbook — moving to a newer ARMSX2 iOS tag

> **STALE as of 2026-07-18, verify before following.** Upstream did a monorepo
> refactor (commit "refactor: move iOS frontend to platforms/ios on single
> shared core", 2026-07-08): the layout below (`app/src/main/{cpp,swift,assets}`)
> may no longer match `github.com/ARMSX2/ARMSX2` — it's now `platforms/ios/app/...`.
> Re-verify the actual current layout before running this playbook; it hasn't
> been re-run/re-tested against the new structure yet.
>
> We also ported all 5 pieces of upstream's iOS JIT resilience layer
> (keepalive timer, `ValidateJITAlive`, boot watchdog, and the Universal-JIT
> 8s-worker-thread-timeout-with-Legacy-fallback — see §2b, `ios_main.mm` /
> `DarwinMisc.cpp`) **out of band, ahead of a full rebase**. The Universal
> timeout piece was initially held back over a suspected `sigsetjmp` cross-
> thread UB risk; verified false via `raw.githubusercontent.com` (readable
> even though `github.com` diff/API views are blocked in-session) — the
> `sigsetjmp` is called fresh on the worker thread itself, right before the
> op that might trap, so the SIGTRAP (synchronous, instruction-triggered) is
> delivered to that same thread. Carried over one accepted trade-off from
> upstream verbatim: if that worker thread hangs, `sa_brk_old` is restored
> unconditionally afterward, so a late trap after the Legacy fallback would
> hit the old handler instead of ours. Upstream's own comment calls this
> "bounded... Universal protocol + hang + late trap" — and AYS2 defaults to
> Legacy always (`ios_main.mm`), so this branch is only reachable at all if
> a user opts into Universal from Settings.
>
> None of this was verified against a real diff via authenticated repo
> access (that session couldn't add `ARMSX2/ARMSX2` — cross-owner add is
> blocked; forking it was also blocked). Verified only by cross-referencing
> `raw.githubusercontent.com` fetches against our own already-trusted code
> (matching identifiers, matching surrounding logic) — high confidence, not
> a substitute for a real rebase diff when one becomes possible.
>
> **2026-07-18 follow-up, with direct upstream contact:** upstream (J1coding)
> confirmed on Discord that `b8e94ea` ("fix JIT keepalive timer running
> during gameplay") was reverted because it "didn't work correctly" — no
> further detail given — and gave the project owner explicit permission to
> finish it ("work is 95% done, go ahead"). We reworked our keepalive to
> validate during gameplay again (matching `b8e94ea`'s intent, not the
> reverted state) with two unconfirmed defensive changes: the canary byte
> now targets the tail of the JIT region instead of the head (real code
> fills from the start forward, so the head is more likely to be live code
> at the moment of the write — reduces, does not prove, collision safety),
> and a real revocation must fail 2 consecutive checks (24s apart) before
> we force interpreter mode. **We do not know upstream's actual root cause
> for the original failure** — these are our best-guess fixes for the most
> plausible failure mode (self-modifying-code hazard from writing into live
> compiled code), not a confirmed fix. Needs real device testing before
> being treated as solved. If upstream ever shares the real cause, reconcile
> against it.
> When the actual rebase happens, diff our 3 ported pieces against upstream's
> real versions and reconcile — ours may differ from what actually shipped.

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
   `AYS2:` on the OLD tree to see exactly what to re-insert.
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
2. **Track the gaps** in `docs/AYS2_GAPS.md` (create as needed): for each known
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
