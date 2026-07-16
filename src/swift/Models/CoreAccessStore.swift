// CoreAccessStore.swift — AYS2 CORE ACCESS supporter membership (additive, AYS2-only).
// SPDX-License-Identifier: GPL-3.0+
//
// Supporter model, deliberately GPL-clean: the emulator stays fully functional
// for everyone. CORE ACCESS sells things the GPL does not cover — server-side
// services and community perks (early beta builds, Discord role, credits,
// upcoming cloud sync). Entitlements live on OUR Cloudflare Worker
// (coreaccess/worker), keyed by the buyer's e-mail; the app only asks the
// worker "is this e-mail active?". Payments are Stripe Payment Links served by
// the worker, so no payment code (or secret) ever ships in the app.

import Foundation
import SwiftUI

@Observable
final class CoreAccessStore: @unchecked Sendable {
    static let shared = CoreAccessStore()

    /// Base URL of the CORE ACCESS worker (see coreaccess/worker/README.md).
    /// Keep in sync with the deployed worker route.
    static let apiBase = URL(string: "https://ays2-core-access.ayanokiyotakaxpsycoworld.workers.dev")!

    // MARK: - Plans (display copy; checkout happens on the worker/Stripe side)

    struct Plan: Identifiable {
        let id: String        // matches the `plan` metadata on the Stripe link
        let title: String
        let price: String
        let cadence: String
        let badge: String?    // "POPULAR" / "BEST VALUE" / "FOUNDER"
        let detail: String
        let link: String      // direct Stripe Payment Link (works without the worker)
    }

    // Stripe TEST-mode payment links. Swap the `test_` links for live ones (and
    // flip apiBase's worker to live) when going to production. The `id` here MUST
    // equal the `plan` metadata set on each Stripe link so the webhook maps it.
    static let plans: [Plan] = [
        Plan(id: "monthly",   title: "1 Month",   price: "3,99 €",  cadence: "/month",
             badge: nil,           detail: "Try CORE ACCESS",
             link: "https://buy.stripe.com/test_aFa4gB4Vo6tI7vjcs25gc00"),
        Plan(id: "quarterly", title: "3 Months",  price: "9,99 €",  cadence: "/3 months",
             badge: "POPULAR",     detail: "≈ 3,33 €/month",
             link: "https://buy.stripe.com/test_8x2eVfbjM19o9Dr8bM5gc01"),
        Plan(id: "yearly",    title: "12 Months", price: "29,99 €", cadence: "/year",
             badge: "BEST VALUE",  detail: "≈ 2,50 €/month · −37%",
             link: "https://buy.stripe.com/test_9B614pdrUcS6eXL1No5gc02"),
        Plan(id: "lifetime",  title: "Lifetime",  price: "79,99 €", cadence: "once",
             badge: "FOUNDER",     detail: "Forever. Founding member badge",
             link: "https://buy.stripe.com/test_8x200l1Jc19oeXL77I5gc03"),
    ]

    static func checkoutURL(plan: Plan) -> URL {
        // Open the Stripe link directly so buying works even before the worker
        // is deployed. (The worker still handles the webhook → entitlement side.)
        URL(string: plan.link) ?? apiBase
    }

    // MARK: - Entitlement state

    struct Entitlement: Codable {
        var active: Bool
        var tier: String?
        var expiresAt: Double?   // unix seconds; nil/huge for lifetime
    }

    private(set) var entitlement: Entitlement?
    private(set) var lastError: String?
    var isChecking = false

    var isActive: Bool {
        guard let e = entitlement, e.active else { return false }
        if let exp = e.expiresAt, exp > 0 { return Date(timeIntervalSince1970: exp) > Date() }
        return true
    }

    var linkedEmail: String {
        get { UserDefaults.standard.string(forKey: "AYS2CoreAccessEmail") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "AYS2CoreAccessEmail") }
    }

    private init() {
        if UserDefaults.standard.object(forKey: "AYS2FirstLaunchDate") == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "AYS2FirstLaunchDate")
        }
        if let data = UserDefaults.standard.data(forKey: "AYS2CoreAccessCache"),
           let cached = try? JSONDecoder().decode(Entitlement.self, from: data) {
            entitlement = cached
        }
        if !linkedEmail.isEmpty {
            Task { await refresh() }
        }
    }

    /// Link an e-mail (the one used at checkout) and verify it with the worker.
    @discardableResult
    func activate(email rawEmail: String) async -> Bool {
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@"), email.contains(".") else {
            await MainActor.run { lastError = "Invalid e-mail address." }
            return false
        }
        linkedEmail = email
        return await refresh()
    }

    /// Re-check the entitlement with the worker. Cached on success so the app
    /// keeps working offline until the next successful refresh.
    @discardableResult
    func refresh() async -> Bool {
        let email = linkedEmail
        guard !email.isEmpty else { return false }
        await MainActor.run { isChecking = true; lastError = nil }
        defer { Task { @MainActor in self.isChecking = false } }
        var url = Self.apiBase.appendingPathComponent("entitlement")
        url.append(queryItems: [URLQueryItem(name: "email", value: email)])
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 12
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                await MainActor.run { lastError = "Server unavailable. Try again later." }
                return false
            }
            let ent = try JSONDecoder().decode(Entitlement.self, from: data)
            await MainActor.run { self.entitlement = ent }
            UserDefaults.standard.set(try? JSONEncoder().encode(ent), forKey: "AYS2CoreAccessCache")
            if !ent.active {
                await MainActor.run { lastError = "No active membership for this e-mail." }
            }
            return ent.active
        } catch {
            await MainActor.run { lastError = "Network error. Try again later." }
            return false
        }
    }

    // MARK: - Post-game upsell cadence
    //
    // Deliberately polite: never during the first 3 days, at most once every
    // 4 days, never twice the same day, never for members, and a permanent
    // opt-out. An aggressive prompt here costs more installs than it converts.

    private var firstLaunch: Date {
        Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "AYS2FirstLaunchDate"))
    }
    private var lastUpsell: Date? {
        let t = UserDefaults.standard.double(forKey: "AYS2LastUpsellDate")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    var upsellOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: "AYS2UpsellOptOut") }
        set { UserDefaults.standard.set(newValue, forKey: "AYS2UpsellOptOut") }
    }

    var shouldShowPostGameUpsell: Bool {
        guard !isActive, !upsellOptedOut else { return false }
        guard Date().timeIntervalSince(firstLaunch) > 3 * 86_400 else { return false }
        if let last = lastUpsell, Date().timeIntervalSince(last) < 4 * 86_400 { return false }
        return true
    }

    func markUpsellShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "AYS2LastUpsellDate")
    }
}
