# AYS2 × Play! overlay manifest

Tracks the migration evaluation to the [Play!](https://github.com/jpd002/Play-)
PS2 core (see `/root/.claude/plans` for the full staged plan — Phase 1-3
already completed: toolchain de-risked, UI architecture decided, feature
parity gaps triaged and accepted). This is separate from `AYS2_OVERLAY.md`,
which documents the current shipping app (ARMSX2/PCSX2 core) — that app
keeps building via `build-ios.yml` unaffected until this replacement reaches
feature parity.

## Why an overlay instead of a submodule

We don't have push access to fork jpd002/Play- into an account this session
can commit to, so a modifiable git submodule isn't possible. Instead,
`build-ios-play.yml` checks out jpd002/Play- fresh at a pinned commit
(unmodified), then copies the files below on top before building — same
"minimal marked seam" discipline as `AYS2_OVERLAY.md`, just applied via
file-copy-at-CI-time rather than an already-merged local copy.

## Distribution: its own rolling Release, separate from the main app

`build-ios-play.yml` packages a real `.ipa` (not just a raw `.app` artifact —
early versions of this workflow uploaded the unpacked `Play.app` bundle,
which isn't directly sideloadable) and publishes it to its own rolling
GitHub Release, tag `play-latest`, with its own `play-source.json`
SideStore/AltStore feed. This is entirely separate machinery from the main
app's `latest` release that `build-ios.yml` publishes: different tag,
different source file, and `gh release edit` is deliberately never called
with `--latest` on `play-latest` — that flag sets the *repo's* single
"Latest release" badge, which must always stay pointed at the real,
user-facing AYS2 app. The Play! preview release is also marked
`--prerelease` for the same reason (keeps it out of `/releases/latest`).
Add `https://github.com/st4rwhx/AYS2/releases/download/play-latest/play-source.json`
as a source in SideStore/AltStore to track preview builds independently of
the main AYS2 source — do not add it to the same source as the real app.

**Pinned upstream commit:** `50aedca2639521bc498ace0b2be1ea012801a86a`

## Overlay files (`vendor/play-overlay/Source/ui_ios/`)

| File | What |
|---|---|
| `AYS2RootView.swift` | SwiftUI shell (`AYS2RootView`) + `AYS2RootViewFactory`, the `@objc`-visible entry point `AppDelegate.mm` calls into. Now a real, functional screen: lists Play!'s own game library via `PlayBridge` and boots into Play!'s own `EmulatorViewController` on tap — not a placeholder. The library scan is dispatched off the main thread deliberately (`Task.detached`), learning directly from a real freeze bug the AYS2 Dashboard carousel had from doing the equivalent reload synchronously on the main thread. Also gates boot on `PlayBridge.isJITAvailable()` and offers a StikDebug bounce on failure — see "JIT: why we override Play!'s own check" below. |
| `RetroKit.swift` | Ported verbatim from `src/swift/Views/RetroKit.swift` — confirmed self-contained (no `ARMSX2Bridge` dependency) back in the Phase 1/3 research, so no adaptation needed, straight copy. |
| `PlayBridge.h` / `PlayBridge.mm` | New. Thin Objective-C bridge exposing Play!'s existing `BootablesDb` (game list, SQLite-backed), `EmulatorViewController` (boot), and `SettingsViewController` (settings) to Swift — the same role `ARMSX2Bridge` plays for the current PCSX2-core app. None of Play!'s own VM/game-list/boot/settings C++ is touched, only surfaced. `+refreshLibrary` mirrors `CoverViewController`'s own default-scan path (active bootable directories + app storage) so results match what Play!'s stock UI would show. `+bootGameAtPath:presentingFrom:` instantiates Play!'s unmodified `EmulatorViewController` from `Main.storyboard` and presents it modally, since our SwiftUI root isn't inside Play!'s own storyboard-driven navigation flow. `+presentSettingsFrom:` does the same for `SettingsViewController` (inside its nav controller), replicating `CoverViewController`'s exact `prepareForSegue:` handling for `showSettings` — full-device-scan/GS-handler selection allowed, JIT service restarted and library re-scanned on dismiss, scan dispatched off the main thread. `+isJITAvailable` is a real `csops()`/`CS_DEBUGGED` check (same syscall as AYS2's own `DarwinMisc::IsJITAvailable`). All three boot/settings/JIT methods `NS_SWIFT_NAME`-pinned: Swift's importer reads the trailing `AtPath`/`From` as a preposition and silently renames these to something else, which is a real build failure CI caught once already, not a hypothetical. |
| `AYS2-Bridging-Header.h` | New. Play!'s target had no Swift code (and so no bridging header) before this overlay — without one, `AYS2RootView.swift` can't see `PlayBridge` or any other Objective-C in the target. Just `#import "PlayBridge.h"`. |
| `Base.lproj/Main.storyboard` | Seam (full-file overlay). Two additive attributes: `storyboardIdentifier="EmulatorViewController"` on the `EmulatorViewController` scene and `storyboardIdentifier="PlaySettingsNav"` on the settings navigation-controller scene, so `PlayBridge` can instantiate either directly (`instantiateViewControllerWithIdentifier:`) instead of only via `CoverViewController`'s segues. Nothing else in the storyboard changes — the original segue-based flow (unused now that our SwiftUI shell replaces the root VC, but left intact) still works identically. |
| `AppDelegate.mm` | Seam (full-file overlay of Play!'s original). Swaps the storyboard-provided root view controller for our SwiftUI shell inside `didFinishLaunchingWithOptions`, after `UIApplicationMain` has already populated `self.window` from `Main.storyboard` (no Scene support in this app). |
| `CMakeLists.txt` | Seam (full-file overlay of `Source/ui_ios/CMakeLists.txt`). Adds `AYS2RootView.swift`, `RetroKit.swift`, and `PlayBridge.mm`/`PlayBridge.h` to the target (the target already declares `LANGUAGES C Swift`, so no new interop plumbing needed beyond the bridging header below). Sets `XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER` to `AYS2-Bridging-Header.h`. Also overrides `XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET` to 15.0 at the target level — the shared `ios.cmake` toolchain sets 12.2, below SwiftUI's iOS 13 minimum; overridden per-target rather than editing the shared toolchain file every other build preset uses. |

## Feature parity gaps (Phase 3 triage, accepted — see plan)

Confirmed absent in Play!'s core itself (not just unexposed in its UI):
analog/button deadzone, stick inversion, pressure modifier, GS hacks beyond
upscale factor + forced bilinear, RetroAchievements, cheats/patches, PINE,
multitap. Confirmed present: analog sensitivity scaling, vibration,
memory cards (broader format support than AYS2's, even), save states,
per-game compatibility patches (different mechanism — `GameConfig.xml`
memory patches vs. PCSX2's named hacks), built-in HLE BIOS, JIT via AltKit
(network-based, different from AYS2's StikDebug `brk` handshake).

## JIT: why we override Play!'s own check

Play!'s only built-in JIT-enabling path is `AltServerJitService` (network
discovery of a classic AltServer instance on a Mac/PC). Its own
availability check, `CoverViewController::IsJitAvailable()`, doesn't call
`csops()`/check `CS_DEBUGGED` at all — it only checks `getppid() != 1`
(Xcode-debugger heuristic), `AltServerJitService.jitEnabled` (the same
AltServer-only path), and whether `/private/var/mobile` is scannable
(jailbreak detection). None of these recognize JIT granted by StikDebug or
SideStore's own on-device enabler. On top of that, our
`PlayBridge.bootGameAtPath:` bypasses `CoverViewController`'s segue-gated
flow entirely (we go straight from `AYS2RootView` to
`EmulatorViewController`), so Play!'s check — broken or not — never even
runs in this app.

`PlayBridge.isJITAvailable` (a real `csops()` check) and `AYS2RootView`'s
JIT-unavailable alert (with a StikDebug deep-link bounce, host-container-
aware the same way the main app's `StikDebugLauncher`/
`AppInstallEnvironment` are) close that gap — without touching
`CoverViewController.mm`, `AltServerJitService`, or any of Play!'s own C++.

**Known remaining gap, unverified either way:** Play!'s executable-memory
allocator (`deps/CodeGen`'s `CMemoryFunction`, `MEMFUNC_USE_MACHVM` on iOS)
toggles a single page between RW and RX via `vm_protect` — the same
"Legacy" strategy AYS2's own `DarwinMisc.cpp` used before iOS 26. iOS 26's
Trusted Execution Monitor (TXM) blocks that toggle even with `CS_DEBUGGED`
set, which is exactly what AYS2's own `LuckTXM` dual-mapping + `brk
#0xf00d` handshake (`MmapCodeDualMap`) was built to work around. If a test
device is on iOS 26+, getting real JIT (not just passing our new
availability check) may additionally require overlaying a patched
`CMemoryFunction.cpp` using that same dual-mapping approach — a
substantially bigger change than this increment, not yet started, pending
confirmation this is actually needed.
