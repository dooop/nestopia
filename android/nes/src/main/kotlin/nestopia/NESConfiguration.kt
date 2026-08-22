// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package nestopia

import android.net.Uri

data class NESConfiguration(
    val romUri: Uri,
    val automaticallyStarts: Boolean = true,
    val showsTouchControls: Boolean = true,
)

sealed interface NESState {
    data object Idle : NESState

    data object Loading : NESState

    data object Running : NESState

    data object Paused : NESState

    data object Stopped : NESState

    data class Failed(
        val message: String,
    ) : NESState
}

enum class NESButton(
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
