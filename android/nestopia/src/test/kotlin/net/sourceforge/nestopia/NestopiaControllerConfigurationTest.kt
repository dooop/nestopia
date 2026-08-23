// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NestopiaControllerConfigurationTest {
    @Test
    fun defaultsToAdaptiveSystemTheme() {
        val configuration = NestopiaControllerConfiguration()

        assertEquals(NestopiaControllerTheme.System, configuration.theme)
        assertEquals(NestopiaControllerPresentationMode.Automatic, configuration.presentationMode)
        assertTrue(configuration.hapticsEnabled)
        assertEquals(0.72f, configuration.overlayOpacity)
    }

    @Test
    fun offersOriginalThemes() {
        assertEquals(
            NestopiaControllerTheme.NES,
            NestopiaControllerConfiguration(theme = NestopiaControllerTheme.NES).theme,
        )
        assertEquals(
            NestopiaControllerTheme.Famicom,
            NestopiaControllerConfiguration(theme = NestopiaControllerTheme.Famicom).theme,
        )
    }

    @Test
    fun preservesCustomControllerLabel() {
        assertEquals("My App", NestopiaControllerConfiguration(controllerLabel = "My App").controllerLabel)
        assertEquals("", NestopiaControllerConfiguration(controllerLabel = "").controllerLabel)
    }
}
