package nestopia

import androidx.compose.ui.graphics.Color

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
    val overlayOpacity: Float = 0.72f,
)
