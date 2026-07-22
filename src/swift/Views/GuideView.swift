// GuideView.swift — in-game walkthrough/guide viewer.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: opened from the pause menu. Shows a walkthrough/guide web page for the
// running game inside the app (WKWebView), so the player doesn't have to leave
// AYS2 and lose their place. The URL is remembered per game via GuideStore; the
// player can edit it (an address field) and it defaults to a title web search.

import SwiftUI

struct GuideView: View {
    let settings: SettingsStore
    /// Storage key for the running game (its ISO name); may be nil if unknown.
    let gameKey: String?
    /// Human-readable title used to build the default search when nothing is saved.
    let displayTitle: String
    let onDismiss: () -> Void

    @State private var store = GuideStore.shared
    @State private var currentURL: URL
    @State private var addressText: String
    @State private var isLoading = false
    @State private var isEditingAddress = false

    init(settings: SettingsStore, gameKey: String?, displayTitle: String, onDismiss: @escaping () -> Void) {
        self.settings = settings
        self.gameKey = gameKey
        self.displayTitle = displayTitle
        self.onDismiss = onDismiss
        let resolved = GuideStore.shared.resolvedURL(for: gameKey, displayTitle: displayTitle)
        _currentURL = State(initialValue: resolved)
        _addressText = State(initialValue: GuideStore.shared.savedURLString(for: gameKey) ?? resolved.absoluteString)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressBar
#if canImport(WebKit)
                WebView(url: currentURL, isLoading: $isLoading)
                    .overlay(alignment: .top) {
                        if isLoading {
                            ProgressView()
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 6)
                        }
                    }
#else
                Spacer()
                Text(settings.localized("Web view isn't available on this platform."))
                    .foregroundStyle(.secondary)
                Spacer()
#endif
            }
            .navigationTitle(settings.localized("Guide"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.localized("Done"), action: onDismiss)
                }
            }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed")
                .foregroundStyle(.secondary)
            TextField(settings.localized("Guide URL"), text: $addressText, onEditingChanged: { editing in
                isEditingAddress = editing
            })
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.URL)
            .submitLabel(.go)
            .onSubmit(loadFromAddress)
            if isEditingAddress || !addressText.isEmpty {
                Button {
                    loadFromAddress()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func loadFromAddress() {
        guard let url = store.normalizedURL(from: addressText) else { return }
        store.setURLString(url.absoluteString, for: gameKey)
        currentURL = url
        addressText = url.absoluteString
    }
}
