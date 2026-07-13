// RootView.swift — Root view switching between menu and game
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct RootView: View {
    @State private var appState = AppState.shared
    @State private var fileImporter = FileImportHandler.shared
    @State private var termsAccepted = TelemetryManager.shared.termsAccepted
    @State private var showCommunity = false

    var body: some View {
        if termsAccepted {
            mainContent
        } else {
            // Consent gate: the app can't be used until the Terms (including the
            // anonymous diagnostics consent) are accepted.
            ZStack {
                RetroBackground()
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
                DashboardView()
                    .overlay(alignment: .bottomTrailing) {
                        CommunityBar()
                            .padding(.trailing, 16)
                            .padding(.bottom, 22)
                    }
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
        .sheet(isPresented: $showCommunity) {
            CommunityWelcomeView()
        }
        .task {
            // Invite to the Discord / GitHub once per app launch, after the
            // Terms gate has been cleared.
            if !AppState.shared.didShowCommunityPrompt {
                AppState.shared.didShowCommunityPrompt = true
                showCommunity = true
            }
        }
    }
}

