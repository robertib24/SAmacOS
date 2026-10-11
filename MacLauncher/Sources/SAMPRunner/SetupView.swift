#if os(macOS)
import RunnerCore
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        let setup = model.setup
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Setup").font(.largeTitle.bold())
                Text("Everything is stored in ~/Library/Application Support/SA-MP Runner. Nothing is installed system-wide and Homebrew isn't needed.")
                    .foregroundStyle(.secondary)

                if setup.rosettaMissing {
                    Step(done: false, title: "Rosetta 2",
                         detail: "Wine is an Intel app, so Apple Silicon Macs need Rosetta. macOS offers to install it the first time Wine starts, or run: softwareupdate --install-rosetta --agree-to-license") {
                        EmptyView()
                    }
                }

                Step(done: setup.runtimeInstalled,
                     title: "Wine runtime",
                     detail: setup.runtimeInstalled
                        ? "Installed."
                        : "Downloads \(WineRuntime.find(id: model.settings.runtimeID)?.displayName ?? "Wine") (~190 MB) and checks its SHA-256.") {
                    if !setup.runtimeInstalled {
                        Button("Download & Install") { Task { await model.installWine() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isBusy)
                    }
                }

                Step(done: setup.prefixReady,
                     title: "Wine prefix",
                     detail: setup.prefixReady ? "Ready." : "A private Windows environment for the game. Created after Wine is installed.") {
                    if setup.runtimeInstalled && !setup.prefixReady {
                        Button("Create") { Task { await model.installWine() } }
                            .disabled(model.isBusy)
                    }
                }

                Step(done: setup.gameInstalled,
                     title: "GTA San Andreas",
                     detail: gameDetail(setup)) {
                    HStack {
                        if setup.legacyAvailable {
                            Button("Import from previous SA-MP Runner") { Task { await model.importLegacy() } }
                                .buttonStyle(.borderedProminent)
                        }
                        Button(setup.gameInstalled ? "Replace…" : "Choose Game Folder…") { model.chooseGameFolder() }
                    }
                    .disabled(model.isBusy)
                }

                Step(done: setup.sampInstalled,
                     title: "SA-MP client",
                     detail: setup.sampInstalled
                        ? "samp.exe and samp.dll found."
                        : "If your game folder doesn't include SA-MP yet, get the SA-MP 0.3.7-R5 (or 0.3.DL) client installer and run it here. Choose \(AppPaths.gameDirectoryWindows) when it asks for the GTA folder.") {
                    if setup.gameInstalled && setup.prefixReady {
                        Button(setup.sampInstalled ? "Run Installer Again…" : "Run SA-MP Installer…") { model.runSAMPInstaller() }
                            .disabled(model.isBusy)
                    }
                }

                if !setup.dxvkLeftovers.isEmpty {
                    Step(done: false,
                         title: "Leftover DXVK files",
                         detail: "\(setup.dxvkLeftovers.joined(separator: ", ")) from the old setup are in the game folder. DXVK's Direct3D 9 doesn't work on MoltenVK; they'll be renamed, not deleted.") {
                        Button("Disable Them") { Task { await model.disableDXVKLeftovers() } }
                            .disabled(model.isBusy)
                    }
                }

                if setup.readyToPlay {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("All set.")
                        Button("Go to Play") { model.section = .play }
                            .buttonStyle(.borderedProminent)
                    }
                    .font(.title3)
                    .padding(.top, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { model.refreshSetup() }
    }

    private func gameDetail(_ setup: LauncherModel.SetupState) -> String {
        if setup.gameInstalled {
            return setup.executable.description
        }
        if setup.legacyAvailable {
            return "Found in the previous launcher's Wine prefix. Importing moves it here (instant) and keeps your settings and SA-MP favorites."
        }
        return "Choose the folder that contains gta_sa.exe. It's copied into the prefix (on APFS the copy is instant and uses no extra space)."
    }
}

private struct Step<Actions: View>: View {
    let done: Bool
    let title: String
    let detail: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    actions()
                }
                Spacer(minLength: 0)
            }
            .padding(6)
        }
    }
}
#endif
