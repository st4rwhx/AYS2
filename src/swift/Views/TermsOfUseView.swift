// TermsOfUseView.swift — first-launch Terms of Use gate + Settings viewer.
// SPDX-License-Identifier: GPL-3.0+
//
// Accepting the Terms on first launch is the consent for anonymous diagnostics
// (section 3). There is no separate opt-out — using the app requires accepting.

import SwiftUI

struct TermsOfUseView: View {
    enum Mode { case gate, view }
    let mode: Mode
    var onAccept: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if mode == .gate {
                        Text("Terms of Use & Privacy")
                            .font(.largeTitle.bold())
                            .padding(.bottom, 4)
                    }
                    section("1. No warranty",
                            "AYS2 is provided \u{201C}as is\u{201D}, without warranty of any kind. You use it at your own risk.")
                    section("2. Your content",
                            "You must legally own any game or BIOS image you use. This app contains no copyrighted games or BIOS and does not help you obtain them. You alone are responsible for the legality of the files you load.")
                    section("3. Anonymous diagnostics",
                            "To find and fix bugs, when the app crashes or hits an error it sends an ANONYMOUS diagnostic report: device model, iOS version, app build, and a technical log excerpt. No account, no name, no personal data and no gameplay content is collected. By accepting these Terms you consent to this diagnostic reporting.")
                    section("4. Trademarks",
                            "\u{201C}PlayStation 2\u{201D} and \u{201C}PS2\u{201D} are trademarks of Sony Interactive Entertainment. This project is not affiliated with or endorsed by Sony.")
                    section("5. License",
                            "This software includes components licensed under the GNU General Public License v3. The corresponding source code is available on request.")
                }
                .padding()
            }

            if mode == .gate {
                VStack(spacing: 10) {
                    Text("By tapping Accept you agree to these Terms, including anonymous diagnostics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        onAccept?()
                    } label: {
                        Text("Accept & Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(mode == .view ? "Terms of Use" : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
