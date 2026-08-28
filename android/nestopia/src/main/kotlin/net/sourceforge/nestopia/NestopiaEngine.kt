// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

package net.sourceforge.nestopia

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.provider.OpenableColumns
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import net.sourceforge.nestopia.internal.NativeNestopia
import java.io.Closeable
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class NestopiaEngine(
    context: Context,
    val configuration: NestopiaConfiguration,
) : Closeable {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "Nestopia") }
    private val _state = MutableStateFlow<NestopiaState>(NestopiaState.Idle)
    private val _frame = MutableStateFlow<Bitmap?>(null)

    val state: StateFlow<NestopiaState> = _state.asStateFlow()
    val frame: StateFlow<Bitmap?> = _frame.asStateFlow()

    @Volatile private var paused = false

    @Volatile private var stopped = false
    private var handle = 0L
    private var audioTrack: AudioTrack? = null
    private var ownsClaim = false
    private var saveLocations: NestopiaSaveLocations? = null
    private val nativeLock = Any()

    fun start() {
        if (_state.value !is NestopiaState.Idle && _state.value !is NestopiaState.Stopped) return
        if (!engineClaimed.compareAndSet(false, true)) {
            _state.value = NestopiaState.Failed("In diesem Prozess läuft bereits eine Nestopia-Engine.")
            return
        }
        ownsClaim = true
        stopped = false
        _state.value = NestopiaState.Loading
        executor.execute(::prepareAndRun)
    }

    fun pause() {
        val currentState = _state.value
        val nextState = currentState.afterPauseRequest()
        if (nextState == currentState) return
        paused = true
        synchronized(nativeLock) {
            audioTrack?.pause()
            writeAutosave()
        }
        _state.value = nextState
    }

    fun resume() {
        val currentState = _state.value
        val nextState = currentState.afterResumeRequest()
        if (nextState == currentState) return
        paused = false
        synchronized(nativeLock) { audioTrack?.play() }
        _state.value = nextState
    }

    fun setButton(
        button: NestopiaButton,
        pressed: Boolean,
        player: Int = 0,
    ) {
        synchronized(nativeLock) {
            if (handle != 0L) NativeNestopia.setButton(handle, player, button.mask, pressed)
        }
    }

    fun reset(hard: Boolean = false) {
        synchronized(nativeLock) {
            if (handle != 0L) NativeNestopia.reset(handle, hard)
        }
    }

    fun saveState(file: File): Boolean =
        synchronized(nativeLock) {
            handle != 0L && NativeNestopia.saveState(handle, file.path)
        }

    fun loadState(file: File): Boolean =
        synchronized(nativeLock) {
            handle != 0L && NativeNestopia.loadState(handle, file.path)
        }

    /** Location of the automatic save state, once the session resolved its save directory. */
    val autosaveFile: File?
        get() = synchronized(nativeLock) { saveLocations?.autosave }

    /** Writes the automatic save state now. Does nothing while autosave is disabled. */
    fun autosave(): Boolean = synchronized(nativeLock) { writeAutosave() }

    /**
     * Removes the automatic save state so the next start begins a fresh game. A session that is
     * still running writes it again, so call this after [close].
     */
    fun clearAutosave(): Boolean = synchronized(nativeLock) { saveLocations?.autosave?.delete() == true }

    override fun close() {
        stopped = true
        executor.shutdownNow()
        synchronized(nativeLock) {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
            writeAutosave()
            if (handle != 0L) NativeNestopia.destroy(handle)
            handle = 0
            saveLocations = null
        }
        releaseClaim()
        _state.value = NestopiaState.Stopped
    }

    private fun prepareAndRun() {
        try {
            val runtimeDirectory = migrateRuntimeDirectory()
            val database = File(runtimeDirectory, "NstDatabase.xml")
            if (!database.isFile) {
                appContext.assets.open("NstDatabase.xml").use { input ->
                    database.outputStream().use(input::copyTo)
                }
            }
            val rom = cacheROM(runtimeDirectory)
            val locations = resolveSaveLocations(runtimeDirectory, rom.identity)

            synchronized(nativeLock) {
                if (stopped) return
                handle = NativeNestopia.create(database.path)
                check(handle != 0L) { "Nestopia konnte nicht initialisiert werden." }
                check(NativeNestopia.loadROM(handle, rom.file.path, locations.battery.path)) {
                    NativeNestopia.lastError(handle)
                }
                saveLocations = locations
                // A stale or incompatible autosave must not keep the game from starting.
                if (configuration.autosave.isEnabled && locations.autosave.isFile) {
                    NativeNestopia.loadState(handle, locations.autosave.path)
                }
                audioTrack = createAudioTrack().also(AudioTrack::play)
            }
            _state.value = NestopiaState.Running
            runLoop()
        } catch (error: Throwable) {
            if (stopped) return
            stopped = true
            synchronized(nativeLock) {
                if (handle != 0L) NativeNestopia.destroy(handle)
                handle = 0
            }
            audioTrack?.release()
            audioTrack = null
            saveLocations = null
            releaseClaim()
            _state.value = NestopiaState.Failed(error.message ?: "Unbekannter Nestopia-Fehler")
        }
    }

    /**
     * Copies the selected ROM into private storage and names it after its content digest so the
     * save identity survives renames, re-picked documents, and changed content URIs.
     */
    private fun cacheROM(runtimeDirectory: File): CachedROM {
        val romDirectory = File(runtimeDirectory, "ROMs").apply { mkdirs() }
        val incoming = File(romDirectory, "incoming.tmp")
        appContext.contentResolver.openInputStream(configuration.romUri).use { input ->
            requireNotNull(input) { "Die ROM-Datei konnte nicht geöffnet werden." }
            incoming.outputStream().use(input::copyTo)
        }
        val identity = NestopiaSaveLocator.identity(romDisplayName(), NestopiaSaveLocator.digest(incoming))
        val destination = File(romDirectory, "$identity.nes")
        destination.delete()
        if (!incoming.renameTo(destination)) {
            incoming.copyTo(destination, overwrite = true)
            incoming.delete()
        }
        runtimeDirectory.listFiles { file -> file.isFile && file.name.startsWith("game-") }?.forEach(File::delete)
        return CachedROM(destination, identity)
    }

    private fun romDisplayName(): String {
        val provided =
            runCatching {
                appContext.contentResolver
                    .query(configuration.romUri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor -> if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null }
            }.getOrNull()
        val name = (provided ?: configuration.romUri.lastPathSegment).orEmpty().substringAfterLast('/')
        return name.substringBeforeLast('.', name).ifEmpty { NestopiaSaveLocator.FALLBACK_DISPLAY_NAME }
    }

    private fun resolveSaveLocations(
        runtimeDirectory: File,
        identity: String,
    ): NestopiaSaveLocations {
        val defaultDirectory = File(runtimeDirectory, "Saves")
        val directory = (configuration.saveDirectory ?: defaultDirectory).apply { mkdirs() }
        val locations = NestopiaSaveLocator.locations(directory, identity)
        val legacyName = "game-${configuration.romUri.toString().hashCode()}.${NestopiaSaveLocator.BATTERY_EXTENSION}"
        NestopiaSaveLocator.migrateLegacyBattery(
            listOf(File(directory, legacyName), File(defaultDirectory, legacyName)),
            locations.battery,
        )
        return locations
    }

    /** Must run while [nativeLock] is held so the native handle stays serialized. */
    private fun writeAutosave(): Boolean {
        if (!configuration.autosave.isEnabled || handle == 0L) return false
        val autosave = saveLocations?.autosave ?: return false
        return NativeNestopia.saveState(handle, autosave.path)
    }

    private fun migrateRuntimeDirectory(): File {
        val destination = File(appContext.filesDir, "Nestopia")
        val legacy = File(appContext.filesDir, "NES")
        if (!destination.exists() && legacy.isDirectory && !legacy.renameTo(destination)) {
            legacy.walkTopDown().forEach { source ->
                val relativePath = source.relativeTo(legacy).path
                val target = if (relativePath.isEmpty()) destination else File(destination, relativePath)
                if (source.isDirectory) {
                    target.mkdirs()
                } else if (!target.exists()) {
                    target.parentFile?.mkdirs()
                    source.copyTo(target)
                }
            }
        }
        destination.mkdirs()
        return destination
    }

    private fun runLoop() {
        val pixels = IntArray(WIDTH * HEIGHT)
        val samples = ShortArray(MAX_AUDIO_SAMPLES)
        val frameNanos = (NativeNestopia.frameDuration(handle) * 1_000_000_000.0).toLong()
        val autosaveNanos =
            if (configuration.autosave.isEnabled) {
                configuration.autosave.resolvedIntervalSeconds * 1_000_000_000L
            } else {
                0L
            }
        var nextFrame = System.nanoTime()
        var nextAutosave = nextFrame + autosaveNanos

        while (!stopped) {
            if (paused) {
                Thread.sleep(10)
                nextFrame = System.nanoTime()
                nextAutosave = nextFrame + autosaveNanos
                continue
            }
            val audioCount =
                synchronized(nativeLock) {
                    if (stopped || handle == 0L) return
                    if (!NativeNestopia.runFrame(handle)) {
                        _state.value = NestopiaState.Failed(NativeNestopia.lastError(handle))
                        return
                    }
                    NativeNestopia.copyVideo(handle, pixels)
                    NativeNestopia.copyAudio(handle, samples)
                }
            _frame.value = Bitmap.createBitmap(pixels, WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
            if (audioCount > 0) {
                synchronized(nativeLock) {
                    audioTrack?.write(samples, 0, audioCount, AudioTrack.WRITE_BLOCKING)
                }
            }

            if (autosaveNanos > 0L && System.nanoTime() >= nextAutosave) {
                synchronized(nativeLock) { writeAutosave() }
                nextAutosave = System.nanoTime() + autosaveNanos
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

    private data class CachedROM(
        val file: File,
        val identity: String,
    )

    private companion object {
        const val WIDTH = 256
        const val HEIGHT = 240
        const val SAMPLE_RATE = 44_100
        const val MAX_AUDIO_SAMPLES = 1_024
        val engineClaimed = AtomicBoolean(false)
    }
}
