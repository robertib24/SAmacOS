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
    }

    // MARK: - Execution

    func launchGame(executablePath: String, arguments: [String] = [], completion: @escaping (Bool) -> Void) {
        if isRunning { completion(false); return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Asiguram curatarea DXVK inainte de fiecare lansare
            let gameDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            self.removeDXVK(targetFolder: gameDir)
            
            let success = self.runWineProcess(path: executablePath, args: arguments)
            DispatchQueue.main.async { completion(success) }
        }
    }

    private func runWineProcess(path: String, args: [String]) -> Bool {
        let process = Process()
        process.executableURL = wineExecutableURL
        
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = winePrefixURL.path
        env["WINEDEBUG"] = "-all"
        // Eliminam variabilele DXVK pentru a fi siguri
        env.removeValue(forKey: "DXVK_HUD")
        env.removeValue(forKey: "DXVK_ASYNC")
        
        process.environment = env

        let fileURL = URL(fileURLWithPath: path)
        let workingDir = fileURL.deletingLastPathComponent()
        let fileName = fileURL.lastPathComponent

        process.currentDirectoryURL = workingDir
        process.arguments = [fileName] + args
        
        Logger.shared.info("Launching: wine \(fileName) (WineD3D / XP Mode)")

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
