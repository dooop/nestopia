import SwiftUI

/// High-level SwiftUI host for one Nestopia ROM.
public struct NES: View {
    @StateObject private var engine: NESEngine
    private let configuration: NESConfiguration

    public init(configuration: NESConfiguration) {
        self.configuration = configuration
        _engine = StateObject(wrappedValue: NESEngine(configuration: configuration))
    }

    public init(rom: URL) {
        self.init(configuration: NESConfiguration(romURL: rom))
    }

    public var body: some View {
        NESView(engine: engine, showsControls: configuration.showsTouchControls)
            .onAppear {
                if configuration.automaticallyStarts { engine.start() }
            }
            .onDisappear { engine.stop() }
    }
}
