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

**Pinned upstream commit:** `50aedca2639521bc498ace0b2be1ea012801a86a`

## Overlay files (`vendor/play-overlay/Source/ui_ios/`)

| File | What |
|---|---|
| `AYS2RootView.swift` | New. SwiftUI shell (`AYS2RootView`) + `AYS2RootViewFactory`, the `@objc`-visible entry point `AppDelegate.mm` calls into. `UIHostingController` is a Swift generic, so the hosting controller has to be constructed on the Swift side and handed back as a plain `UIViewController`. |
| `AppDelegate.mm` | Seam (full-file overlay of Play!'s original). Swaps the storyboard-provided root view controller for our SwiftUI shell inside `didFinishLaunchingWithOptions`, after `UIApplicationMain` has already populated `self.window` from `Main.storyboard` (no Scene support in this app). |
| `CMakeLists.txt` | Seam (full-file overlay of `Source/ui_ios/CMakeLists.txt`). Adds `AYS2RootView.swift` to `OSX_SOURCES` (the target already declares `LANGUAGES C Swift`, so no new interop plumbing needed). Also overrides `XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET` to 15.0 at the target level — the shared `ios.cmake` toolchain sets 12.2, below SwiftUI's iOS 13 minimum; overridden per-target rather than editing the shared toolchain file every other build preset uses. |

## Feature parity gaps (Phase 3 triage, accepted — see plan)

Confirmed absent in Play!'s core itself (not just unexposed in its UI):
analog/button deadzone, stick inversion, pressure modifier, GS hacks beyond
upscale factor + forced bilinear, RetroAchievements, cheats/patches, PINE,
multitap. Confirmed present: analog sensitivity scaling, vibration,
memory cards (broader format support than AYS2's, even), save states,
per-game compatibility patches (different mechanism — `GameConfig.xml`
memory patches vs. PCSX2's named hacks), built-in HLE BIOS, JIT via AltKit
(network-based, different from AYS2's StikDebug `brk` handshake).
