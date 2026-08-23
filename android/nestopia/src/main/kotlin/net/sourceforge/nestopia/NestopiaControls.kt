// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
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
                    .background(palette.body, bodyShape)
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

@Composable
private fun DPad(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        ControllerButton(
            "▲",
            NestopiaButton.Up,
            engine,
            metrics.direction,
            metrics.direction,
            RoundedCornerShape(7.dp),
            palette.directionalPad,
            palette.labels,
            configuration,
            opacity,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            ControllerButton(
                "◀",
                NestopiaButton.Left,
                engine,
                metrics.direction,
                metrics.direction,
                RoundedCornerShape(7.dp),
                palette.directionalPad,
                palette.labels,
                configuration,
                opacity,
            )
            Box(
                Modifier
                    .size(metrics.direction)
                    .background(palette.directionalPad.copy(alpha = palette.directionalPad.alpha * opacity))
                    .padding(metrics.direction * 0.23f)
                    .background(Color.Black.copy(alpha = 0.16f * opacity), CircleShape)
                    .border(1.dp, Color.White.copy(alpha = 0.08f * opacity), CircleShape),
            )
            ControllerButton(
                "▶",
                NestopiaButton.Right,
                engine,
                metrics.direction,
                metrics.direction,
                RoundedCornerShape(7.dp),
                palette.directionalPad,
                palette.labels,
                configuration,
                opacity,
            )
        }
        ControllerButton(
            "▼",
            NestopiaButton.Down,
            engine,
            metrics.direction,
            metrics.direction,
            RoundedCornerShape(7.dp),
            palette.directionalPad,
            palette.labels,
            configuration,
            opacity,
        )
    }
}

@Composable
private fun UtilityButtons(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(metrics.utilitySpacing)) {
        ControllerButton(
            "SELECT",
            NestopiaButton.Select,
            engine,
            metrics.utilityWidth,
            metrics.utilityHeight,
            RoundedCornerShape(50),
            palette.utilityButtons,
            palette.labels,
            configuration,
            opacity,
        )
        ControllerButton(
            "START",
            NestopiaButton.Start,
            engine,
            metrics.utilityWidth,
            metrics.utilityHeight,
            RoundedCornerShape(50),
            palette.utilityButtons,
            palette.labels,
            configuration,
            opacity,
        )
    }
}

@Composable
private fun ActionButtons(
    engine: NestopiaEngine,
    configuration: NestopiaControllerConfiguration,
    metrics: ControllerMetrics,
    palette: ControllerPalette,
    opacity: Float,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(metrics.actionSpacing),
        verticalAlignment = Alignment.Bottom,
    ) {
        Box(Modifier.padding(bottom = metrics.actionSize * 0.22f)) {
            ControllerButton(
                "B",
                NestopiaButton.B,
                engine,
                metrics.actionSize,
                metrics.actionSize,
                CircleShape,
                palette.actionButtons,
                palette.labels,
                configuration,
                opacity,
            )
        }
        ControllerButton(
            "A",
            NestopiaButton.A,
            engine,
            metrics.actionSize,
            metrics.actionSize,
            CircleShape,
            palette.actionButtons,
            palette.labels,
            configuration,
            opacity,
        )
    }
}

@Composable
private fun ControllerButton(
    label: String,
    button: NestopiaButton,
    engine: NestopiaEngine,
    width: Dp,
    height: Dp,
    shape: Shape,
    color: Color,
    labelColor: Color,
    configuration: NestopiaControllerConfiguration,
    opacity: Float,
) {
    val surface = color.copy(alpha = color.alpha * opacity)
    val hapticFeedback = LocalHapticFeedback.current
    var isPressed by remember(button) { mutableStateOf(false) }
    val pressedScale by
        animateFloatAsState(
            targetValue = if (isPressed) 0.92f else 1f,
            animationSpec = tween(durationMillis = 80),
            label = "controllerButtonScale",
        )
    Box(
        modifier =
            Modifier
                .size(width, height)
                .graphicsLayer {
                    scaleX = pressedScale
                    scaleY = pressedScale
                    alpha = if (isPressed) 0.88f else 1f
                }.shadow(if (configuration.theme == NestopiaControllerTheme.System) 5.dp else 3.dp, shape)
                .background(surface, shape)
                .border(1.dp, Color.White.copy(alpha = 0.18f * opacity), shape)
                .semantics { contentDescription = label }
                .pointerInput(button, configuration.hapticsEnabled) {
                    detectTapGestures(
                        onPress = {
                            isPressed = true
                            if (configuration.hapticsEnabled) {
                                hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            }
                            engine.setButton(button, true)
                            try {
                                tryAwaitRelease()
                            } finally {
                                engine.setButton(button, false)
                                isPressed = false
                            }
                        },
                    )
                },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = labelColor,
            fontSize = if (label.length == 1) 20.sp else 9.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

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
