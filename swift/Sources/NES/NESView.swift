import SwiftUI

public struct NESView: View {
    @ObservedObject private var engine: NESEngine
    private let showsControls: Bool

    public init(engine: NESEngine, showsControls: Bool = true) {
        self.engine = engine
        self.showsControls = showsControls
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
                VStack {
                    Spacer()
                    NESControls(engine: engine)
                }
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
