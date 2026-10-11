import Foundation

public enum LaunchTarget: Equatable {
    /// samp.exe's own server browser.
    case sampBrowser
    /// Straight into a server: `samp.exe host:port`, nickname from the registry.
    case connect(ServerAddress)
    /// gta_sa.exe without SA-MP.
    case singlePlayer
}

public struct SessionResult {
    public let exitCode: Int32
    public let duration: TimeInterval
    public let logFile: URL
    public let benchmark: BenchmarkResult?
}

public enum RunnerError: LocalizedError {
    case gameNotInstalled
    case sampNotInstalled
    case invalidNickname(String)
    case alreadyRunning
    case prefixNotReady

    public var errorDescription: String? {
        switch self {
        case .gameNotInstalled: return "GTA San Andreas isn't installed yet. Import your game folder in Setup."
        case .sampNotInstalled: return "SA-MP isn't installed in the game folder. Run the SA-MP installer from Setup."
        case .invalidNickname(let reason): return reason
        case .alreadyRunning: return "The game is already running."
        case .prefixNotReady: return "The Wine prefix hasn't been created yet. Run setup first."
        }
    }
}

/// A running game. Ends when every Windows process in the prefix has exited
/// (samp.exe hands off to gta_sa.exe, so the first process alone isn't enough).
public final class GameSession {
    public let target: LaunchTarget
    public let logFile: URL
    public let startedAt = Date()
    public let benchmark: Bool
    let process: Process

    init(target: LaunchTarget, logFile: URL, benchmark: Bool, process: Process) {
        self.target = target
        self.logFile = logFile
        self.benchmark = benchmark
        self.process = process
    }
}

/// High-level operations shared by the CLI and the app. Methods block while Wine
/// works, so call them off the main thread.
public final class Runner {
    public let paths: AppPaths
    public let settingsStore: SettingsStore
    public let favorites: FavoritesStore
    let fileManager: FileManager

    // The app reads settings on the main thread while Wine work runs elsewhere.
    private let settingsLock = NSLock()
    private var _settings: Settings
    public var settings: Settings {
        settingsLock.lock(); defer { settingsLock.unlock() }
        return _settings
    }

    private let sessionLock = NSLock()
    private var _session: GameSession?
    public var currentSession: GameSession? {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _session
    }

    public init(paths: AppPaths = .default(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        settingsStore = SettingsStore(paths: paths)
        favorites = FavoritesStore(paths: paths)
        _settings = settingsStore.load()
    }

    public func updateSettings(_ change: (inout Settings) -> Void) throws {
        settingsLock.lock(); defer { settingsLock.unlock() }
        var updated = _settings
        change(&updated)
        updated = updated.normalized()
        try settingsStore.save(updated)
        _settings = updated
    }

    public var game: GameFolder { GameFolder(url: paths.gameDirectory, fileManager: fileManager) }

    public func resolvedRuntime() throws -> ResolvedRuntime {
        try RuntimeResolver.resolve(settings: settings, paths: paths, fileManager: fileManager)
    }

    public func prefix() throws -> WinePrefix {
        WinePrefix(paths: paths, runtime: try resolvedRuntime(), fileManager: fileManager)
    }

    // MARK: - Setup

    public var selectedRuntime: WineRuntime? {
        settings.customWinePath == nil ? WineRuntime.find(id: settings.runtimeID) : nil
    }

    public func installRuntime(progress: RuntimeInstaller.Progress? = nil) async throws {
        guard let runtime = selectedRuntime else { return }  // custom Wine: nothing to download
        try await RuntimeInstaller(paths: paths, fileManager: fileManager).install(runtime, progress: progress)
    }

    /// Creates the prefix if needed and applies the launcher's registry settings.
    public func preparePrefix(progress: ((String) -> Void)? = nil) throws {
        let prefix = try self.prefix()
        if !prefix.isInitialized {
            progress?("Creating Wine prefix (first run takes a minute)…")
            try prefix.create()
        }
        progress?("Applying settings…")
        try applyConfiguration(prefix: prefix)
    }

    func applyConfiguration(prefix: WinePrefix) throws {
        let settings = self.settings
        try prefix.localizeUserFolders()
        let exe = AppPaths.gameDirectoryWindows + #"\gta_sa.exe"#
        try prefix.apply(RegistryFile.launcherSettings(settings, gameExeWindowsPath: exe))
        if game.hasGame {
            try SAMPConfigFile.update(paths: paths, settings: settings, fileManager: fileManager)
        }
    }

    public func importGame(from folder: URL, replace: Bool = false) throws {
        try GameImporter.importGame(from: folder, paths: paths, replace: replace, fileManager: fileManager)
        GameImporter.importMacDocumentsUserFiles(paths: paths, fileManager: fileManager)
    }

    public var legacyInstallAvailable: Bool {
        GameFolder(url: paths.legacyGameDirectory, fileManager: fileManager).hasGame && !game.hasGame
    }

    /// Moves the game out of the old launcher's prefix. Returns false if there was none.
    public func importLegacyInstall() throws -> Bool {
        try GameImporter.importLegacyInstall(paths: paths, fileManager: fileManager)
    }

    /// Deletes the old launcher's prefix once its game has been moved out.
    public func removeLegacyPrefix() throws {
        guard fileManager.fileExists(atPath: paths.legacyPrefix.path) else { return }
        try fileManager.removeItem(at: paths.legacyPrefix)
    }

    /// Runs a Windows installer (e.g. the SA-MP client installer) and waits for it.
    public func runInstaller(_ installer: URL) throws {
        let prefix = try self.prefix()
        guard prefix.isInitialized else { throw RunnerError.prefixNotReady }
        try applyConfiguration(prefix: prefix)
        let env = Shell.environment(merging: LaunchEnvironment.maintenance(prefix: prefix.url))
        let log = try newLogFile(prefix: "installer")
        let process = try Shell.spawn(prefix.runtime.wine, [installer.path], environment: env,
                                      currentDirectory: installer.deletingLastPathComponent(), logFile: log)
        process.waitUntilExit()
        try prefix.waitForWineserver()
        // Installers sometimes recreate sa-mp.cfg; re-apply our keys.
        try applyConfiguration(prefix: prefix)
    }

    // MARK: - Play

    /// Starts the game. `onExit` runs on a background queue when it ends.
    @discardableResult
    public func launch(_ target: LaunchTarget, verbose: Bool = false,
                       onExit: ((SessionResult) -> Void)? = nil) throws -> GameSession {
        if currentSession != nil { throw RunnerError.alreadyRunning }
        let settings = self.settings
        if let reason = Nickname.validationError(settings.nickname), target != .singlePlayer {
            throw RunnerError.invalidNickname(reason)
        }
        let game = self.game
        guard game.hasGame else { throw RunnerError.gameNotInstalled }
        if target != .singlePlayer && !game.hasSAMP { throw RunnerError.sampNotInstalled }

        let prefix = try self.prefix()
        guard prefix.isInitialized else { throw RunnerError.prefixNotReady }
        try applyConfiguration(prefix: prefix)

        let benchmark = settings.benchmarkMode
        let env = Shell.environment(merging: LaunchEnvironment.game(settings: settings, prefix: prefix.url,
                                                                    benchmark: benchmark, verbose: verbose))
        let exe: String
        var args: [String] = []
        switch target {
        case .sampBrowser:
            exe = AppPaths.gameDirectoryWindows + #"\samp.exe"#
        case .connect(let address):
            exe = AppPaths.gameDirectoryWindows + #"\samp.exe"#
            args = [address.description]
            try? updateSettings { $0.lastServer = address.description }
        case .singlePlayer:
            exe = AppPaths.gameDirectoryWindows + #"\gta_sa.exe"#
        }

        let log = try newLogFile(prefix: benchmark ? "benchmark" : "game")
        let process = try Shell.spawn(prefix.runtime.wine, [exe] + args, environment: env,
                                      currentDirectory: game.url, logFile: log)
        let session = GameSession(target: target, logFile: log, benchmark: benchmark, process: process)
        sessionLock.lock(); _session = session; sessionLock.unlock()

        let renderer = settings.renderer.rawValue
        DispatchQueue.global(qos: .utility).async { [weak self] in
            process.waitUntilExit()
            try? prefix.waitForWineserver()
            let result = SessionResult(
                exitCode: process.terminationStatus,
                duration: Date().timeIntervalSince(session.startedAt),
                logFile: log,
                benchmark: benchmark ? Benchmark.summarize(logFile: log, renderer: renderer) : nil)
            if let self {
                self.sessionLock.lock(); self._session = nil; self.sessionLock.unlock()
            }
            onExit?(result)
        }
        return session
    }

    /// Ends the game and everything else running in the prefix.
    public func stopGame() {
        (try? prefix())?.killAll()
    }

    /// Opens winecfg / regedit / taskmgr in the prefix.
    public func openWineTool(_ tool: String) throws {
        let prefix = try self.prefix()
        guard prefix.isInitialized else { throw RunnerError.prefixNotReady }
        _ = try prefix.runTool(tool)
    }

    // MARK: - Logs

    func newLogFile(prefix name: String) throws -> URL {
        try fileManager.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        pruneLogs(keep: 15)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return paths.logs.appendingPathComponent("\(name)-\(formatter.string(from: Date())).log")
    }

    func pruneLogs(keep: Int) {
        guard let files = try? fileManager.contentsOfDirectory(at: paths.logs, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let logs = files.filter { $0.pathExtension == "log" }.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for old in logs.dropFirst(keep) { try? fileManager.removeItem(at: old) }
    }

    public func latestLog(prefix name: String) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(atPath: paths.logs.path) else { return nil }
        return files.filter { $0.hasPrefix(name + "-") && $0.hasSuffix(".log") }.sorted().last
            .map { paths.logs.appendingPathComponent($0) }
    }
}
