// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package nestopia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NESControllerConfigurationTest {
    @Test
    fun defaultsToAdaptiveSystemTheme() {
        val configuration = NESControllerConfiguration()

        assertEquals(NESControllerTheme.System, configuration.theme)
        assertEquals(NESControllerPresentationMode.Automatic, configuration.presentationMode)
        assertTrue(configuration.hapticsEnabled)
        assertEquals(0.72f, configuration.overlayOpacity)
    }

    @Test
    fun offersOriginalThemes() {
        assertEquals(NESControllerTheme.NES, NESControllerConfiguration(theme = NESControllerTheme.NES).theme)
        assertEquals(
            NESControllerTheme.Famicom,
            NESControllerConfiguration(theme = NESControllerTheme.Famicom).theme,
        )
    }

    @Test
    fun preservesCustomControllerLabel() {
        assertEquals("My App", NESControllerConfiguration(controllerLabel = "My App").controllerLabel)
        assertEquals("", NESControllerConfiguration(controllerLabel = "").controllerLabel)
    }
}
