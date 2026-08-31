// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun NestopiaControls(
    engine: NestopiaEngine,
    modifier: Modifier = Modifier,
    configuration: NestopiaControllerConfiguration = NestopiaControllerConfiguration(),
) {
    BoxWithConstraints(modifier = modifier) {
        val mode =
            when (configuration.presentationMode) {
                NestopiaControllerPresentationMode.Automatic ->
                    if (maxWidth > maxHeight || maxHeight < 300.dp) {
                        NestopiaControllerPresentationMode.Overlay
                    } else {
                        NestopiaControllerPresentationMode.Gamepad
                    }
                else -> configuration.presentationMode
            }
        val metrics = ControllerMetrics(compact = maxWidth < 500.dp)
        val palette = controllerPalette(configuration)

        if (mode == NestopiaControllerPresentationMode.Overlay) {
            OverlayControls(engine, configuration, metrics, palette)
        } else {
            GamepadControls(engine, configuration, metrics, palette)
        }
    }
}

@Composable
private fun GamepadControls(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
) {
    val controllerLabel = rememberControllerLabel(configuration)
    val bodyShape =
        when (configuration.theme) {
            NestopiaControllerTheme.System -> RoundedCornerShape(24.dp)
            NestopiaControllerTheme.NES -> RoundedCornerShape(18.dp)
            NestopiaControllerTheme.Famicom -> RoundedCornerShape(12.dp)
        }
    Row(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = metrics.outerPadding, vertical = metrics.outerPadding),
        verticalAlignment = Alignment.Bottom,
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .widthIn(max = 680.dp)
                    .shadow(14.dp, bodyShape)
                    .background(bodyPanelBrush(palette.body), bodyShape)
                    .background(bodySheenBrush, bodyShape)
                    .border(1.dp, Color.Black.copy(alpha = 0.22f), bodyShape)
                    .border(1.dp, Color.White.copy(alpha = 0.14f), bodyShape)
                    .padding(metrics.bodyPadding),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            DPad(engine, configuration, metrics, palette, 1f)
            Column(
                modifier =
                    Modifier
                        .padding(horizontal = metrics.sectionSpacing)
                        .background(palette.panel, RoundedCornerShape(9.dp))
                        .padding(horizontal = metrics.utilitySpacing, vertical = metrics.utilitySpacing),
                verticalArrangement = Arrangement.spacedBy(metrics.utilitySpacing),
            ) {
                if (controllerLabel.isNotEmpty()) {
                    Text(
                        text = controllerLabel,
                        color = palette.bodyLabel,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Black,
                        maxLines = 1,
                    )
                }
                UtilityButtons(engine, configuration, metrics, palette, 1f)
            }
            ActionButtons(engine, configuration, metrics, palette, 1f)
        }
    }
}

@Composable
private fun OverlayControls(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
) {
    val opacity = configuration.overlayOpacity.coerceIn(0f, 1f)
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = metrics.outerPadding, vertical = metrics.outerPadding),
    ) {
        DPad(
            engine,
            configuration,
            metrics,
            palette,
            opacity,
            Modifier.align(Alignment.BottomStart),
        )
        UtilityButtons(
            engine,
            configuration,
            metrics,
            palette,
            opacity,
            Modifier.align(Alignment.BottomCenter),
        )
        ActionButtons(
            engine,
            configuration,
            metrics,
            palette,
            opacity,
            Modifier.align(Alignment.BottomEnd),
        )
    }
}

// MARK: Directional pad

@Composable
private fun DPad(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    val cell = metrics.direction
    val plateSize = cell * 3
    val density = LocalDensity.current
    val boundsPx =
        remember(plateSize, density) {
            with(density) { Rect(0f, 0f, plateSize.toPx(), plateSize.toPx()) }
        }
    ControllerTouchSurface(
        engine = engine,
        hapticsEnabled = configuration.hapticsEnabled,
        modifier = modifier.size(plateSize),
        resolveActive = { point, _ -> dPadHitTest(point, boundsPx) },
    ) {
        Box(Modifier.size(plateSize)) {
            CrossPlate(size = plateSize, palette = palette, opacity = opacity)
            ArmOverlay(active, NestopiaButton.Up, cell, opacity, Modifier.offset(x = cell, y = 0.dp))
            ArmOverlay(active, NestopiaButton.Left, cell, opacity, Modifier.offset(x = 0.dp, y = cell))
            ArmOverlay(active, NestopiaButton.Right, cell, opacity, Modifier.offset(x = cell * 2, y = cell))
            ArmOverlay(active, NestopiaButton.Down, cell, opacity, Modifier.offset(x = cell, y = cell * 2))
            CenterBoss(size = cell, opacity = opacity, modifier = Modifier.offset(x = cell, y = cell))
        }
    }
}

@Composable
private fun CrossPlate(
    size: Dp,
    palette: ControllerPalette,
    opacity: Float,
) {
    val shape = remember(size) { DPadCrossShape(cornerRadius = size * 0.09f) }
    Box(
        modifier =
            Modifier
                .size(size)
                .shadow(3.dp, shape)
                .background(dPadBrush(palette.directionalPad, opacity), shape)
                .border(1.5.dp, Color.White.copy(alpha = 0.08f * opacity), shape)
                .border(1.dp, Color.Black.copy(alpha = 0.35f * opacity), shape),
    )
}

@Composable
private fun ArmOverlay(
    active: Set<NestopiaButton>,
    button: NestopiaButton,
    cell: Dp,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    val isActive = active.contains(button)
    val darken by animateOverlayAlpha(isActive, target = 0.24f * opacity)
    Box(
        modifier =
            modifier
                .size(cell)
                .background(Color.Black.copy(alpha = darken)),
    )
}

@Composable
private fun CenterBoss(
    size: Dp,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    val bossSize = size * 0.6f
    val centerOffset = (size - bossSize) / 2
    Box(
        modifier =
            modifier
                .offset(x = centerOffset, y = centerOffset)
                .size(bossSize)
                .background(
                    Brush.radialGradient(
                        listOf(Color.White.copy(alpha = 0.18f * opacity), Color.Black.copy(alpha = 0.30f * opacity)),
                    ),
                    CircleShape,
                ).border(1.dp, Color.Black.copy(alpha = 0.3f * opacity), CircleShape),
    )
}

// MARK: Utility buttons (SELECT / START)

@Composable
private fun UtilityButtons(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val tolerancePx = with(density) { (metrics.utilityWidth * 0.7f).toPx() }
    ControllerTouchSurface(
        engine = engine,
        hapticsEnabled = configuration.hapticsEnabled,
        modifier = modifier,
        resolveActive = { point, frames -> nearestButtonHitTest(point, frames, tolerancePx) },
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(metrics.utilitySpacing)) {
            UtilityCap(NestopiaButton.Select, "SELECT", metrics, palette, opacity)
            UtilityCap(NestopiaButton.Start, "START", metrics, palette, opacity)
        }
    }
}

@Composable
private fun ControllerTouchScope.UtilityCap(
    button: NestopiaButton,
    label: String,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
) {
    val isActive = active.contains(button)
    val pressedScale by animateOverlayScale(isActive)
    Box(
        modifier =
            Modifier
                .size(metrics.utilityWidth, metrics.utilityHeight)
                .graphicsLayer {
                    scaleX = pressedScale
                    scaleY = pressedScale
                }.background(utilityCapsuleBrush(palette.utilityButtons, opacity), CircleShape)
                .border(1.dp, Color.White.copy(alpha = 0.22f * opacity), CircleShape)
                .semantics { contentDescription = label }
                .reportBounds(button),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = label, color = palette.labels, fontSize = 9.sp, fontWeight = FontWeight.Black)
    }
}

// MARK: Action buttons (A / B)

@Composable
private fun ActionButtons(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val tolerancePx = with(density) { (metrics.actionSize * 0.7f).toPx() }
    ControllerTouchSurface(
        engine = engine,
        hapticsEnabled = configuration.hapticsEnabled,
        modifier = modifier,
        resolveActive = { point, frames -> nearestButtonHitTest(point, frames, tolerancePx) },
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(metrics.actionSpacing),
            verticalAlignment = Alignment.Bottom,
        ) {
            Box(Modifier.padding(bottom = metrics.actionSize * 0.22f)) {
                ActionCap(NestopiaButton.B, "B", metrics, palette, opacity)
            }
            ActionCap(NestopiaButton.A, "A", metrics, palette, opacity)
        }
    }
}

@Composable
private fun ControllerTouchScope.ActionCap(
    button: NestopiaButton,
    label: String,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
) {
    val isActive = active.contains(button)
    val pressedScale by animateOverlayScale(isActive)
    val density = LocalDensity.current
    val diameterPx = with(density) { metrics.actionSize.toPx() }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier =
                Modifier
                    .size(metrics.actionSize)
                    .graphicsLayer {
                        scaleX = pressedScale
                        scaleY = pressedScale
                    }.shadow(3.dp, CircleShape)
                    .background(actionCapBrush(palette.actionButtons, opacity, diameterPx), CircleShape)
                    .border(1.2.dp, Color.White.copy(alpha = 0.32f * opacity), CircleShape)
                    .border(1.dp, Color.Black.copy(alpha = 0.28f * opacity), CircleShape)
                    .semantics { contentDescription = label }
                    .reportBounds(button),
        )
        Text(
            text = label,
            color = palette.bodyLabel.copy(alpha = opacity),
            fontSize = 10.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

@Composable
private fun animateOverlayScale(isActive: Boolean) =
    animateFloatAsState(
        targetValue = if (isActive) 0.93f else 1f,
        animationSpec = tween(durationMillis = 70),
        label = "controllerButtonScale",
    )

@Composable
private fun animateOverlayAlpha(
    isActive: Boolean,
    target: Float,
) = animateFloatAsState(
    targetValue = if (isActive) target else 0f,
    animationSpec = tween(durationMillis = 60),
    label = "controllerArmOverlay",
)

private val bodySheenBrush =
    Brush.verticalGradient(
        listOf(Color.White.copy(alpha = 0.08f), Color.Transparent, Color.Black.copy(alpha = 0.10f)),
    )

private data class ControllerMetrics(
    val direction: Dp,
    val actionSize: Dp,
    val utilityWidth: Dp,
    val utilityHeight: Dp,
    val sectionSpacing: Dp,
    val utilitySpacing: Dp,
    val actionSpacing: Dp,
    val bodyPadding: Dp,
    val outerPadding: Dp,
) {
    constructor(compact: Boolean) : this(
        direction = if (compact) 38.dp else 48.dp,
        actionSize = if (compact) 50.dp else 64.dp,
        utilityWidth = if (compact) 46.dp else 58.dp,
        utilityHeight = if (compact) 26.dp else 32.dp,
        sectionSpacing = if (compact) 4.dp else 18.dp,
        utilitySpacing = if (compact) 4.dp else 10.dp,
        actionSpacing = if (compact) 8.dp else 16.dp,
        bodyPadding = if (compact) 12.dp else 22.dp,
        outerPadding = if (compact) 8.dp else 20.dp,
    )
}

private data class ControllerPalette(
    val body: Color,
    val directionalPad: Color,
    val actionButtons: Color,
    val utilityButtons: Color,
    val labels: Color,
    val bodyLabel: Color,
    val panel: Color,
)

@Composable
private fun controllerPalette(configuration: NestopiaControllerConfiguration): ControllerPalette {
    val defaults =
        when (configuration.theme) {
            NestopiaControllerTheme.System ->
                ControllerPalette(
                    body = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.92f),
                    directionalPad = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f),
                    actionButtons = MaterialTheme.colorScheme.primary,
                    utilityButtons = MaterialTheme.colorScheme.secondary,
                    labels = MaterialTheme.colorScheme.onPrimary,
                    bodyLabel = MaterialTheme.colorScheme.onSurface,
                    panel = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )
            NestopiaControllerTheme.NES ->
                ControllerPalette(
                    Color(0xFFB3B3AE),
                    Color(0xFF1A1A1A),
                    Color(0xFFAB0D1F),
                    Color(0xFF292929),
                    Color.White,
                    Color(0xFF262626),
                    Color(0xFF1F1F1F),
                )
            NestopiaControllerTheme.Famicom ->
                ControllerPalette(
                    Color(0xFFE8DBB0),
                    Color(0xFF570A17),
                    Color(0xFFA10814),
                    Color(0xFF6E0D1A),
                    Color(0xFFFFE8B8),
                    Color(0xFF660A17),
                    Color(0xFF570A17),
                )
        }
    val overrides = configuration.colors
    return defaults.copy(
        body = overrides.body ?: defaults.body,
        directionalPad = overrides.directionalPad ?: defaults.directionalPad,
        actionButtons = overrides.actionButtons ?: defaults.actionButtons,
        utilityButtons = overrides.utilityButtons ?: defaults.utilityButtons,
        labels = overrides.labels ?: defaults.labels,
        bodyLabel = overrides.bodyLabel ?: defaults.bodyLabel,
    )
}
