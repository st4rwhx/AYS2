// CoreAccessView.swift — AYS2 CORE ACCESS storefront + post-game upsell (additive).
// SPDX-License-Identifier: GPL-3.0+
//
// The supporter screen. Always dismissible (the X lives top-right, never
// hidden), honest copy, and the emulator itself never gates on membership.

import SwiftUI

// MARK: - Full storefront

struct CoreAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var settings = SettingsStore.shared
    @State private var store = CoreAccessStore.shared
    @State private var selectedPlanID = "yearly"
    @State private var activationEmail = ""
    @State private var activationMessage: String?

    /// true when presented as a sheet (shows the top-right X); false when
    /// pushed from the Settings hub (the nav bar handles going back).
    var showsClose = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RetroBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if store.isActive { memberCard } else {
                        perksCard
                        plansCard
                        activateCard
                    }
                    footer
                }
                .padding(16)
                .padding(.top, showsClose ? 30 : 4)
            }
            if showsClose {
                Button {
                    SoundManager.shared.play(.back)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Retro.mut)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Retro.panel))
                        .overlay(Circle().strokeBorder(Retro.line, lineWidth: 1))
                }
                .padding(.top, 10)
                .padding(.trailing, 14)
                .accessibilityLabel(settings.localized("Close"))
            }
        }
        .task { await store.refresh() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42))
                .foregroundStyle(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                                startPoint: .top, endPoint: .bottom))
            Text("AYS2 CORE ACCESS")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Retro.ink)
            Text(settings.localized("Support the only PS2 emulator built for iOS players — and unlock the perks."))
                .font(.subheadline)
                .foregroundStyle(Retro.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var perksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            perkRow("bolt.fill",            "Beta builds first",
                    "New features weeks before everyone else")
            perkRow("icloud.fill",          "Cloud sync",
                    "Your saves & memory cards everywhere — coming soon")
            perkRow("person.2.fill",        "Discord VIP",
                    "Supporter role, private channel, vote on the roadmap")
            perkRow("rosette",              "Your name in the credits",
                    "Forever part of AYS2's story")
            perkRow("paintpalette.fill",    "Exclusive icons & themes",
                    "Supporter-only looks, delivered over the air")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.line, lineWidth: 1))
    }

    private func perkRow(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Retro.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.localized(title))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Retro.ink)
                Text(settings.localized(sub))
                    .font(.caption).foregroundStyle(Retro.mut)
            }
            Spacer(minLength: 0)
        }
    }

    private var plansCard: some View {
        VStack(spacing: 10) {
            ForEach(CoreAccessStore.plans) { plan in
                planRow(plan)
            }
            Button {
                SoundManager.shared.play(.select)
                if let plan = CoreAccessStore.plans.first(where: { $0.id == selectedPlanID }) {
                    openURL(CoreAccessStore.checkoutURL(plan: plan))
                }
            } label: {
                Text(settings.localized("Continue"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .padding(.top, 4)
            Text(settings.localized("Cancel anytime. Payment secured by Stripe."))
                .font(.caption2).foregroundStyle(Retro.faint)
        }
    }

    private func planRow(_ plan: CoreAccessStore.Plan) -> some View {
        let selected = plan.id == selectedPlanID
        return Button {
            SoundManager.shared.play(.select)
            selectedPlanID = plan.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(settings.localized(plan.title))
                            .font(.subheadline.weight(.bold)).foregroundStyle(Retro.ink)
                        if let badge = plan.badge {
                            Text(settings.localized(badge))
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Retro.accent))
                        }
                    }
                    Text(settings.localized(plan.detail))
                        .font(.caption2).foregroundStyle(Retro.mut)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.price).font(.headline).foregroundStyle(Retro.ink)
                    Text(settings.localized(plan.cadence)).font(.caption2).foregroundStyle(Retro.faint)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Retro.accent : Retro.line2)
                    .font(.system(size: 20))
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 12).fill(Retro.panel))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Retro.accent : Retro.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var activateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.localized("Already a member?"))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Retro.ink)
            Text(settings.localized("Enter the e-mail you used at checkout to activate on this device."))
                .font(.caption).foregroundStyle(Retro.mut)
            HStack(spacing: 8) {
                TextField(settings.localized("E-mail"), text: $activationEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Retro.panel2))
                Button {
                    SoundManager.shared.play(.select)
                    let email = activationEmail
                    Task {
                        let ok = await CoreAccessStore.shared.activate(email: email)
                        activationMessage = ok
                            ? settings.localized("Membership activated. Thank you! 👑")
                            : (CoreAccessStore.shared.lastError ?? settings.localized("Activation failed."))
                    }
                } label: {
                    if store.isChecking { ProgressView().frame(width: 60) }
                    else {
                        Text(settings.localized("Activate"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Retro.accent)
                    }
                }
            }
            if let msg = activationMessage {
                Text(msg).font(.caption).foregroundStyle(store.isActive ? Retro.accent : Retro.mut)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.line, lineWidth: 1))
    }

    private var memberCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40)).foregroundStyle(Retro.accent)
            Text(settings.localized("You're a CORE ACCESS member"))
                .font(.headline).foregroundStyle(Retro.ink)
            if let tier = store.entitlement?.tier {
                Text(tier.capitalized).font(.subheadline).foregroundStyle(Retro.mut)
            }
            Text(settings.localized("Thank you for keeping AYS2 alive. Your perks are active."))
                .font(.caption).foregroundStyle(Retro.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Retro.accent, lineWidth: 1.5))
    }

    private var footer: some View {
        Text(settings.localized("AYS2 stays free and open-source (GPL-3.0). CORE ACCESS funds development and covers services the license doesn't: servers, cloud sync, betas."))
            .font(.caption2)
            .foregroundStyle(Retro.faint)
            .multilineTextAlignment(.center)
            .padding(.bottom, 20)
    }
}

// MARK: - Post-game upsell (compact, polite, always dismissible)

struct CoreAccessUpsellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsStore.shared
    @State private var showStore = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RetroBackground().ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                                    startPoint: .top, endPoint: .bottom))
                    .padding(.top, 26)
                Text(settings.localized("Enjoying AYS2?"))
                    .font(.title3.weight(.heavy)).foregroundStyle(Retro.ink)
                Text(settings.localized("Join CORE ACCESS and get beta builds first, cloud sync for your saves, a Discord VIP role and your name in the credits."))
                    .font(.subheadline)
                    .foregroundStyle(Retro.mut)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                Button {
                    SoundManager.shared.play(.select)
                    showStore = true
                } label: {
                    Text(settings.localized("Discover CORE ACCESS"))
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [Retro.accent, Retro.accentDeep],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                }
                .padding(.horizontal, 22)
                Text(settings.localized("From 3,99 €/month · cancel anytime"))
                    .font(.caption2).foregroundStyle(Retro.faint)
                Button {
                    CoreAccessStore.shared.upsellOptedOut = true
                    dismiss()
                } label: {
                    Text(settings.localized("Don't ask me again"))
                        .font(.caption).foregroundStyle(Retro.faint).underline()
                }
                .padding(.bottom, 18)
            }
            Button {
                SoundManager.shared.play(.back)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Retro.mut)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Retro.panel))
                    .overlay(Circle().strokeBorder(Retro.line, lineWidth: 1))
            }
            .padding(.top, 12)
            .padding(.trailing, 14)
            .accessibilityLabel(settings.localized("Close"))
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showStore, onDismiss: { dismiss() }) {
            CoreAccessView()
        }
    }
}
