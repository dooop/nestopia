// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NestopiaControllerTouchSurfaceTest {
    private val dPadBounds = Rect(0f, 0f, 120f, 120f)

    @Test
    fun dPadHitTestPressesNothingAtCenter() {
        assertTrue(dPadHitTest(Offset(60f, 60f), dPadBounds).isEmpty())
    }

    @Test
    fun dPadHitTestResolvesCardinalDirections() {
        assertEquals(setOf(NestopiaButton.Right), dPadHitTest(Offset(110f, 60f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Left), dPadHitTest(Offset(10f, 60f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Up), dPadHitTest(Offset(60f, 10f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Down), dPadHitTest(Offset(60f, 110f), dPadBounds))
    }

    @Test
    fun dPadHitTestResolvesDiagonalsToTwoDirections() {
        assertEquals(setOf(NestopiaButton.Right, NestopiaButton.Down), dPadHitTest(Offset(100f, 100f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Left, NestopiaButton.Up), dPadHitTest(Offset(20f, 20f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Up, NestopiaButton.Right), dPadHitTest(Offset(100f, 20f), dPadBounds))
        assertEquals(setOf(NestopiaButton.Down, NestopiaButton.Left), dPadHitTest(Offset(20f, 100f), dPadBounds))
    }

    @Test
    fun dPadHitTestReleasesEverythingFarOutsideBounds() {
        assertTrue(dPadHitTest(Offset(400f, 400f), dPadBounds).isEmpty())
    }

    @Test
    fun dPadHitTestToleratesASmallOvershootPastTheEdge() {
        // A finger that slides a little past the visual edge should still
        // register the nearest direction rather than immediately releasing
        // every button.
        assertEquals(setOf(NestopiaButton.Right), dPadHitTest(Offset(122f, 60f), dPadBounds))
    }

    private val actionFrames =
        mapOf(
            NestopiaButton.B to Rect(0f, 0f, 50f, 50f),
            NestopiaButton.A to Rect(100f, 0f, 150f, 50f),
        )

    @Test
    fun nearestButtonHitTestPicksTheContainingButton() {
        assertEquals(setOf(NestopiaButton.B), nearestButtonHitTest(Offset(25f, 25f), actionFrames, 20f))
        assertEquals(setOf(NestopiaButton.A), nearestButtonHitTest(Offset(125f, 25f), actionFrames, 20f))
    }

    @Test
    fun nearestButtonHitTestResolvesASwipeBetweenTwoButtonsToOneOfThem() {
        // Sliding across the gap between the two buttons should always
        // resolve to exactly one of them, never drop the touch, based on
        // which is closer.
        assertEquals(setOf(NestopiaButton.B), nearestButtonHitTest(Offset(70f, 25f), actionFrames, 20f))
        assertEquals(setOf(NestopiaButton.A), nearestButtonHitTest(Offset(80f, 25f), actionFrames, 20f))
    }

    @Test
    fun nearestButtonHitTestReleasesFarOutsideTheGroup() {
        assertTrue(nearestButtonHitTest(Offset(400f, 400f), actionFrames, 20f).isEmpty())
    }

    @Test
    fun nearestButtonHitTestReleasesWithNoFramesReported() {
        assertTrue(nearestButtonHitTest(Offset(25f, 25f), emptyMap(), 20f).isEmpty())
    }
}
