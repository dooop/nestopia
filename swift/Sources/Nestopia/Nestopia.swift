// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// High-level SwiftUI host for one Nestopia ROM.
public struct Nestopia: View {
    @StateObject private var engine: NestopiaEngine
    private let configuration: NestopiaConfiguration
    private let controllerConfiguration: NestopiaControllerConfiguration

    public init(
        configuration: NestopiaConfiguration,
        controllerConfiguration: NestopiaControllerConfiguration = .init()
    ) {
        self.configuration = configuration
        self.controllerConfiguration = controllerConfiguration
        _engine = StateObject(wrappedValue: NestopiaEngine(configuration: configuration))
    }

    public init(
        rom: URL,
        controllerConfiguration: NestopiaControllerConfiguration = .init()
    ) {
        self.init(
            configuration: NestopiaConfiguration(romURL: rom),
            controllerConfiguration: controllerConfiguration
        )
    }

    public var body: some View {
        NestopiaView(
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
