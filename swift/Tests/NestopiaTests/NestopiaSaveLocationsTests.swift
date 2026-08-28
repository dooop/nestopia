// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing

@testable import Nestopia

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("nestopia-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func autosaveIsEnabledByDefault() {
    let configuration = NestopiaConfiguration(romURL: URL(fileURLWithPath: "/tmp/game.nes"))
    #expect(configuration.autosave.isEnabled)
    #expect(configuration.autosave.interval == NestopiaAutosaveConfiguration.defaultInterval)
    #expect(configuration.saveDirectory == nil)
}

@Test func autosaveKeepsConfiguredDirectoryAndSwitch() {
    let directory = URL(fileURLWithPath: "/tmp/saves", isDirectory: true)
    let configuration = NestopiaConfiguration(
        romURL: URL(fileURLWithPath: "/tmp/game.nes"),
        saveDirectory: directory,
        autosave: NestopiaAutosaveConfiguration(isEnabled: false)
    )
    #expect(configuration.saveDirectory == directory)
    #expect(!configuration.autosave.isEnabled)
}

@Test func autosaveIntervalNeverDropsBelowTheMinimum() {
    #expect(
        NestopiaAutosaveConfiguration(interval: 0).resolvedInterval
            == NestopiaAutosaveConfiguration.minimumInterval)
    #expect(NestopiaAutosaveConfiguration(interval: 120).resolvedInterval == 120)
}

@Test func sanitizedNameReplacesUnsupportedCharacters() {
    #expect(NestopiaSaveLocator.sanitized("Super Mario Bros. 3") == "Super-Mario-Bros.-3")
    #expect(NestopiaSaveLocator.sanitized("a/b\\c:d") == "a-b-c-d")
    #expect(NestopiaSaveLocator.sanitized("///") == NestopiaSaveLocator.fallbackDisplayName)
    #expect(NestopiaSaveLocator.sanitized("") == NestopiaSaveLocator.fallbackDisplayName)
    #expect(
        NestopiaSaveLocator.sanitized(String(repeating: "a", count: 80)).count
            == NestopiaSaveLocator.displayNameLimit)
}

@Test func identityAppendsTheContentDigest() {
    #expect(
        NestopiaSaveLocator.identity(
            displayName: "Zelda", digest: "a9993e364706816aba3e25717850c26c9cd0d89d")
            == "Zelda-a9993e364706816a")
    #expect(NestopiaSaveLocator.identity(displayName: "Zelda", digest: nil) == "Zelda")
    #expect(NestopiaSaveLocator.identity(displayName: "Zelda", digest: "") == "Zelda")
}

@Test func locationsUseDistinctBatteryAndAutosaveFiles() {
    let directory = URL(fileURLWithPath: "/tmp/saves", isDirectory: true)
    let locations = NestopiaSaveLocator.locations(directory: directory, identity: "Zelda-abc")
    #expect(locations.directory == directory)
    #expect(locations.battery.lastPathComponent == "Zelda-abc.sav")
    #expect(locations.autosave.lastPathComponent == "Zelda-abc.auto.nst")
}

@Test func digestIsStableForROMContents() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let rom = directory.appendingPathComponent("game.nes")
    try Data("abc".utf8).write(to: rom)
    #expect(NestopiaSaveLocator.digest(forROMAt: rom) == "a9993e364706816aba3e25717850c26c9cd0d89d")
    #expect(NestopiaSaveLocator.digest(forROMAt: directory.appendingPathComponent("nope")) == nil)
}

@Test func renamedROMKeepsItsSaveIdentity() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = directory.appendingPathComponent("game.nes")
    let renamed = directory.appendingPathComponent("game-copy.nes")
    try Data("abc".utf8).write(to: original)
    try Data("abc".utf8).write(to: renamed)
    #expect(
        NestopiaSaveLocator.digest(forROMAt: original)
            == NestopiaSaveLocator.digest(forROMAt: renamed))
}

@Test func legacyBatterySaveMovesToTheDigestKeyedFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacy = directory.appendingPathComponent("game.sav")
    let destination = directory.appendingPathComponent("game-0123456789abcdef.sav")
    try Data("battery".utf8).write(to: legacy)

    #expect(NestopiaSaveLocator.migrateLegacyBattery(from: [legacy], to: destination))
    #expect(FileManager.default.contents(atPath: destination.path) == Data("battery".utf8))
    #expect(!FileManager.default.fileExists(atPath: legacy.path))
}

@Test func migrationNeverOverwritesAnExistingSave() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacy = directory.appendingPathComponent("game.sav")
    let destination = directory.appendingPathComponent("game-0123456789abcdef.sav")
    try Data("legacy".utf8).write(to: legacy)
    try Data("current".utf8).write(to: destination)

    #expect(!NestopiaSaveLocator.migrateLegacyBattery(from: [legacy], to: destination))
    #expect(FileManager.default.contents(atPath: destination.path) == Data("current".utf8))
}

@Test func resolveCreatesTheConfiguredDirectoryAndMigratesTheLegacySave() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let rom = root.appendingPathComponent("Some Game.nes")
    try Data("abc".utf8).write(to: rom)
    let saveDirectory = root.appendingPathComponent("Saves", isDirectory: true)
    try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
    try Data("battery".utf8).write(to: saveDirectory.appendingPathComponent("Some Game.sav"))

    let locations = try NestopiaSaveLocator.resolve(romURL: rom, directory: saveDirectory)
    #expect(locations.directory == saveDirectory)
    #expect(locations.battery.lastPathComponent == "Some-Game-a9993e364706816a.sav")
    #expect(locations.autosave.lastPathComponent == "Some-Game-a9993e364706816a.auto.nst")
    #expect(FileManager.default.contents(atPath: locations.battery.path) == Data("battery".utf8))
}
