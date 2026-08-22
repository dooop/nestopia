import Foundation
import Testing

@testable import NES

@Test func configurationKeepsROMURL() {
    let url = URL(fileURLWithPath: "/tmp/game.nes")
    #expect(NESConfiguration(romURL: url).romURL == url)
}
