import Foundation

/// Creates and maintains the Wine prefix.
public struct WinePrefix {
    public let paths: AppPaths
    public let runtime: ResolvedRuntime
    let fileManager: FileManager

    public init(paths: AppPaths, runtime: ResolvedRuntime, fileManager: FileManager = .default) {
        self.paths = paths
        self.runtime = runtime
        self.fileManager = fileManager
    }

    public var url: URL { paths.prefix }

    public var isInitialized: Bool {
        fileManager.fileExists(atPath: url.appendingPathComponent("system.reg").path)
    }

    private var env: [String: String] {
        Shell.environment(merging: LaunchEnvironment.maintenance(prefix: url))
    }

    /// `wineboot --init`, then keeps Documents/Desktop/etc. inside the prefix.
    public func create() throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        // First boot of a WoW64 prefix takes a while on Rosetta; be generous.
        try Shell.runChecked(runtime.wine, ["wineboot", "--init"], environment: env, timeout: 600)
        try waitForWineserver(timeout: 120)
        try localizeUserFolders()
    }

    /// Wine links `Documents`, `Desktop`, `Downloads`... to the folders in your Mac
    /// home. GTA SA and SA-MP write their settings into Documents, which would put
    /// them in ~/Documents and trigger macOS privacy prompts. Replace those links
    /// with real folders so everything stays in the prefix. Wine only creates the
    /// links when the folder is missing, so this sticks.
    public func localizeUserFolders() throws {
        guard let userDir = paths.prefixUserDirectory(fileManager: fileManager) else { return }
        for name in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos", "Templates"] {
            let link = userDir.appendingPathComponent(name)
            guard let attributes = try? fileManager.attributesOfItem(atPath: link.path),
                  attributes[.type] as? FileAttributeType == .typeSymbolicLink else { continue }
            try fileManager.removeItem(at: link)
            try fileManager.createDirectory(at: link, withIntermediateDirectories: true)
        }
    }

    /// Imports the registry settings, skipping the Wine round-trip when nothing changed
    /// since the last import.
    public func apply(_ registry: RegistryFile) throws {
        let data = registry.encoded()
        let stamp = url.appendingPathComponent(".samp-runner-registry.reg")
        if let previous = try? Data(contentsOf: stamp), previous == data { return }

        let temp = paths.driveC.appendingPathComponent("windows/temp", isDirectory: true)
        try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
        let file = temp.appendingPathComponent("samp-runner.reg")
        try data.write(to: file, options: .atomic)
        try Shell.runChecked(runtime.wine, ["reg", "import", #"C:\windows\temp\samp-runner.reg"#],
                             environment: env, timeout: 120)
        try? fileManager.removeItem(at: file)
        try data.write(to: stamp, options: .atomic)
    }

    /// Opens a Wine tool (winecfg, regedit, taskmgr...) in this prefix.
    public func runTool(_ tool: String, arguments: [String] = []) throws -> Process {
        try Shell.spawn(runtime.wine, [tool] + arguments, environment: env,
                        currentDirectory: nil, logFile: nil)
    }

    /// Ends every Windows process in the prefix (the game, samp.exe, helpers).
    public func killAll() {
        _ = try? Shell.run(runtime.wineserver, ["-k"], environment: env, timeout: 30)
    }

    /// Blocks until every process in the prefix has exited.
    public func waitForWineserver(timeout: TimeInterval? = nil) throws {
        _ = try Shell.run(runtime.wineserver, ["-w"], environment: env, timeout: timeout)
    }

    public func wineVersion() -> String? {
        guard let result = try? Shell.run(runtime.wine, ["--version"], environment: env, timeout: 30),
              result.succeeded else { return nil }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
