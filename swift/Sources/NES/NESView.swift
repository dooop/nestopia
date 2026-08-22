import SwiftUI

public struct NESView: View {
    @ObservedObject private var engine: NESEngine
    private let showsControls: Bool
    private let controllerConfiguration: NESControllerConfiguration

    public init(
        engine: NESEngine,
        showsControls: Bool = true,
        controllerConfiguration: NESControllerConfiguration = .init()
    ) {
        self.engine = engine
        self.showsControls = showsControls
        self.controllerConfiguration = controllerConfiguration
    }

    public var body: some View {
        ZStack {
            Color.black
            if let frame = engine.frame {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(256.0 / 240.0, contentMode: .fit)
            } else {
                status
            }
            if showsControls {
                NESControls(engine: engine, configuration: controllerConfiguration)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var status: some View {
        switch engine.state {
        case .loading:
            ProgressView().tint(.white)
        case .failed(let message):
            ContentUnavailableView(
                "ROM konnte nicht gestartet werden", systemImage: "exclamationmark.triangle", description: Text(message)
            )
            .foregroundStyle(.white)
        default:
            Text("NES").font(.largeTitle.bold()).foregroundStyle(.secondary)
        }
    }
}
