// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

public struct NestopiaControls: View {
    private let engine: NestopiaEngine
    private let configuration: NestopiaControllerConfiguration

    public init(engine: NestopiaEngine, configuration: NestopiaControllerConfiguration = .init()) {
        self.engine = engine
        self.configuration = configuration
    }

    public var body: some View {
        GeometryReader { proxy in
            let mode = resolvedMode(for: proxy.size)
            let metrics = Metrics(compact: proxy.size.width < 500)
            let palette = Palette(theme: configuration.theme, overrides: configuration.colors)

            Group {
                if mode == .overlay {
                    overlayControls(metrics: metrics, palette: palette)
                } else {
                    gamepadControls(metrics: metrics, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game controller")
    }

    private func resolvedMode(for size: CGSize) -> NestopiaControllerPresentationMode {
        guard configuration.presentationMode == .automatic else { return configuration.presentationMode }
        return size.width > size.height || size.height < 300 ? .overlay : .gamepad
    }

    private func gamepadControls(metrics: Metrics, palette: Palette) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            dPad(metrics: metrics, palette: palette, opacity: 1)
            Spacer(minLength: metrics.sectionSpacing)
            VStack(spacing: metrics.utilitySpacing) {
                if !configuration.resolvedControllerLabel.isEmpty {
                    Text(configuration.resolvedControllerLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(palette.bodyLabel)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                utilityButtons(metrics: metrics, palette: palette, opacity: 1)
            }
            .padding(.horizontal, metrics.utilitySpacing)
            .padding(.vertical, metrics.utilitySpacing)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.panel.opacity(configuration.theme == .system ? 0.12 : 0.94))
            )
            Spacer(minLength: metrics.sectionSpacing)
            actionButtons(metrics: metrics, palette: palette, opacity: 1)
        }
        .padding(metrics.bodyPadding)
        .frame(maxWidth: 680)
        .background { controllerBody(palette: palette) }
        .padding(.horizontal, metrics.outerPadding)
        .padding(.bottom, metrics.outerPadding)
    }

    private func overlayControls(metrics: Metrics, palette: Palette) -> some View {
        ZStack(alignment: .bottom) {
            dPad(metrics: metrics, palette: palette, opacity: configuration.overlayOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            utilityButtons(metrics: metrics, palette: palette, opacity: configuration.overlayOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            actionButtons(metrics: metrics, palette: palette, opacity: configuration.overlayOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(.horizontal, metrics.outerPadding)
        .padding(.bottom, metrics.outerPadding)
    }

    private func controllerBody(palette: Palette) -> some View {
        let shape = controllerBodyShape
        return ZStack {
            if configuration.theme == .system {
                #if compiler(>=6.2)
                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
                        shape.fill(.clear)
                            .glassEffect(.regular.tint(palette.body), in: shape)
                    } else {
                        shape.fill(.ultraThinMaterial)
                            .overlay(shape.fill(palette.body))
                    }
                #else
                    shape.fill(.ultraThinMaterial)
                        .overlay(shape.fill(palette.body))
                #endif
            } else {
                shape.fill(palette.body)
            }
            shape.stroke(.white.opacity(configuration.theme == .system ? 0.28 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
    }

    private var controllerBodyShape: AnyShape {
        switch configuration.theme {
        case .system: AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .nes: AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .famicom: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func dPad(metrics: Metrics, palette: Palette, opacity: Double) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: metrics.direction, height: metrics.direction)
                control(
                    "▲", .up, size: CGSize(width: metrics.direction, height: metrics.direction), shape: .rounded,
                    color: palette.dPad, palette: palette, opacity: opacity)
                Color.clear.frame(width: metrics.direction, height: metrics.direction)
            }
            GridRow {
                control(
                    "◀", .left, size: CGSize(width: metrics.direction, height: metrics.direction), shape: .rounded,
                    color: palette.dPad, palette: palette, opacity: opacity)
                ZStack {
                    Rectangle().fill(palette.dPad.opacity(opacity))
                    Circle()
                        .fill(.black.opacity(0.16 * opacity))
                        .overlay(Circle().stroke(.white.opacity(0.08 * opacity), lineWidth: 1))
                        .frame(width: metrics.direction * 0.54, height: metrics.direction * 0.54)
                }
                .frame(width: metrics.direction, height: metrics.direction)
                control(
                    "▶", .right, size: CGSize(width: metrics.direction, height: metrics.direction), shape: .rounded,
                    color: palette.dPad, palette: palette, opacity: opacity)
            }
            GridRow {
                Color.clear.frame(width: metrics.direction, height: metrics.direction)
                control(
                    "▼", .down, size: CGSize(width: metrics.direction, height: metrics.direction), shape: .rounded,
                    color: palette.dPad, palette: palette, opacity: opacity)
                Color.clear.frame(width: metrics.direction, height: metrics.direction)
            }
        }
    }

    private func utilityButtons(metrics: Metrics, palette: Palette, opacity: Double) -> some View {
        HStack(spacing: metrics.utilitySpacing) {
            control(
                "SELECT", .select, size: metrics.utility, shape: .capsule, color: palette.utility, palette: palette,
                opacity: opacity)
            control(
                "START", .start, size: metrics.utility, shape: .capsule, color: palette.utility, palette: palette,
                opacity: opacity)
        }
    }

    private func actionButtons(metrics: Metrics, palette: Palette, opacity: Double) -> some View {
        HStack(alignment: .bottom, spacing: metrics.actionSpacing) {
            control(
                "B", .b, size: metrics.action, shape: .circle, color: palette.action, palette: palette, opacity: opacity
            )
            .padding(.bottom, metrics.action.height * 0.22)
            control(
                "A", .a, size: metrics.action, shape: .circle, color: palette.action, palette: palette, opacity: opacity
            )
        }
    }

    @ViewBuilder
    private func control(
        _ label: String, _ button: NestopiaControllerButton, size: CGSize, shape: ControlShape, color: Color,
        palette: Palette, opacity: Double
    ) -> some View {
        #if os(tvOS)
            Button {
                engine.setButton(button, pressed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { engine.setButton(button, pressed: false) }
            } label: {
                controlLabel(label, size: size, shape: shape, color: color, palette: palette, opacity: opacity)
            }
            .buttonStyle(.plain)
        #else
            PressableControl(
                hapticsEnabled: configuration.hapticsEnabled,
                onPressedChange: { engine.setButton(button, pressed: $0) },
                content: {
                    controlLabel(label, size: size, shape: shape, color: color, palette: palette, opacity: opacity)
                }
            )
        #endif
    }

    private func controlLabel(
        _ label: String, size: CGSize, shape: ControlShape, color: Color, palette: Palette, opacity: Double
    ) -> some View {
        Text(label)
            .font(.system(size: label.count == 1 ? 20 : 9, weight: .black, design: .rounded))
            .foregroundStyle(palette.labels)
            .frame(width: size.width, height: size.height)
            .background { controlSurface(shape: shape, color: color, opacity: opacity) }
            .contentShape(shape.swiftUIShape)
            .accessibilityLabel(label)
    }

    @ViewBuilder
    private func controlSurface(shape: ControlShape, color: Color, opacity: Double) -> some View {
        let surface = shape.swiftUIShape
        if configuration.theme == .system {
            #if compiler(>=6.2)
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
                    surface.fill(.clear)
                        .glassEffect(.regular.tint(color.opacity(opacity)).interactive(), in: surface)
                } else {
                    materialSurface(surface, color: color, opacity: opacity)
                }
            #else
                materialSurface(surface, color: color, opacity: opacity)
            #endif
        } else {
            surface.fill(color.opacity(opacity))
                .overlay(surface.stroke(.white.opacity(0.1 * opacity), lineWidth: 1))
                .shadow(color: .black.opacity(0.25 * opacity), radius: 3, y: 2)
        }
    }

    private func materialSurface(_ surface: AnyShape, color: Color, opacity: Double) -> some View {
        surface.fill(.ultraThinMaterial)
            .overlay(surface.fill(color.opacity(opacity)))
            .overlay(surface.stroke(.white.opacity(0.32 * opacity), lineWidth: 1))
            .shadow(color: .black.opacity(0.2 * opacity), radius: 5, y: 3)
    }
}

private struct Metrics {
    let direction: CGFloat
    let action: CGSize
    let utility: CGSize
    let sectionSpacing: CGFloat
    let utilitySpacing: CGFloat
    let actionSpacing: CGFloat
    let bodyPadding: CGFloat
    let outerPadding: CGFloat

    init(compact: Bool) {
        direction = compact ? 38 : 48
        action = CGSize(width: compact ? 50 : 64, height: compact ? 50 : 64)
        utility = CGSize(width: compact ? 46 : 58, height: compact ? 26 : 32)
        sectionSpacing = compact ? 4 : 18
        utilitySpacing = compact ? 4 : 10
        actionSpacing = compact ? 8 : 16
        bodyPadding = compact ? 12 : 22
        outerPadding = compact ? 8 : 20
    }
}

private struct Palette {
    let body: Color
    let dPad: Color
    let action: Color
    let utility: Color
    let labels: Color
    let bodyLabel: Color
    let panel: Color

    init(theme: NestopiaControllerTheme, overrides: NestopiaControllerColorOverrides) {
        let defaults: (Color, Color, Color, Color, Color, Color, Color)
        switch theme {
        case .system:
            defaults = (
                .primary.opacity(0.08), .primary.opacity(0.68), .accentColor, .primary.opacity(0.55), .white, .primary,
                .primary.opacity(0.12)
            )
        case .nes:
            defaults = (
                Color(red: 0.70, green: 0.70, blue: 0.68), Color(white: 0.10),
                Color(red: 0.67, green: 0.05, blue: 0.12), Color(white: 0.16), .white, Color(white: 0.15),
                Color(white: 0.12)
            )
        case .famicom:
            defaults = (
                Color(red: 0.91, green: 0.86, blue: 0.69), Color(red: 0.34, green: 0.04, blue: 0.09),
                Color(red: 0.63, green: 0.03, blue: 0.08), Color(red: 0.43, green: 0.05, blue: 0.10),
                Color(red: 0.98, green: 0.91, blue: 0.72), Color(red: 0.40, green: 0.04, blue: 0.09),
                Color(red: 0.34, green: 0.04, blue: 0.09)
            )
        }
        body = overrides.body ?? defaults.0
        dPad = overrides.directionalPad ?? defaults.1
        action = overrides.actionButtons ?? defaults.2
        utility = overrides.utilityButtons ?? defaults.3
        labels = overrides.labels ?? defaults.4
        bodyLabel = overrides.bodyLabel ?? defaults.5
        panel = defaults.6
    }
}

#if !os(tvOS)
private struct PressableControl<Content: View>: View {
    let hapticsEnabled: Bool
    let onPressedChange: (Bool) -> Void
    @ViewBuilder let content: () -> Content
    @State private var isPressed = false

    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.92 : 1)
            .brightness(isPressed ? -0.12 : 0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressedChange(true)
                        if hapticsEnabled { performControllerHaptic() }
                    }
                    .onEnded { _ in release() }
            )
            .onDisappear { release() }
    }

    private func release() {
        guard isPressed else { return }
        isPressed = false
        onPressedChange(false)
    }
}
#endif

private func performControllerHaptic() {
    #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
    #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
}

private enum ControlShape {
    case circle
    case capsule
    case rounded

    var swiftUIShape: AnyShape {
        switch self {
        case .circle: AnyShape(Circle())
        case .capsule: AnyShape(Capsule())
        case .rounded: AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
