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

            // Install DXVK to Wine prefix if available in WineEngine
            self.installDXVKToPrefix()

            // Configure Wine - try DXVK first if available
            let useDXVK = self.isDXVKInstalled()
            self.configureWine(useDXVK: useDXVK)

            if useDXVK {
                Logger.shared.info("Wine prefix configured with DXVK")
            } else {
                Logger.shared.info("Wine prefix configured with WineD3D (DXVK not found)")
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    private func createWinePrefix() -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL
        process.environment = ["WINEPREFIX": winePrefixURL.path, "WINEDEBUG": "-all"]
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) } }
        if let machine = machine, !machine.contains("arm64") {
             process.environment?["WINEARCH"] = "win32"
        }

        process.arguments = ["wineboot", "--init"]
        try? process.run()
        process.waitUntilExit()
        
        return process.terminationStatus == 0
    }

    private func removeDXVK(targetFolder: URL?) {
        // Stergem fisierele DXVK care cauzeaza erorile Vulkan
        // Le stergem atat din System32 cat si din folderul jocului
        
        let fileManager = FileManager.default
        let system32 = winePrefixURL.appendingPathComponent("drive_c/windows/system32")
        
        let filesToRemove = ["d3d9.dll", "dxgi.dll", "dxvk.conf"]
        
        // 1. Curatare System32
        for file in filesToRemove {
            let path = system32.appendingPathComponent(file)
            if fileManager.fileExists(atPath: path.path) {
                try? fileManager.removeItem(at: path)
                Logger.shared.info("Removed \(file) from System32")
            }
        }
        
        // 2. Curatare folder joc (daca e specificat)
        if let target = targetFolder {
            for file in filesToRemove {
                let path = target.appendingPathComponent(file)
                if fileManager.fileExists(atPath: path.path) {
                    try? fileManager.removeItem(at: path)
                    Logger.shared.info("Removed \(file) from Game Folder")
                }
            }
        }
    }

    /// Install DXVK DLLs from WineEngine to Wine prefix
    private func installDXVKToPrefix() {
        let fileManager = FileManager.default

        // Check if DXVK DLLs are available in WineEngine
        guard let bundlePath = Bundle.main.resourcePath else {
            Logger.shared.debug("Bundle path not found, checking project root...")
            return installDXVKFromProjectRoot()
        }

        let wineEngineDLLs = URL(fileURLWithPath: bundlePath)
            .appendingPathComponent("WineEngine/dlls/x32")

        // Fallback: check in project root
        if !fileManager.fileExists(atPath: wineEngineDLLs.path) {
            Logger.shared.debug("WineEngine DLLs not in bundle, checking project root...")
            return installDXVKFromProjectRoot()
        }

        // Get DXVK DLLs
        guard let dllFiles = try? fileManager.contentsOfDirectory(atPath: wineEngineDLLs.path) else {
            Logger.shared.debug("No DXVK DLLs found in WineEngine")
            return
        }

        let dxvkDlls = dllFiles.filter { $0.hasSuffix(".dll") }

        if dxvkDlls.isEmpty {
            Logger.shared.debug("No DXVK DLLs found to install")
            return
        }

        Logger.shared.info("Installing DXVK DLLs to Wine prefix...")

        // Copy to Wine prefix system32
        let system32 = winePrefixURL.appendingPathComponent("drive_c/windows/system32")
        try? fileManager.createDirectory(at: system32, withIntermediateDirectories: true)

        var installedCount = 0
        for dll in dxvkDlls {
            let source = wineEngineDLLs.appendingPathComponent(dll)
            let dest = system32.appendingPathComponent(dll)

            // Remove existing DLL
            try? fileManager.removeItem(at: dest)

            // Copy new DLL
            do {
                try fileManager.copyItem(at: source, to: dest)
                installedCount += 1
                Logger.shared.debug("Installed \(dll)")
            } catch {
                Logger.shared.warning("Failed to install \(dll): \(error.localizedDescription)")
            }
        }

        if installedCount > 0 {
            Logger.shared.info("✓ Installed \(installedCount) DXVK DLLs to Wine prefix")
        }
    }

    /// Install DXVK from project root (fallback for development builds)
    private func installDXVKFromProjectRoot() {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let wineEngineDLLs = URL(fileURLWithPath: currentDir)
            .appendingPathComponent("WineEngine/dlls/x32")

        guard fileManager.fileExists(atPath: wineEngineDLLs.path),
              let dllFiles = try? fileManager.contentsOfDirectory(atPath: wineEngineDLLs.path) else {
            Logger.shared.debug("DXVK DLLs not found in project root either")
            return
        }

        let dxvkDlls = dllFiles.filter { $0.hasSuffix(".dll") }

        if dxvkDlls.isEmpty {
            return
        }

        Logger.shared.info("Installing DXVK DLLs from project root...")

        let system32 = winePrefixURL.appendingPathComponent("drive_c/windows/system32")
        try? fileManager.createDirectory(at: system32, withIntermediateDirectories: true)

        var installedCount = 0
        for dll in dxvkDlls {
            let source = wineEngineDLLs.appendingPathComponent(dll)
            let dest = system32.appendingPathComponent(dll)

            try? fileManager.removeItem(at: dest)

            do {
                try fileManager.copyItem(at: source, to: dest)
                installedCount += 1
            } catch {
                Logger.shared.warning("Failed to install \(dll): \(error.localizedDescription)")
            }
        }

        if installedCount > 0 {
            Logger.shared.info("✓ Installed \(installedCount) DXVK DLLs from project root")
        }
    }

    /// Check if DXVK is installed AND MoltenVK is available
    private func isDXVKInstalled() -> Bool {
        // Check 1: DXVK DLLs in Wine prefix
        let system32 = winePrefixURL.appendingPathComponent("drive_c/windows/system32")
        let dxvkDll = system32.appendingPathComponent("d3d9.dll")

        guard FileManager.default.fileExists(atPath: dxvkDll.path) else {
            Logger.shared.info("DXVK not installed - d3d9.dll not found")
            return false
        }

        // Check 2: MoltenVK (Vulkan driver for macOS)
        let moltenVKPaths = [
            "/usr/local/share/vulkan/icd.d/MoltenVK_icd.json",
            "/usr/local/lib/libMoltenVK.dylib",
            "/opt/homebrew/lib/libMoltenVK.dylib"
        ]

        let moltenVKExists = moltenVKPaths.contains { FileManager.default.fileExists(atPath: $0) }

        if !moltenVKExists {
            Logger.shared.warning("DXVK DLLs found but MoltenVK not available - falling back to WineD3D")
            Logger.shared.warning("Install MoltenVK: brew install molten-vk")
            return false
        }

        Logger.shared.info("DXVK + MoltenVK detected - ready to use")
        return true
    }

    private func configureWine(useDXVK: Bool = true) {
        // 1. FIX: Windows XP (Compatibilitate maxima)
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine", "/v", "Version", "/d", "winxp", "/f"])

        // 2. FIX: Virtual Desktop @ 1280x720
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/d", "Default", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/d", "1280x720", "/f"])

        // 3. Audio Fix
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DirectSound", "/v", "HelBuflen", "/d", "512", "/f"])

        // 4. DXVK vs WineD3D configuration
        if useDXVK && isDXVKInstalled() {
            Logger.shared.info("Configuring Wine for DXVK (DirectX → Vulkan → Metal)")

            // Enable DXVK DLL overrides
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d9", "/d", "native", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "dxgi", "/d", "native", "/f"])

            // DXVK-specific registry settings
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "PixelShaderMode", "/d", "enabled", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\X11 Driver", "/v", "ScreenDepth", "/t", "REG_DWORD", "/d", "32", "/f"])
        } else {
            Logger.shared.info("Configuring Wine for WineD3D (fallback mode)")

            // Force builtin WineD3D (not native DXVK DLLs)
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d9", "/d", "builtin", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "dxgi", "/d", "builtin", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d11", "/d", "builtin", "/f"])

            // WineD3D optimizations
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "DirectDrawRenderer", "/d", "opengl", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "OffScreenRenderingMode", "/d", "fbo", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "PixelShaderMode", "/d", "enabled", "/f"])
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\X11 Driver", "/v", "ScreenDepth", "/t", "REG_DWORD", "/d", "32", "/f"])

            // ARB shaders (more stable than GLSL on macOS)
            runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "UseGLSL", "/d", "disabled", "/f"])
        }
    }

    // MARK: - Execution

    /// Detecteaza daca executabilul este un installer
    private func isInstaller(_ executablePath: String) -> Bool {
        let fileName = URL(fileURLWithPath: executablePath).lastPathComponent.lowercased()
        let installerPatterns = [
            "setup", "install", "installer", "unins",
            "uninst", "uninstall", "wise", "nsis"
        ]
        return installerPatterns.contains { fileName.contains($0) }
    }

    /// Aplica safe mode pentru installere (fara virtual desktop)
    private func applySafeModeForInstaller() {
        Logger.shared.info("Applying safe mode for installer...")
        // Sterge virtual desktop pentru installer
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/f"])
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/f"])
    }

    /// Restabileste virtual desktop dupa installer
    private func restoreVirtualDesktop() {
        Logger.shared.info("Restoring virtual desktop...")
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/d", "Default", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/d", "1280x720", "/f"])
    }

    /// Aplica low-end performance patch pentru M2 8GB
    private func applyLowEndPatch(gameDir: URL) {
        Logger.shared.info("Applying low-end performance patch...")

        // Path to patch script
        guard let bundlePath = Bundle.main.resourcePath else { return }
        let patchScript = URL(fileURLWithPath: bundlePath)
            .appendingPathComponent("GameOptimizations/patches/apply-low-end-settings.sh")

        // Fallback: check in project root
        let fallbackScript = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("GameOptimizations/patches/apply-low-end-settings.sh")

        let scriptPath = FileManager.default.fileExists(atPath: patchScript.path) ? patchScript : fallbackScript

        if !FileManager.default.fileExists(atPath: scriptPath.path) {
            Logger.shared.warning("Low-end patch script not found, applying manual settings...")
            applyManualLowEndSettings(gameDir: gameDir)
            return
        }

        // Run patch script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.path, gameDir.path]
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            Logger.shared.info("Low-end patch applied successfully")
        } else {
            Logger.shared.warning("Patch script failed, applying manual settings...")
            applyManualLowEndSettings(gameDir: gameDir)
        }
    }

    /// Manual low-end settings (fallback)
    private func applyManualLowEndSettings(gameDir: URL) {
        let settingsPath = gameDir.appendingPathComponent("gta_sa.set")

        let lowEndConfig = """
        [Display]
        Width=640
        Height=480
        Depth=32
        Windowed=0
        VSync=0
        FrameLimiter=0

        [Graphics]
        VideoMode=1
        Brightness=0
        DrawDistance=0.400000
        AntiAliasing=0
        VisualFX=0
        MipMapping=0
        Shadows=0

        [Audio]
        SfxVolume=100
        MusicVolume=50
        RadioVolume=50
        """

        try? lowEndConfig.write(to: settingsPath, atomically: true, encoding: .utf8)
        Logger.shared.info("Manual low-end settings applied")
    }

    func launchGame(executablePath: String, arguments: [String] = [], completion: @escaping (Bool) -> Void) {
        if isRunning { completion(false); return }

        DispatchQueue.global(qos: .userInitiated).async {
            // Detectam daca e installer si aplicam safe mode
            let isInstaller = self.isInstaller(executablePath)
            if isInstaller {
                self.applySafeModeForInstaller()
            }

            // Install DXVK DLLs to Wine prefix if available
            if !isInstaller {
                self.installDXVKToPrefix()
            }

            // Detect if DXVK is available
            let useDXVK = self.isDXVKInstalled() && !isInstaller

            let success = self.runWineProcess(path: executablePath, args: arguments, isInstaller: isInstaller, useDXVK: useDXVK)

            // Daca a fost installer, restabilim virtual desktop
            if isInstaller {
                self.restoreVirtualDesktop()
            }

            DispatchQueue.main.async { completion(success) }
        }
    }

    private func runWineProcess(path: String, args: [String], isInstaller: Bool = false, useDXVK: Bool = false) -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = winePrefixURL.path
        env["WINEDEBUG"] = "-all"

        if !isInstaller {
            if useDXVK {
                // DXVK MODE - DirectX → Vulkan → Metal
                Logger.shared.info("Using DXVK for rendering")

                // DXVK environment variables
                env["DXVK_HUD"] = "0"  // Disable HUD for performance
                env["DXVK_ASYNC"] = "1"  // Async shader compilation
                env["DXVK_STATE_CACHE_PATH"] = appSupportURL.appendingPathComponent("dxvk_cache").path
                env["DXVK_LOG_LEVEL"] = "warn"
                env["DXVK_CONFIG_FILE"] = appSupportURL.appendingPathComponent("../GameOptimizations/dxvk/dxvk.conf").path

                // MoltenVK optimizations for M2 8GB
                env["MVK_CONFIG_LOG_LEVEL"] = "1"  // Errors only
                env["MVK_CONFIG_TRACE_VULKAN_CALLS"] = "0"
                env["MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS"] = "0"  // Async
                env["MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS"] = "1"
                env["MVK_ALLOW_METAL_FENCES"] = "1"
                env["MVK_ALLOW_METAL_EVENTS"] = "1"
                env["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] = "1"

                // M2 8GB: Conservative memory settings
                env["VK_ICD_FILENAMES"] = "/usr/local/share/vulkan/icd.d/MoltenVK_icd.json"
            } else {
                // WineD3D MODE - Native Wine Direct3D
                Logger.shared.info("Using WineD3D for rendering (fallback)")

                // Remove DXVK vars
                env.removeValue(forKey: "DXVK_HUD")
                env.removeValue(forKey: "DXVK_ASYNC")

                // CSMT for WineD3D
                env["CSMT"] = "enabled"
                env["STAGING_SHARED_MEMORY"] = "1"
            }

            // Common optimizations (both DXVK and WineD3D)
            env["WINE_LARGE_ADDRESS_AWARE"] = "1"
            env["__GL_SHADER_DISK_CACHE_SIZE"] = "268435456"  // 256MB
            env["__GL_SYNC_TO_VBLANK"] = "0"

            // M2 optimization
            var systemInfo = utsname()
            uname(&systemInfo)
            let machine = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingUTF8: $0)
                }
            }
            if let machine = machine, machine.contains("arm64") {
                env["WINE_CPU_TOPOLOGY"] = "4:0"
                Logger.shared.info("M2 detected - using 4 performance cores")
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

        let mode: String
        if isInstaller {
            mode = "SAFE MODE (Installer)"
        } else if useDXVK {
            mode = "DXVK (DX9→Vulkan→Metal) / M2 Optimized"
        } else {
            mode = "WineD3D (Fallback) / XP Mode"
        }
        Logger.shared.info("Launching: wine \(fileName) (\(mode))")

        let logURL = appSupportURL.appendingPathComponent("logs/wine_game.log")
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
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
                    Logger.shared.info("Process terminated")
                }
            }
            return true
        } catch {
            Logger.shared.error("Run failed: \(error)")
            return false
        }
    }

    func killWine() { wineProcess?.terminate() }
    
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
        return WineStatus(isRunning: isRunning, prefixExists: FileManager.default.fileExists(atPath: winePrefixURL.path), wineVersion: "Unknown")
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
