// AYS2RootView.swift — SwiftUI shell hosted inside Play!'s UIKit app.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+
//
// Phase 4 checkpoint: proves SwiftUI can be hosted inside Play!'s existing
// UIKit/storyboard app shell via UIHostingController, wired through Play!'s
// own CMake target (already declares "LANGUAGES C Swift", so this is just
// adding a source file, not bolting on Swift support from scratch).
// AYS2RootViewFactory is the ObjC-visible entry point AppDelegate.mm calls
// into — UIHostingController is a Swift generic and can't be constructed
// directly from Objective-C++, so the hosting controller has to be built on
// the Swift side and handed back up-cast to plain UIViewController.

import SwiftUI

@objc(AYS2RootViewFactory)
public class AYS2RootViewFactory: NSObject {
	@objc public static func makeRootViewController() -> UIViewController {
		UIHostingController(rootView: AYS2RootView())
	}
}

struct AYS2RootView: View {
	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			VStack(spacing: 14) {
				Image(systemName: "gamecontroller.fill")
					.font(.system(size: 48, weight: .semibold))
					.foregroundStyle(.blue)
				Text("AYS2 × Play!")
					.font(.system(size: 28, weight: .heavy, design: .rounded))
					.foregroundStyle(.white)
				Text("SwiftUI shell hosted inside Play!'s app — Phase 4 checkpoint.")
					.font(.footnote)
					.foregroundStyle(.white.opacity(0.6))
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
			}
		}
	}
}
