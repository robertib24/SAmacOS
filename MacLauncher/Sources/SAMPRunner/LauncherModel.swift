#if os(macOS)
import AppKit
import RunnerCore
import SwiftUI

/// UI state for the launcher. All `Runner` calls go through one serial queue so
/// Wine operations never overlap and never block the main thread.
@MainActor
final class LauncherModel: ObservableObject {
    struct SetupState {
        var rosettaMissing = false
        var runtimeInstalled = false
        var prefixReady = false
        var gameInstalled = false
        var sampInstalled = false
        var legacyAvailable = false
        var executable: GameFolder.ExecutableKind = .missing
        var dxvkLeftovers: [String] = []

        var readyToPlay: Bool { runtimeInstalled && prefixReady && gameInstalled && sampInstalled && !rosettaMissing }
    }

    enum Section: String, CaseIterable, Identifiable {
        case play = "Play"
        case servers = "Servers"
        case settings = "Settings"
        case setup = "Setup"
        case diagnostics = "Diagnostics"

        // A data-driven List selects by ID, so the ID is the section itself.
        var id: Self { self }

        var icon: String {
            switch self {
            case .play: return "play.circle"
            case .servers: return "network"
            case .settings: return "slider.horizontal.3"
            case .setup: return "wrench.and.screwdriver"
            case .diagnostics: return "stethoscope"
            }
        }
    }

    @Published var section: Section? = .play
    @Published private(set) var settings: Settings
    @Published private(set) var setup = SetupState()
    @Published private(set) var busyMessage: String?
    @Published private(set) var progress: Double?
    @Published var errorMessage: String?

    @Published private(set) var isRunning = false
    @Published private(set) var sessionNote: String?
    @Published private(set) var lastBenchmark: BenchmarkResult?

    @Published private(set) var favorites: [ServerEntry] = []
    @Published private(set) var internetServers: [ServerEntry] = []
    @Published private(set) var loadingServers = false
    @Published private(set) var serverListError: String?

    @Published private(set) var checks: [DiagnosticCheck] = []

    let runner: Runner
    private let work = DispatchQueue(label: "com.samprunner.work", qos: .userInitiated)

    init(runner: Runner = Runner()) {
        self.runner = runner
        settings = runner.settings
        favorites = runner.favorites.load()
        refreshSetup()
        if !setup.readyToPlay { section = .setup }
    }

    var paths: AppPaths { runner.paths }

    // MARK: - Running blocking work

    private func background<T>(_ body: @escaping (Runner) throws -> T) async throws -> T {
        let runner = self.runner
        return try await withCheckedThrowingContinuation { continuation in
            work.async { continuation.resume(with: Result { try body(runner) }) }
        }
    }

    /// Runs `body` while showing `message`, reporting errors in an alert.
    private func perform(_ message: String, _ body: @escaping (Runner) throws -> Void) async {
        busyMessage = message
        defer { busyMessage = nil; progress = nil; refreshSetup() }
        do {
            try await background(body)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isBusy: Bool { busyMessage != nil }

    // MARK: - Settings

    func binding<Value>(_ keyPath: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { value in self.update { $0[keyPath: keyPath] = value } })
    }

    func update(_ change: (inout Settings) -> Void) {
        var updated = settings
        change(&updated)
        let runtimeChanged = updated.runtimeID != settings.runtimeID || updated.customWinePath != settings.customWinePath
        settings = updated.normalized()
        let snapshot = settings
        work.async { [runner] in
            do {
                try runner.updateSettings { $0 = snapshot }
            } catch {
                let message = error.localizedDescription
                Task { @MainActor in self.errorMessage = message }
            }
            if runtimeChanged {
                Task { @MainActor in self.refreshSetup() }
            }
        }
    }

    var nicknameError: String? { Nickname.validationError(settings.nickname) }

    // MARK: - Setup

    func refreshSetup() {
        let system = SystemInfo.current()
        var state = SetupState()
        state.rosettaMissing = system.isAppleSilicon && !system.rosettaInstalled
        state.runtimeInstalled = (try? runner.resolvedRuntime()) != nil
        state.prefixReady = FileManager.default.fileExists(atPath: paths.prefix.appendingPathComponent("system.reg").path)
        let game = runner.game
        state.gameInstalled = game.hasGame
        state.sampInstalled = game.hasSAMP
        state.executable = game.executableKind
        state.legacyAvailable = runner.legacyInstallAvailable
        state.dxvkLeftovers = game.hasGame ? game.dxvkLeftovers.map(\.lastPathComponent) : []
        setup = state
    }

    func installWine() async {
        busyMessage = "Preparing Wine…"
        progress = 0
        do {
            try await runner.installRuntime { fraction, message in
                Task { @MainActor in
                    self.progress = fraction
                    self.busyMessage = message
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            busyMessage = nil
            progress = nil
            refreshSetup()
            return
        }
        progress = nil
        await perform("Creating the Wine prefix (the first run takes a minute)…") { try $0.preparePrefix() }
    }

    func chooseGameFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your GTA San Andreas folder (the one with gta_sa.exe)"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let replace = setup.gameInstalled
        Task {
            await perform("Importing the game…") { runner in
                try runner.importGame(from: url, replace: replace)
                if (try? runner.prefix())?.isInitialized == true { try runner.preparePrefix() }
            }
        }
    }

    func importLegacy() async {
        await perform("Moving the game from the previous launcher…") { runner in
            _ = try runner.importLegacyInstall()
            if (try? runner.prefix())?.isInitialized == true { try runner.preparePrefix() }
        }
    }

    func runSAMPInstaller() {
        let panel = NSOpenPanel()
        panel.title = "Choose the SA-MP client installer (.exe)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await perform("Running the SA-MP installer — choose \(AppPaths.gameDirectoryWindows) when it asks for the GTA folder…") {
                try $0.runInstaller(url)
            }
        }
    }

    func disableDXVKLeftovers() async {
        await perform("Disabling leftover DXVK files…") { _ = try $0.game.disableDXVKLeftovers() }
    }

    // MARK: - Play

    func play(_ target: LaunchTarget) {
        if target != .singlePlayer, let reason = nicknameError {
            errorMessage = reason
            return
        }
        guard !isRunning else { return }
        isRunning = true
        sessionNote = settings.benchmarkMode ? "Benchmark mode: recording frame times." : nil
        Task {
            do {
                _ = try await background { runner in
                    try runner.launch(target) { result in
                        Task { @MainActor in self.sessionEnded(result) }
                    }
                }
                if case .connect(let address) = target {
                    update { $0.lastServer = address.description }
                }
            } catch {
                isRunning = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sessionEnded(_ result: SessionResult) {
        isRunning = false
        if let bench = result.benchmark {
            lastBenchmark = bench
            sessionNote = nil
        } else if settings.benchmarkMode {
            sessionNote = "Not enough gameplay frames were recorded for a benchmark. Play for at least 30 s after loading."
        } else {
            sessionNote = nil
        }
    }

    func stop() {
        work.async { [runner] in runner.stopGame() }
    }

    // MARK: - Servers

    func loadInternetServers() async {
        loadingServers = true
        serverListError = nil
        defer { loadingServers = false }
        do {
            internetServers = try await OpenMPServerList.fetch().sorted { ($0.players ?? 0) > ($1.players ?? 0) }
        } catch {
            serverListError = "Couldn't load the open.mp server list: \(error.localizedDescription)"
        }
    }

    /// Queries servers a dozen at a time and merges ping/players as results arrive.
    func refresh(_ entries: [ServerEntry]) async {
        for start in stride(from: 0, to: entries.count, by: 12) {
            let batch = Array(entries[start..<min(start + 12, entries.count)])
            let results = await withTaskGroup(of: ServerEntry.self) { group -> [ServerEntry] in
                for entry in batch {
                    group.addTask { await Self.query(entry) }
                }
                var collected: [ServerEntry] = []
                for await entry in group { collected.append(entry) }
                return collected
            }
            merge(results)
        }
    }

    nonisolated private static func query(_ entry: ServerEntry) async -> ServerEntry {
        var copy = entry
        if let (info, ping) = try? await SAMPQuery.queryAsync(entry.address, timeout: 1.5) {
            copy.apply(info, pingMS: ping)
        } else {
            copy.pingMS = nil
        }
        return copy
    }

    private func merge(_ updated: [ServerEntry]) {
        let byID = Dictionary(updated.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        favorites = favorites.map { byID[$0.id] ?? $0 }
        internetServers = internetServers.map { byID[$0.id] ?? $0 }
        try? runner.favorites.save(favorites)
    }

    func isFavorite(_ entry: ServerEntry) -> Bool {
        favorites.contains { $0.address == entry.address }
    }

    func toggleFavorite(_ entry: ServerEntry) {
        do {
            favorites = isFavorite(entry) ? try runner.favorites.remove(entry.address) : try runner.favorites.add(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFavorite(_ text: String) async {
        guard let address = ServerAddress(text) else {
            errorMessage = "“\(text)” isn't a server address. Use host:port, e.g. 1.2.3.4:7777."
            return
        }
        let entry = ServerEntry(address: address)
        toggleFavorite(entry)
        await refresh([entry])
    }

    // MARK: - Diagnostics & tools

    func runDiagnostics() async {
        checks = (try? await background { Doctor.run($0) }) ?? []
    }

    func openWineTool(_ tool: String) {
        Task { await perform("Opening \(tool)…") { try $0.openWineTool(tool) } }
    }

    func reveal(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
#endif
