import Cocoa

class LauncherViewController: NSViewController {

    // UI Elements
    private var playButton: NSButton!
    private var settingsButton: NSButton!
    private var serverBrowserButton: NSButton!
    private var statusLabel: NSTextField!
    private var performanceLabel: NSTextField!

    private let wineManager = WineManager.shared
    private let gameInstaller = GameInstaller.shared
    private let performanceOptimizer = PerformanceOptimizer.shared

    private var performanceTimer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateStatus()
        startPerformanceMonitoring()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        performanceTimer?.invalidate()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Background - use CAGradientLayer instead of deprecated lockFocus/unlockFocus
        view.wantsLayer = true

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.1, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        view.layer?.insertSublayer(gradientLayer, at: 0)

        // Title
        let titleLabel = NSTextField(labelWithString: "SA-MP Runner")
        titleLabel.font = NSFont.systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 0, y: 480, width: 900, height: 60)
        view.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Grand Theft Auto: San Andreas Multiplayer for macOS")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 0, y: 450, width: 900, height: 20)
        view.addSubview(subtitleLabel)

        // Status label
        statusLabel = NSTextField(labelWithString: "Ready to play")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 0, y: 300, width: 900, height: 20)
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.backgroundColor = .clear
        view.addSubview(statusLabel)

        // Play button
        playButton = NSButton(frame: NSRect(x: 350, y: 250, width: 200, height: 50))
        playButton.title = "PLAY"
        playButton.bezelStyle = .rounded
        playButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        playButton.target = self
        playButton.action = #selector(playButtonClicked)

        // Style the button
        playButton.wantsLayer = true
        playButton.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.2, alpha: 1.0).cgColor
        playButton.layer?.cornerRadius = 8

        view.addSubview(playButton)

        // Server Browser button
        serverBrowserButton = NSButton(frame: NSRect(x: 300, y: 190, width: 300, height: 36))
        serverBrowserButton.title = "Server Browser"
        serverBrowserButton.bezelStyle = .rounded
        serverBrowserButton.target = self
        serverBrowserButton.action = #selector(serverBrowserClicked)
        view.addSubview(serverBrowserButton)

        // Settings button
        settingsButton = NSButton(frame: NSRect(x: 300, y: 140, width: 300, height: 36))
        settingsButton.title = "Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        view.addSubview(settingsButton)

        // Performance label
        performanceLabel = NSTextField(labelWithString: "")
        performanceLabel.font = NSFont.systemFont(ofSize: 10)
        performanceLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        performanceLabel.alignment = .right
        performanceLabel.frame = NSRect(x: 700, y: 10, width: 180, height: 40)
        performanceLabel.isBezeled = false
        performanceLabel.isEditable = false
        performanceLabel.backgroundColor = .clear
        view.addSubview(performanceLabel)

        // System info label
        let systemInfo = performanceOptimizer.getSystemInfo()
        let infoLabel = NSTextField(labelWithString: "\(systemInfo.gpuName) • \(systemInfo.cpuCoreCount) cores")
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        infoLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        infoLabel.alignment = .left
        infoLabel.frame = NSRect(x: 20, y: 10, width: 400, height: 20)
        infoLabel.isBezeled = false
        infoLabel.isEditable = false
        infoLabel.backgroundColor = .clear
        view.addSubview(infoLabel)
    }

    // MARK: - Actions

    @objc private func playButtonClicked() {
        if !gameInstaller.isGameInstalled() {
            showInstallationRequired()
            return
        }

        Logger.shared.info("Launching game...")
        statusLabel.stringValue = "Launching..."
        playButton.isEnabled = false

        let wineStatus = wineManager.getStatus()
        if !wineStatus.prefixExists {
            // Need to setup Wine first
            setupWineAndLaunch()
        } else {
            // Launch directly
            launchGame()
        }
    }

    private func setupWineAndLaunch() {
        statusLabel.stringValue = "Setting up Wine environment..."

        wineManager.setupWinePrefix { success, error in
            if success {
                self.launchGame()
            } else {
                self.showError("Failed to setup Wine: \(error ?? "Unknown error")")
                self.playButton.isEnabled = true
            }
        }
    }

    private func launchGame() {
        let executablePath = gameInstaller.getSAMPExecutablePath()

        wineManager.launchGame(executablePath: executablePath) { success in
            if success {
                self.statusLabel.stringValue = "Game is running"
                self.playButton.title = "STOP"
                self.playButton.action = #selector(self.stopGameClicked)
                self.playButton.isEnabled = true
            } else {
                self.showError("Failed to launch game")
                self.playButton.isEnabled = true
            }
        }
    }

    @objc private func stopGameClicked() {
        wineManager.killWine()
        playButton.title = "PLAY"
        playButton.action = #selector(playButtonClicked)
        statusLabel.stringValue = "Game stopped"
    }

    @objc private func serverBrowserClicked() {
        let browserWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        browserWindow.title = "Server Browser"
        browserWindow.center()

        let browserController = ServerBrowserViewController()
        browserWindow.contentViewController = browserController

        browserWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func settingsClicked() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Settings"
        settingsWindow.center()

        let settingsController = SettingsViewController()
        settingsWindow.contentViewController = settingsController

        settingsWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Status Updates

    private func updateStatus() {
        let wineStatus = wineManager.getStatus()

        if wineStatus.isRunning {
            statusLabel.stringValue = "Game is running"
            playButton.title = "STOP"
            playButton.action = #selector(stopGameClicked)
        } else if !gameInstaller.isGameInstalled() {
            statusLabel.stringValue = "Game not installed"
            playButton.isEnabled = false
        } else {
            statusLabel.stringValue = "Ready to play"
            playButton.isEnabled = true
        }
    }

    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceStats()
        }
    }

    private func updatePerformanceStats() {
        let stats = performanceOptimizer.getPerformanceStats()
        let memoryMB = Double(stats.memoryUsage) / 1024.0 / 1024.0

        performanceLabel.stringValue = String(format: "CPU: %.1f%%\nRAM: %.0f MB", stats.cpuUsage, memoryMB)
    }

    // MARK: - Helpers

    private func showInstallationRequired() {
        let alert = NSAlert()
        alert.messageText = "Game Not Installed"
        alert.informativeText = "GTA San Andreas is not installed. Please install the game first."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Now")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Show installation wizard
            let wizardWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            wizardWindow.title = "Installation Wizard"
            wizardWindow.center()

            let wizardController = InstallationWizardViewController()
            wizardWindow.contentViewController = wizardController

            wizardWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

// MARK: - Server Browser (Placeholder)

class ServerBrowserViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let label = NSTextField(labelWithString: "Server Browser - Coming Soon")
        label.font = NSFont.systemFont(ofSize: 24)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 270, width: 800, height: 60)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        view.addSubview(label)
    }
}

// MARK: - Settings View

class SettingsViewController: NSViewController {
    private var presetPopup: NSPopUpButton!
    private let optimizer = PerformanceOptimizer.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Title
        let titleLabel = NSTextField(labelWithString: "Graphics Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.frame = NSRect(x: 30, y: 440, width: 540, height: 30)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)

        // Performance preset
        let presetLabel = NSTextField(labelWithString: "Performance Preset:")
        presetLabel.frame = NSRect(x: 30, y: 380, width: 150, height: 24)
        presetLabel.isEditable = false
        presetLabel.isBordered = false
        presetLabel.backgroundColor = .clear
        view.addSubview(presetLabel)

        presetPopup = NSPopUpButton(frame: NSRect(x: 190, y: 378, width: 200, height: 26))
        presetPopup.addItems(withTitles: ["Auto", "Low", "Medium", "High", "Ultra"])
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        view.addSubview(presetPopup)

        // System info
        let systemInfo = optimizer.getSystemInfo()

        let infoText = """
        System Information:

        Architecture: \(systemInfo.isAppleSilicon ? "Apple Silicon" : "Intel")
        GPU: \(systemInfo.gpuName)
        RAM: \(ByteCountFormatter.string(fromByteCount: Int64(systemInfo.totalRAM), countStyle: .memory))
        CPU Cores: \(systemInfo.cpuCoreCount)
        macOS: \(systemInfo.osVersion)
        MetalFX: \(systemInfo.supportsMetalFX ? "Available" : "Not Available")
        """

        let infoLabel = NSTextField(labelWithString: infoText)
        infoLabel.frame = NSRect(x: 30, y: 200, width: 540, height: 150)
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = .clear
        infoLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        view.addSubview(infoLabel)

        // Shader cache button
        let clearCacheButton = NSButton(frame: NSRect(x: 30, y: 150, width: 200, height: 32))
        clearCacheButton.title = "Clear Shader Cache"
        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.target = self
        clearCacheButton.action = #selector(clearCacheClicked)
        view.addSubview(clearCacheButton)

        // Apply button
        let applyButton = NSButton(frame: NSRect(x: 470, y: 30, width: 100, height: 32))
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(applyClicked)
        view.addSubview(applyButton)

        // Reset Installation button
        let resetButton = NSButton(frame: NSRect(x: 30, y: 30, width: 180, height: 32))
        resetButton.title = "Reset Installation"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetInstallationClicked)
        view.addSubview(resetButton)
    }

    @objc private func presetChanged() {
        // Preview will be applied, but not saved until Apply is clicked
    }

    @objc private func applyClicked() {
        let presetIndex = presetPopup.indexOfSelectedItem
        let presets: [PerformanceOptimizer.PerformancePreset] = [.auto, .low, .medium, .high, .ultra]

        if presetIndex < presets.count {
            optimizer.applyPreset(presets[presetIndex])

            let alert = NSAlert()
            alert.messageText = "Settings Applied"
            alert.informativeText = "Performance settings have been applied successfully."
            alert.alertStyle = .informational
            alert.runModal()
        }

        view.window?.close()
    }

    @objc private func clearCacheClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear Shader Cache?"
        alert.informativeText = "This will delete all compiled shaders. They will be rebuilt on next launch, which may cause temporary stuttering."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            optimizer.clearShaderCache()

            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Cache Cleared"
            confirmAlert.informativeText = "Shader cache has been cleared."
            confirmAlert.alertStyle = .informational
            confirmAlert.runModal()
        }
    }

    @objc private func resetInstallationClicked() {
        let alert = NSAlert()
        alert.messageText = "Reset Installation?"
        alert.informativeText = """
        This will completely remove:
        • Wine prefix and configuration
        • Installed games and SA-MP
        • All settings and cache

        You will need to reinstall everything.

        Are you sure?
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset Everything")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            performReset()
        }
    }

    private func performReset() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SA-MP Runner")

        do {
            // Remove entire application directory
            try fileManager.removeItem(at: appDir)

            // Reset user defaults
            UserDefaults.standard.removeObject(forKey: "HasLaunchedBefore")
            UserDefaults.standard.synchronize()

            let alert = NSAlert()
            alert.messageText = "Reset Complete"
            alert.informativeText = "All data has been removed. Please restart the application to begin fresh installation."
            alert.alertStyle = .informational
            alert.runModal()

            // Close settings and quit app
            view.window?.close()
            NSApp.terminate(nil)

        } catch {
            let alert = NSAlert()
            alert.messageText = "Reset Failed"
            alert.informativeText = "Failed to remove data: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}
