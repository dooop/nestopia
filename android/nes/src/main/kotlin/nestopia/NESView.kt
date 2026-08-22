package nestopia

import android.content.res.Configuration
import android.view.KeyEvent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun NESView(
    engine: NESEngine,
    modifier: Modifier = Modifier,
    showsControls: Boolean = true,
    controllerConfiguration: NESControllerConfiguration = NESControllerConfiguration(),
) {
    val frame by engine.frame.collectAsStateWithLifecycle()
    val state by engine.state.collectAsStateWithLifecycle()
    val focusRequester = remember { FocusRequester() }
    val deviceConfiguration = LocalConfiguration.current
    val isTelevision =
        (deviceConfiguration.uiMode and Configuration.UI_MODE_TYPE_MASK) == Configuration.UI_MODE_TYPE_TELEVISION
    val hasExternalController = rememberHasExternalController()

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(
        modifier =
            modifier
                .background(Color.Black)
                .focusRequester(focusRequester)
                .focusable()
                .onKeyEvent { event ->
                    val button = event.nativeKeyEvent.toNESButton() ?: return@onKeyEvent false
                    engine.setButton(button, event.nativeKeyEvent.action == KeyEvent.ACTION_DOWN)
                    true
                },
        contentAlignment = Alignment.Center,
    ) {
        frame?.let {
            Image(
                bitmap = it.asImageBitmap(),
                contentDescription = "NES video",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
                filterQuality = FilterQuality.None,
            )
        } ?: when (val current = state) {
            NESState.Loading -> CircularProgressIndicator(color = Color.White)
            is NESState.Failed -> Text(current.message, color = Color.White)
            else -> Text("NES", color = Color.Gray)
        }

        if (hasExternalController || isTelevision) {
            NESExternalControllerInput(engine, Modifier.fillMaxSize())
        }

        if (shouldShowOnScreenControls(showsControls, isTelevision, hasExternalController)) {
            NESControls(
                engine = engine,
                configuration = controllerConfiguration,
                modifier =
                    Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxSize()
                        .wrapContentSize(Alignment.BottomCenter)
                        .padding(20.dp),
            )
        }

        if (shouldShowControllerConnectionPrompt(isTelevision, hasExternalController)) {
            Column(
                modifier =
                    Modifier
                        .background(Color.Black.copy(alpha = 0.72f), MaterialTheme.shapes.large)
                        .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("🎮", style = MaterialTheme.typography.displaySmall)
                Text(
                    "Connect a controller to play",
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                )
            }
        }
    }
}

internal fun shouldShowOnScreenControls(
    requested: Boolean,
    isTelevision: Boolean,
    hasExternalController: Boolean,
): Boolean = requested && !isTelevision && !hasExternalController

internal fun shouldShowControllerConnectionPrompt(
    isTelevision: Boolean,
    hasExternalController: Boolean,
): Boolean = isTelevision && !hasExternalController

private fun KeyEvent.toNESButton(): NESButton? =
    when (keyCode) {
        KeyEvent.KEYCODE_DPAD_UP -> NESButton.Up
        KeyEvent.KEYCODE_DPAD_DOWN -> NESButton.Down
        KeyEvent.KEYCODE_DPAD_LEFT -> NESButton.Left
        KeyEvent.KEYCODE_DPAD_RIGHT -> NESButton.Right
        KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_X -> NESButton.A
        KeyEvent.KEYCODE_BUTTON_B, KeyEvent.KEYCODE_Z -> NESButton.B
        KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_ENTER -> NESButton.Start
        KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_SPACE -> NESButton.Select
        else -> null
    }
