#if os(macOS)
import AppKit
import RunnerCore
import SwiftUI

@main
struct SAMPRunnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup("SA-MP Runner") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 880, minHeight: 580)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Game") {
                Button("Play") { model.play(.sampBrowser) }
                    .keyboardShortcut("p", modifiers: [.command])
                    .disabled(model.isRunning || !model.setup.readyToPlay)
                Button("Stop Game") { model.stop() }
                    .keyboardShortcut(".", modifiers: [.command])
                    .disabled(!model.isRunning)
                Divider()
                Button("Wine Configuration…") { model.openWineTool("winecfg") }
                Button("Show Game Folder") { model.reveal(model.paths.gameDirectory) }
                Button("Show Logs") { model.reveal(model.paths.logs) }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started with `swift run` (no app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closing the launcher doesn't stop a running game; it keeps running on its own.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        NavigationSplitView {
            List(LauncherModel.Section.allCases, selection: $model.section) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .badge(section == .setup && !model.setup.readyToPlay ? Text("!") : nil)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            VStack(spacing: 0) {
                switch model.section ?? .play {
                case .play: PlayView()
                case .servers: ServersView()
                case .settings: SettingsView()
                case .setup: SetupView()
                case .diagnostics: DiagnosticsView()
                }
                if let message = model.busyMessage {
                    StatusBar(message: message, progress: model.progress)
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct StatusBar: View {
    let message: String
    let progress: Double?

    var body: some View {
        HStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress).frame(width: 160)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(message).font(.callout).lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
#endif
