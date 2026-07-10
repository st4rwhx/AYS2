// RootView.swift — Root view switching between menu and game
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct RootView: View {
    @State private var appState = AppState.shared
    @State private var fileImporter = FileImportHandler.shared
    @State private var showDiagnosticsNotice = false

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .menu:
                PS2WaveBackground()
                    .ignoresSafeArea()
                MenuTabView()
            case .playing:
                GameScreenView()
            }

            // Isolated anchor for the diagnostics work + first-run notice, kept
            // on its own view so its alert doesn't collide with the import alert.
            Color.clear
                .task {
                    // Only surface the notice once telemetry is actually wired.
                    if TelemetryManager.shared.isConfigured && !TelemetryManager.shared.noticeShown {
                        showDiagnosticsNotice = true
                    }
                    // Report any crash / fatal error from the previous session.
                    TelemetryManager.shared.processPreviousSession()
                }
                .alert("Help improve ELORIS-PRISM", isPresented: $showDiagnosticsNotice) {
                    Button("Turn Off") {
                        TelemetryManager.shared.isEnabled = false
                        TelemetryManager.shared.noticeShown = true
                    }
                    Button("OK") {
                        TelemetryManager.shared.noticeShown = true
                    }
                } message: {
                    Text("When something crashes, the app sends an anonymous diagnostic report (device model, iOS version, and a technical log — no account or personal data) so bugs can be fixed. You can turn this off any time in Settings.")
                }
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
