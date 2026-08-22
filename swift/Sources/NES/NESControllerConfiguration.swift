import SwiftUI

/// The visual identity used by the on-screen controller.
public enum NESControllerTheme: Sendable, Equatable {
    /// Uses a translucent, system-material surface with the current accent color.
    case system
    /// Uses the gray, black, and red palette of the original NES controller.
    case nes
    /// Uses the cream, red, and gold palette of the original Famicom controller.
    case famicom
}

/// Controls how the on-screen controller uses the space offered by its container.
public enum NESControllerPresentationMode: Sendable, Equatable {
    /// Shows a controller body when space permits and a transparent overlay in landscape or compact heights.
    case automatic
    /// Always presents the controls inside a controller-shaped surface.
    case gamepad
    /// Always places translucent controls over the game content.
    case overlay
}

/// Optional color replacements applied after the selected theme is resolved.
public struct NESControllerColorOverrides {
    public var body: Color?
    public var directionalPad: Color?
    public var actionButtons: Color?
    public var utilityButtons: Color?
    public var labels: Color?
    public var bodyLabel: Color?

    public init(
        body: Color? = nil,
        directionalPad: Color? = nil,
        actionButtons: Color? = nil,
        utilityButtons: Color? = nil,
        labels: Color? = nil,
        bodyLabel: Color? = nil
    ) {
        self.body = body
        self.directionalPad = directionalPad
        self.actionButtons = actionButtons
        self.utilityButtons = utilityButtons
        self.labels = labels
        self.bodyLabel = bodyLabel
    }
}

/// Appearance and layout options for the on-screen controller.
public struct NESControllerConfiguration {
    public var theme: NESControllerTheme
    public var presentationMode: NESControllerPresentationMode
    public var colors: NESControllerColorOverrides
    /// Opacity applied to button surfaces in overlay mode.
    public var overlayOpacity: Double

    public init(
        theme: NESControllerTheme = .system,
        presentationMode: NESControllerPresentationMode = .automatic,
        colors: NESControllerColorOverrides = .init(),
        overlayOpacity: Double = 0.72
    ) {
        self.theme = theme
        self.presentationMode = presentationMode
        self.colors = colors
        self.overlayOpacity = min(max(overlayOpacity, 0), 1)
    }
}
