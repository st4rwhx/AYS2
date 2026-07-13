// DashboardView.swift — console-style home: horizontal top nav + cover carousel.
// SPDX-License-Identifier: GPL-3.0+
//
// Replaces the bottom TabView with a top section nav and a swipeable row of
// clean game covers. Native SwiftUI rebuild of the horizontal-dashboard layout
// (no third-party code). Reuses the existing BIOS/Settings/Help screens.

import SwiftUI
import UniformTypeIdentifiers

enum DashSection: String, CaseIterable, Identifiable {
    case games = "Games", bios = "BIOS", settings = "Settings", help = "Help"
    var id: String { rawValue }
}

struct DashboardView: View {
    @State private var section: DashSection = .games

    var body: some View {
        ZStack {
            RetroBackground()
            VStack(spacing: 0) {
                topNav
                Rectangle().fill(Retro.line).frame(height: 1)
                content
            }
        }
    }

    private var topNav: some View {
        HStack(spacing: 14) {
            Rectangle()
                .strokeBorder(Retro.accent, lineWidth: 2)
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(45))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(DashSection.allCases) { s in
                        Button {
                            section = s
                            SoundManager.shared.play(.nav)
                        } label: {
                            VStack(spacing: 6) {
                                Text(s.rawValue)
                                    .font(.system(.title3, design: .serif))
                                    .fontWeight(section == s ? .semibold : .regular)
                                    .foregroundStyle(section == s ? Retro.ink : Retro.faint)
                                Rectangle()
                                    .fill(section == s ? Retro.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 20)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .games:    GamesCarouselView()
        case .bios:     BIOSListView()
        case .settings: NavigationStack { SettingsRootView() }
        case .help:     HelpView()
        }
    }
}

// MARK: - Games as a horizontal cover carousel

struct GamesCarouselView: View {
    @State private var games: [ISOEntry] = []
    @State private var appState = AppState.shared
    @State private var showImporter = false
    @State private var showRestartAlert = false
    @State private var pendingGameName = ""

    private var sortedGames: [ISOEntry] {
        games.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if games.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(sortedGames) { game in
                            coverItem(game)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 20)
                }
            }
            Spacer(minLength: 0)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.data, .item],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .alert("Restart VM?", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart", role: .destructive) {
                appState.shutdownAndBoot(isoName: pendingGameName)
            }
        } message: {
            Text("A game is running. Shut it down and start \(pendingGameName)?")
        }
        .onAppear { loadGames() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            RetroLabel(text: games.isEmpty ? "No games" : "Indexed \(games.count) game\(games.count == 1 ? "" : "s")")
            Spacer()
            Button { loadGames() } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(Retro.mut)
            }
            Button { showImporter = true } label: {
                Label("Import", systemImage: "plus")
            }
            .buttonStyle(RetroButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func coverItem(_ game: ISOEntry) -> some View {
        let isRunning = game.name == appState.runningGameName
        return Button {
            selectGame(game.name)
        } label: {
            VStack(spacing: 10) {
                CleanCover(gameName: game.name, width: 158)
                    .overlay(alignment: .topTrailing) {
                        if game.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Retro.accent)
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isRunning {
                            Text("RUNNING")
                                .font(.system(size: 9, weight: .heavy)).tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Retro.accent)
                                .padding(8)
                        }
                    }
                Text(game.name)
                    .font(.system(.callout, design: .serif))
                    .textCase(.lowercase)
                    .foregroundStyle(Retro.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 158)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleFavorite(game.name)
            } label: {
                Label(game.isFavorite ? "Remove Favorite" : "Add Favorite",
                      systemImage: game.isFavorite ? "star.slash" : "star")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Rectangle()
                .strokeBorder(Retro.line2, lineWidth: 2)
                .frame(width: 74, height: 74)
                .rotationEffect(.degrees(45))
                .overlay(Rectangle().strokeBorder(Retro.accent.opacity(0.6), lineWidth: 1)
                    .frame(width: 44, height: 44).rotationEffect(.degrees(45)))
            Text("no games yet")
                .font(.system(.title2, design: .serif)).foregroundStyle(Retro.ink)
            Text("Import a PS2 disc image — ISO, BIN, CHD or IMG.")
                .font(.system(.subheadline, design: .serif)).foregroundStyle(Retro.mut)
                .multilineTextAlignment(.center)
            Button { showImporter = true } label: {
                Label("Import a game", systemImage: "plus")
            }
            .buttonStyle(RetroButtonStyle())
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: - Data / actions (mirrors GameListView)

    private func selectGame(_ name: String) {
        if name == appState.runningGameName {
            appState.returnToGame()
        } else if appState.runningGameName != nil {
            pendingGameName = name
            showRestartAlert = true
        } else {
            appState.bootGame(isoName: name)
        }
    }

    private func loadGames() {
        let isoDir = iPSX2Bridge.isoDirectory()
        let docsDir = iPSX2Bridge.documentsDirectory()
        let fileNames = iPSX2Bridge.availableISOs()
        let fm = FileManager.default
        games = fileNames.map { name in
            var path = (isoDir as NSString).appendingPathComponent(name)
            if !fm.fileExists(atPath: path) {
                path = (docsDir as NSString).appendingPathComponent(name)
            }
            let attrs = try? fm.attributesOfItem(atPath: path)
            let size = attrs?[.size] as? UInt64 ?? 0
            return ISOEntry(name: name, size: size, isFavorite: iPSX2Bridge.isFavorite(name))
        }
    }

    private func toggleFavorite(_ name: String) {
        iPSX2Bridge.setFavorite(name, favorite: !iPSX2Bridge.isFavorite(name))
        loadGames()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls { FileImportHandler.shared.handleURL(url) }
            loadGames()
        case .failure(let error):
            FileImportHandler.shared.lastImportMessage = "Import failed: \(error.localizedDescription)"
            FileImportHandler.shared.showImportAlert = true
        }
    }
}
