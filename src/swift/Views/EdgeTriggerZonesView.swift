// EdgeTriggerZonesView.swift — landscape edge "grip trigger" touch zones.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: user request — a mobile-native way to hold the shoulder triggers in
// landscape. Pressing the LEFT screen edge holds L (L1 / L2 / both) and the
// RIGHT edge holds R, with a haptic buzz on press and release — like squeezing
// the grip triggers of a phone gamepad. Your index fingers rest on the edges
// instead of hunting for small on-screen buttons.
//
// Implemented as a UIKit view so it can (a) track several fingers at once and
// (b) claim ONLY its two edge strips via hitTest, letting every other touch
// fall through to the floating sticks / pad beneath it. As with the floating
// sticks, the UIKit types are private and only a plain SwiftUI wrapper is
// exposed, so nothing UIKit leaks into the generated Objective-C bridge header.

import SwiftUI
import UIKit

struct EdgeTriggerZonesView: View {
    var enabled: Bool
    /// 0 = L1/R1, 1 = L2/R2, 2 = both (L1+L2 / R1+R2)
    var mode: Int = 0
    var haptics: Bool = true

    var body: some View {
        EdgeTriggerRepresentable(enabled: enabled, mode: mode, haptics: haptics)
            .allowsHitTesting(enabled)
    }
}

private struct EdgeTriggerRepresentable: UIViewRepresentable {
    var enabled: Bool
    var mode: Int
    var haptics: Bool

    func makeUIView(context: Context) -> EdgeTriggerUIView {
        let view = EdgeTriggerUIView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: EdgeTriggerUIView, context: Context) {
        apply(to: uiView)
        if !enabled { uiView.releaseAll() }
    }

    private func apply(to view: EdgeTriggerUIView) {
        view.isUserInteractionEnabled = enabled
        view.hapticsEnabled = haptics
        view.setMode(mode)
    }
}

private final class EdgeTriggerUIView: UIView {
    // Buttons each side holds, driven by the mode.
    private var leftButtons: [ARMSX2PadButton] = [.L1]
    private var rightButtons: [ARMSX2PadButton] = [.R1]
    var hapticsEnabled = true

    private var leftTouches = Set<UITouch>()
    private var rightTouches = Set<UITouch>()

    private lazy var leftBar = Self.makeBar()
    private lazy var rightBar = Self.makeBar()
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    // Zone metrics: narrow vertical strips down the left/right edges, limited to
    // the upper part of the screen so the bottom stays free for the sticks.
    private var zoneWidth: CGFloat { min(max(bounds.width * 0.065, 46), 96) }
    private var zoneHeight: CGFloat { bounds.height * 0.58 }
    private var leftZone: CGRect { CGRect(x: 0, y: 0, width: zoneWidth, height: zoneHeight) }
    private var rightZone: CGRect { CGRect(x: bounds.width - zoneWidth, y: 0, width: zoneWidth, height: zoneHeight) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        layer.addSublayer(leftBar)
        layer.addSublayer(rightBar)
        haptic.prepare()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func makeBar() -> CAShapeLayer {
        let l = CAShapeLayer()
        let neon = UIColor(red: 0.46, green: 0.63, blue: 1.0, alpha: 1.0)
        l.fillColor = neon.withAlphaComponent(0.16).cgColor
        l.shadowColor = neon.cgColor
        l.shadowOpacity = 0.0
        l.shadowRadius = 10
        l.shadowOffset = .zero
        return l
    }

    func setMode(_ mode: Int) {
        switch mode {
        case 1: leftButtons = [.L2]; rightButtons = [.R2]
        case 2: leftButtons = [.L1, .L2]; rightButtons = [.R1, .R2]
        default: leftButtons = [.L1]; rightButtons = [.R1]
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutBars()
    }

    private func layoutBars() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let barW: CGFloat = 5
        let inset: CGFloat = 6
        let top = zoneHeight * 0.18
        let h = zoneHeight * 0.64
        leftBar.frame = CGRect(x: inset, y: top, width: barW, height: h)
        leftBar.path = UIBezierPath(roundedRect: leftBar.bounds, cornerRadius: barW / 2).cgPath
        rightBar.frame = CGRect(x: bounds.width - inset - barW, y: top, width: barW, height: h)
        rightBar.path = UIBezierPath(roundedRect: rightBar.bounds, cornerRadius: barW / 2).cgPath
        CATransaction.commit()
    }

    // Only claim touches inside the two edge strips; everything else passes
    // through to the views beneath (floating sticks, pad, game).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        if leftZone.contains(point) || rightZone.contains(point) { return self }
        return nil
    }

    private func setBar(_ bar: CAShapeLayer, active: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        bar.shadowOpacity = active ? 0.9 : 0.0
        bar.fillColor = UIColor(red: 0.46, green: 0.63, blue: 1.0,
                                alpha: active ? 0.85 : 0.16).cgColor
        CATransaction.commit()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if leftZone.contains(p) {
                let wasEmpty = leftTouches.isEmpty
                leftTouches.insert(touch)
                if wasEmpty { holdLeft(true) }
            } else if rightZone.contains(p) {
                let wasEmpty = rightTouches.isEmpty
                rightTouches.insert(touch)
                if wasEmpty { holdRight(true) }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if leftTouches.remove(touch) != nil, leftTouches.isEmpty { holdLeft(false) }
            if rightTouches.remove(touch) != nil, rightTouches.isEmpty { holdRight(false) }
        }
    }

    private func holdLeft(_ pressed: Bool) {
        for b in leftButtons { EmulatorBridge.shared.setPadButton(b, pressed: pressed) }
        setBar(leftBar, active: pressed)
        if hapticsEnabled { haptic.impactOccurred(intensity: pressed ? 0.9 : 0.4) }
    }

    private func holdRight(_ pressed: Bool) {
        for b in rightButtons { EmulatorBridge.shared.setPadButton(b, pressed: pressed) }
        setBar(rightBar, active: pressed)
        if hapticsEnabled { haptic.impactOccurred(intensity: pressed ? 0.9 : 0.4) }
    }

    /// Release both triggers (mode turned off or gameplay paused).
    func releaseAll() {
        if !leftTouches.isEmpty { leftTouches.removeAll(); holdLeft(false) }
        if !rightTouches.isEmpty { rightTouches.removeAll(); holdRight(false) }
    }
}
