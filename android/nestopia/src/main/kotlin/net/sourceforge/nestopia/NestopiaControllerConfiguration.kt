// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

enum class NestopiaControllerTheme {
    System,
    NES,
    Famicom,
}

enum class NestopiaControllerPresentationMode {
    Automatic,
    Gamepad,
    Overlay,
}

data class NestopiaControllerColorOverrides(
    val body: Color? = null,
    val directionalPad: Color? = null,
    val actionButtons: Color? = null,
    val utilityButtons: Color? = null,
    val labels: Color? = null,
    val bodyLabel: Color? = null,
)

data class NestopiaControllerConfiguration(
    val theme: NestopiaControllerTheme = NestopiaControllerTheme.System,
    val presentationMode: NestopiaControllerPresentationMode = NestopiaControllerPresentationMode.Automatic,
    val colors: NestopiaControllerColorOverrides = NestopiaControllerColorOverrides(),
    /** Text on the controller body. Null uses the host app label; an empty string hides it. */
    val controllerLabel: String? = null,
    val hapticsEnabled: Boolean = true,
    val overlayOpacity: Float = 0.72f,
)

@Composable
internal fun rememberControllerLabel(configuration: NestopiaControllerConfiguration): String {
    val context = LocalContext.current
    val applicationLabel =
        remember(context.applicationContext) {
            context.applicationInfo.loadLabel(context.packageManager).toString()
        }
    return configuration.controllerLabel ?: applicationLabel
}
