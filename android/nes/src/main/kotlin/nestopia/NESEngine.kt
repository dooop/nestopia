package nestopia

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import nestopia.internal.NativeNES
import java.io.Closeable
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class NESEngine(
    context: Context,
    val configuration: NESConfiguration,
) : Closeable {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "Nestopia") }
    private val _state = MutableStateFlow<NESState>(NESState.Idle)
    private val _frame = MutableStateFlow<Bitmap?>(null)

    val state: StateFlow<NESState> = _state.asStateFlow()
    val frame: StateFlow<Bitmap?> = _frame.asStateFlow()

    @Volatile private var paused = false

    @Volatile private var stopped = false
    private var handle = 0L
    private var audioTrack: AudioTrack? = null
    private var ownsClaim = false
    private val nativeLock = Any()

    fun start() {
        if (_state.value !is NESState.Idle && _state.value !is NESState.Stopped) return
        if (!engineClaimed.compareAndSet(false, true)) {
            _state.value = NESState.Failed("In diesem Prozess läuft bereits eine NES-Engine.")
            return
        }
        ownsClaim = true
        stopped = false
        _state.value = NESState.Loading
        executor.execute(::prepareAndRun)
    }

    fun pause() {
        paused = true
        synchronized(nativeLock) { audioTrack?.pause() }
        _state.value = NESState.Paused
    }

    fun resume() {
        paused = false
        synchronized(nativeLock) { audioTrack?.play() }
        _state.value = NESState.Running
    }

    fun setButton(
        button: NESButton,
        pressed: Boolean,
        player: Int = 0,
    ) {
        synchronized(nativeLock) {
            if (handle != 0L) NativeNES.setButton(handle, player, button.mask, pressed)
        }
    }

    fun reset(hard: Boolean = false) {
        synchronized(nativeLock) {
            if (handle != 0L) NativeNES.reset(handle, hard)
        }
    }

    fun saveState(file: File): Boolean =
        synchronized(nativeLock) {
            handle != 0L && NativeNES.saveState(handle, file.path)
        }

    fun loadState(file: File): Boolean =
        synchronized(nativeLock) {
            handle != 0L && NativeNES.loadState(handle, file.path)
        }

    override fun close() {
        stopped = true
        executor.shutdownNow()
        synchronized(nativeLock) {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
            if (handle != 0L) NativeNES.destroy(handle)
            handle = 0
        }
        releaseClaim()
        _state.value = NESState.Stopped
    }

    private fun prepareAndRun() {
        try {
            val runtimeDirectory = File(appContext.filesDir, "NES").apply { mkdirs() }
            val database = File(runtimeDirectory, "NstDatabase.xml")
            if (!database.isFile) {
                appContext.assets.open("NstDatabase.xml").use { input ->
                    database.outputStream().use(input::copyTo)
                }
            }
            val rom = File(runtimeDirectory, "game-${configuration.romUri.toString().hashCode()}.nes")
            appContext.contentResolver.openInputStream(configuration.romUri).use { input ->
                requireNotNull(input) { "Die ROM-Datei konnte nicht geöffnet werden." }
                rom.outputStream().use(input::copyTo)
            }
            val saveDirectory = File(runtimeDirectory, "Saves").apply { mkdirs() }
            val save = File(saveDirectory, "${rom.nameWithoutExtension}.sav")

            synchronized(nativeLock) {
                if (stopped) return
                handle = NativeNES.create(database.path)
                check(handle != 0L) { "Nestopia konnte nicht initialisiert werden." }
                check(NativeNES.loadROM(handle, rom.path, save.path)) { NativeNES.lastError(handle) }
                audioTrack = createAudioTrack().also(AudioTrack::play)
            }
            _state.value = NESState.Running
            runLoop()
        } catch (error: Throwable) {
            if (stopped) return
            stopped = true
            synchronized(nativeLock) {
                if (handle != 0L) NativeNES.destroy(handle)
                handle = 0
            }
            audioTrack?.release()
            audioTrack = null
            releaseClaim()
            _state.value = NESState.Failed(error.message ?: "Unbekannter Nestopia-Fehler")
        }
    }

    private fun runLoop() {
        val pixels = IntArray(WIDTH * HEIGHT)
        val samples = ShortArray(MAX_AUDIO_SAMPLES)
        val frameNanos = (NativeNES.frameDuration(handle) * 1_000_000_000.0).toLong()
        var nextFrame = System.nanoTime()

        while (!stopped) {
            if (paused) {
                Thread.sleep(10)
                nextFrame = System.nanoTime()
                continue
            }
            val audioCount =
                synchronized(nativeLock) {
                    if (stopped || handle == 0L) return
                    if (!NativeNES.runFrame(handle)) {
                        _state.value = NESState.Failed(NativeNES.lastError(handle))
                        return
                    }
                    NativeNES.copyVideo(handle, pixels)
                    NativeNES.copyAudio(handle, samples)
                }
            _frame.value = Bitmap.createBitmap(pixels, WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
            if (audioCount > 0) {
                synchronized(nativeLock) {
                    audioTrack?.write(samples, 0, audioCount, AudioTrack.WRITE_BLOCKING)
                }
            }

            nextFrame += frameNanos
            val remaining = nextFrame - System.nanoTime()
            if (remaining > 0) {
                Thread.sleep(remaining / 1_000_000, (remaining % 1_000_000).toInt())
            } else {
                nextFrame = System.nanoTime()
            }
        }
    }

    private fun releaseClaim() {
        if (ownsClaim) {
            ownsClaim = false
            engineClaimed.set(false)
        }
    }

    private fun createAudioTrack(): AudioTrack {
        val minimum =
            AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
        return AudioTrack
            .Builder()
            .setAudioAttributes(
                AudioAttributes
                    .Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            ).setAudioFormat(
                AudioFormat
                    .Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build(),
            ).setBufferSizeInBytes(maxOf(minimum, MAX_AUDIO_SAMPLES * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    private companion object {
        const val WIDTH = 256
        const val HEIGHT = 240
        const val SAMPLE_RATE = 44_100
        const val MAX_AUDIO_SAMPLES = 1_024
        val engineClaimed = AtomicBoolean(false)
    }
}
