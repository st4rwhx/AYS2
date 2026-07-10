// RootView.swift — Root view switching between menu and game
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct RootView: View {
    @State private var appState = AppState.shared
    @State private var fileImporter = FileImportHandler.shared
    @State private var termsAccepted = TelemetryManager.shared.termsAccepted

    var body: some View {
        if termsAccepted {
            mainContent
        } else {
            // Consent gate: the app can't be used until the Terms (including the
            // anonymous diagnostics consent) are accepted.
            ZStack {
                PS2WaveBackground().ignoresSafeArea()
                TermsOfUseView(mode: .gate) {
                    TelemetryManager.shared.termsAccepted = true
                    termsAccepted = true
                }
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            switch appState.currentScreen {
            case .menu:
                PS2WaveBackground()
                    .ignoresSafeArea()
                MenuTabView()
            case .playing:
                GameScreenView()
            }

            // Report any crash / error from the previous session (once per launch).
            Color.clear
                .task { TelemetryManager.shared.processPreviousSession() }
        }
        .onOpenURL { url in
            fileImporter.handleURL(url)
        }
        .alert("File Import", isPresented: $fileImporter.showImportAlert) {
            Button("OK") {}
        } message: {
            Text(fileImporter.lastImportMessage ?? "")
        }
    }
}

struct MenuTabView: View {
    @State private var appState = AppState.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GameListView()
                .tabItem {
                    Label("Games", systemImage: "gamecontroller")
                }
                .tag(0)

            BIOSListView()
                .tabItem {
                    Label("BIOS", systemImage: "cpu")
                }
                .tag(1)

            HelpView()
                .tabItem {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .tag(2)

            NavigationStack {
                SettingsRootView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, _ in
            SoundManager.shared.play(.nav)
        }
    }
}
