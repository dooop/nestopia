// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import android.net.Uri

data class NestopiaConfiguration(
    val romUri: Uri,
    val automaticallyStarts: Boolean = true,
    val showsTouchControls: Boolean = true,
)

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
