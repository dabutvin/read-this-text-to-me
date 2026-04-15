import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 4)

                    Capsule()
                        .fill(.tint)
                        .frame(width: geometry.size.width * appState.speechService.progress, height: 4)
                        .animation(.linear(duration: 0.1), value: appState.speechService.progress)
                }
            }
            .frame(height: 4)

            HStack(spacing: 24) {
                Button {
                    appState.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .disabled(appState.speechState == .idle)
                .opacity(appState.speechState == .idle ? 0.3 : 1)

                Button {
                    switch appState.speechState {
                    case .idle:
                        appState.speak()
                    case .speaking:
                        appState.pause()
                    case .paused:
                        appState.resume()
                    }
                } label: {
                    Image(systemName: playButtonIcon)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .frame(width: 64, height: 64)
                        .background(.tint.opacity(0.1), in: Circle())
                }

                Button {
                    appState.clearText()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                }
            }
            .foregroundStyle(.primary)

            SpeedSelectorView()
                .environmentObject(appState)
        }
        .padding(.vertical, 8)
    }

    private var playButtonIcon: String {
        switch appState.speechState {
        case .idle: "play.fill"
        case .speaking: "pause.fill"
        case .paused: "play.fill"
        }
    }
}

struct SpeedSelectorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SpeechSpeed.allCases) { speed in
                Button {
                    appState.setSpeed(speed)
                } label: {
                    Text(speed.label)
                        .font(.caption2)
                        .fontWeight(appState.speechSpeed == speed ? .bold : .regular)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            appState.speechSpeed == speed
                                ? AnyShapeStyle(.tint.opacity(0.15))
                                : AnyShapeStyle(.clear)
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(appState.speechSpeed == speed ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
