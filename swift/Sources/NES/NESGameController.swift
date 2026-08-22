import GameController

final class NESGameController {
    private weak var engine: NESEngine?
    private var observers: [NSObjectProtocol] = []

    init(engine: NESEngine) {
        self.engine = engine
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                self?.bind(controller)
            }
        )
        GCController.controllers().forEach(bind)
        bindKeyboard()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func bind(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            self?.engine?.setButton(.a, pressed: pad.buttonA.isPressed)
            self?.engine?.setButton(.b, pressed: pad.buttonB.isPressed)
            self?.engine?.setButton(.start, pressed: pad.buttonMenu.isPressed)
            self?.engine?.setButton(.select, pressed: pad.buttonOptions?.isPressed == true)
            self?.engine?.setButton(.up, pressed: pad.dpad.up.isPressed)
            self?.engine?.setButton(.down, pressed: pad.dpad.down.isPressed)
            self?.engine?.setButton(.left, pressed: pad.dpad.left.isPressed)
            self?.engine?.setButton(.right, pressed: pad.dpad.right.isPressed)
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
