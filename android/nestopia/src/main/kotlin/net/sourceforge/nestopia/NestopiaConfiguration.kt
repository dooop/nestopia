// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import android.net.Uri
import java.io.File

data class NestopiaConfiguration(
    val romUri: Uri,
    val automaticallyStarts: Boolean = true,
    val showsTouchControls: Boolean = true,
    /** Directory holding the battery save and the autosave. Null uses `filesDir/Nestopia/Saves`. */
    val saveDirectory: File? = null,
    /** Automatic save state behavior. Enabled by default. */
    val autosave: NestopiaAutosaveConfiguration = NestopiaAutosaveConfiguration(),
)

/** Controls the automatic save state written and restored for one Nestopia session. */
data class NestopiaAutosaveConfiguration(
    /** Restores the previous autosave on start and keeps writing it while the game runs. */
    val isEnabled: Boolean = true,
    /** Seconds between two periodic autosaves. Values below [MINIMUM_INTERVAL_SECONDS] are raised. */
    val intervalSeconds: Long = DEFAULT_INTERVAL_SECONDS,
) {
    internal val resolvedIntervalSeconds: Long
        get() = maxOf(MINIMUM_INTERVAL_SECONDS, intervalSeconds)

    companion object {
        /** Seconds between two periodic autosaves. */
        const val DEFAULT_INTERVAL_SECONDS = 30L

        /** Shortest interval honored by the engine, regardless of the configured value. */
        const val MINIMUM_INTERVAL_SECONDS = 5L
    }
}

sealed interface NestopiaState {
    data object Idle : NestopiaState

    data object Loading : NestopiaState

    data object Running : NestopiaState

    data object Paused : NestopiaState

    data object Stopped : NestopiaState

    data class Failed(
        val message: String,
    ) : NestopiaState
}

enum class NestopiaButton(
    val mask: Int,
) {
    A(0x01),
    B(0x02),
    Select(0x04),
    Start(0x08),
    Up(0x10),
    Down(0x20),
    Left(0x40),
    Right(0x80),
}
