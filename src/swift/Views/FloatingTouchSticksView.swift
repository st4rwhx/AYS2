// FloatingTouchSticksView.swift — screen-half touch analog sticks.
// SPDX-License-Identifier: GPL-3.0+
//
// AYS2: community request (and the user's own sketch) — instead of fixed
// on-screen sticks, the left half of the game area acts as the left analog
// stick and the right half as the right stick. A stick materializes under the
// thumb where you first touch and follows the drag; lifting recenters it.
//
// Implemented as a UIKit multitouch view (not a SwiftUI DragGesture) because two
// independent thumbs must be tracked at once — SwiftUI gestures don't deliver
// simultaneous multitouch cleanly. Touches feed EmulatorBridge.setLeftStick /
// setRightStick (the same choke point the on-screen sticks and gyro aim use),
// with x-right / y-down positive to match that convention. Glowing ring + knob
// are drawn with CALayers so there's clear visual feedback.

import SwiftUI
import UIKit

/// Public entry point (a plain SwiftUI View) so the private UIKit types below are
/// never exposed to the generated Objective-C header — an internal UIView
/// subclass emitted there breaks the C++ bridge (which has no UIKit import).
struct FloatingTouchSticksView: View {
    var enabled: Bool
    var body: some View {
        TouchSticksRepresentable(enabled: enabled)
    }
}

private struct TouchSticksRepresentable: UIViewRepresentable {
    var enabled: Bool

    func makeUIView(context: Context) -> TouchSticksUIView {
        let view = TouchSticksUIView()
        view.isUserInteractionEnabled = enabled
        return view
    }

    func updateUIView(_ uiView: TouchSticksUIView, context: Context) {
        uiView.isUserInteractionEnabled = enabled
        if !enabled { uiView.releaseAll() }
    }
}

private final class TouchSticksUIView: UIView {
    private let maxRadius: CGFloat = 62
    private let deadzone: Float = 0.06

    private var leftTouch: UITouch?
    private var rightTouch: UITouch?
    private var leftOrigin: CGPoint = .zero
    private var rightOrigin: CGPoint = .zero

    private lazy var leftRing = Self.makeRingLayer()
    private lazy var leftKnob = Self.makeKnobLayer()
    private lazy var rightRing = Self.makeRingLayer()
    private lazy var rightKnob = Self.makeKnobLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        for l in [leftRing, leftKnob, rightRing, rightKnob] {
            l.isHidden = true
            layer.addSublayer(l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layers

    private static func makeRingLayer() -> CAShapeLayer {
        let l = CAShapeLayer()
        l.fillColor = UIColor.white.withAlphaComponent(0.06).cgColor
        l.strokeColor = UIColor.white.withAlphaComponent(0.38).cgColor
        l.lineWidth = 2
        l.shadowColor = UIColor.white.cgColor
        l.shadowOpacity = 0.25
        l.shadowRadius = 6
        l.shadowOffset = .zero
        return l
    }

    private static func makeKnobLayer() -> CAShapeLayer {
        let l = CAShapeLayer()
        l.fillColor = UIColor.white.withAlphaComponent(0.55).cgColor
        l.shadowColor = UIColor.white.cgColor
        l.shadowOpacity = 0.4
        l.shadowRadius = 5
        l.shadowOffset = .zero
        return l
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    private func showStick(ring: CAShapeLayer, knob: CAShapeLayer, at origin: CGPoint) {
        withoutAnimation {
            ring.frame = CGRect(x: origin.x - maxRadius, y: origin.y - maxRadius,
                                width: maxRadius * 2, height: maxRadius * 2)
            ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: 1, dy: 1)).cgPath
            ring.isHidden = false
            let knobSize: CGFloat = 46
            knob.frame = CGRect(x: origin.x - knobSize / 2, y: origin.y - knobSize / 2,
                                width: knobSize, height: knobSize)
            knob.path = UIBezierPath(ovalIn: knob.bounds).cgPath
            knob.isHidden = false
        }
    }

    private func moveKnob(_ knob: CAShapeLayer, to point: CGPoint) {
        withoutAnimation { knob.position = point }
    }

    private func hideStick(ring: CAShapeLayer, knob: CAShapeLayer) {
        withoutAnimation {
            ring.isHidden = true
            knob.isHidden = true
        }
    }

    // MARK: Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if p.x < bounds.midX {
                if leftTouch == nil {
                    leftTouch = touch
                    leftOrigin = p
                    showStick(ring: leftRing, knob: leftKnob, at: p)
                }
            } else if rightTouch == nil {
                rightTouch = touch
                rightOrigin = p
                showStick(ring: rightRing, knob: rightKnob, at: p)
            }
        }
        updateSticks()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateSticks()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === leftTouch {
                leftTouch = nil
                hideStick(ring: leftRing, knob: leftKnob)
                EmulatorBridge.shared.setLeftStick(x: 0, y: 0)
            } else if touch === rightTouch {
                rightTouch = nil
                hideStick(ring: rightRing, knob: rightKnob)
                EmulatorBridge.shared.setRightStick(x: 0, y: 0)
            }
        }
    }

    private func updateSticks() {
        if let t = leftTouch { apply(touch: t, origin: leftOrigin, knob: leftKnob, isLeft: true) }
        if let t = rightTouch { apply(touch: t, origin: rightOrigin, knob: rightKnob, isLeft: false) }
    }

    private func apply(touch: UITouch, origin: CGPoint, knob: CAShapeLayer, isLeft: Bool) {
        let p = touch.location(in: self)
        let dx = p.x - origin.x
        let dy = p.y - origin.y
        let dist = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let clamped = min(dist, maxRadius)
        moveKnob(knob, to: CGPoint(x: origin.x + cos(angle) * clamped,
                                   y: origin.y + sin(angle) * clamped))
        var nx = Float(cos(angle) * clamped / maxRadius)   // right positive
        var ny = Float(sin(angle) * clamped / maxRadius)   // down positive (matches on-screen stick)
        if abs(nx) < deadzone { nx = 0 }
        if abs(ny) < deadzone { ny = 0 }
        if isLeft {
            EmulatorBridge.shared.setLeftStick(x: nx, y: ny)
        } else {
            EmulatorBridge.shared.setRightStick(x: nx, y: ny)
        }
    }

    /// Releases both sticks and hides the rings (e.g. when the mode is turned off
    /// or gameplay is paused).
    func releaseAll() {
        if leftTouch != nil {
            leftTouch = nil
            hideStick(ring: leftRing, knob: leftKnob)
            EmulatorBridge.shared.setLeftStick(x: 0, y: 0)
        }
        if rightTouch != nil {
            rightTouch = nil
            hideStick(ring: rightRing, knob: rightKnob)
            EmulatorBridge.shared.setRightStick(x: 0, y: 0)
        }
    }
}
