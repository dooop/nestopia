// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing

@testable import NES

@Test func configurationKeepsROMURL() {
    let url = URL(fileURLWithPath: "/tmp/game.nes")
    #expect(NESConfiguration(romURL: url).romURL == url)
}

@Test func controllerConfigurationDefaultsToAdaptiveSystemTheme() {
    let configuration = NESControllerConfiguration()
    #expect(configuration.theme == .system)
    #expect(configuration.presentationMode == .automatic)
    #expect(configuration.hapticsEnabled)
    #expect(configuration.overlayOpacity == 0.72)
}

@Test func controllerConfigurationOffersOriginalThemes() {
    #expect(NESControllerConfiguration(theme: .nes).theme == .nes)
    #expect(NESControllerConfiguration(theme: .famicom).theme == .famicom)
}

@Test func controllerConfigurationClampsOverlayOpacity() {
    #expect(NESControllerConfiguration(overlayOpacity: -1).overlayOpacity == 0)
    #expect(NESControllerConfiguration(overlayOpacity: 2).overlayOpacity == 1)
}

@Test func controllerConfigurationPreservesCustomControllerLabel() {
    #expect(NESControllerConfiguration(controllerLabel: "My App").resolvedControllerLabel == "My App")
    #expect(NESControllerConfiguration(controllerLabel: "").resolvedControllerLabel.isEmpty)
}

@Test func externalControllerHidesOnScreenControls() {
    #expect(shouldShowOnScreenControls(requested: true, isTelevision: false, hasExternalController: false))
    #expect(!shouldShowOnScreenControls(requested: true, isTelevision: false, hasExternalController: true))
}

@Test func televisionNeverShowsControlsAndPromptsWithoutController() {
    #expect(!shouldShowOnScreenControls(requested: true, isTelevision: true, hasExternalController: false))
    #expect(shouldShowControllerConnectionPrompt(isTelevision: true, hasExternalController: false))
    #expect(!shouldShowControllerConnectionPrompt(isTelevision: true, hasExternalController: true))
}
