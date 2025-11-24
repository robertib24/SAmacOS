import Foundation

class WineManager {
    static let shared = WineManager()

    private var wineProcess: Process?
    private var isRunning = false

    private let appSupportURL: URL
    private let winePrefixURL: URL
    private let wineExecutableURL: URL

    private init() {
        let fileManager = FileManager.default
        appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SA-MP Runner")
        winePrefixURL = appSupportURL.appendingPathComponent("wine")

        if let bundlePath = Bundle.main.resourcePath,
           FileManager.default.fileExists(atPath: bundlePath + "/wine/bin/wine") {
            wineExecutableURL = URL(fileURLWithPath: bundlePath).appendingPathComponent("wine/bin/wine")
        } else {
            let possiblePaths = ["/opt/homebrew/bin/wine", "/usr/local/bin/wine", "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine"]
            let foundPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
            wineExecutableURL = URL(fileURLWithPath: foundPath ?? "/usr/local/bin/wine")
        }
    }

    // MARK: - Setup Logic

    func setupWinePrefix(completion: @escaping (Bool, String?) -> Void) {
        Logger.shared.info("Setting up Wine prefix...")
        DispatchQueue.global(qos: .userInitiated).async {
            let bootSuccess = self.createWinePrefix()
            if !bootSuccess {
                DispatchQueue.main.async { completion(false, "Wine boot failed") }
                return
            }

            // Configure Wine for WineD3D (OpenGL) - NO DXVK on Apple Silicon
            self.configureWineD3D()

            Logger.shared.info("Wine prefix configured with WineD3D (Apple Silicon compatible)")

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    private func createWinePrefix() -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL
        process.environment = ["WINEPREFIX": winePrefixURL.path, "WINEDEBUG": "-all"]
        
        process.arguments = ["wineboot", "--init"]
        try? process.run()
        process.waitUntilExit()
        
        return process.terminationStatus == 0
    }

    /// Remove DXVK DLLs ONLY from game folder - NOT from System32!
    /// System32 needs d3d9.dll for WineD3D to work!
    private func cleanGameFolderDXVK(gameFolder: URL) {
        let fileManager = FileManager.default
        
        // ONLY remove from game folder - these override System32
        let dxvkFiles = ["d3d9.dll", "dxgi.dll", "d3d11.dll", "d3d10.dll", "d3d10core.dll", "dxvk.conf"]
        
        for file in dxvkFiles {
            let path = gameFolder.appendingPathComponent(file)
            if fileManager.fileExists(atPath: path.path) {
                try? fileManager.removeItem(at: path)
                Logger.shared.info("Removed DXVK override: \(file) from Game Folder")
            }
        }
        
        // DO NOT touch System32! WineD3D needs those DLLs!
    }

    /// Configure Wine to use WineD3D (OpenGL) instead of DXVK
    private func configureWineD3D() {
        Logger.shared.info("Configuring WineD3D (OpenGL) for Apple Silicon...")

        // 1. Windows 7 for better DirectX 9 support
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine", "/v", "Version", "/d", "win7", "/f"])

        // 2. Virtual Desktop
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/d", "Default", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/d", "1280x720", "/f"])

        // 3. Audio settings
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DirectSound", "/v", "HelBuflen", "/d", "512", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DirectSound", "/v", "SndQueueMax", "/d", "3", "/f"])

        // 4. FORCE BUILTIN d3d9.dll (WineD3D) - THIS IS CRITICAL!
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d9", "/d", "builtin", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "ddraw", "/d", "builtin", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d8", "/d", "builtin", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d11", "/d", "builtin", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "dxgi", "/d", "builtin", "/f"])

        // 5. WineD3D OpenGL settings
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "DirectDrawRenderer", "/d", "opengl", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "OffScreenRenderingMode", "/d", "fbo", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "PixelShaderMode", "/d", "enabled", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "VertexShaderMode", "/d", "hardware", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "UseGLSL", "/d", "enabled", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "VideoMemorySize", "/d", "2048", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "csmt", "/t", "REG_DWORD", "/d", "3", "/f"])

        // 6. DirectX version registry (GTA SA checks this!)
        runWineCommand("reg", arguments: ["add", "HKLM\\Software\\Microsoft\\DirectX", "/v", "Version", "/d", "4.09.00.0904", "/f"])
        runWineCommand("reg", arguments: ["add", "HKLM\\Software\\Microsoft\\DirectX", "/v", "InstalledVersion", "/d", "4.09.00.0904", "/f"])

        Logger.shared.info("WineD3D configuration complete")
    }

    // MARK: - Execution

    private func isInstaller(_ executablePath: String) -> Bool {
        let fileName = URL(fileURLWithPath: executablePath).lastPathComponent.lowercased()
        let installerPatterns = ["setup", "install", "installer", "unins", "uninst", "uninstall"]
        return installerPatterns.contains { fileName.contains($0) }
    }

    private func applySafeModeForInstaller() {
        Logger.shared.info("Applying safe mode for installer...")
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/f"])
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/f"])
    }

    private func restoreVirtualDesktop() {
        Logger.shared.info("Restoring virtual desktop...")
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/d", "Default", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/d", "1280x720", "/f"])
    }

    func launchGame(executablePath: String, arguments: [String] = [], completion: @escaping (Bool) -> Void) {
        if isRunning { completion(false); return }

        DispatchQueue.global(qos: .userInitiated).async {
            let isInstaller = self.isInstaller(executablePath)
            if isInstaller {
                self.applySafeModeForInstaller()
            }

            // Only clean DXVK from game folder (NOT System32!)
            if !isInstaller {
                let gameFolder = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
                self.cleanGameFolderDXVK(gameFolder: gameFolder)
            }

            let success = self.runWineProcess(path: executablePath, args: arguments, isInstaller: isInstaller)

            if isInstaller {
                self.restoreVirtualDesktop()
            }

            DispatchQueue.main.async { completion(success) }
        }
    }

    private func runWineProcess(path: String, args: [String], isInstaller: Bool = false) -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = winePrefixURL.path
        env["WINEDEBUG"] = "-all"

        if !isInstaller {
            Logger.shared.info("Using WineD3D (OpenGL) for rendering - M2 compatible")

            // WineD3D / OpenGL optimizations
            env["STAGING_SHARED_MEMORY"] = "1"
            env["__GL_THREADED_OPTIMIZATIONS"] = "1"
            env["__GL_SYNC_TO_VBLANK"] = "0"
            env["WINE_LARGE_ADDRESS_AWARE"] = "1"

            // M2 CPU optimization
            var systemInfo = utsname()
            uname(&systemInfo)
            let machine = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingUTF8: $0)
                }
            }
            if let machine = machine, machine.contains("arm64") {
                env["WINE_CPU_TOPOLOGY"] = "4:0"
                Logger.shared.info("Apple Silicon detected - using 4 performance cores")
            }
        } else {
            Logger.shared.info("Running installer in safe mode")
        }

        env["FREETYPE_PROPERTIES"] = "truetype:interpreter-version=35"
        process.environment = env

        let fileURL = URL(fileURLWithPath: path)
        let workingDir = fileURL.deletingLastPathComponent()
        let fileName = fileURL.lastPathComponent

        process.currentDirectoryURL = workingDir
        process.arguments = [fileName] + args
        process.qualityOfService = .userInteractive

        let mode = isInstaller ? "SAFE MODE (Installer)" : "WineD3D (OpenGL) / M2 Optimized"
        Logger.shared.info("Launching: wine \(fileName) (\(mode))")

        let logURL = appSupportURL.appendingPathComponent("logs/wine_game.log")
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let logFile = try? FileHandle(forWritingTo: logURL) {
            process.standardOutput = logFile
            process.standardError = logFile
        }

        do {
            try process.run()
            self.wineProcess = process
            self.isRunning = true
            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isRunning = false
                    Logger.shared.info("Game process terminated")
                }
            }
            return true
        } catch {
            Logger.shared.error("Failed to launch: \(error)")
            return false
        }
    }

    func killWine() {
        wineProcess?.terminate()
    }
    
    func shutdown() {
        killWine()
        let p = Process()
        p.executableURL = wineExecutableURL
        p.environment = ["WINEPREFIX": winePrefixURL.path]
        p.arguments = ["wineserver", "-k"]
        try? p.run()
        p.waitUntilExit()
    }

    func getStatus() -> WineStatus {
        return WineStatus(
            isRunning: isRunning,
            prefixExists: FileManager.default.fileExists(atPath: winePrefixURL.path),
            wineVersion: "WineD3D (OpenGL)"
        )
    }
    
    @discardableResult
    func runWineCommand(_ command: String, arguments: [String]) -> Bool {
        let p = Process()
        p.executableURL = wineExecutableURL
        p.environment = ["WINEPREFIX": winePrefixURL.path, "WINEDEBUG": "-all"]
        p.arguments = [command] + arguments
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
    
    var winePrefix: String { return winePrefixURL.path }
}

public struct WineStatus {
    let isRunning: Bool
    let prefixExists: Bool
    let wineVersion: String
}
