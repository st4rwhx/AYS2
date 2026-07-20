// AYS2RootView.swift — SwiftUI shell hosted inside Play!'s UIKit app.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+
//
// Phase 4: a real, functional screen backed by Play!'s own game list and
// boot path — not a placeholder. PlayBridge.h/.mm (seam) surfaces Play!'s
// existing BootablesDb (game list, SQLite-backed) and EmulatorViewController
// (boot, from the unmodified Main.storyboard) to Swift, the same role
// ARMSX2Bridge plays for the current PCSX2-core app. None of Play!'s own
// VM/game-list/boot code is touched — this only drives it from SwiftUI.
//
// The scan in PlayBridge.refreshLibrary() does real disk I/O (mirrors
// CoverViewController's own default-scan path), so it's kept off the main
// thread here — the AYS2 Dashboard carousel had a real freeze bug from a
// similar library reload running synchronously on the main thread; this
// screen is written to not repeat that mistake from the start.

import SwiftUI
import UIKit

@objc(AYS2RootViewFactory)
public class AYS2RootViewFactory: NSObject {
	@objc public static func makeRootViewController() -> UIViewController {
		UIHostingController(rootView: AYS2RootView())
	}
}

private struct PlayGame: Identifiable {
	let id: String // bootable path — stable and unique per game
	let title: String
	let path: String
	let coverURL: URL?
}

// AYS2: ported from the main app's AppInstallEnvironment (seam) — same
// blind spot applies here. Under a host container (LiveContainer),
// Bundle.main.bundleIdentifier still reports Play!'s own declared id, not
// the actually-running container process StikDebug would need to target,
// so the stikdebug:// deep link below can't work from in here in that case.
private enum PlayInstallEnvironment {
	static var isLikelyExternalContainer: Bool {
		Bundle.main.bundlePath
			.range(of: "/Documents/Applications/", options: .caseInsensitive) != nil
	}
}

struct AYS2RootView: View {
	@State private var games: [PlayGame] = []
	@State private var isLoading = true
	@State private var jitAlertGame: PlayGame?
	@State private var jitOpenInProgress = false
	@State private var isPreparingJIT = false
	@State private var jitPrepareFailedGame: PlayGame?
	@State private var jitDiagnosticMessage = ""

	var body: some View {
		ZStack {
			RetroBackground()
			VStack(alignment: .leading, spacing: 0) {
				header
				if isLoading {
					Spacer()
					ProgressView().tint(Retro.accent)
					Spacer()
				} else if games.isEmpty {
					emptyState
				} else {
					gameGrid
				}
				if isPreparingJIT {
					VStack(spacing: 12) {
						ProgressView().tint(Retro.accent)
						Text("Preparing JIT — this can take up to 15 seconds the first time…")
							.font(.footnote)
							.foregroundStyle(Retro.mut)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 40)
					}
					.padding(20)
					.background(Retro.panel2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
				}
			}
		}
		.task {
			await loadLibrary()
		}
		.alert(
			"JIT prepare failed",
			isPresented: Binding(get: { jitPrepareFailedGame != nil }, set: { if !$0 { jitPrepareFailedGame = nil } }),
			presenting: jitPrepareFailedGame
		) { game in
			Button("Continue Anyway", role: .destructive) {
				if let presenter = rootPresenter {
					PlayBridge.bootGameAtPath(game.path, presentingFrom: presenter)
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: { _ in
			// AYS2: this is the case isJITAvailable() alone can't catch — CS_DEBUGGED
			// was set (a debugger is attached), but the iOS 26 TXM pool registration
			// itself failed. Shows PlayBridge.jitStatus()'s real diagnostic instead of
			// a generic message, since on-device testing showed this failure mode
			// produces neither a crash log nor any way to read the app's own stderr.
			Text(jitDiagnosticMessage)
		}
		.alert(
			"JIT unavailable",
			isPresented: Binding(get: { jitAlertGame != nil }, set: { if !$0 { jitAlertGame = nil } }),
			presenting: jitAlertGame
		) { game in
			if !PlayInstallEnvironment.isLikelyExternalContainer {
				Button("Open StikDebug") {
					openStikDebugForJIT()
				}
			}
			Button("Continue Anyway", role: .destructive) {
				if let presenter = rootPresenter {
					PlayBridge.bootGameAtPath(game.path, presentingFrom: presenter)
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: { _ in
			// Play!'s own JIT-available check (CoverViewController's
			// IsJitAvailable()) never runs in this app — we boot straight into
			// EmulatorViewController from this SwiftUI shell, bypassing that
			// segue gate entirely. This is our own real CS_DEBUGGED check
			// (PlayBridge.isJITAvailable), not Play!'s AltServer-only one, so
			// it correctly recognizes JIT granted via StikDebug or SideStore.
			Text(PlayInstallEnvironment.isLikelyExternalContainer
				? "Play! will crash on boot without JIT. Running inside a host container (e.g. LiveContainer): this can't target the right process from in here. Enable JIT from the container itself — hold this app in LiveContainer's list, open its settings, and turn on \"Launch with JIT\" (or run the matching script against the container, not Play!, directly in StikDebug)."
				: "Play! will crash on boot without JIT. If you're using StikDebug or SideStore's own JIT enabler, grant JIT for this app there first, then try again.")
		}
	}

	private var header: some View {
		HStack {
			RetroLabel(text: "AYS2 × Play!")
			Spacer()
			Text("\(games.count) \(games.count == 1 ? "game" : "games")")
				.font(.footnote)
				.foregroundStyle(Retro.mut)
			Button {
				presentSettings()
			} label: {
				Image(systemName: "gearshape")
					.foregroundStyle(Retro.mut)
			}
			.padding(.leading, 4)
		}
		.padding(.horizontal, 20)
		.padding(.top, 16)
		.padding(.bottom, 10)
	}

	private var emptyState: some View {
		VStack(spacing: 10) {
			Spacer()
			Image(systemName: "square.stack.3d.up.slash")
				.font(.system(size: 44, weight: .thin))
				.foregroundStyle(Retro.line2)
			Text("No games found")
				.font(.headline)
				.foregroundStyle(Retro.ink)
			Text("Add PS2 disc images to the app's storage, then pull down to refresh.")
				.font(.footnote)
				.foregroundStyle(Retro.mut)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 40)
			Spacer()
		}
		.frame(maxWidth: .infinity)
	}

	private var gameGrid: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 20) {
				ForEach(games) { game in
					Button {
						boot(game)
					} label: {
						VStack(spacing: 6) {
							coverThumbnail(for: game)
							Text(game.title)
								.font(.caption.weight(.medium))
								.foregroundStyle(Retro.ink)
								.lineLimit(2)
								.multilineTextAlignment(.center)
						}
					}
					.buttonStyle(.plain)
				}
			}
			.padding(20)
		}
		.refreshable {
			await loadLibrary()
		}
	}

	@ViewBuilder
	private func coverThumbnail(for game: PlayGame) -> some View {
		RoundedRectangle(cornerRadius: 10, style: .continuous)
			.fill(Retro.panel2)
			.aspectRatio(Retro.coverRatio, contentMode: .fit)
			.overlay {
				if let coverURL = game.coverURL {
					AsyncImage(url: coverURL) { phase in
						if let image = phase.image {
							image.resizable().scaledToFill()
						}
					}
					.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
				}
			}
			.overlay(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.strokeBorder(Retro.line, lineWidth: 1)
			)
	}

	private func loadLibrary() async {
		if games.isEmpty { isLoading = true }
		await Task.detached(priority: .userInitiated) {
			PlayBridge.refreshLibrary()
		}.value
		games = PlayBridge.availableGames().compactMap { raw in
			guard let title = raw["title"], let path = raw["path"] else { return nil }
			let coverURLString = raw["coverUrl"] ?? ""
			return PlayGame(
				id: path,
				title: title,
				path: path,
				coverURL: coverURLString.isEmpty ? nil : URL(string: coverURLString)
			)
		}
		isLoading = false
	}

	/// Play! has no UIScene support (pre-scene, window-based app lifecycle,
	/// same as its own AppDelegate/window setup) — .windows is the correct
	/// way to reach the key window here, not a legacy fallback.
	private var rootPresenter: UIViewController? {
		UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
	}

	private func boot(_ game: PlayGame) {
		guard let presenter = rootPresenter else { return }
		guard PlayBridge.isJITAvailable() else {
			jitAlertGame = game
			return
		}
		// AYS2: eager prepare (seam) — isJITAvailable() only proves a
		// debugger is attached (CS_DEBUGGED), not that the iOS 26 TXM pool
		// is actually registered and ready. Doing this here, synchronously,
		// with a visible result is what replaces the silent hang-with-no-
		// crash-log on-device testing found when that gap was left for
		// CBasicBlock::Compile() to discover deep inside VM boot.
		guard !isPreparingJIT else { return }
		isPreparingJIT = true
		Task {
			let ready = await Task.detached(priority: .userInitiated) {
				PlayBridge.prepareJIT()
			}.value
			isPreparingJIT = false
			if ready {
				PlayBridge.bootGameAtPath(game.path, presentingFrom: presenter)
			} else {
				jitDiagnosticMessage = PlayBridge.jitStatus()
				jitPrepareFailedGame = game
			}
		}
	}

	private func presentSettings() {
		guard let presenter = rootPresenter else { return }
		PlayBridge.presentSettings(from: presenter)
	}

	// AYS2: StikDebug bounce for Play! (seam) — Play!'s own JIT path
	// (AltServerJitService) only talks to a classic AltServer on a Mac/PC on
	// the same LAN; it has no StikDebug/SideStore-style deep link of its own.
	// Same URL-scheme + fallback-chain approach as the main AYS2 app's
	// StikDebugLauncher.open(), using Play!'s own real bundle id (this file
	// runs inside Play.app, so Bundle.main correctly reports Play!'s id, not
	// AYS2's) — deliberately not ported wholesale, this app only needs the
	// "open it" half, not auto-open/cooldown/host-container detection.
	private func openStikDebugForJIT() {
		guard !jitOpenInProgress else { return }
		let bundleID = Bundle.main.bundleIdentifier ?? ""
		let encoded = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
		let candidates = [
			"stikdebug://enable-jit?bundle-id=\(encoded)",
			"stikjit://enable-jit?bundle-id=\(encoded)"
		].compactMap(URL.init(string:))
		jitOpenInProgress = true
		openFirstAvailable(candidates)
	}

	private func openFirstAvailable(_ urls: [URL]) {
		guard let url = urls.first else {
			jitOpenInProgress = false
			return
		}
		UIApplication.shared.open(url, options: [:]) { success in
			if success {
				jitOpenInProgress = false
			} else {
				openFirstAvailable(Array(urls.dropFirst()))
			}
		}
	}
}
