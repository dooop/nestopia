// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package nestopia

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

enum class NESControllerTheme {
    System,
    NES,
    Famicom,
}

enum class NESControllerPresentationMode {
    Automatic,
    Gamepad,
    Overlay,
}

data class NESControllerColorOverrides(
    val body: Color? = null,
    val directionalPad: Color? = null,
    val actionButtons: Color? = null,
    val utilityButtons: Color? = null,
    val labels: Color? = null,
    val bodyLabel: Color? = null,
)

data class NESControllerConfiguration(
    val theme: NESControllerTheme = NESControllerTheme.System,
    val presentationMode: NESControllerPresentationMode = NESControllerPresentationMode.Automatic,
    val colors: NESControllerColorOverrides = NESControllerColorOverrides(),
    /** Text on the controller body. Null uses the host app label; an empty string hides it. */
    val controllerLabel: String? = null,
    val hapticsEnabled: Boolean = true,
    val overlayOpacity: Float = 0.72f,
)

@Composable
internal fun rememberControllerLabel(configuration: NESControllerConfiguration): String {
    val context = LocalContext.current
    val applicationLabel =
        remember(context.applicationContext) {
            context.applicationInfo.loadLabel(context.packageManager).toString()
        }
    return configuration.controllerLabel ?: applicationLabel
}
