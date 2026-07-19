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
//
// Now styled with RetroKit.swift (ported verbatim, self-contained, no
// ARMSX2Bridge dependency) instead of a plain placeholder — first proof
// that AYS2's actual design system, not just SwiftUI itself, survives the
// move to Play!'s app shell.

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
			RetroBackground()
			VStack(spacing: 14) {
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
					                     startPoint: .top, endPoint: .bottom))
					.frame(width: 72, height: 72)
					.overlay(
						Image(systemName: "gamecontroller.fill")
							.font(.system(size: 30, weight: .semibold))
							.foregroundStyle(.white)
					)
				Text("AYS2 × Play!")
					.font(.system(size: 28, weight: .heavy, design: .rounded))
					.foregroundStyle(Retro.ink)
				Text("SwiftUI + RetroKit hosted inside Play!'s app — Phase 4 checkpoint.")
					.font(.footnote)
					.foregroundStyle(Retro.mut)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
			}
		}
	}
}
