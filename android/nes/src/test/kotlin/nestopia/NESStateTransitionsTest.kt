// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package nestopia

import org.junit.Assert.assertEquals
import org.junit.Test

class NESStateTransitionsTest {
    @Test
    fun resumeBeforeStartKeepsEngineIdle() {
        assertEquals(NESState.Idle, NESState.Idle.afterResumeRequest())
    }

    @Test
    fun lifecycleEventsDoNotInterruptLoading() {
        assertEquals(NESState.Loading, NESState.Loading.afterPauseRequest())
        assertEquals(NESState.Loading, NESState.Loading.afterResumeRequest())
    }

    @Test
    fun runningEngineCanPauseAndResume() {
        val paused = NESState.Running.afterPauseRequest()

        assertEquals(NESState.Paused, paused)
        assertEquals(NESState.Running, paused.afterResumeRequest())
    }

    @Test
    fun terminalStatesIgnoreLifecycleEvents() {
        val failed = NESState.Failed("failure")

        assertEquals(NESState.Stopped, NESState.Stopped.afterResumeRequest())
        assertEquals(failed, failed.afterPauseRequest())
        assertEquals(failed, failed.afterResumeRequest())
    }
}
