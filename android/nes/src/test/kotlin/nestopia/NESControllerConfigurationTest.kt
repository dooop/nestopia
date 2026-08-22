package nestopia

import org.junit.Assert.assertEquals
import org.junit.Test

class NESControllerConfigurationTest {
    @Test
    fun defaultsToAdaptiveSystemTheme() {
        val configuration = NESControllerConfiguration()

        assertEquals(NESControllerTheme.System, configuration.theme)
        assertEquals(NESControllerPresentationMode.Automatic, configuration.presentationMode)
        assertEquals(0.72f, configuration.overlayOpacity)
    }
}
