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
