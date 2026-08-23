// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import CNestopiaCore
import Combine
import CoreGraphics
import Foundation

/// Owns the process-wide native Nestopia session and its frame loop.
public final class NestopiaEngine: ObservableObject {
    private static let claimLock = NSLock()
    private static var engineClaimed = false

    @Published public private(set) var state: NestopiaState = .idle
    @Published public private(set) var frame: CGImage?
    @Published public private(set) var hasConnectedController = false

    public let configuration: NestopiaConfiguration

    private let queue = DispatchQueue(label: "nestopia.swift.engine", qos: .userInteractive)
    private var core: OpaquePointer?
    private var timer: DispatchSourceTimer?
    private var audio: NestopiaAudioOutput?
    private var controller: NestopiaGameController?
    private var paused = false
    private var securityScopedROM = false
    private var ownsClaim = false

    public init(configuration: NestopiaConfiguration) {
        self.configuration = configuration
    }

    deinit {
        stopSynchronously()
    }

    public func start() {
        guard state == .idle || state == .stopped else { return }
        if controller == nil {
            controller = NestopiaGameController(engine: self) { [weak self] connected in
                self?.hasConnectedController = connected
            }
        }
        Self.claimLock.lock()
        guard !Self.engineClaimed else {
            Self.claimLock.unlock()
            state = .failed("In diesem Prozess läuft bereits eine Nestopia-Engine.")
            return
        }
        Self.engineClaimed = true
        ownsClaim = true
        Self.claimLock.unlock()
        state = .loading
        let configuration = configuration

        queue.async { [weak self] in
            guard let self else { return }
            self.securityScopedROM = configuration.romURL.startAccessingSecurityScopedResource()
            let databasePath = Bundle.module.url(forResource: "NstDatabase", withExtension: "xml")?
                .path
            guard let core = nestopia_engine_create(databasePath) else {
                self.fail("Nestopia konnte nicht initialisiert werden.")
                return
            }
            self.core = core

            let saveURL = self.saveURL(
                for: configuration.romURL, directory: configuration.saveDirectory)
            do {
                try FileManager.default.createDirectory(
                    at: saveURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            } catch {
                self.fail(
                    "Der Speicherordner konnte nicht erstellt werden: \(error.localizedDescription)"
                )
                return
            }

            guard nestopia_engine_load_rom(core, configuration.romURL.path, saveURL.path) else {
                let message = String(cString: nestopia_engine_last_error(core))
                self.fail(message)
                return
            }

            self.audio = NestopiaAudioOutput()
            self.audio?.start()
            self.installTimer(core: core)
            DispatchQueue.main.async {
                self.state = .running
            }
        }
    }

    public func pause() {
        queue.async { [weak self] in
            self?.paused = true
            self?.audio?.pause()
            DispatchQueue.main.async { self?.state = .paused }
        }
    }

    public func resume() {
        queue.async { [weak self] in
            self?.paused = false
            self?.audio?.resume()
            DispatchQueue.main.async { self?.state = .running }
        }
    }

    public func stop() {
        queue.async { [weak self] in self?.stopSynchronously() }
    }

    public func reset(hard: Bool = false) {
        queue.async { [weak self] in
            guard let core = self?.core else { return }
            nestopia_engine_reset(core, hard)
        }
    }

    public func setButton(_ button: NestopiaControllerButton, player: Int = 0, pressed: Bool) {
        queue.async { [weak self] in
            guard let core = self?.core else { return }
            let nativeButton = NestopiaButton(rawValue: UInt32(button.rawValue))
            nestopia_engine_set_button(core, UInt32(player), nativeButton, pressed)
        }
    }

    @discardableResult
    public func saveState(to url: URL) -> Bool {
        queue.sync {
            guard let core else { return false }
            return nestopia_engine_save_state(core, url.path)
        }
    }

    @discardableResult
    public func loadState(from url: URL) -> Bool {
        queue.sync {
            guard let core else { return false }
            return nestopia_engine_load_state(core, url.path)
        }
    }

    private func installTimer(core: OpaquePointer) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let duration = nestopia_engine_frame_duration(core)
        timer.schedule(deadline: .now(), repeating: duration, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.runFrame(core: core) }
        self.timer = timer
        timer.resume()
    }

    private func runFrame(core: OpaquePointer) {
        guard !paused, nestopia_engine_run_frame(core) else { return }

        if let audioSamples = nestopia_engine_audio_buffer(core) {
            audio?.enqueue(
                samples: audioSamples,
                count: Int(nestopia_engine_audio_sample_count(core))
            )
        }

        guard let pixels = nestopia_engine_video_buffer(core) else { return }
        let byteCount = Int(nestopia_engine_video_pixel_count()) * MemoryLayout<UInt32>.size
        let data = Data(bytes: pixels, count: byteCount)
        guard let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(
                width: 256,
                height: 240,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 256 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return }
        DispatchQueue.main.async { [weak self] in self?.frame = image }
    }

    private func saveURL(for romURL: URL, directory: URL?) -> URL {
        if let directory {
            return
                directory
                .appendingPathComponent(romURL.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("sav")
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let fileName = romURL.deletingPathExtension().lastPathComponent
        let baseDirectory = applicationSupport.appendingPathComponent(
            "Nestopia/Saves", isDirectory: true)
        let destination =
            baseDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("sav")
        let legacySave =
            applicationSupport
            .appendingPathComponent("NES/Saves", isDirectory: true)
            .appendingPathComponent(fileName)
            .appendingPathExtension("sav")

        if !FileManager.default.fileExists(atPath: destination.path),
            FileManager.default.fileExists(atPath: legacySave.path)
        {
            try? FileManager.default.createDirectory(
                at: baseDirectory, withIntermediateDirectories: true)
            do {
                try FileManager.default.moveItem(at: legacySave, to: destination)
            } catch {
                try? FileManager.default.copyItem(at: legacySave, to: destination)
            }
        }
        return destination
    }

    private func fail(_ message: String) {
        stopSynchronously(finalState: .failed(message))
    }

    private func stopSynchronously(finalState: NestopiaState = .stopped) {
        timer?.cancel()
        timer = nil
        audio?.stop()
        audio = nil
        if let core {
            nestopia_engine_destroy(core)
            self.core = nil
        }
        if securityScopedROM {
            configuration.romURL.stopAccessingSecurityScopedResource()
            securityScopedROM = false
        }
        if ownsClaim {
            Self.claimLock.lock()
            Self.engineClaimed = false
            ownsClaim = false
            Self.claimLock.unlock()
        }
        DispatchQueue.main.async { [weak self] in
            self?.controller = nil
            self?.hasConnectedController = false
            self?.state = finalState
        }
    }
}
