// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.sqrt

/**
 * The classic four-armed directional pad plate, drawn as one continuous
 * rounded shape (rather than four separate buttons) to match the molded
 * plastic cross of the original hardware. Mirrors
 * `swift/Design/ControllerArt/dpad-plate.svg` (shared with the Apple wrapper).
 */
internal class DPadCrossShape(
    private val cornerRadius: Dp,
) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density,
    ): Outline {
        val cornerRadiusPx = with(density) { cornerRadius.toPx() }
        val armW = size.width / 3f
        val armH = size.height / 3f
        val x0 = 0f
        val x1 = armW
        val x2 = armW * 2
        val x3 = size.width
        val y0 = 0f
        val y1 = armH
        val y2 = armH * 2
        val y3 = size.height
        val points =
            listOf(
                Offset(x1, y0),
                Offset(x2, y0),
                Offset(x2, y1),
                Offset(x3, y1),
                Offset(x3, y2),
                Offset(x2, y2),
                Offset(x2, y3),
                Offset(x1, y3),
                Offset(x1, y2),
                Offset(x0, y2),
                Offset(x0, y1),
                Offset(x1, y1),
            )
        return Outline.Generic(roundedPolygonPath(points, cornerRadiusPx))
    }
}

/**
 * Builds a closed path through [points], rounding every corner by [radius].
 * Used to give the plus-shaped d-pad the same soft, molded corners as the
 * circular and capsule controls instead of sharp polygon joints.
 */
internal fun roundedPolygonPath(
    points: List<Offset>,
    radius: Float,
): Path {
    val path = Path()
    val count = points.size
    if (count <= 2) return path

    fun point(index: Int): Offset = points[((index % count) + count) % count]

    for (index in 0 until count) {
        val previous = point(index - 1)
        val current = point(index)
        val next = point(index + 1)
        val toPrevious = unitVector(current, previous)
        val toNext = unitVector(current, next)
        val cornerRadius = minOf(radius, distance(current, previous) / 2, distance(current, next) / 2)
        val start = Offset(current.x + toPrevious.x * cornerRadius, current.y + toPrevious.y * cornerRadius)
        val end = Offset(current.x + toNext.x * cornerRadius, current.y + toNext.y * cornerRadius)
        if (index == 0) {
            path.moveTo(start.x, start.y)
        } else {
            path.lineTo(start.x, start.y)
        }
        path.quadraticTo(current.x, current.y, end.x, end.y)
    }
    path.close()
    return path
}

private fun unitVector(
    from: Offset,
    to: Offset,
): Offset {
    val dx = to.x - from.x
    val dy = to.y - from.y
    val length = sqrt(dx * dx + dy * dy)
    return if (length > 0f) Offset(dx / length, dy / length) else Offset.Zero
}

private fun distance(
    a: Offset,
    b: Offset,
): Float {
    val dx = a.x - b.x
    val dy = a.y - b.y
    return sqrt(dx * dx + dy * dy)
}

/**
 * Vertical brushed-plastic gradient for the controller's outer body panel.
 * Mirrors `swift/Design/ControllerArt/body-panel.svg`.
 */
internal fun bodyPanelBrush(
    color: Color,
    alpha: Float = 1f,
): Brush =
    Brush.verticalGradient(
        listOf(
            color.adjustedBrightness(0.07f).copy(alpha = alpha),
            color.copy(alpha = alpha),
            color.adjustedBrightness(-0.06f).copy(alpha = alpha),
        ),
    )

/**
 * Recessed-plate gradient for the d-pad cross. Mirrors
 * `swift/Design/ControllerArt/dpad-plate.svg`.
 */
internal fun dPadBrush(
    color: Color,
    alpha: Float,
): Brush =
    Brush.verticalGradient(
        listOf(
            color.adjustedBrightness(0.10f).copy(alpha = alpha),
            color.adjustedBrightness(-0.12f).copy(alpha = alpha),
        ),
    )

/**
 * Glossy domed-cap gradient for the round action buttons, with the highlight
 * offset toward the upper-left the way an injection-molded button catches
 * light. Mirrors `swift/Design/ControllerArt/action-button.svg`.
 */
internal fun actionCapBrush(
    color: Color,
    alpha: Float,
    diameterPx: Float,
): Brush =
    Brush.radialGradient(
        colors =
            listOf(
                color.adjustedBrightness(0.34f).copy(alpha = alpha),
                color.copy(alpha = alpha),
                color.adjustedBrightness(-0.24f).copy(alpha = alpha),
            ),
        center = Offset(diameterPx * 0.32f, diameterPx * 0.26f),
        radius = (diameterPx * 0.55f).coerceAtLeast(1f),
    )

/**
 * Inset-groove gradient for the SELECT/START capsules. Mirrors
 * `swift/Design/ControllerArt/utility-capsule.svg`.
 */
internal fun utilityCapsuleBrush(
    color: Color,
    alpha: Float,
): Brush =
    Brush.verticalGradient(
        listOf(
            color.adjustedBrightness(-0.06f).copy(alpha = alpha),
            color.adjustedBrightness(0.10f).copy(alpha = alpha),
            color.adjustedBrightness(-0.10f).copy(alpha = alpha),
        ),
    )

/**
 * Returns this color with its HSV brightness (value) shifted by [delta]
 * (clamped to `[0, 1]`), used to derive gradient stops from a single theme
 * color instead of hand-picking a second color per control.
 */
internal fun Color.adjustedBrightness(delta: Float): Color {
    val hsv = FloatArray(3)
    android.graphics.Color.colorToHSV(this.toArgb(), hsv)
    hsv[2] = (hsv[2] + delta).coerceIn(0f, 1f)
    val alpha255 = (alpha * 255f).toInt().coerceIn(0, 255)
    return Color(android.graphics.Color.HSVToColor(alpha255, hsv))
}
