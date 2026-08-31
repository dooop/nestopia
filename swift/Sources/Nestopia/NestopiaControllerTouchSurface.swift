// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

// tvOS has no touch screen and no `DragGesture`; on-screen controls are never
// shown there (`shouldShowOnScreenControls` excludes television), so this
// entire touch-handling surface is compiled out and the tvOS branches in
// NestopiaControls.swift drive buttons directly from focus/click instead.
#if !os(tvOS)
    /// Named coordinate space shared by every control inside one
    /// `ControllerTouchSurface`, so button frames and drag locations can be
    /// compared directly regardless of how deep in the view hierarchy a button sits.
    let controllerTouchSpace = "NestopiaControllerTouchSpace"

    struct ControllerButtonFrameKey: PreferenceKey {
        static let defaultValue: [NestopiaControllerButton: CGRect] = [:]
        static func reduce(
            value: inout [NestopiaControllerButton: CGRect],
            nextValue: () -> [NestopiaControllerButton: CGRect]
        ) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    extension View {
        /// Publishes this view's frame, in `controllerTouchSpace`, keyed by `button`
        /// so an enclosing `ControllerTouchSurface` can hit-test drags against it.
        func reportingControllerFrame(of button: NestopiaControllerButton) -> some View {
            background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ControllerButtonFrameKey.self,
                        value: [button: proxy.frame(in: .named(controllerTouchSpace))]
                    )
                }
            )
        }
    }

    /// Hosts one contiguous touch surface for a group of related controller
    /// buttons (the four directions, or the two action buttons, or the two
    /// utility buttons) so a single finger sliding across the group presses and
    /// releases buttons continuously as it crosses their frames, instead of only
    /// affecting whichever button the touch happened to start on.
    struct ControllerTouchSurface<Content: View>: View {
        let engine: NestopiaEngine
        let hapticsEnabled: Bool
        let resolveActive:
            (CGPoint, [NestopiaControllerButton: CGRect]) -> Set<NestopiaControllerButton>
        let content: (Set<NestopiaControllerButton>) -> Content

        init(
            engine: NestopiaEngine,
            hapticsEnabled: Bool,
            resolveActive: @escaping (CGPoint, [NestopiaControllerButton: CGRect]) -> Set<
                NestopiaControllerButton
            >,
            @ViewBuilder content: @escaping (Set<NestopiaControllerButton>) -> Content
        ) {
            self.engine = engine
            self.hapticsEnabled = hapticsEnabled
            self.resolveActive = resolveActive
            self.content = content
        }

        @State private var frames: [NestopiaControllerButton: CGRect] = [:]
        @State private var active: Set<NestopiaControllerButton> = []

        var body: some View {
            content(active)
                .coordinateSpace(name: controllerTouchSpace)
                .onPreferenceChange(ControllerButtonFrameKey.self) { frames = $0 }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(controllerTouchSpace))
                        .onChanged { update(to: resolveActive($0.location, frames)) }
                        .onEnded { _ in update(to: []) }
                )
                .onDisappear { update(to: []) }
        }

        private func update(to newActive: Set<NestopiaControllerButton>) {
            guard newActive != active else { return }
            let pressed = newActive.subtracting(active)
            let released = active.subtracting(newActive)
            active = newActive
            for button in released { engine.setButton(button, pressed: false) }
            for button in pressed { engine.setButton(button, pressed: true) }
            if hapticsEnabled && !pressed.isEmpty { performControllerHaptic() }
        }
    }
#endif

/// Resolves which direction(s) of a square d-pad surface a point falls in.
/// The eight compass sectors around the center map to a cardinal press or,
/// for the four diagonals, two simultaneous cardinal presses (matching how
/// the physical pad's cross tilts under a corner press). A small dead zone at
/// the center presses nothing, and a point outside the (slightly inflated)
/// bounds releases every direction.
func dPadHitTest(at point: CGPoint, in bounds: CGRect) -> Set<NestopiaControllerButton> {
    let inflated = bounds.insetBy(dx: -bounds.width * 0.12, dy: -bounds.height * 0.12)
    guard inflated.contains(point) else { return [] }

    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let dx = point.x - center.x
    let dy = point.y - center.y
    let deadZone = min(bounds.width, bounds.height) * 0.16
    if abs(dx) < deadZone && abs(dy) < deadZone { return [] }

    let degrees = atan2(dy, dx) * 180 / .pi
    switch degrees {
    case -22.5..<22.5: return [.right]
    case 22.5..<67.5: return [.right, .down]
    case 67.5..<112.5: return [.down]
    case 112.5..<157.5: return [.down, .left]
    case -157.5..<(-112.5): return [.left, .up]
    case -67.5..<(-22.5): return [.up, .right]
    default:
        return degrees >= 157.5 || degrees < -157.5 ? [.left] : [.up]
    }
}

/// Resolves the single button (by nearest center) a point should activate
/// among a small group of adjacent buttons — used for the action and utility
/// pairs, where a swipe between the two should always land on exactly one of
/// them as long as it stays within the group's combined bounds plus
/// `tolerance`.
func nearestButtonHitTest(
    at point: CGPoint,
    among frames: [NestopiaControllerButton: CGRect],
    tolerance: CGFloat
) -> Set<NestopiaControllerButton> {
    guard let first = frames.values.first else { return [] }
    let union = frames.values.dropFirst().reduce(first) { $0.union($1) }
    guard union.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { return [] }
    guard
        let nearest = frames.min(by: {
            squaredDistance(point, $0.value.controllerCenter)
                < squaredDistance(point, $1.value.controllerCenter)
        })
    else { return [] }
    return [nearest.key]
}

private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx * dx + dy * dy
}

extension CGRect {
    fileprivate var controllerCenter: CGPoint { CGPoint(x: midX, y: midY) }
}

func performControllerHaptic() {
    #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
    #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
}
