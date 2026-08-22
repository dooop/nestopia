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
