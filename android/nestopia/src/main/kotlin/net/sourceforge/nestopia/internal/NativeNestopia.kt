// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia.internal

internal object NativeNestopia {
    init {
        System.loadLibrary("nestopia")
    }

    external fun create(databasePath: String): Long

    external fun destroy(handle: Long)

    external fun loadROM(
        handle: Long,
        romPath: String,
        savePath: String,
    ): Boolean

    external fun runFrame(handle: Long): Boolean

    external fun frameDuration(handle: Long): Double

    external fun copyVideo(
        handle: Long,
        destination: IntArray,
    )

    external fun copyAudio(
        handle: Long,
        destination: ShortArray,
    ): Int

    external fun setButton(
        handle: Long,
        player: Int,
        button: Int,
        pressed: Boolean,
    )

    external fun reset(
        handle: Long,
        hardReset: Boolean,
    )

    external fun saveState(
        handle: Long,
        path: String,
    ): Boolean

    external fun loadState(
        handle: Long,
        path: String,
    ): Boolean

    external fun lastError(handle: Long): String
}
