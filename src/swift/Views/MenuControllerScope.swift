// MenuControllerScope.swift — attach controller navigation to a screen.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: a view calls `.menuControllerScope("id") { command in ... }` to receive
// decoded controller navigation commands while it is the topmost menu on screen.
// The scope registers itself on the MenuControllerInput scope stack when it
// appears (and becomes inactive), so a sheet presented over the Dashboard takes
// over input and the Dashboard underneath ignores commands until the sheet closes.

import SwiftUI

private struct MenuControllerScopeModifier: ViewModifier {
    let id: String
    let isActive: Bool
    let onCommand: (MenuCommand) -> Void

    @State private var input = MenuControllerInput.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isActive { input.pushScope(id) }
            }
            .onDisappear {
                input.popScope(id)
            }
            .onChange(of: isActive) { _, active in
                if active { input.pushScope(id) } else { input.popScope(id) }
            }
            .onChange(of: input.commandToken) { _, _ in
                // Only the topmost scope acts, so nested sheets don't double-handle.
                guard input.activeScope == id, let command = input.lastCommand else { return }
                onCommand(command)
            }
    }
}

extension View {
    /// Receive controller navigation commands while this view is the topmost menu
    /// scope. `isActive` can gate handling off (e.g. while an alert is presented)
    /// without removing the view.
    func menuControllerScope(
        _ id: String,
        isActive: Bool = true,
        onCommand: @escaping (MenuCommand) -> Void
    ) -> some View {
        modifier(MenuControllerScopeModifier(id: id, isActive: isActive, onCommand: onCommand))
    }
}
