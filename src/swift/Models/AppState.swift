// AppState.swift — App screen state management
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

@Observable
final class AppState: @unchecked Sendable {
    static let shared = AppState()

    enum Screen {
        case menu
        case playing
    }

    var currentScreen: Screen = .menu
    var selectedTab: Int = 0
    var runningGameName: String? = nil
    var hideStatusBar: Bool = false

    @ObservationIgnored private var pendingBootAction: (() -> Void)?
    @ObservationIgnored private var shutdownObserver: NSObjectProtocol?

    @ObservationIgnored private var autoBootObserver: NSObjectProtocol?

    private init() {
        // Create the user-facing folders up front so the app's Documents
        // directory shows in Files → On My iPhone → iPSX2 with clear "iso" and
        // "bios" drop targets (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace
        // are set in Info.plist). Also makes the folder appear even before any import.
        Self.ensureUserDirectories()

        shutdownObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("iPSX2VMDidShutdown"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.runningGameName = nil
            if let action = self?.pendingBootAction {
                self?.pendingBootAction = nil
                action()
            } else {
                // No pending reboot — return to menu (VM crash / normal shutdown)
                self?.currentScreen = .menu
            }
        }

        // [P48] Auto-boot: ObjC side posts this notification to switch UI to game screen
        autoBootObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("iPSX2AutoBootDidStart"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.runningGameName = "AutoBoot"
            self?.currentScreen = .playing
        }
    }

    /// Creates Documents/iso and Documents/bios if missing, plus a short
    /// README so an empty folder still shows something useful in the Files app.
    static func ensureUserDirectories() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        for sub in ["iso", "bios"] {
            let dir = docs.appendingPathComponent(sub, isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let readme = docs.appendingPathComponent("README.txt")
        if !fm.fileExists(atPath: readme.path) {
            let text = """
            Cobalis — user files
            --------------------
            • Put PS2 disc images (.iso / .bin / .img / .chd) in the "iso" folder.
            • Put your PS2 BIOS dump (.bin) in the "bios" folder.
            You can also import them from inside the app (Games / BIOS tabs → import button).
            """
            try? text.data(using: .utf8)?.write(to: readme)
        }
    }

    func bootGame(isoName: String) {
        iPSX2Bridge.bootISO(isoName)
        iPSX2Bridge.requestVMBoot()
        runningGameName = isoName
        currentScreen = .playing
    }

    func bootBIOSOnly() {
        iPSX2Bridge.setINIString("GameISO", key: "BootISO", value: "")
        iPSX2Bridge.requestVMBoot()
        runningGameName = "BIOS"
        currentScreen = .playing
    }

    func returnToMenu() {
        currentScreen = .menu
        // [P44-2] Restore opaque background on hosting controller
        NotificationCenter.default.post(name: NSNotification.Name("iPSX2ReturnToMenu"), object: nil)
    }

    func returnToGame() {
        if runningGameName != nil {
            // [P44-2] Clear background so Metal surface shows through
            NotificationCenter.default.post(name: NSNotification.Name("iPSX2EnterGameScreen"), object: nil)
            currentScreen = .playing
        }
    }

    func shutdownAndBoot(isoName: String) {
        pendingBootAction = { [weak self] in
            self?.bootGame(isoName: isoName)
        }
        iPSX2Bridge.requestVMShutdown()
    }

    func shutdownAndBootBIOS() {
        pendingBootAction = { [weak self] in
            self?.bootBIOSOnly()
        }
        iPSX2Bridge.requestVMShutdown()
    }
}
