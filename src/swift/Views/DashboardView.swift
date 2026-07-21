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

/// AYS2: how the hub's games section is laid out — the flowing carousel, a
/// cover grid, or a compact list. Persisted via @AppStorage.
enum LibraryViewMode: String, CaseIterable, Identifiable {
    case carousel, grid, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .carousel: return "Carousel"
        case .grid:     return "Grid"
        case .list:     return "List"
        }
    }
    var systemImage: String {
        switch self {
        case .carousel: return "rectangle.stack"
        case .grid:     return "square.grid.2x2"
        case .list:     return "list.bullet"
        }
    }
}

/// AYS2: routes controller navigation commands from the Dashboard's single
/// controller scope down to whichever section is active (seam). The active
/// section observes `token` and reads `command`. Sections also report whether a
/// modal (sheet/alert) is up via `modalPresented`, which disables controller
/// navigation while the modal is open (touch drives modals for now).
@Observable
final class DashboardNav {
    private(set) var command: MenuCommand?
    private(set) var token: UInt64 = 0
    var modalPresented = false
    /// Set by a section that has pushed a sub-screen, so L1/R1 don't switch the
    /// Dashboard section out from under it (commands still flow, so Back works).
    var suppressSectionSwitch = false

    func send(_ command: MenuCommand) {
        self.command = command
        token &+= 1
    }
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
    // AYS2: routes physical-controller navigation into the active section (seam).
    @State private var nav = DashboardNav()

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
        // AYS2: controller menu navigation (seam). This single scope is always
        // mounted while the Dashboard is on screen, so L1/R1 section switching
        // works from any tab; everything else forwards to the active section.
        // Disabled while a section has a modal up (touch owns modals for now).
        .menuControllerScope("dashboard", isActive: !nav.modalPresented) { command in
            switch command {
            case .pageLeft:  stepSection(-1)
            case .pageRight: stepSection(1)
            default:         nav.send(command)
            }
        }
    }

    private func stepSection(_ delta: Int) {
        // A section that has pushed a sub-screen suppresses tab switching so it
        // doesn't change out from under the pushed screen.
        guard !nav.suppressSectionSwitch else { return }
        let all = DashSection.allCases
        guard let idx = all.firstIndex(of: section) else { return }
        section = all[(idx + delta + all.count) % all.count]
        SoundManager.shared.play(.nav)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .games:    GamesCarouselView(nav: nav)
        case .bios:     BIOSListView()
        case .settings: SettingsGridView(nav: nav)
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
            // AYS2 wordmark (seam) — replaces the old decorative diamond glyph,
            // which looked tappable but did nothing. A plain brand label reads
            // clearer and doesn't invite a dead tap.
            Text("AYS2")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                                startPoint: .top, endPoint: .bottom))
                .fixedSize()

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
    // AYS2: controller navigation router from the Dashboard (seam).
    let nav: DashboardNav

    @State private var appState = AppState.shared
    @State private var settings = SettingsStore.shared
    @State private var coverStore = CoverStore.shared
    @State private var games: [DashGame] = []
    @State private var showImporter = false
    @State private var showCoverImporter = false
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
    // AYS2: tracks the last game a swipe UI sound played for (seam) — nil
    // until the carousel's first settle, so the sound doesn't fire on
    // initial load, only on an actual swipe between two games.
    @State private var lastSoundedGameID: String?
    // AYS2: long-press context menu targets (seam) — mirrors GameListView's
    // gameContextMenu, reusing the same panels/sheets so a game long-pressed
    // from the carousel gets the same Game Info/Per-Game Settings/Cheats &
    // Patches/Covers/Game Data menu as from the full library list.
    @State private var gameInfoTarget: ISOEntry?
    @State private var gameSettingsTarget: ISOEntry?
    @State private var cheatsManagerTarget: DashGame?
    @State private var pendingDeleteDataGame: DashGame?
    @State private var pendingDeleteGame: DashGame?
    // AYS2: custom display name editing (seam).
    @State private var renameTarget: DashGame?
    @State private var renameText = ""
    // AYS2: menu parity with the library (seam) — settings-profile export/import
    // and hide-from-library, so the carousel long-press menu matches the list.
    @State private var hiddenStore = HiddenGamesStore.shared
    @State private var profileShareItem: ShareSheetItem?
    @State private var showProfileImporter = false
    @State private var profileImportGame: DashGame?
    @State private var profileMessage: String?
    // AYS2: hub games layout — carousel / grid / list (seam), remembered.
    @AppStorage("ays2LibraryViewMode") private var viewMode: LibraryViewMode = .carousel

    private var indexedText: String {
        "\(settings.localized("Indexed")) \(games.count) \(settings.localized(games.count == 1 ? "game" : "games"))"
    }

    /// True while any sheet/alert is presented from the carousel — controller
    /// navigation is suspended so it doesn't move the row behind an open modal.
    private var anyModalPresented: Bool {
        showImporter || showCoverImporter || showLibrary || showRestartAlert
            || showActionAlert || gameInfoTarget != nil || gameSettingsTarget != nil
            || cheatsManagerTarget != nil || pendingDeleteDataGame != nil
            || pendingDeleteGame != nil || renameTarget != nil
            || profileShareItem != nil || showProfileImporter || profileMessage != nil
    }

    /// The game currently centered in the carousel (the controller's selection).
    private var focusedGame: DashGame? {
        games.first { $0.id == focusedGameID } ?? games.first
    }

    /// Moves the carousel selection by `delta` (controller left/right). The
    /// `.scrollPosition(id:)` binding scrolls the row to the new focus.
    private func moveFocus(_ delta: Int) {
        guard !games.isEmpty else { return }
        let currentIndex = games.firstIndex { $0.id == focusedGameID } ?? 0
        let next = max(0, min(games.count - 1, currentIndex + delta))
        guard next != currentIndex else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            focusedGameID = games[next].id
        }
    }

    private func handleControllerCommand(_ command: MenuCommand) {
        guard !anyModalPresented else { return }
        switch command {
        case .left:  moveFocus(-1)
        case .right: moveFocus(1)
        case .select:
            if games.isEmpty {
                showImporter = true
            } else if let game = focusedGame {
                selectGame(game)
            }
        case .altAction:
            // Triangle / Y — add game (matches the on-screen hint).
            showImporter = true
        case .menu:
            // Menu / Options — open the focused game's info & actions.
            if let game = focusedGame { gameInfoTarget = game.asISOEntry }
        case .up, .down, .back, .pageLeft, .pageRight:
            break // handled at the Dashboard level or not applicable here
        }
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
                    switch viewMode {
                    case .carousel:
                        focusedInfo
                        carouselScroll
                    case .grid:
                        gridScroll
                    case .list:
                        listScroll
                    }
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
        // AYS2: cover import + result alert on the hub (seam) — mirrors the
        // Library screen so covers can be managed without leaving the home.
        .sheet(isPresented: $showCoverImporter) {
            ImportDocumentPicker(
                allowedContentTypes: CoverStore.coverContentTypes,
                allowsMultipleSelection: true
            ) { result in
                showCoverImporter = false
                switch result {
                case .success(let urls):
                    coverStore.importCoverURLs(urls, forGameNamed: nil)
                    loadGames()
                case .failure(let error):
                    if !FileImportHandler.isUserCancelledPickerError(error) {
                        coverStore.lastCoverMessage = "Cover import failed: \(error.localizedDescription)"
                        coverStore.showCoverAlert = true
                    }
                }
            }
        }
        .alert(settings.localized("Cover Result"), isPresented: $coverStore.showCoverAlert) {
            Button(settings.localized("OK")) {}
        } message: {
            Text(coverStore.lastCoverMessage ?? "")
        }
        .sheet(isPresented: $showLibrary, onDismiss: { loadGames() }) {
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
        // AYS2: rename a game's display name (seam).
        .alert(
            settings.localized("Rename Game"),
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField(settings.localized("Display name"), text: $renameText)
            Button(settings.localized("Cancel"), role: .cancel) { renameTarget = nil }
            Button(settings.localized("Save")) {
                if let game = renameTarget {
                    GameNameStore.shared.setName(renameText, forBoot: game.bootName)
                }
                renameTarget = nil
            }
        } message: {
            Text(settings.localized("Set a custom name shown in the library. Leave empty to restore the original."))
        }
        // AYS2: settings-profile export/import (seam) — menu parity with the library.
        .sheet(item: $profileShareItem) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showProfileImporter) {
            ImportDocumentPicker(
                allowedContentTypes: [UTType(filenameExtension: "ini") ?? .data, .data],
                allowsMultipleSelection: false
            ) { result in
                showProfileImporter = false
                importSettingsProfile(result)
            }
        }
        .alert(settings.localized("Settings Profile"), isPresented: Binding(
            get: { profileMessage != nil },
            set: { if !$0 { profileMessage = nil } }
        )) {
            Button(settings.localized("OK")) { profileMessage = nil }
        } message: {
            Text(profileMessage ?? "")
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
        // AYS2: controller navigation (seam) — consume forwarded commands and
        // keep the Dashboard scope disabled while a modal is up.
        .onChange(of: nav.token) { _, _ in
            if let command = nav.command { handleControllerCommand(command) }
        }
        .onChange(of: anyModalPresented) { _, presented in
            nav.modalPresented = presented
        }
        // AYS2: reveal/hide toggle reloads the hub list (seam).
        .onChange(of: hiddenStore.revealHidden) { _, _ in loadGames() }
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
            if let lastSoundedGameID, lastSoundedGameID != focusedGameID {
                // AYS2: matches the sound used when picking a CORE ACCESS
                // subscription tier (CoreAccessView's planRow), not the .nav
                // sound used for top-nav tab switches (seam/fix).
                SoundManager.shared.play(.select)
            }
            lastSoundedGameID = focusedGameID
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

    /// The flowing hero carousel (default). Horizontal snap scroller keyed to
    /// `focusedGameID`, with scale/opacity/blur focus transitions.
    private var carouselScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(games) { game in
                    // AYS2: read Performance Mode into a Sendable local — the
                    // nonisolated scrollTransition closure can't touch `settings`.
                    let reduceBlur = settings.performanceMode
                    coverItem(game)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.72)
                                .opacity(phase.isIdentity ? 1.0 : 0.35)
                                .blur(radius: (phase.isIdentity || reduceBlur) ? 0 : 2)
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

    /// A cover grid — more games visible at once, adaptive columns.
    private var gridScroll: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 16)], spacing: 18) {
                ForEach(games) { game in
                    Button {
                        SoundManager.shared.play(.boot)
                        selectGame(game)
                    } label: {
                        VStack(spacing: 6) {
                            CleanCover(game: game, width: 104)
                            Text(displayName(for: game))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Retro.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu { gameContextMenu(for: game) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
    }

    /// A compact list — a thumbnail, the title, and format, one row per game.
    private var listScroll: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(games) { game in
                    Button {
                        SoundManager.shared.play(.boot)
                        selectGame(game)
                    } label: {
                        HStack(spacing: 12) {
                            CleanCover(game: game, width: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(for: game))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Retro.ink)
                                    .lineLimit(1)
                                Text(game.name.pathExtensionLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Retro.mut)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            if game.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(Retro.accent)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Retro.line2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Retro.panel.opacity(0.55))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { gameContextMenu(for: game) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
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

    /// The carousel / grid / list switcher (accent pill) plus the Show-Hidden
    /// reveal. Its own property so the header HStack stays type-checkable.
    private var layoutMenu: some View {
        Menu {
            Picker(settings.localized("Layout"), selection: $viewMode) {
                ForEach(LibraryViewMode.allCases) { mode in
                    Label(settings.localized(mode.label), systemImage: mode.systemImage).tag(mode)
                }
            }
            // AYS2: reveal games hidden from the hub (seam) — shared flag with the
            // Library, so a game hidden via the context menu can be un-hidden here.
            if hiddenStore.hiddenCount > 0 {
                Divider()
                Toggle(isOn: $hiddenStore.revealHidden) {
                    Label(settings.localized("Show Hidden Games") + " (\(hiddenStore.hiddenCount))",
                          systemImage: hiddenStore.revealHidden ? "eye" : "eye.slash")
                }
            }
        } label: {
            Image(systemName: viewMode.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                             startPoint: .top, endPoint: .bottom))
                )
        }
        .accessibilityLabel(settings.localized("Layout"))
        .onChange(of: viewMode) { _, _ in SoundManager.shared.play(.nav) }
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
            // AYS2: layout switcher (seam) — carousel / grid / list, next to the
            // Covers control. Extracted to keep the header type-checkable.
            layoutMenu
            // AYS2: Covers control on the hub (seam) — this was only reachable
            // from the full Library screen before; user asked for it on the home.
            Menu {
                Button {
                    SoundManager.shared.play(.select)
                    Task { _ = await coverStore.downloadMissingCovers(for: games.map { $0.asISOEntry.coverInfo }) }
                } label: {
                    Label(settings.localized("Download Missing Covers"), systemImage: "icloud.and.arrow.down")
                }
                .disabled(coverStore.isDownloadingCovers || games.isEmpty)
                Button {
                    SoundManager.shared.play(.select)
                    showCoverImporter = true
                } label: {
                    Label(settings.localized("Import Local Covers"), systemImage: "photo.badge.plus")
                }
                Button {
                    SoundManager.shared.play(.nav)
                    showLibrary = true
                } label: {
                    Label(settings.localized("More Cover Options"), systemImage: "square.grid.2x2")
                }
            } label: {
                Image(systemName: coverStore.isDownloadingCovers ? "icloud.and.arrow.down" : "photo.stack")
                    .foregroundStyle(Retro.mut)
            }
            .accessibilityLabel(settings.localized("Covers"))
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
    /// rather than two equal covers side by side. 190pt (the original size)
    /// combined with 30pt spacing made the swipe distance too long for a
    /// light thumb swipe; that got overcorrected down to 160pt/14pt, which
    /// read as cramped and small. Restored partway — the swipe-feel fix
    /// turned out to be the .task(id:) debounce in `body`, not the size, so
    /// this (with the 20pt spacing above) still keeps the step well under
    /// the original 220pt while giving covers real presence again.
    private static let heroCoverWidth: CGFloat = 178

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
                Text(displayName(for: game))
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

    /// AYS2: a game's shown name — the user's custom name if set, else the
    /// extension-stripped original (seam). Never affects identity/boot.
    private func displayName(for game: DashGame) -> String {
        GameNameStore.shared.customName(forBoot: game.bootName) ?? displayName(game.name)
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
        let fm = FileManager.default
        // AYS2: metadata cache (seam/fix) — this used to call
        // ARMSX2Bridge.gameMetadata(forISO:) unconditionally for every game
        // on every reload (including the reload that follows every cover
        // download, favorite toggle, import, and delete), which parses each
        // ISO's header from scratch. For a library of any real size that's
        // several seconds of synchronous main-thread work — the app renders
        // the carousel, then goes unresponsive to every tap/swipe until it
        // finishes, easily read as a freeze or a dead button. Reusing
        // GameLibrarySnapshot (already built for this exact cost in
        // GameListView) skips the reparse whenever the file is unchanged.
        games = ARMSX2Bridge.availableISOEntries().compactMap { raw -> DashGame? in
            guard let name = raw["name"] as? String, let path = raw["path"] as? String else { return nil }
            let external = (raw["external"] as? NSNumber)?.boolValue ?? (raw["external"] as? Bool ?? false)
            let bootName = external ? path : name
            let fileURL = URL(fileURLWithPath: path)
            let entryID = external ? path : fileURL.path
            let attrs = try? fm.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
            let modificationDate = attrs?[.modificationDate] as? Date
            let metadata: [String: String]
            if let cached = GameLibrarySnapshot.shared.cachedMetadata(for: entryID, modificationDate: modificationDate, size: size) {
                metadata = cached
            } else {
                metadata = ARMSX2Bridge.gameMetadata(forISO: bootName)
                GameLibrarySnapshot.shared.storeMetadata(metadata, modificationDate: modificationDate, size: size, for: entryID)
            }
            let coverURL = coverStore.coverURL(forGameName: name, gamePath: fileURL, metadata: metadata)
            let signature = CoverThumbnailCache.signature(for: coverURL)
            return DashGame(
                id: entryID,
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
        // AYS2: user-hidden entries are filtered out of the hub unless the
        // "Show Hidden Games" reveal toggle (shared with the Library) is on — so
        // a game hidden from the carousel can also be un-hidden right here (seam).
        .filter { hiddenStore.revealHidden || !hiddenStore.isHidden($0.bootName) }
        .sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        GameLibrarySnapshot.shared.persistMetadataCache()
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

        // AYS2: custom display name (seam) — mainly for modded ISOs with a
        // glitched embedded title.
        Button {
            renameText = GameNameStore.shared.customName(forBoot: game.bootName) ?? ""
            presentMenuPanel { renameTarget = game }
        } label: {
            Label(settings.localized("Rename"), systemImage: "pencil")
        }

        // AYS2: export/import this game's per-game settings profile (seam) —
        // menu parity with the library list.
        Menu {
            Button {
                exportSettingsProfile(for: game)
            } label: {
                Label(settings.localized("Export Profile"), systemImage: "square.and.arrow.up")
            }
            Button {
                presentMenuPanel {
                    profileImportGame = game
                    showProfileImporter = true
                }
            } label: {
                Label(settings.localized("Import Profile"), systemImage: "square.and.arrow.down")
            }
        } label: {
            Label(settings.localized("Settings Profile"), systemImage: "doc.badge.gearshape")
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

        // AYS2: hide/show this entry in the library (seam) — menu parity with
        // the library list.
        Button {
            hiddenStore.toggle(bootName: game.bootName)
            loadGames()
        } label: {
            let hidden = hiddenStore.isHidden(game.bootName)
            Label(settings.localized(hidden ? "Show in Library" : "Hide from Library"),
                  systemImage: hidden ? "eye" : "eye.slash")
        }

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

    // AYS2: per-game settings profile export/import (seam) — same behavior as the
    // library list. Shares the game's per-game .ini as "<Game Name>.ini"; import
    // writes it back for the same game (applies on next boot).
    private func exportSettingsProfile(for game: DashGame) {
        guard let path = ARMSX2Bridge.perGameSettingsFilePath(forISO: game.bootName) else {
            profileMessage = settings.localized("This game has no per-game settings to export yet. Set some in Per-Game Settings first.")
            return
        }
        let source = URL(fileURLWithPath: path)
        let safeName = game.name.replacingOccurrences(of: "/", with: "-")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).ini")
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            profileShareItem = ShareSheetItem(url: destination)
        } catch {
            profileMessage = "\(settings.localized("Could not export the profile:")) \(error.localizedDescription)"
        }
    }

    private func importSettingsProfile(_ result: Result<[URL], Error>) {
        guard let game = profileImportGame else { return }
        profileImportGame = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let ok = ARMSX2Bridge.importPerGameSettings(fromFile: url.path, forISO: game.bootName)
            profileMessage = ok
                ? "\(settings.localized("Imported settings profile for")) \(game.name). \(settings.localized("It applies the next time this game boots."))"
                : "\(settings.localized("Couldn't import the profile for")) \(game.name)."
        case .failure(let error):
            if !FileImportHandler.isUserCancelledPickerError(error) {
                profileMessage = "\(settings.localized("Import failed:")) \(error.localizedDescription)"
            }
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
            // AYS2: batched into a single handleURLs call instead of one
            // handleURL per file (seam/fix) — the per-file version ran a
            // full import+alert cycle per file, so adding many games at once
            // fired loadGames() N times back-to-back (only this final call
            // does that now) and repeatedly stomped showImportAlert's
            // message before SwiftUI could even present it once.
            _ = FileImportHandler.shared.handleURLs(urls, preferredDestination: .automatic)
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
    // AYS2: user request — show total play time on the cover (see PlayTimeStore).
    @State private var playTimeStore = PlayTimeStore.shared

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
                Text(GameNameStore.shared.displayName(forBoot: game.bootName, fallback: game.name))
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
        // AYS2: play-time badge, pinned to the top of the cover (user request).
        .overlay(alignment: .topLeading) {
            if let playtime = playTimeStore.formatted(forGame: game.bootName) {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                    Text(playtime)
                }
                .font(.system(size: max(9, width * 0.058), weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
            }
        }
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

/// A Settings hub category — value-driven so it can be pushed by touch or by a
/// controller's select command through the NavigationStack path.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case emulation, video, overlay, controls, virtualPad
    case achievements, appearance, system, coreAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emulation: return "Emulation"
        case .video: return "Video"
        case .overlay: return "Overlay"
        case .controls: return "Controls"
        case .virtualPad: return "Virtual Pad"
        case .achievements: return "Achievements"
        case .appearance: return "Appearance"
        case .system: return "System"
        case .coreAccess: return "Core Access"
        }
    }

    var subtitle: String {
        switch self {
        case .emulation: return "Core · Speed · Cheats"
        case .video: return "Renderer · Resolution · FPS"
        case .overlay: return "OSD · HUD · Stats"
        case .controls: return "Gamepad · Mapping"
        case .virtualPad: return "Touch · Layout · Scale"
        case .achievements: return "Login · Hardcore · Progress"
        case .appearance: return "Theme · Background"
        case .system: return "Sounds · About · Version"
        case .coreAccess: return "Support · Perks · Betas"
        }
    }

    var systemImage: String {
        switch self {
        case .emulation: return "cpu"
        case .video: return "display"
        case .overlay: return "text.below.photo"
        case .controls: return "gamecontroller"
        case .virtualPad: return "hand.draw"
        case .achievements: return "trophy"
        case .appearance: return "circle.lefthalf.filled"
        case .system: return "gearshape"
        case .coreAccess: return "crown.fill"
        }
    }
}

struct SettingsGridView: View {
    // AYS2: controller navigation router from the Dashboard (seam).
    let nav: DashboardNav

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let categories = SettingsCategory.allCases

    @State private var path: [SettingsCategory] = []
    // AYS2: controller focus index into the tile grid (seam).
    @State private var focusedIndex = 0
    @State private var input = MenuControllerInput.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        SettingsTile(
                            category: category,
                            // Only show the controller focus ring when a controller is
                            // connected — touch users never see a stuck highlight.
                            isFocused: input.controllerConnected && index == focusedIndex
                        ) {
                            path.append(category)
                        }
                    }
                }
                .padding(16)
            }
            .background(RetroBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsCategory.self) { category in
                destination(for: category)
            }
        }
        // AYS2: consume forwarded controller commands (seam).
        .onChange(of: nav.token) { _, _ in
            if let command = nav.command { handleControllerCommand(command) }
        }
        // Suppress Dashboard section switching while a sub-screen is pushed.
        .onChange(of: path.isEmpty) { _, empty in
            nav.suppressSectionSwitch = !empty
        }
        .onDisappear { nav.suppressSectionSwitch = false }
    }

    @ViewBuilder
    private func destination(for category: SettingsCategory) -> some View {
        switch category {
        case .emulation:    EmulatorSettingsView()
        case .video:        GraphicsSettingsView()
        case .overlay:      OverlaySettingsView()
        case .controls:     GamepadSettingsView()
        case .virtualPad:   VirtualPadSettingsView()
        case .achievements: RetroAchievementsSettingsView()
        case .appearance:   AppearanceSettingsView()
        case .system:       SystemSettingsView()
        case .coreAccess:   CoreAccessView(showsClose: false)
        }
    }

    private func handleControllerCommand(_ command: MenuCommand) {
        // While a sub-screen is pushed, only Back (pop) is handled here; the
        // pushed screen's own controls are touch-driven.
        if !path.isEmpty {
            if command == .back { path.removeLast() }
            return
        }
        let count = categories.count
        switch command {
        case .left:  focusedIndex = max(0, focusedIndex - 1)
        case .right: focusedIndex = min(count - 1, focusedIndex + 1)
        case .up:    focusedIndex = max(0, focusedIndex - 2)
        case .down:  focusedIndex = min(count - 1, focusedIndex + 2)
        case .select, .menu:
            SoundManager.shared.play(.nav)
            path.append(categories[focusedIndex])
        case .back, .altAction, .pageLeft, .pageRight:
            break
        }
    }
}

/// One large solid tile in the Settings hub.
struct SettingsTile: View {
    let category: SettingsCategory
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: category.systemImage)
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(.white.opacity(0.20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title.uppercased())
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(category.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
            }
            .frame(height: 132)
            // AYS2: controller focus ring (seam) — a bright border + lift when the
            // tile is the current controller selection.
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: isFocused ? 3 : 0)
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .shadow(color: Retro.accentDeep.opacity(isFocused ? 0.5 : 0.25),
                    radius: isFocused ? 12 : 8, x: 0, y: 5)
            .animation(.easeOut(duration: 0.14), value: isFocused)
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
