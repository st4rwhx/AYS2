// WebView.swift — a minimal WKWebView wrapper for SwiftUI.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: used by the in-game Guide viewer to show a walkthrough/guide web page
// without leaving the app. Kept deliberately small — it loads a URL and exposes
// loading state via a binding. All WebKit work stays on the main actor (WKWebView
// is main-actor only), so there are no cross-isolation hazards.

import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

#if canImport(WebKit)
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload when the requested URL actually changed, so SwiftUI re-renders
        // (e.g. loading-state toggles) don't stomp on the user's in-page navigation.
        if webView.url != url && context.coordinator.lastRequestedURL != url {
            context.coordinator.lastRequestedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var lastRequestedURL: URL?

        init(isLoading: Binding<Bool>) { _isLoading = isLoading }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
#endif
