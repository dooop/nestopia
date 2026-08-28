// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import java.io.File
import java.security.MessageDigest

/** Absolute locations of the persistent files belonging to one game. */
internal data class NestopiaSaveLocations(
    /** Directory holding every persistent file of the session. */
    val directory: File,
    /** Cartridge battery/EEPROM contents, written by the emulated machine. */
    val battery: File,
    /** Automatic save state, written and restored by the wrapper. */
    val autosave: File,
)

/**
 * Derives save file locations from a stable game identity.
 *
 * The naming rule is mirrored by `NestopiaSaveLocations.swift` on Apple platforms
 * so both platforms address the same game with the same file name.
 */
internal object NestopiaSaveLocator {
    const val BATTERY_EXTENSION = "sav"
    const val AUTOSAVE_EXTENSION = "auto.nst"

    /** Hex characters of the ROM digest kept in a file name. */
    const val DIGEST_LENGTH = 16

    /** Longest sanitized display name kept in a file name. */
    const val DISPLAY_NAME_LIMIT = 48
    const val FALLBACK_DISPLAY_NAME = "game"

    /** Replaces everything outside `A-Z a-z 0-9 . _ -` so the name is safe on every file system. */
    fun sanitized(name: String): String {
        val builder = StringBuilder()
        for (character in name) {
            val allowed =
                character in 'a'..'z' ||
                    character in 'A'..'Z' ||
                    character in '0'..'9' ||
                    character == '.' ||
                    character == '_' ||
                    character == '-'
            if (allowed) {
                builder.append(character)
            } else if (builder.lastOrNull() != '-') {
                builder.append('-')
            }
        }
        val trimmed = builder.toString().take(DISPLAY_NAME_LIMIT).trim('-', '.')
        return trimmed.ifEmpty { FALLBACK_DISPLAY_NAME }
    }

    /** Combines a readable name with a content digest so renamed or moved ROMs keep their saves. */
    fun identity(
        displayName: String,
        digest: String?,
    ): String {
        val name = sanitized(displayName)
        return if (digest.isNullOrEmpty()) name else "$name-${digest.take(DIGEST_LENGTH)}"
    }

    fun locations(
        directory: File,
        identity: String,
    ): NestopiaSaveLocations =
        NestopiaSaveLocations(
            directory = directory,
            battery = File(directory, "$identity.$BATTERY_EXTENSION"),
            autosave = File(directory, "$identity.$AUTOSAVE_EXTENSION"),
        )

    /** Lowercase SHA-1 of the ROM contents, or null when the file cannot be read. */
    fun digest(rom: File): String? =
        runCatching {
            val digest = MessageDigest.getInstance("SHA-1")
            rom.inputStream().use { stream ->
                val buffer = ByteArray(1 shl 16)
                while (true) {
                    val read = stream.read(buffer)
                    if (read <= 0) break
                    digest.update(buffer, 0, read)
                }
            }
            digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xFF) }
        }.getOrNull()

    /** Moves the first existing legacy battery file onto [destination] when that file is missing. */
    fun migrateLegacyBattery(
        candidates: List<File>,
        destination: File,
    ): Boolean {
        if (destination.exists()) return false
        val legacy =
            candidates.firstOrNull { it.absolutePath != destination.absolutePath && it.isFile }
                ?: return false
        destination.parentFile?.mkdirs()
        if (legacy.renameTo(destination)) return true
        return runCatching {
            legacy.copyTo(destination, overwrite = false)
            legacy.delete()
            true
        }.getOrDefault(false)
    }
}
