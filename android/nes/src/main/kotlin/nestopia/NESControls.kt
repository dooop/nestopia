package nestopia

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun NESControls(
    engine: NESEngine,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Bottom,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Control("▲", NESButton.Up, engine)
            Row {
                Control("◀", NESButton.Left, engine)
                Spacer(Modifier.size(52.dp))
                Control("▶", NESButton.Right, engine)
            }
            Control("▼", NESButton.Down, engine)
        }
        Column(horizontalAlignment = Alignment.End) {
            Row {
                Control("SELECT", NESButton.Select, engine, 54)
                Control("START", NESButton.Start, engine, 54)
            }
            Row {
                Control("B", NESButton.B, engine, 68)
                Control("A", NESButton.A, engine, 68)
            }
        }
    }
}

@Composable
private fun Control(
    label: String,
    button: NESButton,
    engine: NESEngine,
    size: Int = 52,
) {
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .background(Color.Black.copy(alpha = 0.72f), CircleShape)
                .pointerInput(button) {
                    detectTapGestures(
                        onPress = {
                            engine.setButton(button, true)
                            tryAwaitRelease()
                            engine.setButton(button, false)
                        },
                    )
                },
        contentAlignment = Alignment.Center,
    ) {
        Text(label, color = Color.White, fontWeight = FontWeight.Bold)
    }
}
