// PlayBridge.h — Objective-C bridge exposing Play!'s BootablesDb (game list)
// and EmulatorViewController (boot) to Swift.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+
//
// Plays the same role ARMSX2Bridge.h/.mm plays for the current PCSX2-core
// app: a thin, additive Objective-C surface over C++ the emulator already
// owns, so AYS2's SwiftUI can drive it without any of Play!'s own VM/game-
// list code being rewritten. Only NSObject/Foundation/UIKit types appear
// here (visible to Swift via the target's bridging header) — the C++ lives
// entirely in PlayBridge.mm.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayBridge : NSObject

/// Scans the usual bootable locations (active directories plus the app's own
/// storage) and refreshes Play!'s BootablesDb. Mirrors
/// CoverViewController's own buildCollectionWithForcedFullScan:NO path, so
/// results line up with what Play!'s stock UI would show. Does disk I/O —
/// call off the main thread.
+ (void)refreshLibrary;

/// One dictionary per game: "title", "path", and "coverUrl" (may be an empty
/// string when Play! has no cover on file for that game). Reads the already-
/// populated BootablesDb, so this is cheap — call +refreshLibrary first to
/// populate/update it.
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)availableGames;

/// Presents Play!'s own EmulatorViewController (instantiated from
/// Main.storyboard, unmodified) modally over `presenter`, booting the game
/// at `path`.
// Explicit NS_SWIFT_NAME (seam/fix): without it, Swift's Clang importer
// treats "AtPath" as a preposition describing the first parameter and
// renames this to bootGame(atPath:presentingFrom:) — a real build failure
// caught by CI, not a hypothetical. Pinning the name keeps the Swift call
// site matching what's written here.
+ (void)bootGameAtPath:(NSString *)path presentingFrom:(UIViewController *)presenter NS_SWIFT_NAME(bootGameAtPath(_:presentingFrom:));

/// Presents Play!'s own SettingsViewController (instantiated from
/// Main.storyboard inside its navigation controller, unmodified) modally
/// over `presenter`. Mirrors CoverViewController's own "showSettings" segue
/// handling: allows full-device-scan and GS-handler selection, restarts the
/// AltServer JIT service and refreshes the library on dismiss exactly like
/// the stock flow does.
// Explicit NS_SWIFT_NAME for the same reason as bootGameAtPath: above —
// pin the exact Swift signature instead of trusting the importer's
// preposition-splitting heuristic to guess the same way we call it.
+ (void)presentSettingsFrom:(UIViewController *)presenter NS_SWIFT_NAME(presentSettings(from:));

/// Real CS_DEBUGGED check (csops), independent of Play!'s own
/// CoverViewController::IsJitAvailable() heuristic (parent-pid / AltServer-
/// only / jailbreak-directory probes — none of which recognize a StikDebug-
/// or SideStore-granted JIT). +bootGameAtPath:presentingFrom: bypasses
/// CoverViewController's segue-gated flow entirely (it goes straight from
/// our SwiftUI shell to EmulatorViewController), so this is the only JIT
/// check that actually runs before boot in this app.
+ (BOOL)isJITAvailable;

/// Eagerly does the one-time iOS 26 TXM pool setup (mmap + StikDebug brk
/// handshake + vm_remap) if this device needs it, and reports whether it
/// actually succeeded — not just whether CS_DEBUGGED happens to be set
/// (which +isJITAvailable checks, and which the OS sets the instant ANY
/// debugger attaches, well before the TXM pool is really ready). Blocks for
/// up to ~15s the first time on a real iOS 26 TXM device — call off the
/// main thread. Returns YES immediately (no-op) on pre-iOS-26 devices,
/// where nothing needs pre-registration.
+ (BOOL)prepareJIT;

/// Human-readable JIT/TXM-pool diagnostic string for display — the pool's
/// real internal state, not app stderr (unreachable without a Mac) or an
/// iOS crash log (this failure mode doesn't produce one; it hangs rather
/// than crashes).
+ (NSString *)jitStatus;

@end

NS_ASSUME_NONNULL_END
