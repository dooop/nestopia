// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package nestopia

internal fun NESState.afterPauseRequest(): NESState =
    when (this) {
        NESState.Running -> NESState.Paused
        else -> this
    }

internal fun NESState.afterResumeRequest(): NESState =
    when (this) {
        NESState.Paused -> NESState.Running
        else -> this
    }
