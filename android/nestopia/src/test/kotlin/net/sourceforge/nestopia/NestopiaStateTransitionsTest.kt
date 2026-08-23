// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import org.junit.Assert.assertEquals
import org.junit.Test

class NestopiaStateTransitionsTest {
    @Test
    fun resumeBeforeStartKeepsEngineIdle() {
        assertEquals(NestopiaState.Idle, NestopiaState.Idle.afterResumeRequest())
    }

    @Test
    fun lifecycleEventsDoNotInterruptLoading() {
        assertEquals(NestopiaState.Loading, NestopiaState.Loading.afterPauseRequest())
        assertEquals(NestopiaState.Loading, NestopiaState.Loading.afterResumeRequest())
    }

    @Test
    fun runningEngineCanPauseAndResume() {
        val paused = NestopiaState.Running.afterPauseRequest()

        assertEquals(NestopiaState.Paused, paused)
        assertEquals(NestopiaState.Running, paused.afterResumeRequest())
    }

    @Test
    fun terminalStatesIgnoreLifecycleEvents() {
        val failed = NestopiaState.Failed("failure")

        assertEquals(NestopiaState.Stopped, NestopiaState.Stopped.afterResumeRequest())
        assertEquals(failed, failed.afterPauseRequest())
        assertEquals(failed, failed.afterResumeRequest())
    }
}
