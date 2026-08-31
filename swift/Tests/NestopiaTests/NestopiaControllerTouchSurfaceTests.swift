// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing

@testable import Nestopia

private let dPadBounds = CGRect(x: 0, y: 0, width: 120, height: 120)

@Test func dPadHitTestPressesNothingAtCenter() {
    #expect(dPadHitTest(at: CGPoint(x: 60, y: 60), in: dPadBounds).isEmpty)
}

@Test func dPadHitTestResolvesCardinalDirections() {
    #expect(dPadHitTest(at: CGPoint(x: 110, y: 60), in: dPadBounds) == [.right])
    #expect(dPadHitTest(at: CGPoint(x: 10, y: 60), in: dPadBounds) == [.left])
    #expect(dPadHitTest(at: CGPoint(x: 60, y: 10), in: dPadBounds) == [.up])
    #expect(dPadHitTest(at: CGPoint(x: 60, y: 110), in: dPadBounds) == [.down])
}

@Test func dPadHitTestResolvesDiagonalsToTwoDirections() {
    #expect(dPadHitTest(at: CGPoint(x: 100, y: 100), in: dPadBounds) == [.right, .down])
    #expect(dPadHitTest(at: CGPoint(x: 20, y: 20), in: dPadBounds) == [.left, .up])
    #expect(dPadHitTest(at: CGPoint(x: 100, y: 20), in: dPadBounds) == [.right, .up])
    #expect(dPadHitTest(at: CGPoint(x: 20, y: 100), in: dPadBounds) == [.down, .left])
}

@Test func dPadHitTestReleasesEverythingFarOutsideBounds() {
    #expect(dPadHitTest(at: CGPoint(x: 400, y: 400), in: dPadBounds).isEmpty)
}

@Test func dPadHitTestToleratesASmallOvershootPastTheEdge() {
    // A finger that slides a little past the visual edge should still register
    // the nearest direction rather than immediately releasing every button.
    #expect(dPadHitTest(at: CGPoint(x: 122, y: 60), in: dPadBounds) == [.right])
}

private let actionFrames: [NestopiaControllerButton: CGRect] = [
    .b: CGRect(x: 0, y: 0, width: 50, height: 50),
    .a: CGRect(x: 100, y: 0, width: 50, height: 50),
]

@Test func nearestButtonHitTestPicksTheContainingButton() {
    #expect(
        nearestButtonHitTest(at: CGPoint(x: 25, y: 25), among: actionFrames, tolerance: 20) == [.b])
    #expect(
        nearestButtonHitTest(at: CGPoint(x: 125, y: 25), among: actionFrames, tolerance: 20) == [.a])
}

@Test func nearestButtonHitTestResolvesASwipeBetweenTwoButtonsToOneOfThem() {
    // Sliding across the gap between the two buttons should always resolve to
    // exactly one of them, never drop the touch, based on which is closer.
    #expect(
        nearestButtonHitTest(at: CGPoint(x: 70, y: 25), among: actionFrames, tolerance: 20) == [.b])
    #expect(
        nearestButtonHitTest(at: CGPoint(x: 80, y: 25), among: actionFrames, tolerance: 20) == [.a])
}

@Test func nearestButtonHitTestReleasesFarOutsideTheGroup() {
    #expect(
        nearestButtonHitTest(at: CGPoint(x: 400, y: 400), among: actionFrames, tolerance: 20)
            .isEmpty)
}

@Test func nearestButtonHitTestReleasesWithNoFramesReported() {
    #expect(nearestButtonHitTest(at: CGPoint(x: 25, y: 25), among: [:], tolerance: 20).isEmpty)
}
