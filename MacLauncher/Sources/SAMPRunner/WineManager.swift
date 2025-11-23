import Foundation

/// Manages Wine process lifecycle and configuration
class WineManager {
    static let shared = WineManager()

    private var wineProcess: Process?
    private var isRunning = false

    // Paths
    private let appSupportURL: URL
    private let winePrefixURL: URL
    private let wineExecutableURL: URL

    private init() {
        let fileManager = FileManager.default
        appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SA-MP Runner")
        winePrefixURL = appSupportURL.appendingPathComponent("wine")

        // Wine bundled with the app
        if let bundlePath = Bundle.main.resourcePath,
           FileManager.default.fileExists(atPath: bundlePath + "/wine/bin/wine") {
            wineExecutableURL = URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("wine/bin/wine")
        } else {
            // Fallback to system wine - detect based on architecture
            let possiblePaths = [
                "/opt/homebrew/bin/wine",    // Apple Silicon (M1/M2/M3)
                "/usr/local/bin/wine",       // Intel Mac
                "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine"  // Wine.app
            ]

            var foundPath: String?
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    foundPath = path
                    break
                }
            }

            wineExecutableURL = URL(fileURLWithPath: foundPath ?? "/usr/local/bin/wine")
        }
    }

    // MARK: - Wine Setup

    func setupWinePrefix(completion: @escaping (Bool, String?) -> Void) {
        Logger.shared.info("Setting up Wine prefix at: \(winePrefixURL.path)")

        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.createWinePrefix()

            DispatchQueue.main.async {
                if success {
                    self.configureWinePrefix()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to create Wine prefix")
                }
            }
        }
    }

    private func createWinePrefix() -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = winePrefixURL.path

        // Don't set WINEARCH on Apple Silicon - Wine 8+ uses wow64 mode automatically
        // On Intel, we can use win32 for better compatibility
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        let isAppleSilicon = machine?.contains("arm64") ?? false

        // Only set WINEARCH on Intel Macs
        if !isAppleSilicon {
            environment["WINEARCH"] = "win32"
        }
        // On Apple Silicon, Wine will use win64 with wow64 support for 32-bit apps

        environment["WINEDEBUG"] = "-all"  // Suppress debug output for setup
        process.environment = environment

        process.arguments = ["wineboot", "--init"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            Logger.shared.error("Failed to create Wine prefix: \(error.localizedDescription)")
            return false
        }
    }

    private func configureWinePrefix() {
        Logger.shared.info("Configuring Wine prefix...")

        // Set registry values for optimal performance
        setRegistryValue(key: "HKCU\\Software\\Wine\\DirectSound", name: "HelBuflen", value: "512")
        setRegistryValue(key: "HKCU\\Software\\Wine\\DirectSound", name: "SndQueueMax", value: "3")

        // Configure DLL overrides for DXVK
        setDLLOverride("d3d9", "native")
        setDLLOverride("dxgi", "native")

        // Windows version (Windows 10)
        setRegistryValue(key: "HKCU\\Software\\Wine", name: "Version", value: "win10")
    }

    private func setRegistryValue(key: String, name: String, value: String) {
        let process = Process()
        process.executableURL = wineExecutableURL

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = winePrefixURL.path
        process.environment = environment

        process.arguments = ["reg", "add", key, "/v", name, "/d", value, "/f"]

        try? process.run()
        process.waitUntilExit()
    }

    private func setDLLOverride(_ dll: String, _ mode: String) {
        let key = "HKCU\\Software\\Wine\\DllOverrides"
        setRegistryValue(key: key, name: dll, value: mode)
    }

    // MARK: - Game Launch

    func launchGame(executablePath: String, arguments: [String] = [], completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
            Logger.shared.warning("Game is already running")
            completion(false)
            return
        }

        Logger.shared.info("Launching game: \(executablePath)")

        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.startWineProcess(executablePath: executablePath, arguments: arguments)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    private func startWineProcess(executablePath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL

        // Setup environment variables for optimal performance
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = winePrefixURL.path

        // Don't set WINEARCH on Apple Silicon (wow64 handles it automatically)

        // DXVK settings
        environment["DXVK_HUD"] = "fps,devinfo,memory"
        environment["DXVK_ASYNC"] = "1"
        environment["DXVK_STATE_CACHE_PATH"] = appSupportURL.appendingPathComponent("dxvk_cache").path
        environment["DXVK_LOG_LEVEL"] = "warn"

        // MoltenVK settings (macOS specific)
        environment["MVK_CONFIG_LOG_LEVEL"] = "1"  // Errors only
        environment["MVK_CONFIG_TRACE_VULKAN_CALLS"] = "0"
        environment["MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS"] = "0"
        environment["MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS"] = "1"
        environment["MVK_ALLOW_METAL_FENCES"] = "1"
        environment["MVK_ALLOW_METAL_EVENTS"] = "1"

        // Performance settings
        environment["STAGING_SHARED_MEMORY"] = "1"
        environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
        environment["__GL_THREADED_OPTIMIZATIONS"] = "1"

        // macOS Metal settings
        environment["MTL_HUD_ENABLED"] = "0"
        environment["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] = "1"

        process.environment = environment

        // Set working directory to the game folder
        let gameDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
        process.currentDirectoryURL = gameDirectory

        // Run wine with just the executable name (not full path) from the game directory
        // This avoids issues with spaces in paths
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        process.arguments = [executableName] + arguments

        Logger.shared.info("Working directory: \(gameDirectory.path)")
        Logger.shared.info("Executing: wine \(executableName)")

        // Redirect output to log file
        let logURL = appSupportURL.appendingPathComponent("logs/wine_game.log")
        if let logFile = try? FileHandle(forWritingTo: logURL) {
            process.standardOutput = logFile
            process.standardError = logFile
        }

        do {
            try process.run()
            self.wineProcess = process
            self.isRunning = true

            // Monitor process termination
            process.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isRunning = false
                    Logger.shared.info("Game process terminated")
                }
            }

            return true
        } catch {
            Logger.shared.error("Failed to launch game: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Process Management

    func killWine() {
        guard let process = wineProcess, isRunning else {
            return
        }

        Logger.shared.info("Terminating Wine process...")
        process.terminate()

        // Force kill after 5 seconds if still running
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            if self.isRunning {
                Logger.shared.warning("Force killing Wine process")
                self.wineProcess?.interrupt()
            }
        }
    }

    func shutdown() {
        killWine()

        // Run wineserver --kill to clean up
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: wineExecutableURL.path
            .replacingOccurrences(of: "/bin/wine", with: "/bin/wineserver"))

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = winePrefixURL.path
        killProcess.environment = environment

        killProcess.arguments = ["--kill"]

        try? killProcess.run()
        killProcess.waitUntilExit()
    }

    func getStatus() -> WineStatus {
        return WineStatus(
            isRunning: isRunning,
            prefixExists: FileManager.default.fileExists(atPath: winePrefixURL.path),
            wineVersion: getWineVersion()
        )
    }

    private func getWineVersion() -> String {
        let process = Process()
        process.executableURL = wineExecutableURL
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let version = String(data: data, encoding: .utf8) {
                return version.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            Logger.shared.error("Failed to get Wine version: \(error.localizedDescription)")
        }

        return "Unknown"
    }

    private func convertToWindowsPath(_ macPath: String) -> String {
        // Convert macOS path to Windows path
        // /Users/.../wine/drive_c/Program Files/... -> C:\Program Files\...
        let driveCPrefix = winePrefixURL.path + "/drive_c/"

        if macPath.hasPrefix(driveCPrefix) {
            // Remove the drive_c prefix and convert to Windows path
            let relativePath = String(macPath.dropFirst(driveCPrefix.count))
            let windowsPath = "C:\\" + relativePath.replacingOccurrences(of: "/", with: "\\")
            Logger.shared.info("Converted path: \(macPath) -> \(windowsPath)")
            return windowsPath
        } else {
            // If path doesn't match expected format, return as-is and log warning
            Logger.shared.warning("Path doesn't match Wine prefix format: \(macPath)")
            return macPath
        }
    }

    // MARK: - Utilities

    func runWineCommand(_ command: String, arguments: [String] = []) -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = winePrefixURL.path
        process.environment = environment

        process.arguments = [command] + arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // Public getters for Wine paths
    var winePath: String {
        return wineExecutableURL.path
    }

    var winePrefix: String {
        return winePrefixURL.path
    }
}

// MARK: - Wine Status

struct WineStatus {
    let isRunning: Bool
    let prefixExists: Bool
    let wineVersion: String
}
