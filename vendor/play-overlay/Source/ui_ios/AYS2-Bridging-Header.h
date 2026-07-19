// AYS2-Bridging-Header.h — exposes Objective-C to AYS2RootView.swift/RetroKit.swift.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+
//
// Play!'s target has no Swift-Objective-C bridging header of its own (it had
// no Swift code before this overlay), so this is additive — it doesn't
// change how any existing Objective-C++ file sees the rest of the target.

#import "PlayBridge.h"
