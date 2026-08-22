import SwiftUI

/// High-level SwiftUI host for one Nestopia ROM.
public struct NES: View {
    @StateObject private var engine: NESEngine
    private let configuration: NESConfiguration
    private let controllerConfiguration: NESControllerConfiguration

    public init(
        configuration: NESConfiguration,
        controllerConfiguration: NESControllerConfiguration = .init()
    ) {
        self.configuration = configuration
        self.controllerConfiguration = controllerConfiguration
        _engine = StateObject(wrappedValue: NESEngine(configuration: configuration))
    }

    public init(
        rom: URL,
        controllerConfiguration: NESControllerConfiguration = .init()
    ) {
        self.init(
            configuration: NESConfiguration(romURL: rom),
            controllerConfiguration: controllerConfiguration
        )
    }

    public var body: some View {
        NESView(
            engine: engine,
            showsControls: configuration.showsTouchControls,
            controllerConfiguration: controllerConfiguration
        )
        .onAppear {
            if configuration.automaticallyStarts { engine.start() }
        }
        .onDisappear { engine.stop() }
    }
}
