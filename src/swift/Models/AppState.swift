// AppState.swift — App screen state management
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UIKit

@Observable
final class AppState: @unchecked Sendable {
    static let shared = AppState()
    static let systemChromeNeedsUpdateNotification = Notification.Name("ARMSX2iOSSystemChromeNeedsUpdate")

    enum Screen {
        case menu
        case playing
    }

    var currentScreen: Screen = .menu
    var selectedTab: Int = 0
    var runningGameName: String? = nil
    var hideStatusBar: Bool = false {
        didSet {
            if oldValue != hideStatusBar {
                NotificationCenter.default.post(name: Self.systemChromeNeedsUpdateNotification, object: nil)
            }
        }
    }
    var hideHomeIndicator: Bool = false {
        didSet {
            if oldValue != hideHomeIndicator {
                NotificationCenter.default.post(name: Self.systemChromeNeedsUpdateNotification, object: nil)
            }
        }
    }

    // AYS2: external-launch tracking (seam) — user suggestion. True when the
    // current game was booted from an external front-end via deep link
    // (armsx2://launch). Lets "Quit to Launcher on game exit" close the app so
    // the front-end regains focus instead of dropping into the library.
    @ObservationIgnored var launchedExternally = false

    @ObservationIgnored private var pendingBootAction: (() -> Void)?
    @ObservationIgnored private var shutdownObserver: NSObjectProtocol?

    @ObservationIgnored private var autoBootObserver: NSObjectProtocol?

    // AYS2: play-time tracking (seam) — see PlayTimeStore. A session is the
    // wall-clock span a real game's VM is running. Flushed on VM shutdown and
    // on app-backgrounding so time survives an app kill; BIOS-only boots are
    // not tracked.
    @ObservationIgnored private var playSessionGame: String?
    @ObservationIgnored private var playSessionStart: Date?
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?

    // AYS2: interval auto-save (seam) — a rolling background save-state to a
    // dedicated slot so a crash / dead battery doesn't lose progress. The tick
    // runs every minute while a real game is running and re-reads the interval,
    // so changing it in Settings takes effect without rebooting the game.
    // Slot 10 (the last manual slot) is reserved as the auto-slot; the Save
    // States panel labels it so it's distinguishable from manual saves.
    static let autoSaveSlot: Int = 10
    @ObservationIgnored private var autoSaveTimer: Timer?
    @ObservationIgnored private var minutesSinceAutoSave = 0

    private init() {
        shutdownObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ARMSX2iOSVMDidShutdown"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.endPlaySession()
            self?.runningGameName = nil
            if let action = self?.pendingBootAction {
                self?.pendingBootAction = nil
                action()
            } else {
                // No pending reboot — return to menu (VM crash / normal shutdown)
                self?.currentScreen = .menu
            }
        }

        // Flush accumulated play time when the app backgrounds, but keep the
        // session open (start reset to now) so foregrounding keeps counting.
        // Guards against losing time if iOS kills the app while backgrounded.
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.flushPlaySession(keepOpen: true)
        }

        // [P48] Auto-boot: ObjC side posts this notification to switch UI to game screen
        autoBootObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ARMSX2iOSAutoBootDidStart"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.runningGameName = "AutoBoot"
            self?.currentScreen = .playing
        }
    }

    func bootGame(isoName: String, external: Bool = false) {
        launchedExternally = external
        Task { @MainActor in
            StikDebugLauncher.autoOpenIfNeeded(reason: "game boot")
        }
        ARMSX2Bridge.bootISO(isoName)
        ARMSX2Bridge.prepareGameRenderViewForCurrentRenderer()
        runningGameName = isoName
        beginPlaySession(for: isoName)
        startAutoSaveTimer()
        currentScreen = .playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            ARMSX2Bridge.requestVMBoot()
        }
    }

    // MARK: - Interval auto-save

    private func startAutoSaveTimer() {
        stopAutoSaveTimer()
        minutesSinceAutoSave = 0
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.autoSaveTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoSaveTimer = timer
    }

    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func autoSaveTick() {
        let interval = SettingsStore.shared.autoSaveIntervalMinutes
        guard interval > 0 else { return }
        // Only real games — never BIOS-only or the auto-boot placeholder.
        guard let game = runningGameName, game != "BIOS", game != "AutoBoot" else { return }
        guard ARMSX2Bridge.isVMRunning() else { return }

        minutesSinceAutoSave += 1
        guard minutesSinceAutoSave >= interval else { return }
        minutesSinceAutoSave = 0
        ARMSX2Bridge.saveState(toSlot: Self.autoSaveSlot, completion: nil)
    }

    func bootBIOSOnly() {
        Task { @MainActor in
            StikDebugLauncher.autoOpenIfNeeded(reason: "BIOS boot")
        }
        ARMSX2Bridge.setINIString("GameISO", key: "BootISO", value: "")
        ARMSX2Bridge.prepareGameRenderViewForCurrentRenderer()
        runningGameName = "BIOS"
        currentScreen = .playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            ARMSX2Bridge.requestVMBoot()
        }
    }

    func returnToMenu() {
        if ARMSX2Bridge.isVMRunning() {
            ARMSX2Bridge.setVMPaused(true)
        }
        currentScreen = .menu
        // [P44-2] Restore opaque background on hosting controller
        NotificationCenter.default.post(name: NSNotification.Name("ARMSX2iOSReturnToMenu"), object: nil)
    }

    func returnToGame() {
        if runningGameName != nil {
            // [P44-2] Clear background so Metal surface shows through
            NotificationCenter.default.post(name: NSNotification.Name("ARMSX2iOSEnterGameScreen"), object: nil)
            currentScreen = .playing
            ARMSX2Bridge.setVMPaused(false)
        }
    }

    func shutdownAndBoot(isoName: String) {
        // Preserve external-launch state across reset/disc-swap reboots.
        let external = launchedExternally
        pendingBootAction = { [weak self] in
            self?.bootGame(isoName: isoName, external: external)
        }
        ARMSX2Bridge.requestVMShutdown()
    }

    /// Cleanly shut the VM down and quit the app so an external front-end
    /// (Cocoon, Daijishō, etc.) regains focus, instead of returning to the
    /// library. Only called when the game was launched externally and the
    /// user opted in (see SettingsStore.quitToLauncherOnExit).
    func quitToLauncher() {
        endPlaySession()
        if ARMSX2Bridge.isVMRunning() {
            ARMSX2Bridge.requestVMShutdown()
        }
        // Give the shutdown a brief moment to flush (memory cards etc.) before
        // terminating. exit(0) is intentional here — it's exactly the
        // "close the app" behaviour front-end launcher users ask for.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            exit(0)
        }
    }

    func shutdownAndBootBIOS() {
        pendingBootAction = { [weak self] in
            self?.bootBIOSOnly()
        }
        ARMSX2Bridge.requestVMShutdown()
    }

    func resetCurrentVM() {
        guard let runningGameName else { return }

        if runningGameName == "BIOS" {
            shutdownAndBootBIOS()
        } else {
            shutdownAndBoot(isoName: runningGameName)
        }
    }

    // MARK: - Play-time tracking (see PlayTimeStore)

    private func beginPlaySession(for isoName: String) {
        // Flush any session still open (e.g. reset/reboot that reused bootGame
        // without a full shutdown in between) before starting the new one.
        flushPlaySession(keepOpen: false)
        playSessionGame = isoName
        playSessionStart = Date()
    }

    /// Adds the elapsed span to the store. When keepOpen is true the session
    /// continues with its start reset to now (backgrounding); when false the
    /// session is closed (shutdown / new boot).
    private func flushPlaySession(keepOpen: Bool) {
        guard let game = playSessionGame, let start = playSessionStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0 {
            PlayTimeStore.shared.addSeconds(elapsed, forGame: game)
        }
        if keepOpen {
            playSessionStart = Date()
        } else {
            playSessionGame = nil
            playSessionStart = nil
        }
    }

    private func endPlaySession() {
        flushPlaySession(keepOpen: false)
        stopAutoSaveTimer()
    }
}
