// TelemetryManager.swift — anonymous crash & error reporting (Terms-based consent).
// SPDX-License-Identifier: GPL-3.0+
//
// On each launch the app preserves the previous session's log (pcsx2_log.prev.txt,
// written by ios_main.mm before the new log truncates it). The emulator's signal
// handler already writes crashes (SIGSEGV/BUS/ILL/ABRT + backtrace) and fatal
// errors (JIT/VM alloc failures) into that log with @@ markers. This manager
// scans it, and if it finds a crash or emulator error, uploads an anonymous
// report to the ingest endpoint (a Cloudflare Worker that files a GitHub issue).
// No account, no personal data — a random install UUID, device model, iOS
// version, build id, and a capped log tail. Consent is granted by accepting the
// Terms of Use on first launch (see TermsOfUseView); there is no separate toggle.

import Foundation
import UIKit

final class TelemetryManager: @unchecked Sendable {
    static let shared = TelemetryManager()

    // Ingest endpoint (Cloudflare Worker). Empty until the Worker is deployed —
    // while empty the uploader is a safe no-op. Set this to the deployed URL.
    static let endpointString = ""

    private let termsAcceptedKey = "termsAccepted"
    private let installIDKey = "telemetryInstallID"

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    // MARK: - Consent

    /// Consent is granted by accepting the Terms of Use on first launch — that IS
    /// the consent, so there is no separate opt-out. Diagnostics are active for
    /// every session once the Terms are accepted.
    var termsAccepted: Bool {
        get { UserDefaults.standard.bool(forKey: termsAcceptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: termsAcceptedKey) }
    }

    private var installID: String {
        if let id = UserDefaults.standard.string(forKey: installIDKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: installIDKey)
        return id
    }

    private var endpoint: URL? {
        Self.endpointString.isEmpty ? nil : URL(string: Self.endpointString)
    }

    /// True once an ingest endpoint is configured. Used to avoid showing the
    /// privacy notice before telemetry can actually send anything.
    var isConfigured: Bool { endpoint != nil }

    // MARK: - Launch hook

    /// Scans the previous session's log for a crash / error and uploads a report
    /// if one is found. Runs on the main actor (UIDevice is main-isolated) and
    /// hands the heavy work to a background queue; consumes the log so nothing is
    /// reported twice.
    @MainActor
    func processPreviousSession() {
        guard termsAccepted else { return }
        let endpoint = self.endpoint
        let id = installID
        let device = Self.deviceModelIdentifier()
        let os = UIDevice.current.systemVersion
        DispatchQueue.global(qos: .utility).async { [session] in
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let prev = docs.appendingPathComponent("pcsx2_log.prev.txt")
            guard let raw = try? String(contentsOf: prev, encoding: .utf8) else { return }
            try? FileManager.default.removeItem(at: prev) // consume — report at most once

            guard let endpoint,
                  let report = Self.buildReport(from: raw, installID: id, device: device, os: os)
            else { return }
            Self.post(report, to: endpoint, session: session)
        }
    }

    // MARK: - Report building

    /// Builds a report when the previous session shows a crash or an emulator
    /// error — covering the whole emulator, not just JIT/VM. Returns nil for
    /// clean sessions so the tracker isn't spammed.
    ///
    /// Coverage: hard crashes (signal handler), known-fatal JIT/VM markers, and
    /// — crucially — anything surfaced to the user via `Host::ReportError`
    /// (unsupported game, disc read failure, renderer/shader failure, boot
    /// failure, etc.). ReportError is high-signal (it's a user-facing error
    /// dialog), so this stays broad without flagging benign warnings.
    static func buildReport(from log: String, installID: String, device: String, os: String) -> [String: Any]? {
        let lines = log.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        func firstLine(containing needle: String) -> String {
            lines.first(where: { $0.contains(needle) }).map(Self.cleanSignature) ?? ""
        }

        // Priority order: hardest failures first.
        let signatures: [(marker: String, kind: String)] = [
            ("Signal: SIGSEGV", "crash-sigsegv"),
            ("Signal: SIGBUS", "crash-sigbus"),
            ("Signal: SIGILL", "crash-sigill"),
            ("Signal: SIGABRT", "crash-sigabrt"),
            ("FATAL: TXM registration failed", "jit-txm-fail"),
            ("Failed to allocate code memory", "jit-codemem-fail"),
            ("Failed to allocate VM memory", "vm-alloc-fail"),
            ("CPUThreadInitialize failed", "vm-init-fail"),
        ]

        var kind: String?
        var signature = ""
        if let hit = signatures.first(where: { log.contains($0.marker) }) {
            kind = hit.kind
            signature = firstLine(containing: hit.marker)
        } else if let err = lines.first(where: { $0.contains("Host::ReportError") }) {
            // Any user-facing emulator error (disc/renderer/boot/unsupported/…).
            kind = "error"
            signature = Self.cleanSignature(err)
        }
        guard let kind else { return nil } // clean session — nothing to report

        let tail = lines.suffix(300).joined(separator: "\n")
        let cappedTail = String(tail.suffix(26_000))

        return [
            "installID": installID,
            "kind": kind,
            "signature": signature.isEmpty ? kind : signature,
            "build": firstLine(containing: "@@BUILD_ID@@"),
            "device": device,
            "os": os,
            "game": Self.extractGameSerial(from: log),
            "jitMode": firstLine(containing: "@@JIT_MODE@@"),
            "perf": firstLine(containing: "Speed:"), // OSD perf line, if logged
            "log": cappedTail,
        ]
    }

    /// Strips ANSI colour codes and a leading `[  2.09]` timestamp, and caps the
    /// length — so the same error yields a stable fingerprint server-side.
    private static func cleanSignature(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\u{1b}\\[[0-9;]*m", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "^\\[\\s*[0-9.]+\\]\\s*", with: "", options: .regularExpression)
        out = out.trimmingCharacters(in: .whitespaces)
        return String(out.prefix(180))
    }

    /// Best-effort PS2 disc serial (e.g. SLUS-20946) so a report names the game.
    private static func extractGameSerial(from log: String) -> String {
        guard let r = log.range(of: "S[A-Z]{3}[-_ ]?[0-9]{3}\\.?[0-9]{2}", options: .regularExpression)
        else { return "" }
        return String(log[r])
    }

    // MARK: - Upload

    private static func post(_ report: [String: Any], to endpoint: URL, session: URLSession) {
        guard let body = try? JSONSerialization.data(withJSONObject: report) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        session.dataTask(with: req).resume() // fire-and-forget
    }

    static func deviceModelIdentifier() -> String {
        var info = utsname()
        uname(&info)
        let bytes = Mirror(reflecting: info.machine).children.compactMap { child -> UInt8? in
            guard let c = child.value as? CChar, c != 0 else { return nil }
            return UInt8(bitPattern: c)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
