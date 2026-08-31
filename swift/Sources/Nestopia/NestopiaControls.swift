// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

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
        guard configuration.presentationMode == .automatic else {
            return configuration.presentationMode
        }
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
            utilityButtons(
                metrics: metrics, palette: palette, opacity: configuration.overlayOpacity
            )
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
                shape.fill(bodyPanelGradient(color: palette.body))
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .clear, .black.opacity(0.10)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                shape.stroke(.black.opacity(0.22), lineWidth: 1)
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

    // MARK: - Directional pad

    #if os(tvOS)
        private func dPad(metrics: Metrics, palette: Palette, opacity: Double) -> some View {
            let cell = metrics.direction
            let bounds = CGSize(width: cell * 3, height: cell * 3)
            return ZStack {
                crossPlate(size: bounds, palette: palette, opacity: opacity)
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Color.clear.frame(width: cell, height: cell)
                        tvDirectionButton(.up, "▲", cell: cell, palette: palette, opacity: opacity)
                        Color.clear.frame(width: cell, height: cell)
                    }
                    GridRow {
                        tvDirectionButton(
                            .left, "◀", cell: cell, palette: palette, opacity: opacity)
                        centerBoss(size: cell, opacity: opacity)
                        tvDirectionButton(
                            .right, "▶", cell: cell, palette: palette, opacity: opacity)
                    }
                    GridRow {
                        Color.clear.frame(width: cell, height: cell)
                        tvDirectionButton(
                            .down, "▼", cell: cell, palette: palette, opacity: opacity)
                        Color.clear.frame(width: cell, height: cell)
                    }
                }
            }
            .frame(width: bounds.width, height: bounds.height)
        }

        private func tvDirectionButton(
            _ button: NestopiaControllerButton, _ glyph: String, cell: CGFloat, palette: Palette,
            opacity: Double
        ) -> some View {
            Button {
                engine.setButton(button, pressed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    engine.setButton(button, pressed: false)
                }
            } label: {
                Text(glyph)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(palette.labels)
                    .frame(width: cell, height: cell)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    #else
        private func dPad(metrics: Metrics, palette: Palette, opacity: Double) -> some View {
            let cell = metrics.direction
            let bounds = CGSize(width: cell * 3, height: cell * 3)
            return ControllerTouchSurface(
                engine: engine,
                hapticsEnabled: configuration.hapticsEnabled,
                resolveActive: { point, _ in
                    dPadHitTest(at: point, in: CGRect(origin: .zero, size: bounds))
                },
                content: { active in
                    ZStack {
                        crossPlate(size: bounds, palette: palette, opacity: opacity)
                        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                            GridRow {
                                Color.clear.frame(width: cell, height: cell)
                                armOverlay(
                                    .up, active: active, cell: cell, opacity: opacity)
                                Color.clear.frame(width: cell, height: cell)
                            }
                            GridRow {
                                armOverlay(
                                    .left, active: active, cell: cell, opacity: opacity)
                                centerBoss(size: cell, opacity: opacity)
                                armOverlay(
                                    .right, active: active, cell: cell, opacity: opacity)
                            }
                            GridRow {
                                Color.clear.frame(width: cell, height: cell)
                                armOverlay(
                                    .down, active: active, cell: cell, opacity: opacity)
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                    .frame(width: bounds.width, height: bounds.height)
                }
            )
        }
    #endif

    private func crossPlate(size: CGSize, palette: Palette, opacity: Double) -> some View {
        let shape = DPadCrossShape(cornerRadius: size.width * 0.09)
        return ZStack {
            shape.fill(dPadGradient(color: palette.dPad, opacity: opacity))
            shape.stroke(.white.opacity(0.08 * opacity), lineWidth: 1.5)
            shape.stroke(.black.opacity(0.35 * opacity), lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.2 * opacity), radius: 3, y: 2)
    }

    private func armOverlay(
        _ button: NestopiaControllerButton, active: Set<NestopiaControllerButton>, cell: CGFloat,
        opacity: Double
    ) -> some View {
        Rectangle()
            .fill(.black.opacity(active.contains(button) ? 0.24 * opacity : 0))
            .frame(width: cell, height: cell)
            .animation(.easeOut(duration: 0.06), value: active.contains(button))
    }

    private func centerBoss(size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.18 * opacity), .black.opacity(0.30 * opacity)],
                    center: .center, startRadius: 0, endRadius: size * 0.32
                )
            )
            .overlay(Circle().stroke(.black.opacity(0.3 * opacity), lineWidth: 1))
            .frame(width: size * 0.6, height: size * 0.6)
    }

    // MARK: - Utility buttons (SELECT / START)

    #if os(tvOS)
        private func utilityButtons(
            metrics: Metrics, palette: Palette, opacity: Double
        ) -> some View {
            HStack(spacing: metrics.utilitySpacing) {
                tvUtilityButton(
                    .select, "SELECT", metrics: metrics, palette: palette, opacity: opacity)
                tvUtilityButton(
                    .start, "START", metrics: metrics, palette: palette, opacity: opacity)
            }
        }

        private func tvUtilityButton(
            _ button: NestopiaControllerButton, _ label: String, metrics: Metrics, palette: Palette,
            opacity: Double
        ) -> some View {
            Button {
                engine.setButton(button, pressed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    engine.setButton(button, pressed: false)
                }
            } label: {
                utilityCapVisual(
                    label: label, size: metrics.utility, palette: palette, opacity: opacity,
                    isActive: false)
            }
            .buttonStyle(.plain)
        }
    #else
        private func utilityButtons(
            metrics: Metrics, palette: Palette, opacity: Double
        ) -> some View {
            ControllerTouchSurface(
                engine: engine,
                hapticsEnabled: configuration.hapticsEnabled,
                resolveActive: { point, frames in
                    nearestButtonHitTest(
                        at: point, among: frames, tolerance: metrics.utility.width * 0.7)
                },
                content: { active in
                    HStack(spacing: metrics.utilitySpacing) {
                        utilityCap(
                            .select, label: "SELECT", metrics: metrics, palette: palette,
                            opacity: opacity, active: active)
                        utilityCap(
                            .start, label: "START", metrics: metrics, palette: palette,
                            opacity: opacity, active: active)
                    }
                }
            )
        }

        private func utilityCap(
            _ button: NestopiaControllerButton, label: String, metrics: Metrics, palette: Palette,
            opacity: Double, active: Set<NestopiaControllerButton>
        ) -> some View {
            utilityCapVisual(
                label: label, size: metrics.utility, palette: palette, opacity: opacity,
                isActive: active.contains(button)
            )
            .reportingControllerFrame(of: button)
        }
    #endif

    private func utilityCapVisual(
        label: String, size: CGSize, palette: Palette, opacity: Double, isActive: Bool
    ) -> some View {
        Capsule()
            .fill(utilityCapsuleGradient(color: palette.utility, opacity: opacity))
            .overlay(Capsule().strokeBorder(.white.opacity(0.22 * opacity), lineWidth: 1))
            .overlay(
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(palette.labels)
            )
            .frame(width: size.width, height: size.height)
            .scaleEffect(isActive ? 0.94 : 1)
            .brightness(isActive ? -0.12 : 0)
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.07), value: isActive)
            .accessibilityLabel(label)
    }

    // MARK: - Action buttons (A / B)

    #if os(tvOS)
        private func actionButtons(
            metrics: Metrics, palette: Palette, opacity: Double
        ) -> some View {
            HStack(alignment: .bottom, spacing: metrics.actionSpacing) {
                tvActionButton(.b, "B", metrics: metrics, palette: palette, opacity: opacity)
                    .padding(.bottom, metrics.action.height * 0.22)
                tvActionButton(.a, "A", metrics: metrics, palette: palette, opacity: opacity)
            }
        }

        private func tvActionButton(
            _ button: NestopiaControllerButton, _ label: String, metrics: Metrics, palette: Palette,
            opacity: Double
        ) -> some View {
            Button {
                engine.setButton(button, pressed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    engine.setButton(button, pressed: false)
                }
            } label: {
                actionCapVisual(
                    label: label, diameter: metrics.action.width, palette: palette,
                    opacity: opacity, isActive: false)
            }
            .buttonStyle(.plain)
        }
    #else
        private func actionButtons(
            metrics: Metrics, palette: Palette, opacity: Double
        ) -> some View {
            ControllerTouchSurface(
                engine: engine,
                hapticsEnabled: configuration.hapticsEnabled,
                resolveActive: { point, frames in
                    nearestButtonHitTest(
                        at: point, among: frames, tolerance: metrics.action.width * 0.7)
                },
                content: { active in
                    HStack(alignment: .bottom, spacing: metrics.actionSpacing) {
                        actionCap(
                            .b, label: "B", metrics: metrics, palette: palette,
                            opacity: opacity, active: active
                        )
                        .padding(.bottom, metrics.action.height * 0.22)
                        actionCap(
                            .a, label: "A", metrics: metrics, palette: palette,
                            opacity: opacity, active: active)
                    }
                }
            )
        }

        private func actionCap(
            _ button: NestopiaControllerButton, label: String, metrics: Metrics, palette: Palette,
            opacity: Double, active: Set<NestopiaControllerButton>
        ) -> some View {
            actionCapVisual(
                label: label, diameter: metrics.action.width, palette: palette, opacity: opacity,
                isActive: active.contains(button)
            )
            .reportingControllerFrame(of: button)
        }
    #endif

    private func actionCapVisual(
        label: String, diameter: CGFloat, palette: Palette, opacity: Double, isActive: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(
                    actionCapGradient(color: palette.action, opacity: opacity, diameter: diameter)
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.32 * opacity), lineWidth: 1.2))
                .overlay(Circle().stroke(.black.opacity(0.28 * opacity), lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .scaleEffect(isActive ? 0.93 : 1)
                .brightness(isActive ? -0.12 : 0)
                .shadow(color: .black.opacity(0.28 * opacity), radius: 3, y: 2)
                .contentShape(Circle())
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(palette.bodyLabel)
                .opacity(opacity)
        }
        .animation(.easeOut(duration: 0.07), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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
                .primary.opacity(0.08), .primary.opacity(0.68), .accentColor,
                .primary.opacity(0.55), .white, .primary,
                .primary.opacity(0.12)
            )
        case .nes:
            defaults = (
                Color(red: 0.70, green: 0.70, blue: 0.68), Color(white: 0.10),
                Color(red: 0.67, green: 0.05, blue: 0.12), Color(white: 0.16), .white,
                Color(white: 0.15),
                Color(white: 0.12)
            )
        case .famicom:
            defaults = (
                Color(red: 0.91, green: 0.86, blue: 0.69),
                Color(red: 0.34, green: 0.04, blue: 0.09),
                Color(red: 0.63, green: 0.03, blue: 0.08),
                Color(red: 0.43, green: 0.05, blue: 0.10),
                Color(red: 0.98, green: 0.91, blue: 0.72),
                Color(red: 0.40, green: 0.04, blue: 0.09),
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
