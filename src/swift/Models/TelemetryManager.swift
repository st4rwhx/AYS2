// TelemetryManager.swift — anonymous, opt-out crash & error reporting.
// SPDX-License-Identifier: GPL-3.0+
//
// On each launch the app preserves the previous session's log (pcsx2_log.prev.txt,
// written by ios_main.mm before the new log truncates it). The emulator's signal
// handler already writes crashes (SIGSEGV/BUS/ILL/ABRT + backtrace) and fatal
// errors (JIT/VM alloc failures) into that log with @@ markers. This manager
// scans it, and if it finds a crash or known fatal error, uploads an anonymous
// report to the ingest endpoint (a Cloudflare Worker that files a GitHub issue).
// No account, no personal data — a random install UUID, device model, iOS
// version, build id, and a capped log tail. Opt-out via Settings; default on.

import Foundation
import UIKit

final class TelemetryManager: @unchecked Sendable {
    static let shared = TelemetryManager()

    // Ingest endpoint (Cloudflare Worker). Empty until the Worker is deployed —
    // while empty the uploader is a safe no-op. Set this to the deployed URL.
    static let endpointString = ""

    private let enabledKey = "telemetryEnabled"
    private let noticeShownKey = "telemetryNoticeShown"
    private let installIDKey = "telemetryInstallID"

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    // MARK: - Consent

    /// Diagnostics on/off. Defaults to ON (first-run notice lets users opt out).
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var noticeShown: Bool {
        get { UserDefaults.standard.bool(forKey: noticeShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: noticeShownKey) }
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

    /// Scans the previous session's log for a crash / fatal error and uploads a
    /// report if one is found. Call once per launch from the main actor; the
    /// heavy work runs off the main thread and consumes the log so nothing is
    /// reported twice. Device/OS are captured here (UIDevice is main-isolated).
    func processPreviousSession() {
        guard isEnabled else { return }
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

    /// Builds a report only when the log shows a crash or a known fatal error;
    /// returns nil for clean sessions so we don't spam the tracker.
    static func buildReport(from log: String, installID: String, device: String, os: String) -> [String: Any]? {
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
        guard let hit = signatures.first(where: { log.contains($0.marker) }) else { return nil }

        let lines = log.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        func firstLine(containing needle: String) -> String {
            lines.first(where: { $0.contains(needle) })?
                .trimmingCharacters(in: .whitespaces) ?? ""
        }

        // Last ~250 lines, hard-capped so payloads stay small.
        let tail = lines.suffix(250).joined(separator: "\n")
        let cappedTail = String(tail.suffix(24_000))

        return [
            "installID": installID,
            "kind": hit.kind,
            "signature": hit.marker,
            "build": firstLine(containing: "@@BUILD_ID@@"),
            "device": device,
            "os": os,
            "jitMode": firstLine(containing: "@@JIT_MODE@@"),
            "jitAlloc": firstLine(containing: "@@JIT_ALLOC@@ FATAL"),
            "log": cappedTail,
        ]
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
