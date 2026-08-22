import SwiftUI

public struct NESControls: View {
    private let engine: NESEngine

    public init(engine: NESEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            dPad
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    control("SELECT", .select)
                    control("START", .start)
                }
                HStack(spacing: 18) {
                    control("B", .b, diameter: 64)
                    control("A", .a, diameter: 64)
                }
            }
        }
        .padding()
        .foregroundStyle(.white)
    }

    private var dPad: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow { Color.clear.frame(width: 50, height: 50); control("▲", .up); Color.clear.frame(width: 50, height: 50) }
            GridRow { control("◀", .left); Color.black.opacity(0.75).frame(width: 50, height: 50); control("▶", .right) }
            GridRow { Color.clear.frame(width: 50, height: 50); control("▼", .down); Color.clear.frame(width: 50, height: 50) }
        }
    }

    @ViewBuilder
    private func control(_ label: String, _ button: NESControllerButton, diameter: CGFloat = 50) -> some View {
        #if os(tvOS)
        Button {
            engine.setButton(button, pressed: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                engine.setButton(button, pressed: false)
            }
        } label: {
            controlLabel(label, diameter: diameter)
        }
        .buttonStyle(.plain)
        #else
        controlLabel(label, diameter: diameter)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in engine.setButton(button, pressed: true) }
                    .onEnded { _ in engine.setButton(button, pressed: false) }
            )
        #endif
    }

    private func controlLabel(_ label: String, diameter: CGFloat) -> some View {
        Text(label)
            .font(.system(size: label.count == 1 ? 22 : 10, weight: .bold, design: .rounded))
            .frame(width: diameter, height: diameter)
            .background(.black.opacity(0.75), in: Circle())
            .contentShape(Circle())
            .accessibilityLabel(label)
    }
}
