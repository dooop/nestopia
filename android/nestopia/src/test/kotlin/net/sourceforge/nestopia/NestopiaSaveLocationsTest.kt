// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class NestopiaSaveLocationsTest {
    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun autosaveIsEnabledByDefault() {
        val autosave = NestopiaAutosaveConfiguration()

        assertTrue(autosave.isEnabled)
        assertEquals(NestopiaAutosaveConfiguration.DEFAULT_INTERVAL_SECONDS, autosave.intervalSeconds)
    }

    @Test
    fun autosaveIntervalNeverDropsBelowTheMinimum() {
        assertEquals(
            NestopiaAutosaveConfiguration.MINIMUM_INTERVAL_SECONDS,
            NestopiaAutosaveConfiguration(intervalSeconds = 0).resolvedIntervalSeconds,
        )
        assertEquals(120L, NestopiaAutosaveConfiguration(intervalSeconds = 120).resolvedIntervalSeconds)
    }

    @Test
    fun sanitizedNameReplacesUnsupportedCharacters() {
        assertEquals("Super-Mario-Bros.-3", NestopiaSaveLocator.sanitized("Super Mario Bros. 3"))
        assertEquals("a-b-c-d", NestopiaSaveLocator.sanitized("a/b\\c:d"))
        assertEquals(NestopiaSaveLocator.FALLBACK_DISPLAY_NAME, NestopiaSaveLocator.sanitized("///"))
        assertEquals(NestopiaSaveLocator.FALLBACK_DISPLAY_NAME, NestopiaSaveLocator.sanitized(""))
        assertEquals(
            NestopiaSaveLocator.DISPLAY_NAME_LIMIT,
            NestopiaSaveLocator.sanitized("a".repeat(80)).length,
        )
    }

    @Test
    fun identityAppendsTheContentDigest() {
        assertEquals(
            "Zelda-a9993e364706816a",
            NestopiaSaveLocator.identity("Zelda", "a9993e364706816aba3e25717850c26c9cd0d89d"),
        )
        assertEquals("Zelda", NestopiaSaveLocator.identity("Zelda", null))
        assertEquals("Zelda", NestopiaSaveLocator.identity("Zelda", ""))
    }

    @Test
    fun locationsUseDistinctBatteryAndAutosaveFiles() {
        val directory = folder.newFolder("Saves")

        val locations = NestopiaSaveLocator.locations(directory, "Zelda-abc")

        assertEquals(directory, locations.directory)
        assertEquals("Zelda-abc.sav", locations.battery.name)
        assertEquals("Zelda-abc.auto.nst", locations.autosave.name)
    }

    @Test
    fun digestIsStableForROMContents() {
        val rom = folder.newFile("game.nes").apply { writeText("abc") }
        val renamed = folder.newFile("game-copy.nes").apply { writeText("abc") }

        assertEquals("a9993e364706816aba3e25717850c26c9cd0d89d", NestopiaSaveLocator.digest(rom))
        assertEquals(NestopiaSaveLocator.digest(rom), NestopiaSaveLocator.digest(renamed))
        assertNull(NestopiaSaveLocator.digest(File(folder.root, "missing.nes")))
    }

    @Test
    fun largeROMsAreHashedInChunks() {
        val rom = folder.newFile("big.nes").apply { writeBytes(ByteArray(300_000) { 0x41 }) }

        assertEquals(40, NestopiaSaveLocator.digest(rom)?.length)
    }

    @Test
    fun legacyBatterySaveMovesToTheDigestKeyedFile() {
        val legacy = folder.newFile("game-12345.sav").apply { writeText("battery") }
        val destination = File(folder.root, "game-0123456789abcdef.sav")

        assertTrue(NestopiaSaveLocator.migrateLegacyBattery(listOf(legacy), destination))
        assertEquals("battery", destination.readText())
        assertFalse(legacy.exists())
    }

    @Test
    fun migrationNeverOverwritesAnExistingSave() {
        val legacy = folder.newFile("game-12345.sav").apply { writeText("legacy") }
        val destination = folder.newFile("game-0123456789abcdef.sav").apply { writeText("current") }

        assertFalse(NestopiaSaveLocator.migrateLegacyBattery(listOf(legacy), destination))
        assertEquals("current", destination.readText())
        assertTrue(legacy.exists())
    }

    @Test
    fun migrationIgnoresMissingCandidates() {
        val destination = File(folder.root, "game-0123456789abcdef.sav")

        assertFalse(NestopiaSaveLocator.migrateLegacyBattery(listOf(File(folder.root, "absent.sav")), destination))
        assertFalse(destination.exists())
    }
}
