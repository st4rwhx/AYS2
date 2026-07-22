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
//
// Options (all user-configurable in Virtual Controller settings):
//   • per-half enable — keep only the left, only the right, or neither;
//   • swap — left half drives the RIGHT stick and vice-versa;
//   • size — scale the ring/knob radius;
//   • skin — a few visual styles for the ring + knob.

import SwiftUI
import UIKit

/// Visual style for the floating sticks. Raw values are persisted in the INI.
enum FloatingStickSkin: Int, CaseIterable, Identifiable {
    case glow = 0        // soft white ring + translucent knob (original)
    case aysNeon = 1     // blue neon to match the AYS2 Signature pad skin
    case minimal = 2     // thin, low-key hairline ring
    case bold = 3        // thick high-contrast ring for visibility

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .glow: return "Glow"
        case .aysNeon: return "AYS2 Neon"
        case .minimal: return "Minimal"
        case .bold: return "Bold"
        }
    }
}

/// Public entry point (a plain SwiftUI View) so the private UIKit types below are
/// never exposed to the generated Objective-C header — an internal UIView
/// subclass emitted there breaks the C++ bridge (which has no UIKit import).
struct FloatingTouchSticksView: View {
    var enabled: Bool
    var leftEnabled: Bool = true
    var rightEnabled: Bool = true
    var swapped: Bool = false
    var scale: CGFloat = 1.0
    var skin: FloatingStickSkin = .glow
    var deadzone: Float = 0.06
    var sensitivity: Float = 1.0
    var opacity: CGFloat = 1.0
    var edgeHaptic: Bool = false

    var body: some View {
        TouchSticksRepresentable(
            enabled: enabled,
            leftEnabled: leftEnabled,
            rightEnabled: rightEnabled,
            swapped: swapped,
            scale: scale,
            skin: skin,
            deadzone: deadzone,
            sensitivity: sensitivity,
            opacity: opacity,
            edgeHaptic: edgeHaptic
        )
    }
}

private struct TouchSticksRepresentable: UIViewRepresentable {
    var enabled: Bool
    var leftEnabled: Bool
    var rightEnabled: Bool
    var swapped: Bool
    var scale: CGFloat
    var skin: FloatingStickSkin
    var deadzone: Float
    var sensitivity: Float
    var opacity: CGFloat
    var edgeHaptic: Bool

    func makeUIView(context: Context) -> TouchSticksUIView {
        let view = TouchSticksUIView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: TouchSticksUIView, context: Context) {
        apply(to: uiView)
        if !enabled { uiView.releaseAll() }
    }

    private func apply(to view: TouchSticksUIView) {
        view.isUserInteractionEnabled = enabled
        view.leftEnabled = leftEnabled
        view.rightEnabled = rightEnabled
        view.swapped = swapped
        view.stickScale = scale
        view.deadzone = deadzone
        view.sensitivity = sensitivity
        view.edgeHaptic = edgeHaptic
        view.alpha = opacity
        view.applySkin(skin)
    }
}

private final class TouchSticksUIView: UIView {
    private let baseRadius: CGFloat = 62

    var leftEnabled = true
    var rightEnabled = true
    var swapped = false
    var deadzone: Float = 0.06
    var sensitivity: Float = 1.0
    var edgeHaptic = false
    var stickScale: CGFloat = 1.0 { didSet { if abs(oldValue - stickScale) > 0.001 { relayoutActive() } } }
    private var skin: FloatingStickSkin = .glow
    private var skinApplied = false
    private var leftAtEdge = false
    private var rightAtEdge = false
    private let edgeHaptics = UIImpactFeedbackGenerator(style: .rigid)

    private var maxRadius: CGFloat { baseRadius * stickScale }

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
        applySkin(.glow)
        edgeHaptics.prepare()
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

    /// Restyle the ring/knob layers to the chosen skin.
    func applySkin(_ newSkin: FloatingStickSkin) {
        guard newSkin != skin || !skinApplied else { return }
        skin = newSkin
        skinApplied = true
        let neon = UIColor(red: 0.46, green: 0.63, blue: 1.0, alpha: 1.0)
        for ring in [leftRing, rightRing] {
            switch newSkin {
            case .glow:
                ring.strokeColor = UIColor.white.withAlphaComponent(0.38).cgColor
                ring.fillColor = UIColor.white.withAlphaComponent(0.06).cgColor
                ring.lineWidth = 2
                ring.shadowColor = UIColor.white.cgColor
                ring.shadowOpacity = 0.25; ring.shadowRadius = 6
            case .aysNeon:
                ring.strokeColor = neon.withAlphaComponent(0.9).cgColor
                ring.fillColor = neon.withAlphaComponent(0.08).cgColor
                ring.lineWidth = 2.4
                ring.shadowColor = neon.cgColor
                ring.shadowOpacity = 0.7; ring.shadowRadius = 9
            case .minimal:
                ring.strokeColor = UIColor.white.withAlphaComponent(0.28).cgColor
                ring.fillColor = UIColor.clear.cgColor
                ring.lineWidth = 1.4
                ring.shadowOpacity = 0
            case .bold:
                ring.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
                ring.fillColor = UIColor.white.withAlphaComponent(0.10).cgColor
                ring.lineWidth = 4
                ring.shadowColor = UIColor.black.cgColor
                ring.shadowOpacity = 0.5; ring.shadowRadius = 4
            }
        }
        for knob in [leftKnob, rightKnob] {
            switch newSkin {
            case .glow:
                knob.fillColor = UIColor.white.withAlphaComponent(0.55).cgColor
                knob.shadowColor = UIColor.white.cgColor; knob.shadowOpacity = 0.4; knob.shadowRadius = 5
            case .aysNeon:
                knob.fillColor = neon.withAlphaComponent(0.5).cgColor
                knob.shadowColor = neon.cgColor; knob.shadowOpacity = 0.8; knob.shadowRadius = 8
            case .minimal:
                knob.fillColor = UIColor.white.withAlphaComponent(0.4).cgColor
                knob.shadowOpacity = 0
            case .bold:
                knob.fillColor = UIColor.white.withAlphaComponent(0.85).cgColor
                knob.shadowColor = UIColor.black.cgColor; knob.shadowOpacity = 0.5; knob.shadowRadius = 3
            }
        }
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
            let knobSize: CGFloat = 46 * stickScale
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

    /// Re-lay the currently held sticks after a size change so the ring keeps
    /// pace with the new scale without waiting for the next touch.
    private func relayoutActive() {
        if leftTouch != nil { showStick(ring: leftRing, knob: leftKnob, at: leftOrigin) }
        if rightTouch != nil { showStick(ring: rightRing, knob: rightKnob, at: rightOrigin) }
        updateSticks()
    }

    // MARK: Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if p.x < bounds.midX {
                if leftEnabled, leftTouch == nil {
                    leftTouch = touch
                    leftOrigin = p
                    showStick(ring: leftRing, knob: leftKnob, at: p)
                }
            } else if rightEnabled, rightTouch == nil {
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
                leftAtEdge = false
                hideStick(ring: leftRing, knob: leftKnob)
                setStick(forLeftHalf: true, x: 0, y: 0)
            } else if touch === rightTouch {
                rightTouch = nil
                rightAtEdge = false
                hideStick(ring: rightRing, knob: rightKnob)
                setStick(forLeftHalf: false, x: 0, y: 0)
            }
        }
    }

    private func updateSticks() {
        if let t = leftTouch { apply(touch: t, origin: leftOrigin, knob: leftKnob, isLeftHalf: true) }
        if let t = rightTouch { apply(touch: t, origin: rightOrigin, knob: rightKnob, isLeftHalf: false) }
    }

    private func apply(touch: UITouch, origin: CGPoint, knob: CAShapeLayer, isLeftHalf: Bool) {
        let p = touch.location(in: self)
        let dx = p.x - origin.x
        let dy = p.y - origin.y
        let dist = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let clamped = min(dist, maxRadius)
        moveKnob(knob, to: CGPoint(x: origin.x + cos(angle) * clamped,
                                   y: origin.y + sin(angle) * clamped))

        // Optional haptic tick the moment the thumb reaches the ring's edge.
        if edgeHaptic {
            let atEdge = dist >= maxRadius - 0.5
            let wasAtEdge = isLeftHalf ? leftAtEdge : rightAtEdge
            if atEdge && !wasAtEdge { edgeHaptics.impactOccurred(intensity: 0.6) }
            if isLeftHalf { leftAtEdge = atEdge } else { rightAtEdge = atEdge }
        }

        // Normalize, apply deadzone, then scale by sensitivity (clamped to unit).
        var nx = Float(cos(angle) * clamped / maxRadius)   // right positive
        var ny = Float(sin(angle) * clamped / maxRadius)   // down positive (matches on-screen stick)
        if abs(nx) < deadzone { nx = 0 }
        if abs(ny) < deadzone { ny = 0 }
        nx = max(-1, min(1, nx * sensitivity))
        ny = max(-1, min(1, ny * sensitivity))
        setStick(forLeftHalf: isLeftHalf, x: nx, y: ny)
    }

    /// Route a half's value to the correct analog stick, honoring the swap option.
    private func setStick(forLeftHalf isLeftHalf: Bool, x: Float, y: Float) {
        let drivesLeftStick = (isLeftHalf != swapped)
        if drivesLeftStick {
            EmulatorBridge.shared.setLeftStick(x: x, y: y)
        } else {
            EmulatorBridge.shared.setRightStick(x: x, y: y)
        }
    }

    /// Releases both sticks and hides the rings (e.g. when the mode is turned off
    /// or gameplay is paused).
    func releaseAll() {
        if leftTouch != nil {
            leftTouch = nil
            leftAtEdge = false
            hideStick(ring: leftRing, knob: leftKnob)
            setStick(forLeftHalf: true, x: 0, y: 0)
        }
        if rightTouch != nil {
            rightTouch = nil
            rightAtEdge = false
            hideStick(ring: rightRing, knob: rightKnob)
            setStick(forLeftHalf: false, x: 0, y: 0)
        }
    }
}
