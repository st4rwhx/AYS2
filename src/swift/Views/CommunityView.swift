// CommunityView.swift — Discord + GitHub community prompts.
// SPDX-License-Identifier: GPL-3.0+
//
// A warm welcome sheet shown once per launch inviting the player to the Discord
// and to star the fork, plus a small pair of floating buttons kept on every tab.

import SwiftUI

enum CommunityLinks {
    static let discord = URL(string: "https://discord.gg/AXAzExECSv")!
    static let github = URL(string: "https://github.com/balajsimon/ELORIS-PRISM")!

    /// Discord "blurple".
    static let blurple = Color(red: 0.345, green: 0.396, blue: 0.949)
    /// ELORIS-PRISM accent (matches the controller skin / prism).
    static let prism = Color(red: 0.29, green: 0.56, blue: 1.0)
}

// MARK: - Startup welcome sheet

struct CommunityWelcomeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.08),
                         Color(red: 0.09, green: 0.06, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 4)

                Image(systemName: "hexagon.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [CommunityLinks.prism, CommunityLinks.blurple, .cyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: CommunityLinks.prism.opacity(0.6), radius: 16)

                VStack(spacing: 6) {
                    Text("Welcome to ELORIS-PRISM")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("A passion-built PS2 experience for iOS.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .multilineTextAlignment(.center)

                card(
                    icon: "bubble.left.and.bubble.right.fill",
                    accent: CommunityLinks.blurple,
                    title: "Join our Discord",
                    message: "Need help, want to share your save states, or request a game? The community is where it all happens — come say hi.",
                    cta: "Join the server",
                    url: CommunityLinks.discord
                )

                card(
                    icon: "star.fill",
                    accent: .yellow,
                    title: "Star the fork on GitHub",
                    message: "Enjoying it? Give the repo a star so you never lose this fork again — and it genuinely helps the project grow and stay alive.",
                    cta: "Star on GitHub",
                    url: CommunityLinks.github
                )

                Spacer(minLength: 4)

                Button { dismiss() } label: {
                    Text("Continue to ELORIS-PRISM")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CommunityLinks.prism, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button("Maybe later") { dismiss() }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func card(icon: String, accent: Color, title: String,
                      message: String, cta: String, url: URL) -> some View {
        Button { openURL(url) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(accent.gradient, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.white)
                    Text(message).font(.caption).foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cta).font(.caption.bold()).foregroundStyle(accent).padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Persistent floating buttons (present on every tab)

struct CommunityBar: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            iconButton(icon: "bubble.left.and.bubble.right.fill",
                       accent: CommunityLinks.blurple, url: CommunityLinks.discord)
            iconButton(icon: "star.fill",
                       accent: .yellow, url: CommunityLinks.github)
        }
    }

    private func iconButton(icon: String, accent: Color, url: URL) -> some View {
        Button {
            SoundManager.shared.play(.nav)
            openURL(url)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.92), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }
}
