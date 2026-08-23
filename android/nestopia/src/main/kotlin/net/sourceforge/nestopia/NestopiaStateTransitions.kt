// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

internal fun NestopiaState.afterPauseRequest(): NestopiaState =
    when (this) {
        NestopiaState.Running -> NestopiaState.Paused
        else -> this
    }

internal fun NestopiaState.afterResumeRequest(): NestopiaState =
    when (this) {
        NestopiaState.Paused -> NestopiaState.Running
        else -> this
    }
