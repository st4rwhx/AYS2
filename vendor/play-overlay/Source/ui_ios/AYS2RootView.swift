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

struct AYS2RootView: View {
	@State private var games: [PlayGame] = []
	@State private var isLoading = true

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
			}
		}
		.task {
			await loadLibrary()
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
		PlayBridge.bootGameAtPath(game.path, presentingFrom: presenter)
	}

	private func presentSettings() {
		guard let presenter = rootPresenter else { return }
		PlayBridge.presentSettings(from: presenter)
	}
}
