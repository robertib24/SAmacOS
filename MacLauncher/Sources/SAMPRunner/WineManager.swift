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
            
            // Curatam DXVK si configuram Wine standard
            self.removeDXVK(targetFolder: nil)
            self.configureWine()
            
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

    private func configureWine() {
        // 1. FIX: Windows XP (Compatibilitate maxima)
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine", "/v", "Version", "/d", "winxp", "/f"])

        // 2. FIX: Virtual Desktop @ 1280x720
        // Acesta este singurul mod de a evita eroarea "Cannot find 800x600 video mode"
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer", "/v", "Desktop", "/d", "Default", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Explorer\\Desktops", "/v", "Default", "/d", "1280x720", "/f"])

        // 3. Audio Fix
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\DirectSound", "/v", "HelBuflen", "/d", "512", "/f"])

        // 4. CLEANUP: Stergem override-urile DXVK din registry
        // Astfel Wine va folosi "builtin" (WineD3D) in loc de "native" (DXVK)
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\DllOverrides", "/v", "d3d9", "/f"])
        runWineCommand("reg", arguments: ["delete", "HKCU\\Software\\Wine\\DllOverrides", "/v", "dxgi", "/f"])

        // 5. PERFORMANCE: WineD3D optimizations pentru Direct3D9
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "csmt", "/t", "REG_DWORD", "/d", "7", "/f"])  // CSMT cu mai multe thread-uri
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "DirectDrawRenderer", "/d", "opengl", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "OffScreenRenderingMode", "/d", "fbo", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "StrictDrawOrdering", "/d", "disabled", "/f"])

        // 6. COLOR FIX: Pixel format si color depth
        // Fortam 32-bit color pentru a evita probleme cu culorile
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "PixelShaderMode", "/d", "enabled", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\X11 Driver", "/v", "ScreenDepth", "/t", "REG_DWORD", "/d", "32", "/f"])

        // 7. SHADER FIX: Dezactivam GLSL daca cauzeaza probleme cu culorile
        // ARB shaders sunt mai stabili pe macOS pentru jocuri vechi
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "UseGLSL", "/d", "disabled", "/f"])

        // 8. PERFORMANCE: Memory optimizations - AGGRESSIVE
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "VideoMemorySize", "/t", "REG_DWORD", "/d", "8192", "/f"])  // 8GB VRAM

        // 9. RENDERING PERFORMANCE: Dezactivam AlwaysOffscreen pentru FPS mai bun
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "AlwaysOffscreen", "/d", "disabled", "/f"])

        // 10. FPS BOOST: Optimizari agresive pentru performance maxim
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "RenderTargetLockMode", "/d", "disabled", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "Multisampling", "/d", "disabled", "/f"])
        runWineCommand("reg", arguments: ["add", "HKCU\\Software\\Wine\\Direct3D", "/v", "SampleCount", "/t", "REG_DWORD", "/d", "1", "/f"])
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

    func launchGame(executablePath: String, arguments: [String] = [], completion: @escaping (Bool) -> Void) {
        if isRunning { completion(false); return }

        DispatchQueue.global(qos: .userInitiated).async {
            // Asiguram curatarea DXVK inainte de fiecare lansare
            let gameDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            self.removeDXVK(targetFolder: gameDir)

            // Detectam daca e installer si aplicam safe mode
            let isInstaller = self.isInstaller(executablePath)
            if isInstaller {
                self.applySafeModeForInstaller()
            }

            let success = self.runWineProcess(path: executablePath, args: arguments, isInstaller: isInstaller)

            // Daca a fost installer, restabilim virtual desktop
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

        // Eliminam variabilele DXVK pentru a fi siguri
        env.removeValue(forKey: "DXVK_HUD")
        env.removeValue(forKey: "DXVK_ASYNC")

        if !isInstaller {
            // PERFORMANCE BOOST: Enable CSMT (Command Stream Multi-Threading)
            // Aceasta este cea mai importanta optimizare pentru WineD3D!
            env["CSMT"] = "enabled"
            env["STAGING_SHARED_MEMORY"] = "1"

            // PERFORMANCE BOOST: Wine optimizations
            env["WINE_LARGE_ADDRESS_AWARE"] = "1"  // Mai mult RAM pentru joc
            env["__GL_THREADED_OPTIMIZATIONS"] = "1"  // OpenGL threading

            // AGGRESSIVE FPS BOOST: Mai multe thread-uri pentru rendering
            let cpuCount = ProcessInfo.processInfo.processorCount
            env["__GL_SHADER_DISK_CACHE_SIZE"] = "1073741824"  // 1GB shader cache
            env["__GL_SYNC_TO_VBLANK"] = "0"  // Disable vsync la driver level
            env["WINE_CPU_TOPOLOGY"] = "\(cpuCount):0"  // Foloseste toate core-urile

            // REMOVED: esync/fsync - cauzeaza probleme de performance si culori

            // PERFORMANCE: Apple Silicon - prioritize performance cores + more aggressive
            var systemInfo = utsname()
            uname(&systemInfo)
            let machine = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingUTF8: $0)
                }
            }
            if let machine = machine, machine.contains("arm64") {
                // Pe Apple Silicon, setam afinity agresiva + mai multa prioritate
                env["WINE_CPU_TOPOLOGY"] = "8:0"  // Foloseste 8 P-cores daca sunt disponibile
                Logger.shared.info("Apple Silicon detected - using all performance cores")
            }
        } else {
            // SAFE MODE pentru installere - minimal env vars
            Logger.shared.info("Running installer in safe mode (no virtual desktop, minimal optimizations)")
        }

        // macOS specific optimizations (aplicam si pentru installere)
        env["FREETYPE_PROPERTIES"] = "truetype:interpreter-version=35"

        process.environment = env

        let fileURL = URL(fileURLWithPath: path)
        let workingDir = fileURL.deletingLastPathComponent()
        let fileName = fileURL.lastPathComponent

        process.currentDirectoryURL = workingDir
        process.arguments = [fileName] + args

        // Set high priority pentru mai bun performance
        process.qualityOfService = .userInteractive

        let mode = isInstaller ? "SAFE MODE (Installer)" : "WineD3D+CSMT / XP Mode / Optimized"
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
