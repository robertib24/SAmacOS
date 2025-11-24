import Foundation

class GameInstaller {
    static let shared = GameInstaller()
    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let gtaSAPath: URL
    
    private var isInstalling = false

    private init() {
        appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SA-MP Runner")
        gtaSAPath = appSupportURL.appendingPathComponent("wine/drive_c/Program Files/Rockstar Games/GTA San Andreas")
    }

    func isGameInstalled() -> Bool {
        return fileManager.fileExists(atPath: gtaSAPath.appendingPathComponent("gta_sa.exe").path) &&
               fileManager.fileExists(atPath: gtaSAPath.appendingPathComponent("samp.exe").path)
    }
    
    func verifyGTASAInstallation() -> Bool {
        return fileManager.fileExists(atPath: gtaSAPath.appendingPathComponent("gta_sa.exe").path)
    }

    func installGTASA(from sourceURL: URL, progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Logger.shared.info("Installing GTA SA...")
            do {
                try self.fileManager.createDirectory(at: self.gtaSAPath, withIntermediateDirectories: true)
                
                let enumerator = self.fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: nil)
                while let fileURL = enumerator?.nextObject() as? URL {
                    let relativePath = fileURL.path.replacingOccurrences(of: sourceURL.path, with: "")
                    let destURL = self.gtaSAPath.appendingPathComponent(relativePath)
                    if !relativePath.isEmpty {
                        try? self.fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? self.fileManager.removeItem(at: destURL)
                        try self.fileManager.copyItem(at: fileURL, to: destURL)
                    }
                }
                
                self.applyPatches()
                DispatchQueue.main.async { completion(true, nil) }
            } catch {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
            }
        }
    }

    func installSAMP(version: String, progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        if isInstalling { return }
        isInstalling = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let urlString = "https://gta-multiplayer.cz/downloads/sa-mp-0.3.7-R5-2-MP-install.exe"
            guard let url = URL(string: urlString) else { return }
            
            let tempDir = self.appSupportURL.appendingPathComponent("temp")
            try? self.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let installerPath = tempDir.appendingPathComponent("samp_install.exe")
            try? self.fileManager.removeItem(at: installerPath)
            
            progress(0.2, "Downloading Installer...")
            
            let semaphore = DispatchSemaphore(value: 0)
            var downloadError: Error?
            
            let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
                if let error = error { downloadError = error }
                else if let localURL = localURL {
                    do {
                        try self.fileManager.moveItem(at: localURL, to: installerPath)
                        let size = (try? self.fileManager.attributesOfItem(atPath: installerPath.path)[.size] as? UInt64) ?? 0
                        if size < 2000000 { throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "File too small"]) }
                    } catch { downloadError = error }
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
            
            if let error = downloadError {
                self.isInstalling = false
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }
            
            progress(0.5, "Running Installer...")
            
            let group = DispatchGroup()
            group.enter()
            
            WineManager.shared.launchGame(executablePath: installerPath.path) { _ in
                group.leave()
            }
            
            var attempts = 0
            while attempts < 180 {
                sleep(1)
                if self.fileManager.fileExists(atPath: self.gtaSAPath.appendingPathComponent("samp.exe").path) {
                    break
                }
                attempts += 1
            }
            
            self.isInstalling = false
            self.configureSAMP()
            self.applyPatches()
            
            DispatchQueue.main.async { completion(true, nil) }
        }
    }
    
    private func applyPatches() {
        // FIX: Doar ștergem gta_sa.set pentru a lăsa jocul să-și creeze unul nou curat
        // pentru Windows XP environment.
        let settingsPath = gtaSAPath.appendingPathComponent("gta_sa.set")
        try? fileManager.removeItem(at: settingsPath)
    }
    
    private func configureSAMP() {
        let config = "[samp]\npagesize=10\ngamma=1.0\nfontface=Arial\nfontweight=0\ntimestamp=1"
        try? config.write(to: gtaSAPath.appendingPathComponent("SAMP/sa-mp.cfg"), atomically: true, encoding: .utf8)
    }
    
    func getGamePath() -> URL { return gtaSAPath }
    func getSAMPExecutablePath() -> String { return gtaSAPath.appendingPathComponent("samp.exe").path }
    func getGTASAExecutablePath() -> String { return gtaSAPath.appendingPathComponent("gta_sa.exe").path }
    func verifySAMPInstallation() -> Bool { return isGameInstalled() }
}
