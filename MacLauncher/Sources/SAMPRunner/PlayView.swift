#if os(macOS)
import RunnerCore
import SwiftUI

struct PlayView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var quickConnect = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("San Andreas Multiplayer").font(.largeTitle.bold())
                    Text("\(model.settings.renderer.displayName) · FPS cap \(model.settings.fpsLimit)")
                        .foregroundStyle(.secondary)
                }

                if !model.setup.readyToPlay {
                    GroupBox {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Setup isn't finished yet.")
                            Spacer()
                            Button("Open Setup") { model.section = .setup }
                        }
                        .padding(4)
                    }
                }

                GroupBox("Player") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Nickname", text: model.binding(\.nickname))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        if let error = model.nicknameError {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(6)
                }

                HStack(spacing: 12) {
                    if model.isRunning {
                        Button(role: .destructive) { model.stop() } label: {
                            Label("Stop Game", systemImage: "stop.fill").frame(minWidth: 160)
                        }
                        .controlSize(.large)
                        ProgressView().controlSize(.small)
                        Text("Game is running").foregroundStyle(.secondary)
                    } else {
                        Button { model.play(.sampBrowser) } label: {
                            Label("Play", systemImage: "play.fill").frame(minWidth: 160)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.setup.readyToPlay)

                        if let last = model.settings.lastServer, let address = ServerAddress(last) {
                            Button("Rejoin \(last)") { model.play(.connect(address)) }
                                .controlSize(.large)
                                .disabled(!model.setup.readyToPlay)
                        }
                        Button("Single Player") { model.play(.singlePlayer) }
                            .controlSize(.large)
                            .disabled(!model.setup.gameInstalled || !model.setup.prefixReady)
                    }
                }

                GroupBox("Quick connect") {
                    HStack {
                        TextField("host:port", text: $quickConnect)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                            .onSubmit(connect)
                        Button("Connect", action: connect)
                            .disabled(ServerAddress(quickConnect) == nil || model.isRunning || !model.setup.readyToPlay)
                        Spacer()
                        Button("Browse servers…") { model.section = .servers }
                    }
                    .padding(6)
                }

                if let note = model.sessionNote {
                    Label(note, systemImage: "info.circle").foregroundStyle(.secondary)
                }

                if let bench = model.lastBenchmark {
                    GroupBox("Last benchmark") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 28) {
                                Metric(value: bench.averageFPS, unit: "FPS", caption: "average")
                                Metric(value: bench.onePercentLowFPS, unit: "FPS", caption: "1% low")
                                Metric(value: bench.worstFrameMS, unit: "ms", caption: "worst frame")
                            }
                            Text("Renderer: \(bench.renderer ?? "?") · \(bench.frames) frames over \(Int(bench.seconds)) s. "
                                 + "Switch renderer in Settings and play the same spot to compare.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(6)
                    }
                }

                GroupBox("For the best frame rate") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• In the game: Options › Display Setup › Frame Limiter **Off** (otherwise it caps at 25–30 FPS). The FPS cap from Settings applies instead.")
                        Text("• Use a resolution like 1440×900 or 1280×800 and keep Retina mode off.")
                        Text("• Draw Distance and Visual FX cost CPU time, which is the bottleneck under Rosetta. Lower them before resolution.")
                        Text("• With 8 GB RAM, quit browsers and chat apps before playing to avoid swap stutter.")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(6)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func connect() {
        guard let address = ServerAddress(quickConnect) else { return }
        model.play(.connect(address))
    }
}

private struct Metric: View {
    let value: Double
    let unit: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(value.rounded())) \(unit)").font(.title2.monospacedDigit().bold())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}
#endif
