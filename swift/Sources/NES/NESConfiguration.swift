import Foundation

/// Runtime options for one Nestopia session.
public struct NESConfiguration: Sendable, Equatable {
    public var romURL: URL
    public var saveDirectory: URL?
    public var automaticallyStarts: Bool
    public var showsTouchControls: Bool

    public init(
        romURL: URL,
        saveDirectory: URL? = nil,
        automaticallyStarts: Bool = true,
        showsTouchControls: Bool = true
    ) {
        self.romURL = romURL
        self.saveDirectory = saveDirectory
        self.automaticallyStarts = automaticallyStarts
        self.showsTouchControls = showsTouchControls
    }
}

public enum NESState: Equatable, Sendable {
    case idle
    case loading
    case running
    case paused
    case stopped
    case failed(String)
}

public enum NESControllerButton: Int, CaseIterable, Sendable {
    case a = 0x01
    case b = 0x02
    case select = 0x04
    case start = 0x08
    case up = 0x10
    case down = 0x20
    case left = 0x40
    case right = 0x80
}
