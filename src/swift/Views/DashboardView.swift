// DashboardView.swift — AYS2 console-style home (NXE dashboard).
// SPDX-License-Identifier: GPL-3.0+
//
// The AYS2 identity layer: a light/dark NXE field, a horizontal top nav
// (logo · bumpers · tabs), PlayStation-blue accent, a swipeable row of full 3D
// covers, and a tiled Settings hub. Games boot straight from the carousel; the
// full ARMSX2 library (cover downloads, disc management) is one tap away.

import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum DashSection: String, CaseIterable, Identifiable {
    case games = "Games", bios = "BIOS", settings = "Settings", help = "Help"
    var id: String { rawValue }
}

/// One indexed game shown in the carousel, resolved against the ARMSX2 library.
struct DashGame: Identifiable {
    let id: String
    let name: String
    let bootName: String
    let coverURL: URL?
    let coverSignature: String?
    let isFavorite: Bool
    let serial: String?
    // AYS2: carries what's needed to build a full ISOEntry on demand for the
    // carousel's long-press context menu (GameInfoPanel/PerGameSettingsPanel
    // need one) without duplicating GameListView's whole richer model here.
    let fileURL: URL?
    let metadata: [String: String]
    let isExternal: Bool

    /// Built lazily (not stored) since it stats the file for its size — only
    /// needed when the user actually opens the context menu, not on every
    /// carousel reload.
    var asISOEntry: ISOEntry {
        let attrs = fileURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
        let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
        return ISOEntry(
            name: name,
            fileURL: fileURL,
            bootPath: isExternal ? bootName : nil,
            coverURL: coverURL,
            coverSignature: coverSignature,
            metadata: metadata,
            size: size,
            isFavorite: isFavorite,
            isExternal: isExternal
        )
    }
}

struct DashboardView: View {
    @State private var section: DashSection = .games

    var body: some View {
        ZStack {
            RetroBackground()
            VStack(spacing: 0) {
                TopNav(section: $section)
                Rectangle().fill(Retro.line).frame(height: 1)
                content
            }
        }
        .overlay(alignment: .bottomTrailing) {
            CommunityBar()
                .padding(.trailing, 16)
                .padding(.bottom, 22)
        }
        .tint(Retro.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .games:    GamesCarouselView()
        case .bios:     BIOSListView()
        case .settings: SettingsGridView()
        case .help:     HelpView()
        }
    }
}

// MARK: - Top navigation bar (logo · bumpers · tabs)

struct TopNav: View {
    @Binding var section: DashSection

    private func step(_ delta: Int) {
        let all = DashSection.allCases
        guard let idx = all.firstIndex(of: section) else { return }
        let next = (idx + delta + all.count) % all.count
        section = all[next]
        SoundManager.shared.play(.nav)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Logo mark in a rounded square, like the console's home glyph.
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Retro.line2, lineWidth: 1.5)
                .frame(width: 34, height: 34)
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 15, height: 15)
                        .rotationEffect(.degrees(45))
                )

            // L1 bumper — steps to the previous tab (matches a controller's L1).
            Button { step(-1) } label: { BumperPill(text: "L1") }
                .buttonStyle(.plain)

            // Section tabs with the active PlayStation-blue underline. Plain
            // HStack, not a ScrollView — only 4 short fixed labels, they
            // always fit without scrolling on any device. AYS2: a
            // ScrollView here was intercepting taps as scroll gestures on
            // iPad (trackpad/pointer input in particular), making the tabs
            // — including Settings — unreachable for some users (seam/fix).
            HStack(spacing: 22) {
                ForEach(DashSection.allCases) { s in
                    Button {
                        section = s
                        SoundManager.shared.play(.nav)
                    } label: {
                        VStack(spacing: 5) {
                            Text(s.rawValue)
                                .font(.system(size: 17, weight: section == s ? .bold : .regular))
                                .foregroundStyle(section == s ? Retro.ink : Retro.mut)
                                // AYS2: force single-line — dropping the
                                // ScrollView (iPad tap fix) meant these now
                                // sit in a width-constrained HStack, and
                                // without this they wrapped to two lines
                                // ("Gam/es", "Setti/ngs") instead of staying
                                // on one, growing the nav bar taller (fix).
                                .lineLimit(1)
                                .fixedSize()
                            Rectangle()
                                .fill(section == s ? Retro.accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            // R1 bumper — steps to the next tab (matches a controller's R1).
            Button { step(1) } label: { BumperPill(text: "R1") }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Games as a horizontal cover carousel

struct GamesCarouselView: View {
    @State private var appState = AppState.shared
    @State private var settings = SettingsStore.shared
    @State private var coverStore = CoverStore.shared
    @State private var games: [DashGame] = []
    @State private var showImporter = false
    @State private var showLibrary = false
    @State private var showRestartAlert = false
    @State private var pendingGame: DashGame?
    @State private var actionTitle = ""
    @State private var actionMessage = ""
    @State private var showActionAlert = false
    // AYS2: kinetic hub carousel (seam) — center-focus tracking for the
    // scroll-transition scale effect and the ambient background tint.
    @State private var focusedGameID: String?
    @State private var focusedImage: UIImage?
    @State private var focusedSynopsis: String?
    // AYS2: long-press context menu targets (seam) — mirrors GameListView's
    // gameContextMenu, reusing the same panels/sheets so a game long-pressed
    // from the carousel gets the same Game Info/Per-Game Settings/Cheats &
    // Patches/Covers/Game Data menu as from the full library list.
    @State private var gameInfoTarget: ISOEntry?
    @State private var gameSettingsTarget: ISOEntry?
    @State private var cheatsManagerTarget: DashGame?
    @State private var pendingDeleteDataGame: DashGame?
    @State private var pendingDeleteGame: DashGame?

    private var indexedText: String {
        "\(settings.localized("Indexed")) \(games.count) \(settings.localized(games.count == 1 ? "game" : "games"))"
    }

    var body: some View {
        // AYS2: kinetic hub carousel (seam) — ambient backdrop keyed on the
        // scroll-focused cover, behind the same header/list/hint chrome.
        ZStack {
            AmbientHeroBackground(focusedImage: focusedImage, focusKey: focusedGameID)
            VStack(alignment: .leading, spacing: 0) {
                header
                if games.isEmpty {
                    emptyState
                } else {
                    focusedInfo
                    // AYS2: the snap step is cover-width + this spacing —
                    // 30pt made the swipe distance needed to cross into the
                    // next game roughly half the screen width (too far for
                    // a normal thumb swipe, needed a hard deliberate flick).
                    // Tightened so a light, natural swipe is enough (seam/fix).
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(games) { game in
                                coverItem(game)
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1.0 : 0.72)
                                            .opacity(phase.isIdentity ? 1.0 : 0.35)
                                            .blur(radius: phase.isIdentity ? 0 : 2)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, (UIScreen.main.bounds.width - Self.heroCoverWidth) / 2)
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $focusedGameID, anchor: .center)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                Spacer(minLength: 0)
                HintBar(hints: [
                    .init(button: .triangle, label: settings.localized("add game")),
                    .init(button: .cross, label: settings.localized("select")),
                    .init(button: .circle, label: settings.localized("back")),
                ])
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.data, .item],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showLibrary) {
            NavigationStack { GameListView() }
        }
        .sheet(item: $gameInfoTarget) { game in
            GameInfoPanel(game: game, coverStore: coverStore)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $gameSettingsTarget) { game in
            PerGameSettingsPanel(game: game)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(34)
        }
        .sheet(item: $cheatsManagerTarget) { game in
            CheatsPatchesManagerView(isoName: game.bootName, gameTitle: game.name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(actionTitle, isPresented: $showActionAlert) {
            Button(settings.localized("OK")) {}
        } message: {
            Text(actionMessage)
        }
        .alert(settings.localized("Restart VM?"), isPresented: $showRestartAlert) {
            Button(settings.localized("Cancel"), role: .cancel) {}
            Button(settings.localized("Restart"), role: .destructive) {
                SoundManager.shared.play(.boot)
                if let pendingGame { appState.shutdownAndBoot(isoName: pendingGame.bootName) }
            }
        } message: {
            Text("\(settings.localized("A game is running. Shut it down and start")) \(pendingGame?.name ?? "")?")
        }
        .alert(
            settings.localized("Delete Game Data?"),
            isPresented: Binding(
                get: { pendingDeleteDataGame != nil },
                set: { if !$0 { pendingDeleteDataGame = nil } }
            )
        ) {
            Button(settings.localized("Cancel"), role: .cancel) {
                pendingDeleteDataGame = nil
            }
            Button(settings.localized("Delete Game Data"), role: .destructive) {
                if let game = pendingDeleteDataGame {
                    deleteGameData(game)
                }
                pendingDeleteDataGame = nil
            }
        } message: {
            Text(settings.localized("This clears save states, PNACH files, per-game settings, compatibility overrides, and generated cache for this game. Memory card contents are not deleted."))
        }
        .alert(
            settings.localized("Delete Game?"),
            isPresented: Binding(
                get: { pendingDeleteGame != nil },
                set: { if !$0 { pendingDeleteGame = nil } }
            )
        ) {
            Button(settings.localized("Cancel"), role: .cancel) {
                pendingDeleteGame = nil
            }
            Button(settings.localized("Delete ROM"), role: .destructive) {
                if let game = pendingDeleteGame {
                    deleteGame(game, deleteData: false)
                }
                pendingDeleteGame = nil
            }
            Button(settings.localized("Delete ROM + Game Data"), role: .destructive) {
                if let game = pendingDeleteGame {
                    deleteGame(game, deleteData: true)
                }
                pendingDeleteGame = nil
            }
        } message: {
            Text(settings.localized("Delete the selected game file? You can also remove its generated game data at the same time."))
        }
        .onAppear { loadGames() }
        // AYS2: debounced via .task(id:)'s automatic cancel-and-restart
        // (seam/fix). .scrollPosition(id:) updates focusedGameID
        // continuously while the user is actively dragging — not just once
        // scrolling settles — so a plain .onChange fired a disk read +
        // network/disk synopsis lookup + an expensive full-bleed 60pt
        // ambient blur re-render on every intermediate focus mid-swipe.
        // That main-thread contention during the live gesture is what made
        // swiping feel like it needed real force. Only the id that survives
        // ~120ms un-superseded (scrolling actually stopped) does the work.
        .task(id: focusedGameID) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            loadFocusedImage(for: focusedGameID)
            loadFocusedSynopsis(for: focusedGameID)
        }
    }

    /// Loads the focused game's cover independently of `CleanCover`'s own
    /// per-item loading — the ambient background needs a decoded `UIImage`
    /// (for Core Image sampling), not just a URL, and must not depend on
    /// whichever cover view happens to still be alive on screen.
    private func loadFocusedImage(for gameID: String?) {
        guard let gameID, let game = games.first(where: { $0.id == gameID }), let url = game.coverURL else {
            focusedImage = nil
            return
        }
        Task {
            let data = await Task.detached { try? Data(contentsOf: url) }.value
            guard let data, let image = UIImage(data: data) else { return }
            // Focus may have moved on again while this was loading; only
            // apply the result if it's still the current focus.
            if focusedGameID == gameID { focusedImage = image }
        }
    }

    /// Best-effort synopsis for the focused game via GameSynopsisStore
    /// (community database, cached to disk) — works for any game with a
    /// recognized serial, not a hardcoded list. Silently shows nothing on
    /// miss (unrecognized title, offline, no description available).
    private func loadFocusedSynopsis(for gameID: String?) {
        guard let gameID, let game = games.first(where: { $0.id == gameID }), let serial = game.serial, !serial.isEmpty else {
            focusedSynopsis = nil
            return
        }
        let preferFrench = settings.appLanguage.resolved == .french
        Task {
            let text = await GameSynopsisStore.shared.synopsis(rawSerial: serial, preferFrench: preferFrench)
            if focusedGameID == gameID { focusedSynopsis = text }
        }
    }

    private var focusedInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let synopsis = focusedSynopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.footnote)
                    .foregroundStyle(Retro.mut)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .id(focusedGameID)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: focusedSynopsis)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(minHeight: 20, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center) {
            RetroLabel(text: indexedText)
            Spacer()
            Button {
                SoundManager.shared.play(.nav)
                showLibrary = true
            } label: {
                Image(systemName: "square.grid.2x2").foregroundStyle(Retro.mut)
            }
            Button {
                SoundManager.shared.play(.nav)
                loadGames()
            } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(Retro.mut)
            }
            Button {
                SoundManager.shared.play(.select)
                showImporter = true
            } label: {
                Label(settings.localized("Import"), systemImage: "plus")
            }
            .buttonStyle(RetroButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// Hero cover width — sized so roughly one game reads as fully in focus
    /// per screen, with the next one peeking at the edge (console-hub style),
    /// rather than two equal covers side by side. Kept smaller than a first
    /// pass at this (190pt) — the "hero" feel comes from the scale/opacity/
    /// blur falloff on neighbors during scroll, not from raw size, and a
    /// smaller step (width + spacing) keeps the swipe distance needed to
    /// advance one game short enough for a normal, light thumb swipe.
    private static let heroCoverWidth: CGFloat = 160

    private func coverItem(_ game: DashGame) -> some View {
        let isRunning = game.bootName == appState.runningGameName
        return Button {
            selectGame(game)
        } label: {
            VStack(spacing: 8) {
                CleanCover(game: game, width: Self.heroCoverWidth)
                    .overlay(alignment: .topTrailing) {
                        Menu {
                            Button {
                                SoundManager.shared.play(.select)
                                toggleFavorite(game)
                            } label: {
                                Label(game.isFavorite ? settings.localized("Remove Favorite") : settings.localized("Add Favorite"),
                                      systemImage: game.isFavorite ? "star.slash" : "star")
                            }
                            Button {
                                SoundManager.shared.play(.nav)
                                showLibrary = true
                            } label: {
                                Label(settings.localized("Manage in Library"), systemImage: "square.grid.2x2")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Retro.ink)
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Retro.panel.opacity(0.92)))
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if game.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.yellow)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Retro.panel.opacity(0.92)))
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isRunning {
                            Text(settings.localized("RUNNING"))
                                .font(.system(size: 9, weight: .heavy)).tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color(red: 0.30, green: 0.68, blue: 0.31)))
                                .padding(7)
                        }
                    }
                Text(displayName(game.name))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Retro.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: Self.heroCoverWidth)
            }
        }
        .buttonStyle(.plain)
        .frame(width: Self.heroCoverWidth)
        // AYS2: long-press context menu (seam) — same Game Info/Per-Game
        // Settings/Cheats & Patches/Covers/Game Data menu as GameListView's
        // library rows, so a hero cover behaves like the rest of the library.
        .contextMenu {
            gameContextMenu(for: game)
        }
    }

    /// Drops the disc-image extension for a cleaner title under the cover.
    private func displayName(_ name: String) -> String {
        let lower = name.lowercased()
        for ext in [".iso", ".bin", ".chd", ".img", ".elf", ".cso", ".zso", ".gz"] where lower.hasSuffix(ext) {
            return String(name.dropLast(ext.count))
        }
        return name
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 54, weight: .thin))
                .foregroundStyle(Retro.line2)
            Text(settings.localized("No games yet"))
                .font(.title2.weight(.bold)).foregroundStyle(Retro.ink)
            Text(settings.localized("Import a PS2 disc image — ISO, BIN, CHD or IMG."))
                .font(.subheadline).foregroundStyle(Retro.mut)
                .multilineTextAlignment(.center)
            Button {
                SoundManager.shared.play(.select)
                showImporter = true
            } label: {
                Label(settings.localized("Import a game"), systemImage: "plus")
            }
            .buttonStyle(RetroButtonStyle())
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: - Data / actions

    private func selectGame(_ game: DashGame) {
        if game.bootName == appState.runningGameName {
            SoundManager.shared.play(.boot)
            appState.returnToGame()
            return
        }
        guard ARMSX2Bridge.hasBIOS() else {
            actionTitle = settings.localized("BIOS Required")
            actionMessage = settings.localized("Import a valid PS2 BIOS before starting games.")
            showActionAlert = true
            return
        }
        guard ARMSX2Bridge.canResolveISO(game.bootName) else {
            loadGames()
            return
        }
        if appState.runningGameName != nil {
            pendingGame = game
            showRestartAlert = true
        } else {
            SoundManager.shared.play(.boot)
            appState.bootGame(isoName: game.bootName)
        }
    }

    private func loadGames() {
        let coverStore = CoverStore.shared
        games = ARMSX2Bridge.availableISOEntries().compactMap { raw -> DashGame? in
            guard let name = raw["name"] as? String, let path = raw["path"] as? String else { return nil }
            let external = (raw["external"] as? NSNumber)?.boolValue ?? (raw["external"] as? Bool ?? false)
            let bootName = external ? path : name
            let fileURL = URL(fileURLWithPath: path)
            let metadata = ARMSX2Bridge.gameMetadata(forISO: bootName)
            let coverURL = coverStore.coverURL(forGameName: name, gamePath: fileURL, metadata: metadata)
            let signature = CoverThumbnailCache.signature(for: coverURL)
            return DashGame(
                id: external ? path : fileURL.path,
                name: name,
                bootName: bootName,
                coverURL: coverURL,
                coverSignature: signature,
                isFavorite: ARMSX2Bridge.isFavorite(bootName),
                serial: metadata["serial"],
                fileURL: fileURL,
                metadata: metadata,
                isExternal: external
            )
        }
        .sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        // AYS2: kinetic hub carousel (seam) — keep focus valid across
        // reloads (import, favorite toggle) instead of always resetting it.
        if focusedGameID == nil || !games.contains(where: { $0.id == focusedGameID }) {
            focusedGameID = games.first?.id
            loadFocusedImage(for: focusedGameID)
            loadFocusedSynopsis(for: focusedGameID)
        }
    }

    private func toggleFavorite(_ game: DashGame) {
        ARMSX2Bridge.setFavorite(game.bootName, favorite: !game.isFavorite)
        loadGames()
    }

    // AYS2: long-press context menu (seam) — ported from GameListView's
    // gameContextMenu(for: ISOEntry), operating on DashGame directly and
    // reusing the same panels/sheets (Game Info, Per-Game Settings, Cheats &
    // Patches) so the carousel's hero cover offers the same menu as the
    // full library list.
    @ViewBuilder
    private func gameContextMenu(for game: DashGame) -> some View {
        Button {
            presentMenuPanel { gameInfoTarget = game.asISOEntry }
        } label: {
            Label(settings.localized("Game Info"), systemImage: "info.circle")
        }

        Button {
            presentMenuPanel { gameSettingsTarget = game.asISOEntry }
        } label: {
            Label(settings.localized("Per-Game Settings"), systemImage: "slider.horizontal.3")
        }

        Button {
            presentMenuPanel { cheatsManagerTarget = game }
        } label: {
            Label(settings.localized("Cheats & Patches"), systemImage: "rectangle.stack.badge.plus")
        }

        Menu {
            Button {
                downloadCover(for: game)
            } label: {
                Label(settings.localized("Download Cover"), systemImage: "icloud.and.arrow.down")
            }
            .disabled(coverStore.isDownloadingCovers)

            if game.coverURL != nil {
                Button(role: .destructive) {
                    coverStore.removeManagedCovers(forGameNamed: game.name)
                    loadGames()
                } label: {
                    Label(settings.localized("Remove Cover"), systemImage: "trash")
                }
            }
        } label: {
            Label(settings.localized("Covers"), systemImage: "photo.stack")
        }

        Divider()

        Menu {
            Button {
                clearGameCache(game)
            } label: {
                Label(settings.localized("Clear Game Cache"), systemImage: "trash.slash")
            }

            Button(role: .destructive) {
                presentMenuPanel { pendingDeleteDataGame = game }
            } label: {
                Label(settings.localized("Delete Game Data"), systemImage: "externaldrive.badge.xmark")
            }

            if !game.isExternal {
                Button(role: .destructive) {
                    presentMenuPanel { pendingDeleteGame = game }
                } label: {
                    Label(settings.localized("Delete Game"), systemImage: "trash")
                }
            }
        } label: {
            Label(settings.localized("Game Data"), systemImage: "externaldrive")
        }
    }

    private func presentMenuPanel(_ action: @escaping () -> Void) {
        // AYS2: guard against a scene backgrounding during this delay
        // (seam/fix) — see RootView.swift's showCommunityWelcome timer for
        // the full rationale (stuck sheet dimming overlay swallowing touches
        // on foreground return, worse on iPad's non-fullscreen sheets).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard UIApplication.shared.applicationState == .active else { return }
            action()
        }
    }

    private func downloadCover(for game: DashGame) {
        Task {
            _ = await coverStore.downloadMissingCovers(for: [game.asISOEntry.coverInfo])
            loadGames()
        }
    }

    private func clearGameCache(_ game: DashGame) {
        actionTitle = settings.localized("Clear Game Cache")
        actionMessage = ARMSX2Bridge.clearCache(forISO: game.bootName)
        showActionAlert = true
    }

    private func deleteGameData(_ game: DashGame) {
        actionTitle = settings.localized("Delete Game Data")
        actionMessage = ARMSX2Bridge.deleteGameData(forISO: game.bootName)
        showActionAlert = true
    }

    private func deleteGame(_ game: DashGame, deleteData: Bool) {
        if game.bootName == appState.runningGameName {
            actionTitle = settings.localized("Delete Game")
            actionMessage = settings.localized("Stop this game before deleting it.")
            showActionAlert = true
            return
        }

        let success = ARMSX2Bridge.deleteISO(game.bootName, deleteGameData: deleteData)
        if success {
            coverStore.removeManagedCovers(forGameNamed: game.name)
            loadGames()
        }
        actionTitle = settings.localized("Delete Game")
        actionMessage = success ? settings.localized("Game deleted.") : settings.localized("Could not delete this game file.")
        showActionAlert = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls { _ = FileImportHandler.shared.handleURL(url) }
            loadGames()
        case .failure(let error):
            actionTitle = settings.localized("Import")
            actionMessage = "\(settings.localized("Import failed:")) \(error.localizedDescription)"
            showActionAlert = true
        }
    }
}

/// A game's cover art shown whole and uncropped at true PS2 case proportions —
/// the full artwork with a soft drop shadow so it reads as a physical 3D box.
struct CleanCover: View {
    let game: DashGame
    var width: CGFloat = 168

    @State private var image: UIImage?

    private var height: CGFloat { width * Retro.coverRatio }

    var body: some View {
        ZStack {
            Retro.panel2
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                LinearGradient(colors: [Retro.panel, Retro.panel2], startPoint: .top, endPoint: .bottom)
                Text(game.name)
                    .font(.system(size: width * 0.11, weight: .semibold))
                    .foregroundStyle(Retro.mut)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(10)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Retro.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 10)
        .task(id: game.coverURL) {
            image = nil
            guard let url = game.coverURL else { return }
            let data = await Task.detached { try? Data(contentsOf: url) }.value
            if let data { image = UIImage(data: data) }
        }
    }
}

// MARK: - Settings as a tiled grid (console-dashboard "hub")

struct SettingsGridView: View {
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    SettingsTile(title: "Emulation", subtitle: "Core · Speed · Cheats",
                                 systemImage: "cpu") { EmulatorSettingsView() }
                    SettingsTile(title: "Video", subtitle: "Renderer · Resolution · FPS",
                                 systemImage: "display") { GraphicsSettingsView() }
                    SettingsTile(title: "Overlay", subtitle: "OSD · HUD · Stats",
                                 systemImage: "text.below.photo") { OverlaySettingsView() }
                    SettingsTile(title: "Controls", subtitle: "Gamepad · Mapping",
                                 systemImage: "gamecontroller") { GamepadSettingsView() }
                    SettingsTile(title: "Virtual Pad", subtitle: "Touch · Layout · Scale",
                                 systemImage: "hand.draw") { VirtualPadSettingsView() }
                    SettingsTile(title: "Appearance", subtitle: "Theme · Background",
                                 systemImage: "circle.lefthalf.filled") { AppearanceSettingsView() }
                    SettingsTile(title: "System", subtitle: "Sounds · About · Version",
                                 systemImage: "gearshape") { SystemSettingsView() }
                    SettingsTile(title: "Core Access", subtitle: "Support · Perks · Betas",
                                 systemImage: "crown.fill") { CoreAccessView(showsClose: false) }
                }
                .padding(16)
            }
            .background(RetroBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// One large solid tile in the Settings hub.
struct SettingsTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: systemImage)
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(.white.opacity(0.20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
            }
            .frame(height: 132)
            .shadow(color: Retro.accentDeep.opacity(0.25), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

/// Small "System" settings screen (the bits that had no dedicated view).
struct SystemSettingsView: View {
    @AppStorage("uiSoundsEnabled") private var uiSoundsEnabled = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $uiSoundsEnabled) {
                    Label("UI Sounds", systemImage: "speaker.wave.2")
                }
            } footer: {
                Text("Original menu sounds. Obeys the mute switch.")
            }
            Section {
                NavigationLink {
                    TermsOfUseView(mode: .view)
                } label: {
                    Label("Terms of Use & Privacy", systemImage: "hand.raised")
                }
                NavigationLink {
                    LicenseView()
                } label: {
                    Label("Licenses & Credits", systemImage: "doc.text")
                }
            } footer: {
                Text("Diagnostics are anonymous — device model, iOS version and technical logs on crashes/errors, to fix bugs. No account or personal data.")
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(ARMSX2Bridge.buildVersion())
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("System")
        .navigationBarTitleDisplayMode(.inline)
    }
}
