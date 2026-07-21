// QuickMenuView.swift — In-game pause menu card
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

/// Destinations the pause menu hands back to the host to present. (Also the associated payload of
/// the host's overlay route state machine.)
enum QuickMenuDestination: Equatable {
    case perGame, speed, saveStates, cheats, retroAchievements, padLayout, resetROM, guide
}

/// Native in-game pause menu: a premium opaque graphite "command deck" presented by the host as a
/// bounded card over a lighter, controlled dim of the paused gameplay. The host pauses the VM
/// while this card is shown. Toggles are bound directly; everything else is routed back to the
/// host through closures (unchanged from before) so the existing panels, child-screen routing and
/// confirmation flows stay exactly as in Phase A.
///
/// Layout adapts to the card's geometry (read via a GeometryReader, since the host frames this
/// view to the bounded card size): two columns when the card is comfortably wide, one column
/// otherwise. Resume is pinned inside the panel footer so it never detaches or hides rows.
struct QuickMenuView: View {
    let settings: SettingsStore
    @Binding var padVisible: Bool
    @Binding var fullScreen: Bool
    @Binding var menuButtonHidden: Bool

    let vmMenuAvailable: Bool
    let gameMenuAvailable: Bool
    let virtualPadHiddenByController: Bool
    let gameTitle: String?
    let controllerSkinMenu: AnyView
    let discMenu: AnyView
    let variant: PauseLayoutVariant
    let activePadLayoutName: String

    let onCycleOSD: () -> Void
    let onOpen: (QuickMenuDestination) -> Void
    let onClearCache: () -> Void
    let onBackToMenu: () -> Void
    let onResume: () -> Void

    /// Compact sizing for the header/footer on iPad (any orientation) and iPhone landscape; the
    /// larger, liked sizing is reserved for iPhone portrait.
    private var compact: Bool { variant != .phonePortrait }

    // MARK: - Controller focus (seam)
    // AYS2: physical-controller navigation of the pause card. A flat ordered list
    // of the focusable action/toggle rows (the two injected SwiftUI Menus — disc
    // and controller skin — can't be opened by a controller, so they're skipped).
    // D-pad moves focus, A activates the focused row, B resumes.
    @State private var focusedIndex = 0
    @State private var input = MenuControllerInput.shared

    private struct PauseFocusItem {
        let id: String
        let activate: () -> Void
    }

    private var focusItems: [PauseFocusItem] {
        var items: [PauseFocusItem] = [
            .init(id: "osd", activate: onCycleOSD),
            .init(id: "virtualPad", activate: { padVisible.toggle() }),
            .init(id: "fullScreen", activate: { fullScreen.toggle() }),
            .init(id: "hideMenu", activate: {
                let newValue = !(menuButtonHidden || settings.hideMenuButton)
                menuButtonHidden = newValue
                settings.hideMenuButton = newValue
            }),
        ]
        if vmMenuAvailable { items.append(.init(id: "speed", activate: { onOpen(.speed) })) }
        if gameMenuAvailable { items.append(.init(id: "perGame", activate: { onOpen(.perGame) })) }
        items.append(.init(id: "padLayout", activate: { onOpen(.padLayout) }))
        if gameMenuAvailable || vmMenuAvailable {
            items.append(.init(id: "saveStates", activate: { onOpen(.saveStates) }))
        }
        if gameMenuAvailable {
            items.append(.init(id: "retroAchievements", activate: { onOpen(.retroAchievements) }))
            items.append(.init(id: "cheats", activate: { onOpen(.cheats) }))
        }
        if gameMenuAvailable || vmMenuAvailable {
            items.append(.init(id: "guide", activate: { onOpen(.guide) }))
        }
        if vmMenuAvailable { items.append(.init(id: "resetROM", activate: { onOpen(.resetROM) })) }
        if gameMenuAvailable { items.append(.init(id: "clearCache", activate: onClearCache)) }
        items.append(.init(id: "backToMenu", activate: onBackToMenu))
        return items
    }

    /// The id of the row the controller is on — only when a controller is
    /// connected, so touch users never see a focus highlight.
    private var currentFocusID: String? {
        guard input.controllerConnected else { return nil }
        let items = focusItems
        guard focusedIndex >= 0, focusedIndex < items.count else { return nil }
        return items[focusedIndex].id
    }

    private func handlePauseCommand(_ command: MenuCommand) {
        let count = focusItems.count
        guard count > 0 else { return }
        switch command {
        case .up, .left:
            focusedIndex = (focusedIndex - 1 + count) % count
        case .down, .right:
            focusedIndex = (focusedIndex + 1) % count
        case .select:
            let items = focusItems
            if focusedIndex >= 0, focusedIndex < items.count { items[focusedIndex].activate() }
        case .back, .menu:
            onResume()
        case .altAction, .pageLeft, .pageRight:
            break
        }
    }

    var body: some View {
        // The host (GameOverlayContainer) frames this view to the bounded card size; read that
        // size here to decide whether the geometry comfortably supports two columns.
        GeometryReader { geo in
            overlayBody(width: geo.size.width, height: geo.size.height)
        }
        // AYS2: controller navigation of the pause card (seam).
        .menuControllerScope("pauseMenu") { command in
            handlePauseCommand(command)
        }
    }

    @ViewBuilder
    private func overlayBody(width: CGFloat, height: CGFloat) -> some View {
        if variant == .phoneLandscape {
            landscapeBody(width: width, height: height)
        } else {
            portraitBody(width: width, height: height)
        }
    }

    @ViewBuilder
    private func portraitBody(width: CGFloat, height: CGFloat) -> some View {
        OverlayPanelScaffold {
            VStack(spacing: 0) {
                OverlayHeader(
                    systemImage: "pause.circle.fill",
                    title: settings.localized("Paused"),
                    subtitle: gameTitle,
                    compact: compact
                )
                scrollContent(twoColumns: supportsTwoColumns(width: width, height: height))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func landscapeBody(width: CGFloat, height: CGFloat) -> some View {
        OverlayPanelScaffold {
            VStack(spacing: 0) {
                LandscapeCommandBar(
                    settings: settings,
                    gameTitle: gameTitle,
                    onResume: onResume,
                    iconOnly: width < 380
                )
                ScrollView {
                    cardsContent(twoColumns: width > 700)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .environment(\.overlayCompact, true)
    }

    /// Two columns only when the card is wide enough (and, for phone landscape, tall enough) to
    /// keep both columns comfortable. iPad portrait and short/small phone-landscape devices fall
    /// back to one column. iPhone portrait is always one column. One unified scroll surface either
    /// way — never independent per-column scrolls.
    private func supportsTwoColumns(width: CGFloat, height: CGFloat) -> Bool {
        switch variant {
        case .phonePortrait:
            return false
        case .ipadTwoColumn:
            return width >= 500 && height >= 320
        case .phoneLandscape:
            return width >= 570 && height >= 300
        }
    }

    @ViewBuilder
    private func cardsContent(twoColumns: Bool) -> some View {
        if twoColumns {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: variant == .phoneLandscape ? 11 : 14) {
                    OverlaySectionCard(title: settings.localized("Quick Actions")) { quickActionsRows }
                    OverlaySectionCard(title: settings.localized("This Game")) { thisGameRows }
                }
                VStack(spacing: variant == .phoneLandscape ? 11 : 14) {
                    OverlaySectionCard(title: settings.localized("Game Tools")) { gameToolsRows }
                    OverlaySectionCard(title: settings.localized("Reset & Exit")) { resetAndExitRows }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, variant == .phoneLandscape ? 8 : 10)
            .padding(.bottom, variant == .phoneLandscape ? 8 : 10)
        } else {
            VStack(spacing: 14) {
                OverlaySectionCard(title: settings.localized("Quick Actions")) { quickActionsRows }
                OverlaySectionCard(title: settings.localized("This Game")) { thisGameRows }
                OverlaySectionCard(title: settings.localized("Game Tools")) { gameToolsRows }
                OverlaySectionCard(title: settings.localized("Reset & Exit")) { resetAndExitRows }
            }
            .padding(.horizontal, 16)
            .padding(.top, variant == .phoneLandscape ? 8 : 10)
            .padding(.bottom, variant == .phoneLandscape ? 8 : 10)
        }
    }

    @ViewBuilder
    private func scrollContent(twoColumns: Bool) -> some View {
        ScrollView {
            cardsContent(twoColumns: twoColumns)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OverlayFooter(
                primaryLabel: settings.localized("Resume"),
                primarySystemImage: "play.fill",
                primaryAction: onResume,
                compact: compact
            )
        }
    }

    // MARK: - Section row content

    @ViewBuilder private var quickActionsRows: some View {
        OverlayActionRow(
            label: settings.localized("OSD"),
            systemImage: "speedometer",
            trailingValue: settings.localized(settings.osdPreset.label),
            isFocused: currentFocusID == "osd",
            action: onCycleOSD
        )
        .accessibilityHint(settings.localized("Cycles the on-screen display"))

        OverlayToggleRow(label: settings.localized("Virtual Pad"), systemImage: "gamecontroller", isFocused: currentFocusID == "virtualPad", isOn: $padVisible)
            .accessibilityHint(settings.localized("Show or hide the on-screen controls"))

        if virtualPadHiddenByController {
            Text(settings.localized("Hidden while controller is connected"))
                .font(.caption)
                .foregroundStyle(OverlayTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 34)
                .padding(.bottom, 4)
        }

        OverlayToggleRow(label: settings.localized("Full Screen"), systemImage: "arrow.up.left.and.arrow.down.right", isFocused: currentFocusID == "fullScreen", isOn: $fullScreen)
            .accessibilityHint(settings.localized("Hide system bars and fill the screen"))

        OverlayToggleRow(
            label: settings.localized("Hide Menu Button"),
            systemImage: "eye.slash",
            isFocused: currentFocusID == "hideMenu",
            isOn: Binding(
                get: { menuButtonHidden || settings.hideMenuButton },
                set: { newValue in
                    menuButtonHidden = newValue
                    settings.hideMenuButton = newValue
                }
            )
        )
        .accessibilityHint(settings.localized("Tap the game area or press any controller button to show it again"))

        if vmMenuAvailable {
            OverlayActionRow(label: settings.localized("Speed / Fast Forward"), systemImage: "forward.fill", isFocused: currentFocusID == "speed") {
                onOpen(.speed)
            }
        }
    }

    @ViewBuilder private var thisGameRows: some View {
        if gameMenuAvailable {
            OverlayActionRow(label: settings.localized("Per-Game Settings"), systemImage: "slider.horizontal.3", isFocused: currentFocusID == "perGame") {
                onOpen(.perGame)
            }
            .accessibilityHint(settings.localized("Graphics, audio, CPU, pad, and fixes for this title"))
        }
        injectedMenuRow(controllerSkinMenu)
        OverlayActionRow(
            label: settings.localized("Edit Virtual Pad Layout"),
            systemImage: "square.resize",
            trailingValue: activePadLayoutName,
            isFocused: currentFocusID == "padLayout"
        ) {
            onOpen(.padLayout)
        }
    }

    @ViewBuilder private var gameToolsRows: some View {
        if gameMenuAvailable || vmMenuAvailable {
            OverlayActionRow(label: settings.localized("Save / Load States"), systemImage: "square.stack.3d.up.fill", isFocused: currentFocusID == "saveStates") {
                onOpen(.saveStates)
            }
        }
        if vmMenuAvailable {
            injectedMenuRow(discMenu)
        }
        if gameMenuAvailable {
            OverlayActionRow(label: settings.localized("RetroAchievements"), systemImage: "trophy.fill", isFocused: currentFocusID == "retroAchievements") {
                onOpen(.retroAchievements)
            }
            OverlayActionRow(label: settings.localized("Cheats & Patches"), systemImage: "rectangle.stack.badge.plus", isFocused: currentFocusID == "cheats") {
                onOpen(.cheats)
            }
        }
        if gameMenuAvailable || vmMenuAvailable {
            OverlayActionRow(label: settings.localized("Walkthrough / Guide"), systemImage: "book.closed", isFocused: currentFocusID == "guide") {
                onOpen(.guide)
            }
            .accessibilityHint(settings.localized("Open a walkthrough for this game without leaving AYS2"))
        }
    }

    @ViewBuilder private var resetAndExitRows: some View {
        if vmMenuAvailable {
            OverlayActionRow(label: settings.localized("Reset ROM"), systemImage: "arrow.counterclockwise.circle", isDestructive: true, isFocused: currentFocusID == "resetROM") {
                onOpen(.resetROM)
            }
        }
        if gameMenuAvailable {
            OverlayActionRow(label: settings.localized("Clear Current Game Cache"), systemImage: "trash.slash", isFocused: currentFocusID == "clearCache", action: onClearCache)
        }
        OverlayActionRow(label: settings.localized("Back to Menu"), systemImage: "list.bullet", isFocused: currentFocusID == "backToMenu", action: onBackToMenu)
            .accessibilityHint(settings.localized("Quits this game and returns to the library"))
    }

    /// Hosts an injected SwiftUI `Menu` (controller skin / change disc) as a row that matches the
    /// graphite action rows as closely as an opaque AnyView allows. The menu's own action
    /// semantics are untouched.
    @ViewBuilder
    private func injectedMenuRow(_ menu: AnyView) -> some View {
        menu
            .foregroundStyle(OverlayTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: variant == .phoneLandscape ? 38 : 44, alignment: .leading)
    }
}

private struct LandscapeCommandBar: View {
    let settings: SettingsStore
    let gameTitle: String?
    let onResume: () -> Void
    let iconOnly: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(OverlayTheme.accent)
                Text(settings.localized("Paused"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OverlayTheme.textPrimary)
                    .layoutPriority(1)
                if let title = gameTitle, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(OverlayTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(-1)
                }
                Spacer(minLength: 8)
                Button(action: onResume) {
                    if iconOnly {
                        Image(systemName: "play.fill")
                    } else {
                        Label(settings.localized("Resume"), systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            OverlayTheme.separator
                .frame(height: 0.5)
        }
    }
}
