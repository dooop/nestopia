// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalHapticFeedback
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2

/**
 * Scope handed to a [ControllerTouchSurface]'s content so each button can
 * report its own bounds (via [reportBounds]) and read which buttons in the
 * group are currently pressed (via [active]).
 */
internal class ControllerTouchScope(
    val active: Set<NestopiaButton>,
    private val groupCoordinates: () -> LayoutCoordinates?,
    private val bounds: MutableMap<NestopiaButton, Rect>,
) {
    fun Modifier.reportBounds(button: NestopiaButton): Modifier =
        onGloballyPositioned { childCoordinates ->
            val group = groupCoordinates() ?: return@onGloballyPositioned
            bounds[button] = group.localBoundingBoxOf(childCoordinates)
        }
}

/**
 * Hosts one contiguous touch surface for a group of related controller
 * buttons (the four directions, or the two action buttons, or the two
 * utility buttons) so a finger sliding across the group presses and releases
 * buttons continuously as it crosses their reported bounds, instead of only
 * affecting whichever button the touch happened to start on — each button's
 * own [pointerInput] otherwise only ever sees the touch it was hit-tested
 * against at the initial press.
 */
@Composable
internal fun ControllerTouchSurface(
    engine: NestopiaEngine,
    hapticsEnabled: Boolean,
    modifier: Modifier = Modifier,
    resolveActive: (Offset, Map<NestopiaButton, Rect>) -> Set<NestopiaButton>,
    content: @Composable ControllerTouchScope.() -> Unit,
) {
    val hapticFeedback = LocalHapticFeedback.current
    // The pointer-input coroutine below is long-lived and only restarts when
    // `engine`/`hapticsEnabled` change; `resolveActive` is a fresh closure on
    // every recomposition (it captures per-frame geometry), so it must be read
    // through rememberUpdatedState rather than used as a pointerInput key —
    // otherwise every recomposition would cancel and restart the gesture
    // handler, dropping whatever touch was in progress.
    val currentResolveActive by rememberUpdatedState(resolveActive)
    var active by remember { mutableStateOf(emptySet<NestopiaButton>()) }
    val bounds = remember { mutableMapOf<NestopiaButton, Rect>() }
    var groupCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }

    fun update(newActive: Set<NestopiaButton>) {
        if (newActive == active) return
        val pressed = newActive - active
        val released = active - newActive
        active = newActive
        released.forEach { engine.setButton(it, false) }
        pressed.forEach { engine.setButton(it, true) }
        if (hapticsEnabled && pressed.isNotEmpty()) {
            hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
    }

    Box(
        modifier =
            modifier
                .onGloballyPositioned { groupCoordinates = it }
                .pointerInput(engine, hapticsEnabled) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        down.consume()
                        update(currentResolveActive(down.position, bounds))
                        var pressedCount = 1
                        while (pressedCount > 0) {
                            val event = awaitPointerEvent()
                            val pressedChanges = event.changes.filter { it.pressed }
                            pressedChanges.forEach { it.consume() }
                            pressedCount = pressedChanges.size
                            update(
                                pressedChanges.fold(emptySet<NestopiaButton>()) { acc, change ->
                                    acc + currentResolveActive(change.position, bounds)
                                },
                            )
                        }
                    }
                },
    ) {
        ControllerTouchScope(active, { groupCoordinates }, bounds).content()
    }
}

/**
 * Resolves which direction(s) of a square d-pad surface a point falls in.
 * The eight compass sectors around the center map to a cardinal press or,
 * for the four diagonals, two simultaneous cardinal presses (matching how
 * the physical pad's cross tilts under a corner press). A small dead zone at
 * the center presses nothing, and a point outside the (slightly inflated)
 * bounds releases every direction.
 */
internal fun dPadHitTest(
    point: Offset,
    bounds: Rect,
): Set<NestopiaButton> {
    val inflated = bounds.inflated(bounds.width * 0.12f, bounds.height * 0.12f)
    if (!inflated.contains(point)) return emptySet()

    val center = bounds.center
    val dx = point.x - center.x
    val dy = point.y - center.y
    val deadZone = minOf(bounds.width, bounds.height) * 0.16f
    if (abs(dx) < deadZone && abs(dy) < deadZone) return emptySet()

    val degrees = atan2(dy, dx) * 180.0 / PI
    return when {
        degrees >= -22.5 && degrees < 22.5 -> setOf(NestopiaButton.Right)
        degrees >= 22.5 && degrees < 67.5 -> setOf(NestopiaButton.Right, NestopiaButton.Down)
        degrees >= 67.5 && degrees < 112.5 -> setOf(NestopiaButton.Down)
        degrees >= 112.5 && degrees < 157.5 -> setOf(NestopiaButton.Down, NestopiaButton.Left)
        degrees >= -157.5 && degrees < -112.5 -> setOf(NestopiaButton.Left, NestopiaButton.Up)
        degrees >= -67.5 && degrees < -22.5 -> setOf(NestopiaButton.Up, NestopiaButton.Right)
        degrees >= 157.5 || degrees < -157.5 -> setOf(NestopiaButton.Left)
        else -> setOf(NestopiaButton.Up)
    }
}

/**
 * Resolves the single button (by nearest center) a point should activate
 * among a small group of adjacent buttons — used for the action and utility
 * pairs, where a swipe between the two should always land on exactly one of
 * them as long as it stays within the group's combined bounds plus
 * [tolerance].
 */
internal fun nearestButtonHitTest(
    point: Offset,
    frames: Map<NestopiaButton, Rect>,
    tolerance: Float,
): Set<NestopiaButton> {
    if (frames.isEmpty()) return emptySet()
    val union = frames.values.reduce { a, b -> a.unioned(b) }
    if (!union.inflated(tolerance, tolerance).contains(point)) return emptySet()
    val nearest =
        frames.minByOrNull { (_, rect) ->
            val center = rect.center
            val dx = point.x - center.x
            val dy = point.y - center.y
            dx * dx + dy * dy
        } ?: return emptySet()
    return setOf(nearest.key)
}

private fun Rect.inflated(
    dx: Float,
    dy: Float,
): Rect = Rect(left - dx, top - dy, right + dx, bottom + dy)

private fun Rect.unioned(other: Rect): Rect =
    Rect(
        left = minOf(left, other.left),
        top = minOf(top, other.top),
        right = maxOf(right, other.right),
        bottom = maxOf(bottom, other.bottom),
    )
