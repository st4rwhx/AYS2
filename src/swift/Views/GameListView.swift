// GameListView.swift — ROM browser as a PS2-style floating-disc grid
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UniformTypeIdentifiers

struct ISOEntry: Identifiable {
    let id = UUID()
    let name: String
    let size: UInt64
    var isFavorite: Bool
}

struct GameListView: View {
    @State private var games: [ISOEntry] = []
    @State private var appState = AppState.shared
    @State private var showRestartAlert = false
    @State private var showStopAlert = false
    @State private var pendingGameName: String = ""
    @State private var showImporter = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var sortedGames: [ISOEntry] {
        games.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if games.isEmpty && appState.runningGameName == nil {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if let gameName = appState.runningGameName {
                                runningCard(gameName: gameName)
                            }
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(sortedGames) { game in
                                    discTile(game)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Games")
            .aeroScreen(.landscape)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { loadGames() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if iPSX2Bridge.hasBIOS() {
                        Button("BIOS Only") {
                            if appState.runningGameName == "BIOS" {
                                appState.returnToGame()
                            } else if appState.runningGameName != nil {
                                pendingGameName = ""
                                showRestartAlert = true
                            } else {
                                appState.bootBIOSOnly()
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            .alert("Restart VM?", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Restart", role: .destructive) {
                    if pendingGameName.isEmpty {
                        appState.shutdownAndBootBIOS()
                    } else {
                        appState.shutdownAndBoot(isoName: pendingGameName)
                    }
                }
            } message: {
                let target = pendingGameName.isEmpty ? "BIOS Only" : pendingGameName
                Text("VM is currently running.\nShut down and start \(target)?")
            }
            .alert("Stop Emulation?", isPresented: $showStopAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Stop", role: .destructive) {
                    iPSX2Bridge.requestVMStop()
                    appState.runningGameName = nil
                }
            } message: {
                Text("This will shut down the running game. All unsaved progress will be lost.")
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .onAppear { loadGames() }
    }

    // MARK: - Running card (resume / stop)

    private func runningCard(gameName: String) -> some View {
        VStack(spacing: 0) {
            Button {
                appState.returnToGame()
            } label: {
                HStack(spacing: 12) {
                    SerialCoverImage(serial: iPSX2Bridge.currentGameSerial(), contentMode: .fill) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                    .frame(width: 42, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Now Running")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                        Text(gameName == "BIOS" ? "BIOS Only" : gameName)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Resume")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(14)
            }
            Divider().overlay(Color.white.opacity(0.1))
            Button(role: .destructive) {
                showStopAlert = true
            } label: {
                Label("Stop Emulation", systemImage: "stop.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.green.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Disc tile

    private func discTile(_ game: ISOEntry) -> some View {
        let isRunning = game.name == appState.runningGameName
        return Button {
            selectGame(game.name)
        } label: {
            VStack(spacing: 12) {
                BoxArt(gameName: game.name, height: 132)
                    .padding(.top, 4)
                Text(game.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Aero.ink.opacity(0.4), radius: 3, y: 1)
                Text(formatSize(game.size))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .shadow(color: Aero.ink.opacity(0.3), radius: 2, y: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .aeroGlass(corner: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isRunning ? Aero.leaf.opacity(0.75) : .clear, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if game.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.yellow)
                        .padding(12)
                }
            }
            .overlay(alignment: .topLeading) {
                if isRunning {
                    Circle()
                        .fill(.green)
                        .frame(width: 11, height: 11)
                        .shadow(color: .green, radius: 5)
                        .padding(13)
                }
            }
            .shadow(color: isRunning ? Color.green.opacity(0.25) : Color.blue.opacity(0.15),
                    radius: 12, y: 6)
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

    // MARK: - Empty state

    private var emptyState: some View {
        AeroEmptyState(
            title: "No games yet",
            message: "Import a PS2 disc image — ISO, BIN, CHD or IMG — to start your library.",
            buttonTitle: "Import a game",
            systemImage: "square.and.arrow.down",
            hint: "Or drop files into On My iPhone › ELORIS-PRISM › iso",
            action: { showImporter = true }
        )
    }

    // MARK: - Data

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
            let fav = iPSX2Bridge.isFavorite(name)
            return ISOEntry(name: name, size: size, isFavorite: fav)
        }
    }

    private func toggleFavorite(_ name: String) {
        let current = iPSX2Bridge.isFavorite(name)
        iPSX2Bridge.setFavorite(name, favorite: !current)
        loadGames()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                FileImportHandler.shared.handleURL(url)
            }
            loadGames()
        case .failure(let error):
            FileImportHandler.shared.lastImportMessage = "Import failed: \(error.localizedDescription)"
            FileImportHandler.shared.showImportAlert = true
        }
    }

    private func formatSize(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

/// A glossy PS2-style optical disc drawn entirely in SwiftUI.
struct DiscArt: View {
    private let sheen = Gradient(colors: [
        Color(red: 0.49, green: 0.75, blue: 1.00),
        Color(red: 0.04, green: 0.11, blue: 0.27),
        Color(red: 0.29, green: 0.56, blue: 1.00),
        Color(red: 0.04, green: 0.11, blue: 0.27),
        Color(red: 0.49, green: 0.75, blue: 1.00),
        Color(red: 0.04, green: 0.11, blue: 0.27),
        Color(red: 0.29, green: 0.56, blue: 1.00),
        Color(red: 0.49, green: 0.75, blue: 1.00)
    ])

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: sheen, center: .center))
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                // hub hole
                Circle()
                    .fill(Color(red: 0.03, green: 0.06, blue: 0.16))
                    .frame(width: d * 0.30, height: d * 0.30)
                    .overlay(
                        Circle().stroke(Color(red: 0.45, green: 0.65, blue: 1.0).opacity(0.35),
                                        lineWidth: d * 0.035)
                    )
            }
            .frame(width: d, height: d)
            .shadow(color: Color.blue.opacity(0.35), radius: 10, y: 6)
        }
    }
}
