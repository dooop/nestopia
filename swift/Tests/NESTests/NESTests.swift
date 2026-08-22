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
    #expect(configuration.overlayOpacity == 0.72)
}

@Test func controllerConfigurationClampsOverlayOpacity() {
    #expect(NESControllerConfiguration(overlayOpacity: -1).overlayOpacity == 0)
    #expect(NESControllerConfiguration(overlayOpacity: 2).overlayOpacity == 1)
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
