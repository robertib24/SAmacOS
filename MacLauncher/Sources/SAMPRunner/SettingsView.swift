#if os(macOS)
import RunnerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var confirmReset = false

    private var fpsLimit: Binding<Double> {
        Binding(get: { Double(model.settings.fpsLimit) },
                set: { value in model.update { $0.fpsLimit = Int(value) } })
    }

    var body: some View {
        Form {
            Section {
                Picker("Renderer", selection: model.binding(\.renderer)) {
                    ForEach(Renderer.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text("GTA SA uses Direct3D 9. Wine translates it with wined3d to Vulkan (MoltenVK → Metal) or to Apple's OpenGL. "
                     + "Vulkan avoids the extra buffer copies 32-bit games pay on the OpenGL path; if you see missing or "
                     + "flickering graphics, switch to OpenGL. Turn on Benchmark mode to compare them.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Retina resolution (sharper, slower)", isOn: model.binding(\.retinaMode))
                Picker("Video memory", selection: model.binding(\.videoMemoryMB)) {
                    ForEach([1024, 2048, 3072], id: \.self) { Text("\($0) MB").tag($0) }
                }
            } header: {
                Text("Graphics")
            }

            Section {
                LabeledContent("FPS cap: \(model.settings.fpsLimit)") {
                    Slider(value: fpsLimit, in: 20...90, step: 5)
                        .frame(maxWidth: 280)
                }
                Text("SA-MP's limiter (sa-mp.cfg fpslimit). It only applies with the in-game Frame Limiter OFF. "
                     + "60 matches a 60 Hz MacBook display; going above it just burns battery.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Show Metal performance HUD (FPS, frame time, memory)", isOn: model.binding(\.showMetalHUD))
                Toggle("Benchmark mode (record frame times, show results after playing)", isOn: model.binding(\.benchmarkMode))
            } header: {
                Text("Performance")
            }

            Section {
                Toggle("Option key works as Alt", isOn: model.binding(\.optionKeyAsAlt))
                Toggle("Load d3d9.dll mods from the game folder (ReShade, ENB…)", isOn: model.binding(\.allowGameFolderD3D9))
                Text("Off by default so leftover DXVK files can't break rendering.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Input & mods")
            }

            Section {
                Picker("Runtime", selection: model.binding(\.runtimeID)) {
                    ForEach(WineRuntime.catalog) { runtime in
                        Text(runtime.displayName).tag(runtime.id)
                    }
                }
                .disabled(model.settings.customWinePath != nil)
                if let runtime = WineRuntime.find(id: model.settings.runtimeID) {
                    Text(runtime.notes).font(.caption).foregroundStyle(.secondary)
                    if model.settings.customWinePath == nil && !runtime.isInstalled(in: model.paths) {
                        Button("Download \(runtime.displayName)") { Task { await model.installWine() } }
                            .disabled(model.isBusy)
                    }
                }
                TextField("Custom wine binary (optional)", text: Binding(
                    get: { model.settings.customWinePath ?? "" },
                    set: { value in model.update { $0.customWinePath = value.isEmpty ? nil : value } }))
                Text("Point this at another Wine (e.g. a CrossOver or Sikarugir engine's bin/wine) to try it with the same prefix.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Wine Configuration…") { model.openWineTool("winecfg") }
                    Button("Show Game Folder") { model.reveal(model.paths.gameDirectory) }
                    Button("Show Logs") { model.reveal(model.paths.logs) }
                    Spacer()
                    Button("Recreate Wine Prefix…") { confirmReset = true }
                        .disabled(model.isBusy || model.isRunning)
                }
                .disabled(!model.setup.prefixReady)
                .confirmationDialog("Recreate the Wine prefix?", isPresented: $confirmReset) {
                    Button("Recreate", role: .destructive) { Task { await model.resetPrefix() } }
                } message: {
                    Text("Fixes a broken Windows environment. Your game folder, settings and SA-MP favorites are kept; anything else installed into the prefix is removed.")
                }
            } header: {
                Text("Wine")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
