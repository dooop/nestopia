// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import CryptoKit
import Foundation

/// Controls the automatic save state written and restored for one Nestopia session.
public struct NestopiaAutosaveConfiguration: Sendable, Equatable {
    /// Seconds between two periodic autosaves.
    public static let defaultInterval: TimeInterval = 30
    /// Shortest interval honored by the engine, regardless of the configured value.
    public static let minimumInterval: TimeInterval = 5

    /// Restores the previous autosave on start and keeps writing it while the game runs.
    public var isEnabled: Bool
    /// Seconds between two periodic autosaves. Values below ``minimumInterval`` are raised.
    public var interval: TimeInterval

    public init(
        isEnabled: Bool = true,
        interval: TimeInterval = NestopiaAutosaveConfiguration.defaultInterval
    ) {
        self.isEnabled = isEnabled
        self.interval = interval
    }

    var resolvedInterval: TimeInterval {
        max(Self.minimumInterval, interval)
    }
}

/// Absolute locations of the persistent files belonging to one game.
struct NestopiaSaveLocations: Equatable {
    /// Directory holding every persistent file of the session.
    let directory: URL
    /// Cartridge battery/EEPROM contents, written by the emulated machine.
    let battery: URL
    /// Automatic save state, written and restored by the wrapper.
    let autosave: URL
}

/// Derives save file locations from a stable game identity.
///
/// The naming rule is mirrored by `NestopiaSaveLocations.kt` on Android so both
/// platforms address the same game with the same file name.
enum NestopiaSaveLocator {
    static let batteryExtension = "sav"
    static let autosaveExtension = "auto.nst"
    /// Hex characters of the ROM digest kept in a file name.
    static let digestLength = 16
    /// Longest sanitized display name kept in a file name.
    static let displayNameLimit = 48
    static let fallbackDisplayName = "game"

    /// Replaces everything outside `A-Z a-z 0-9 . _ -` so the name is safe on every file system.
    static func sanitized(_ name: String) -> String {
        var result = ""
        for scalar in name.unicodeScalars {
            let isAllowed =
                (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z")
                || (scalar >= "0" && scalar <= "9") || scalar == "." || scalar == "_"
                || scalar == "-"
            if isAllowed {
                result.unicodeScalars.append(scalar)
            } else if result.last != "-" {
                result.append("-")
            }
        }
        result = String(result.prefix(displayNameLimit))
        while let last = result.last, last == "-" || last == "." { result.removeLast() }
        while let first = result.first, first == "-" || first == "." { result.removeFirst() }
        return result.isEmpty ? fallbackDisplayName : result
    }

    /// Combines a readable name with a content digest so renamed or moved ROMs keep their saves.
    static func identity(displayName: String, digest: String?) -> String {
        let name = sanitized(displayName)
        guard let digest, !digest.isEmpty else { return name }
        return "\(name)-\(digest.prefix(digestLength))"
    }

    static func locations(directory: URL, identity: String) -> NestopiaSaveLocations {
        NestopiaSaveLocations(
            directory: directory,
            battery: directory.appendingPathComponent("\(identity).\(batteryExtension)"),
            autosave: directory.appendingPathComponent("\(identity).\(autosaveExtension)")
        )
    }

    /// Lowercase SHA-1 of the ROM contents, or `nil` when the file cannot be read.
    static func digest(forROMAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = Insecure.SHA1()
        while let chunk = try? handle.read(upToCount: 1 << 16), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Default directory used when the configuration does not name one.
    static func defaultDirectory() -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Nestopia/Saves", isDirectory: true)
    }

    /// Battery files written before saves were keyed by content digest.
    static func legacyBatteryURLs(romURL: URL, directory: URL) -> [URL] {
        let rawName = romURL.deletingPathExtension().lastPathComponent
        guard !rawName.isEmpty else { return [] }
        let fileName = "\(rawName).\(batteryExtension)"
        var candidates = [directory.appendingPathComponent(fileName)]
        guard
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return candidates }
        for legacyDirectory in ["Nestopia/Saves", "NES/Saves"] {
            candidates.append(
                applicationSupport
                    .appendingPathComponent(legacyDirectory, isDirectory: true)
                    .appendingPathComponent(fileName)
            )
        }
        return candidates
    }

    /// Moves the first existing legacy battery file onto `destination` when that file is missing.
    @discardableResult
    static func migrateLegacyBattery(from candidates: [URL], to destination: URL) -> Bool {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { return false }
        guard
            let legacy = candidates.first(where: {
                $0.standardizedFileURL != destination.standardizedFileURL
                    && manager.fileExists(atPath: $0.path)
            })
        else { return false }
        do {
            try manager.moveItem(at: legacy, to: destination)
            return true
        } catch {
            guard (try? manager.copyItem(at: legacy, to: destination)) != nil else { return false }
            try? manager.removeItem(at: legacy)
            return true
        }
    }

    /// Resolves, creates, and migrates the save locations for one session.
    static func resolve(romURL: URL, directory: URL?) throws -> NestopiaSaveLocations {
        let resolvedDirectory = directory ?? defaultDirectory()
        try FileManager.default.createDirectory(
            at: resolvedDirectory, withIntermediateDirectories: true)
        let locations = locations(
            directory: resolvedDirectory,
            identity: identity(
                displayName: romURL.deletingPathExtension().lastPathComponent,
                digest: digest(forROMAt: romURL)
            )
        )
        migrateLegacyBattery(
            from: legacyBatteryURLs(romURL: romURL, directory: resolvedDirectory),
            to: locations.battery
        )
        return locations
    }
}
