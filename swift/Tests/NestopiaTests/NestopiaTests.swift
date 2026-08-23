// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing

@testable import Nestopia

@Test func configurationKeepsROMURL() {
    let url = URL(fileURLWithPath: "/tmp/game.nes")
    #expect(NestopiaConfiguration(romURL: url).romURL == url)
}

@Test func controllerConfigurationDefaultsToAdaptiveSystemTheme() {
    let configuration = NestopiaControllerConfiguration()
    #expect(configuration.theme == .system)
    #expect(configuration.presentationMode == .automatic)
    #expect(configuration.hapticsEnabled)
    #expect(configuration.overlayOpacity == 0.72)
}

@Test func controllerConfigurationOffersOriginalThemes() {
    #expect(NestopiaControllerConfiguration(theme: .nes).theme == .nes)
    #expect(NestopiaControllerConfiguration(theme: .famicom).theme == .famicom)
}

@Test func controllerConfigurationClampsOverlayOpacity() {
    #expect(NestopiaControllerConfiguration(overlayOpacity: -1).overlayOpacity == 0)
    #expect(NestopiaControllerConfiguration(overlayOpacity: 2).overlayOpacity == 1)
}

@Test func controllerConfigurationPreservesCustomControllerLabel() {
    #expect(NestopiaControllerConfiguration(controllerLabel: "My App").resolvedControllerLabel == "My App")
    #expect(NestopiaControllerConfiguration(controllerLabel: "").resolvedControllerLabel.isEmpty)
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
