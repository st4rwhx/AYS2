// DashboardView.swift — console-style home: horizontal top nav + tiled sections.
// SPDX-License-Identifier: GPL-3.0+
//
// Faithful native-SwiftUI rebuild of the modern console-dashboard layout: a
// light field, a horizontal top nav (logo · bumpers · tabs · avatar), a
// swipeable row of full covers, a tiled Settings grid and clean white detail
// cards. PlayStation blue accent (this is a PS2 emulator). No third-party code.

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
                TopNav(section: $section)
                Rectangle().fill(Retro.line).frame(height: 1)
                content
            }
        }
        .preferredColorScheme(.light)   // NXE dashboard is always light
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

// MARK: - Top navigation bar (logo · bumpers · tabs · avatar)

struct TopNav: View {
    @Binding var section: DashSection

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

            BumperPill(text: "LB")

            // Section tabs with the active green→blue underline.
            ScrollView(.horizontal, showsIndicators: false) {
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
                                Rectangle()
                                    .fill(section == s ? Retro.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            BumperPill(text: "RB")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
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

    private var withCoverText: String {
        "Indexed \(games.count) game\(games.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if games.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(sortedGames) { game in
                            coverItem(game)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                }
            }
            Spacer(minLength: 0)
            HintBar(hints: [
                .init(button: .triangle, label: "add game"),
                .init(button: .cross, label: "select"),
                .init(button: .circle, label: "back"),
            ])
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
            RetroLabel(text: withCoverText)
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
        .padding(.top, 12)
    }

    private func coverItem(_ game: ISOEntry) -> some View {
        let isRunning = game.name == appState.runningGameName
        return Button {
            selectGame(game.name)
        } label: {
            VStack(spacing: 8) {
                CleanCover(gameName: game.name, width: 168)
                    // Options button, top-right.
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Retro.ink)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.92)))
                            .padding(7)
                    }
                    // Favorite star, if any.
                    .overlay(alignment: .topLeading) {
                        if game.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.yellow)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.92)))
                                .padding(7)
                        }
                    }
                    // Running badge, bottom-left.
                    .overlay(alignment: .bottomLeading) {
                        if isRunning {
                            Text("RUNNING")
                                .font(.system(size: 9, weight: .heavy)).tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color(red: 0.30, green: 0.68, blue: 0.31)))
                                .padding(7)
                        }
                    }
                // Small title BELOW the cover, on the light field — no dark scrim.
                Text(displayName(game.name))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Retro.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 168)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 168)
        .contextMenu {
            Button {
                toggleFavorite(game.name)
            } label: {
                Label(game.isFavorite ? "Remove Favorite" : "Add Favorite",
                      systemImage: game.isFavorite ? "star.slash" : "star")
            }
        }
    }

    /// Drops the disc-image extension for a cleaner title under the cover.
    private func displayName(_ name: String) -> String {
        let lower = name.lowercased()
        for ext in [".iso", ".bin", ".chd", ".img", ".elf", ".cso", ".gz"] where lower.hasSuffix(ext) {
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
            Text("No games yet")
                .font(.title2.weight(.bold)).foregroundStyle(Retro.ink)
            Text("Import a PS2 disc image — ISO, BIN, CHD or IMG.")
                .font(.subheadline).foregroundStyle(Retro.mut)
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
                    SettingsTile(title: "System", subtitle: "Sounds · About · Version",
                                 systemImage: "gearshape") { SystemSettingsView() }
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
                // Big translucent icon, bottom-right.
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
                Text("Diagnostics are anonymous and part of the Terms of Use — device model, iOS version and technical logs on crashes/errors, to fix bugs. No account or personal data.")
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(iPSX2Bridge.buildVersion())
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("System")
        .navigationBarTitleDisplayMode(.inline)
    }
}
