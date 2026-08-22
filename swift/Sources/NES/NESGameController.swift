// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import GameController

final class NESGameController {
    private weak var engine: NESEngine?
    private let connectionChanged: (Bool) -> Void
    private var observers: [NSObjectProtocol] = []
    private var boundControllers: [GCController] = []

    init(engine: NESEngine, connectionChanged: @escaping (Bool) -> Void) {
        self.engine = engine
        self.connectionChanged = connectionChanged
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshControllers()
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshControllers()
            }
        )
        refreshControllers()
        bindKeyboard()
    }

    deinit {
        for controller in boundControllers {
            controller.extendedGamepad?.valueChangedHandler = nil
        }
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func refreshControllers() {
        for controller in boundControllers {
            controller.extendedGamepad?.valueChangedHandler = nil
        }
        for player in 0..<2 {
            releaseButtons(player: player)
        }

        boundControllers = Array(GCController.controllers().filter { $0.extendedGamepad != nil }.prefix(2))
        for (player, controller) in boundControllers.enumerated() {
            bind(controller, player: player)
        }
        connectionChanged(!boundControllers.isEmpty)
    }

    private func bind(_ controller: GCController, player: Int) {
        guard let gamepad = controller.extendedGamepad else { return }
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            self?.engine?.setButton(.a, player: player, pressed: pad.buttonA.isPressed)
            self?.engine?.setButton(.b, player: player, pressed: pad.buttonB.isPressed)
            self?.engine?.setButton(.start, player: player, pressed: pad.buttonMenu.isPressed)
            self?.engine?.setButton(.select, player: player, pressed: pad.buttonOptions?.isPressed == true)
            self?.engine?.setButton(.up, player: player, pressed: pad.dpad.up.isPressed)
            self?.engine?.setButton(.down, player: player, pressed: pad.dpad.down.isPressed)
            self?.engine?.setButton(.left, player: player, pressed: pad.dpad.left.isPressed)
            self?.engine?.setButton(.right, player: player, pressed: pad.dpad.right.isPressed)
        }
    }

    private func releaseButtons(player: Int) {
        for button in NESControllerButton.allCases {
            engine?.setButton(button, player: player, pressed: false)
        }
    }

    private func bindKeyboard() {
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            let button: NESControllerButton?
            switch keyCode {
            case .upArrow: button = .up
            case .downArrow: button = .down
            case .leftArrow: button = .left
            case .rightArrow: button = .right
            case .keyX: button = .a
            case .keyZ: button = .b
            case .returnOrEnter: button = .start
            case .spacebar: button = .select
            default: button = nil
            }
            if let button { self?.engine?.setButton(button, pressed: pressed) }
        }
    }
}
