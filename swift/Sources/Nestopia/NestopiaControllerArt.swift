// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// The classic four-armed directional pad plate, drawn as one continuous rounded
/// shape (rather than four separate buttons) to match the molded plastic cross
/// of the original hardware. Mirrors `swift/Design/ControllerArt/dpad-plate.svg`.
struct DPadCrossShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let armW = rect.width / 3
        let armH = rect.height / 3
        let x0 = rect.minX
        let x1 = rect.minX + armW
        let x2 = rect.minX + armW * 2
        let x3 = rect.maxX
        let y0 = rect.minY
        let y1 = rect.minY + armH
        let y2 = rect.minY + armH * 2
        let y3 = rect.maxY
        let points: [CGPoint] = [
            CGPoint(x: x1, y: y0), CGPoint(x: x2, y: y0),
            CGPoint(x: x2, y: y1), CGPoint(x: x3, y: y1),
            CGPoint(x: x3, y: y2), CGPoint(x: x2, y: y2),
            CGPoint(x: x2, y: y3), CGPoint(x: x1, y: y3),
            CGPoint(x: x1, y: y2), CGPoint(x: x0, y: y2),
            CGPoint(x: x0, y: y1), CGPoint(x: x1, y: y1),
        ]
        return roundedPolygonPath(points, radius: cornerRadius)
    }
}

/// Builds a closed path through `points`, rounding every corner by `radius`.
/// Used to give the plus-shaped d-pad the same soft, molded corners as the
/// circular and capsule controls instead of sharp polygon joints.
func roundedPolygonPath(_ points: [CGPoint], radius: CGFloat) -> Path {
    var path = Path()
    let count = points.count
    guard count > 2 else { return path }

    func point(_ index: Int) -> CGPoint { points[((index % count) + count) % count] }

    for index in 0..<count {
        let previous = point(index - 1)
        let current = point(index)
        let next = point(index + 1)
        let toPrevious = unitVector(from: current, to: previous)
        let toNext = unitVector(from: current, to: next)
        let radius = min(radius, distance(current, previous) / 2, distance(current, next) / 2)
        let start = CGPoint(
            x: current.x + toPrevious.x * radius, y: current.y + toPrevious.y * radius)
        let end = CGPoint(x: current.x + toNext.x * radius, y: current.y + toNext.y * radius)
        if index == 0 {
            path.move(to: start)
        } else {
            path.addLine(to: start)
        }
        path.addQuadCurve(to: end, control: current)
    }
    path.closeSubpath()
    return path
}

private func unitVector(from a: CGPoint, to b: CGPoint) -> CGPoint {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let length = (dx * dx + dy * dy).squareRoot()
    guard length > 0 else { return .zero }
    return CGPoint(x: dx / length, y: dy / length)
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return (dx * dx + dy * dy).squareRoot()
}

/// Vertical brushed-plastic gradient for the controller's outer body panel.
/// Mirrors `swift/Design/ControllerArt/body-panel.svg`.
func bodyPanelGradient(color: Color, opacity: Double = 1) -> LinearGradient {
    LinearGradient(
        colors: [
            color.adjustedBrightness(0.07).opacity(opacity),
            color.opacity(opacity),
            color.adjustedBrightness(-0.06).opacity(opacity),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Recessed-plate gradient for the d-pad cross. Mirrors
/// `swift/Design/ControllerArt/dpad-plate.svg`.
func dPadGradient(color: Color, opacity: Double) -> LinearGradient {
    LinearGradient(
        colors: [
            color.adjustedBrightness(0.10).opacity(opacity),
            color.adjustedBrightness(-0.12).opacity(opacity),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Glossy domed-cap gradient for the round action buttons, with the highlight
/// offset toward the upper-left the way an injection-molded button catches
/// light. Mirrors `swift/Design/ControllerArt/action-button.svg`.
func actionCapGradient(color: Color, opacity: Double, diameter: CGFloat) -> RadialGradient {
    RadialGradient(
        colors: [
            color.adjustedBrightness(0.34).opacity(opacity),
            color.opacity(opacity),
            color.adjustedBrightness(-0.24).opacity(opacity),
        ],
        center: UnitPoint(x: 0.32, y: 0.26),
        startRadius: 0,
        endRadius: diameter * 0.55
    )
}

/// Inset-groove gradient for the SELECT/START capsules. Mirrors
/// `swift/Design/ControllerArt/utility-capsule.svg`.
func utilityCapsuleGradient(color: Color, opacity: Double) -> LinearGradient {
    LinearGradient(
        colors: [
            color.adjustedBrightness(-0.06).opacity(opacity),
            color.adjustedBrightness(0.10).opacity(opacity),
            color.adjustedBrightness(-0.10).opacity(opacity),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    /// Returns this color with its HSB brightness shifted by `delta` (clamped
    /// to `[0, 1]`), used to derive gradient stops from a single theme color
    /// instead of hand-picking a second color per control.
    func adjustedBrightness(_ delta: Double) -> Color {
        #if canImport(UIKit)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            guard
                UIColor(self).getHue(
                    &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            else { return self }
            let adjusted = min(max(Double(brightness) + delta, 0), 1)
            return Color(
                hue: Double(hue), saturation: Double(saturation), brightness: adjusted,
                opacity: Double(alpha))
        #elseif canImport(AppKit)
            guard let converted = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let adjusted = min(max(Double(brightness) + delta, 0), 1)
            return Color(
                hue: Double(hue), saturation: Double(saturation), brightness: adjusted,
                opacity: Double(alpha))
        #else
            return self
        #endif
    }
}
