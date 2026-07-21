// MenuControllerInput.swift — physical-controller navigation for the app menus.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: community request — drive the SwiftUI menus (Dashboard, library,
// settings, pause menu) with a physical game controller, not just in-game input.
// iOS SwiftUI doesn't auto-steer focus from a game controller the way tvOS does,
// so we poll the controller ourselves and publish discrete navigation commands
// that individual screens consume to move their own focus/selection.
//
// Input is read via non-destructive GCController snapshots (the same approach the
// in-game path uses): setting a valueChangedHandler would conflict with SDL, but
// reading `.isPressed`/`.value` does not. A main run-loop Timer polls while a
// menu is active and a controller is connected; edge detection turns held inputs
// into a first press plus a delayed auto-repeat. (Block-based Timer/notification
// observers keep this a plain Swift class — no NSObject/@objc needed, matching
// GyroAimStore's motion loop.)
//
// Focus ownership across nested menus/sheets is handled with a scope stack: each
// navigable screen pushes a scope id while it's on-screen and only the topmost
// scope acts on a command (so a sheet over the Dashboard consumes input and the
// Dashboard underneath stays put).

import Foundation
import SwiftUI
#if canImport(GameController)
import GameController
#endif

/// A discrete menu navigation command decoded from the controller.
enum MenuCommand: Hashable {
    case up, down, left, right
    case select    // A / cross
    case back      // B / circle
    case altAction // Y / triangle — secondary action (e.g. add game)
    case menu      // Menu / Options — open context actions
    case pageLeft, pageRight   // L1 / R1 — tab / section stepping
}

@Observable
final class MenuControllerInput: @unchecked Sendable {
    static let shared = MenuControllerInput()

    /// The most recent command. Consumers observe `commandToken` (which changes on
    /// every command, even repeats of the same one) and then read `lastCommand`.
    private(set) var lastCommand: MenuCommand?
    private(set) var commandToken: UInt64 = 0

    /// True while at least one external controller is connected — screens can use
    /// this to show/hide on-screen button hints.
    private(set) var controllerConnected = false

    // MARK: Scope stack (focus ownership)

    private var scopeStack: [String] = []
    /// The id of the topmost registered scope, or nil when none is active. Only the
    /// top scope should act on commands.
    var activeScope: String? { scopeStack.last }

    func pushScope(_ id: String) {
        // A re-push (same id appearing again) moves it back to the top.
        scopeStack.removeAll { $0 == id }
        scopeStack.append(id)
    }

    func popScope(_ id: String) {
        if let idx = scopeStack.lastIndex(of: id) {
            scopeStack.remove(at: idx)
        }
    }

    // MARK: Activation

    /// Whether a menu is currently on screen (set false while a game is playing).
    @ObservationIgnored private var menuActive = false
    @ObservationIgnored private var pollTimer: Timer?

    private init() {
#if canImport(GameController)
        controllerConnected = !GCController.controllers().isEmpty
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in self?.controllersChanged() }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in self?.controllersChanged() }
#endif
    }

    /// Called by the app root when the menu UI appears/disappears. Polling only
    /// runs while a menu is active AND a controller is connected.
    func setMenuActive(_ active: Bool) {
        menuActive = active
        updatePolling()
    }

    private func controllersChanged() {
#if canImport(GameController)
        controllerConnected = !GCController.controllers().isEmpty
        updatePolling()
#endif
    }

    private func updatePolling() {
#if canImport(GameController)
        let shouldRun = menuActive && controllerConnected
        if shouldRun && pollTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            // .common so polling continues during scroll/gesture run-loop modes.
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
            resetEdgeState()
        } else if !shouldRun, let timer = pollTimer {
            timer.invalidate()
            pollTimer = nil
        }
#endif
    }

    // MARK: Edge detection + auto-repeat

    private struct Repeater {
        var held = false
        var nextFire: CFTimeInterval = 0
    }
    @ObservationIgnored private var directionState: [MenuCommand: Repeater] = [:]
    @ObservationIgnored private var buttonHeld: [MenuCommand: Bool] = [:]

    private let initialDelay: CFTimeInterval = 0.42
    private let repeatInterval: CFTimeInterval = 0.12
    private let axisThreshold: Float = 0.55

    private func resetEdgeState() {
        directionState.removeAll()
        buttonHeld.removeAll()
    }

#if canImport(GameController)
    private func tick() {
        guard let gamepad = GCController.controllers().lazy.compactMap({ $0.extendedGamepad }).first else {
            return
        }
        let now = CACurrentMediaTime()

        // Directions: dpad OR left thumbstick, whichever is active. These auto-repeat.
        let up = gamepad.dpad.up.isPressed || gamepad.leftThumbstick.yAxis.value > axisThreshold
        let down = gamepad.dpad.down.isPressed || gamepad.leftThumbstick.yAxis.value < -axisThreshold
        let left = gamepad.dpad.left.isPressed || gamepad.leftThumbstick.xAxis.value < -axisThreshold
        let right = gamepad.dpad.right.isPressed || gamepad.leftThumbstick.xAxis.value > axisThreshold

        updateDirection(.up, active: up, now: now)
        updateDirection(.down, active: down, now: now)
        updateDirection(.left, active: left, now: now)
        updateDirection(.right, active: right, now: now)

        // Buttons: fire once per press (no auto-repeat).
        updateButton(.select, active: gamepad.buttonA.isPressed)
        updateButton(.back, active: gamepad.buttonB.isPressed)
        updateButton(.altAction, active: gamepad.buttonY.isPressed)
        updateButton(.menu, active: gamepad.buttonMenu.isPressed
                     || (gamepad.buttonOptions?.isPressed ?? false))
        updateButton(.pageLeft, active: gamepad.leftShoulder.isPressed)
        updateButton(.pageRight, active: gamepad.rightShoulder.isPressed)
    }
#endif

    private func updateDirection(_ command: MenuCommand, active: Bool, now: CFTimeInterval) {
        var state = directionState[command] ?? Repeater()
        if active {
            if !state.held {
                state.held = true
                state.nextFire = now + initialDelay
                emit(command)
            } else if now >= state.nextFire {
                state.nextFire = now + repeatInterval
                emit(command)
            }
        } else {
            state.held = false
        }
        directionState[command] = state
    }

    private func updateButton(_ command: MenuCommand, active: Bool) {
        let wasHeld = buttonHeld[command] ?? false
        if active && !wasHeld {
            emit(command)
        }
        buttonHeld[command] = active
    }

    private func emit(_ command: MenuCommand) {
        lastCommand = command
        commandToken &+= 1
    }
}
