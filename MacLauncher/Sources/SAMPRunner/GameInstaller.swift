import Foundation
import Darwin

/// Handles GTA SA and SA-MP installation
class GameInstaller {
    static let shared = GameInstaller()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let gtaSAPath: URL
    private let sampPath: URL

    // Required GTA SA files for verification
    private let requiredFiles = [
        "gta_sa.exe",
        "models/gta3.img",  // Main game data (not in data/ folder!)
        "audio/CONFIG/BankLkup.dat"
    ]

    private init() {
        appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SA-MP Runner")
        gtaSAPath = appSupportURL.appendingPathComponent("wine/drive_c/Program Files/Rockstar Games/GTA San Andreas")
        sampPath = gtaSAPath.appendingPathComponent("samp")
    }

    // MARK: - Installation Status

    func isGameInstalled() -> Bool {
        return verifyGTASAInstallation() && verifySAMPInstallation()
    }

    func verifyGTASAInstallation() -> Bool {
        guard fileManager.fileExists(atPath: gtaSAPath.path) else {
            Logger.shared.info("GTA SA directory does not exist")
            return false
        }

        for file in requiredFiles {
            let filePath = gtaSAPath.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath.path) {
                Logger.shared.warning("Missing required file: \(file)")
                return false
            }
        }

        Logger.shared.info("GTA SA installation verified")
        return true
    }

    func verifySAMPInstallation() -> Bool {
        let sampExe = gtaSAPath.appendingPathComponent("samp.exe")
        let sampDll = gtaSAPath.appendingPathComponent("samp.dll")

        let exists = fileManager.fileExists(atPath: sampExe.path) &&
                     fileManager.fileExists(atPath: sampDll.path)

        if exists {
            Logger.shared.info("SA-MP installation verified")
        } else {
            Logger.shared.info("SA-MP not installed")
        }

        return exists
    }

    // MARK: - GTA SA Installation

    func installGTASA(from sourceURL: URL, progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Logger.shared.info("Installing GTA SA from: \(sourceURL.path)")
            progress(0.1, "Creating installation directory...")

            // Create destination directory
            do {
                try self.fileManager.createDirectory(at: self.gtaSAPath, withIntermediateDirectories: true)
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to create installation directory: \(error.localizedDescription)")
                }
                return
            }

            progress(0.2, "Copying game files...")

            // Copy files
            let success = self.copyDirectory(from: sourceURL, to: self.gtaSAPath) { currentProgress in
                progress(0.2 + (currentProgress * 0.6), "Copying game files...")
            }

            if !success {
                DispatchQueue.main.async {
                    completion(false, "Failed to copy game files")
                }
                return
            }

            progress(0.8, "Verifying installation...")

            // Verify installation
            let verified = self.verifyGTASAInstallation()

            if verified {
                progress(0.9, "Applying compatibility patches...")
                self.applyGTASAPatches()

                progress(1.0, "Installation complete!")

                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Installation verification failed")
                }
            }
        }
    }

    private func copyDirectory(from source: URL, to destination: URL, progress: @escaping (Double) -> Void) -> Bool {
        do {
            // Get total size for progress calculation
            let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            var files: [(URL, Int64)] = []

            while let fileURL = enumerator?.nextObject() as? URL {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                    files.append((fileURL, Int64(size)))
                }
            }

            var copiedSize: Int64 = 0

            // Copy files
            for (fileURL, size) in files {
                let relativePath = fileURL.path.replacingOccurrences(of: source.path, with: "")
                let destURL = destination.appendingPathComponent(relativePath)

                // Create parent directory if needed
                let parentDir = destURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parentDir.path) {
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }

                // Remove existing file if present (for re-installation)
                if fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.removeItem(at: destURL)
                }

                // Copy file
                try fileManager.copyItem(at: fileURL, to: destURL)

                copiedSize += size
                progress(Double(copiedSize) / Double(totalSize))
            }

            return true
        } catch {
            Logger.shared.error("Copy failed: \(error.localizedDescription)")
            return false
        }
    }

    private func applyGTASAPatches() {
        Logger.shared.info("Applying GTA SA compatibility patches...")

        // Create optimized gta_sa.set (settings file)
        createOptimizedSettings()

        // Apply no-CD patch if needed
        // (Not implemented - users must have legitimate copy)

        // Set file permissions
        setFilePermissions()
    }

    private func createOptimizedSettings() {
        // GTA SA settings optimized for macOS + Wine
        let settings = """
        [Display]
        Width=1920
        Height=1080
        Depth=32
        Windowed=0
        VSync=0
        FrameLimiter=0

        [Graphics]
        VideoMode=1
        Brightness=0
        DrawDistance=1.2
        AntiAliasing=1
        VisualFX=2
        MipMapping=1

        [Audio]
        SfxVolume=100
        MusicVolume=80
        RadioVolume=80
        RadioEQ=0

        [Controller]
        Method=0

        [Game]
        Language=english
        """

        let settingsPath = gtaSAPath.appendingPathComponent("gta_sa.set")
        try? settings.write(to: settingsPath, atomically: true, encoding: .utf8)
    }

    private func setFilePermissions() {
        // Make executables... executable
        let executables = ["gta_sa.exe", "samp.exe"]
        for exe in executables {
            let path = gtaSAPath.appendingPathComponent(exe)
            if fileManager.fileExists(atPath: path.path) {
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
            }
        }
    }

    // MARK: - SA-MP Installation

    func installSAMP(version: String = "0.3.7", progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Logger.shared.info("Installing SA-MP version: \(version)")
            progress(0.1, "Downloading SA-MP...")

            // Download SA-MP
            let downloadURL = self.getSAMPDownloadURL(version: version)

            self.downloadFile(from: downloadURL) { fileURL in
                guard let fileURL = fileURL else {
                    DispatchQueue.main.async {
                        completion(false, "Failed to download SA-MP")
                    }
                    return
                }

                progress(0.5, "Extracting SA-MP...")

                // Extract and install
                let success = self.extractAndInstallSAMP(from: fileURL)

                if success {
                    progress(0.9, "Configuring SA-MP...")
                    self.configureSAMP()

                    progress(1.0, "SA-MP installation complete!")

                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Failed to extract SA-MP")
                    }
                }

                // Clean up
                try? self.fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func getSAMPDownloadURL(version: String) -> URL {
        // SA-MP official download URLs
        // Note: This is a placeholder - actual implementation would need to handle different versions
        return URL(string: "https://sa-mp.mp/files/SA-MP-\(version)-install.exe")!
    }

    private func downloadFile(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                Logger.shared.error("Download failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let localURL = localURL else {
                completion(nil)
                return
            }

            // Move to temporary location
            let tempURL = self.appSupportURL.appendingPathComponent("temp/samp_installer.exe")
            try? self.fileManager.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            try? self.fileManager.removeItem(at: tempURL)
            try? self.fileManager.moveItem(at: localURL, to: tempURL)

            completion(tempURL)
        }

        task.resume()
    }

    private func extractAndInstallSAMP(from installerURL: URL) -> Bool {
        Logger.shared.info("Installing SA-MP from: \(installerURL.path)")

        // Run SA-MP installer using Wine in silent mode
        let wineManager = WineManager.shared

        // Convert macOS path to Wine Windows path
        let winePath = installerURL.path.replacingOccurrences(of: "/Users", with: "Z:/Users")

        // Build Wine command to run installer silently
        // SA-MP installer supports /S for silent install with /D for destination
        let gtaSAWinePath = "C:\\Program Files\\Rockstar Games\\GTA San Andreas"
        let installCommand = "\"\(winePath)\" /S /D=\(gtaSAWinePath)"

        Logger.shared.info("Running SA-MP installer: wine cmd /c \(installCommand)")

        // Execute installer via Wine
        let process = Process()
        process.executableURL = URL(fileURLWithPath: wineManager.winePath)
        process.arguments = ["cmd", "/c", installCommand]

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = wineManager.winePrefix
        environment["WINEDEBUG"] = "-all" // Suppress Wine debug messages

        // Check architecture for WINEARCH
        var systemInfo = Darwin.utsname()
        Darwin.uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        let isAppleSilicon = machine?.contains("arm64") ?? false
        if !isAppleSilicon {
            environment["WINEARCH"] = "win32"
        }

        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                Logger.shared.info("SA-MP installer completed successfully")

                // Verify installation
                let sampExe = gtaSAPath.appendingPathComponent("samp.exe")
                if fileManager.fileExists(atPath: sampExe.path) {
                    Logger.shared.info("SA-MP installation verified")
                    return true
                } else {
                    Logger.shared.warning("SA-MP installer ran but files not found")
                    return false
                }
            } else {
                Logger.shared.error("SA-MP installer failed with status: \(process.terminationStatus)")
                return false
            }
        } catch {
            Logger.shared.error("Failed to run SA-MP installer: \(error.localizedDescription)")
            return false
        }
    }

    private func configureSAMP() {
        Logger.shared.info("Configuring SA-MP...")

        // Create SA-MP userdata directory
        let sampUserData = gtaSAPath.appendingPathComponent("SAMP")
        try? fileManager.createDirectory(at: sampUserData, withIntermediateDirectories: true)

        // Create default sa-mp.cfg
        let config = """
        [samp]
        pagesize=10
        gamma=1.0
        fontface=Arial
        fontweight=0
        timestamp=1
        """

        let configPath = sampUserData.appendingPathComponent("sa-mp.cfg")
        try? config.write(to: configPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Utilities

    func getGamePath() -> URL {
        return gtaSAPath
    }

    func getSAMPExecutablePath() -> String {
        return gtaSAPath.appendingPathComponent("samp.exe").path
    }

    func getGTASAExecutablePath() -> String {
        return gtaSAPath.appendingPathComponent("gta_sa.exe").path
    }

    func getInstallationSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: gtaSAPath, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    func uninstall(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Logger.shared.info("Uninstalling game...")

            do {
                try self.fileManager.removeItem(at: self.gtaSAPath)
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                Logger.shared.error("Uninstall failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
