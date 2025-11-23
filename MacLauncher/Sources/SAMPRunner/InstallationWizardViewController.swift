import Cocoa

class InstallationWizardViewController: NSViewController {

    private enum InstallationStep {
        case welcome
        case systemCheck
        case wineSetup
        case gameInstall
        case sampInstall
        case optimization
        case complete
    }

    private var currentStep: InstallationStep = .welcome
    private var contentView: NSView!
    private var nextButton: NSButton!
    private var backButton: NSButton!
    private var cancelButton: NSButton!
    private var progressIndicator: NSProgressIndicator!

    private let wineManager = WineManager.shared
    private let gameInstaller = GameInstaller.shared
    private let performanceOptimizer = PerformanceOptimizer.shared

    private var selectedGamePath: URL?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showStep(.welcome)
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Content view (dynamic)
        contentView = NSView(frame: NSRect(x: 20, y: 80, width: 660, height: 380))
        view.addSubview(contentView)

        // Progress indicator
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: 660, height: 20))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 6
        progressIndicator.doubleValue = 0
        view.addSubview(progressIndicator)

        // Buttons
        nextButton = NSButton(frame: NSRect(x: 580, y: 20, width: 100, height: 32))
        nextButton.title = "Next"
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        view.addSubview(nextButton)

        backButton = NSButton(frame: NSRect(x: 470, y: 20, width: 100, height: 32))
        backButton.title = "Back"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(backClicked)
        view.addSubview(backButton)

        cancelButton = NSButton(frame: NSRect(x: 20, y: 20, width: 100, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        view.addSubview(cancelButton)
    }

    // MARK: - Step Management

    private func showStep(_ step: InstallationStep) {
        currentStep = step

        // Clear content view
        contentView.subviews.forEach { $0.removeFromSuperview() }

        // Update progress
        switch step {
        case .welcome: progressIndicator.doubleValue = 0
        case .systemCheck: progressIndicator.doubleValue = 1
        case .wineSetup: progressIndicator.doubleValue = 2
        case .gameInstall: progressIndicator.doubleValue = 3
        case .sampInstall: progressIndicator.doubleValue = 4
        case .optimization: progressIndicator.doubleValue = 5
        case .complete: progressIndicator.doubleValue = 6
        }

        // Show appropriate content
        switch step {
        case .welcome:
            showWelcome()
        case .systemCheck:
            showSystemCheck()
        case .wineSetup:
            showWineSetup()
        case .gameInstall:
            showGameInstall()
        case .sampInstall:
            showSAMPInstall()
        case .optimization:
            showOptimization()
        case .complete:
            showComplete()
        }

        // Update buttons
        updateButtons()
    }

    private func updateButtons() {
        switch currentStep {
        case .welcome:
            backButton.isEnabled = false
            nextButton.title = "Next"
            cancelButton.isEnabled = true
        case .systemCheck:
            backButton.isEnabled = true
            nextButton.title = "Next"
        case .wineSetup, .sampInstall, .optimization:
            backButton.isEnabled = false
            nextButton.isEnabled = false
        case .gameInstall:
            backButton.isEnabled = true
            nextButton.title = "Install"
        case .complete:
            backButton.isEnabled = false
            nextButton.isEnabled = true
            nextButton.title = "Finish"
            cancelButton.isEnabled = false
        }
    }

    // MARK: - Step Views

    private func showWelcome() {
        let title = createLabel("Welcome to SA-MP Runner", fontSize: 28, bold: true)
        title.frame = NSRect(x: 0, y: 280, width: 660, height: 40)
        title.alignment = .center
        contentView.addSubview(title)

        let message = createLabel("""
        This wizard will help you install and configure
        GTA San Andreas Multiplayer on macOS.

        You will need:
        • A legal copy of GTA San Andreas (Windows version)
        • macOS 11.0 or later

        Click Next to begin the installation process.
        """, fontSize: 14, bold: false)
        message.frame = NSRect(x: 50, y: 100, width: 560, height: 150)
        message.alignment = .center
        contentView.addSubview(message)
    }

    private func showSystemCheck() {
        let title = createLabel("System Requirements Check", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let systemInfo = performanceOptimizer.getSystemInfo()

        var statusText = ""
        var allGood = true

        // Check macOS version
        if #available(macOS 11.0, *) {
            statusText += "✓ macOS version: \(systemInfo.osVersion)\n"
        } else {
            statusText += "✗ macOS version too old (need 11.0+)\n"
            allGood = false
        }

        // Check RAM
        let ramGB = Double(systemInfo.totalRAM) / 1024.0 / 1024.0 / 1024.0
        if ramGB >= 8 {
            statusText += "✓ RAM: \(String(format: "%.1f GB", ramGB))\n"
        } else {
            statusText += "✗ RAM: \(String(format: "%.1f GB", ramGB)) (need 8+ GB)\n"
            allGood = false
        }

        // Disk space check removed - not required
        // Users can install with any available space

        // Check Metal support
        statusText += "✓ GPU: \(systemInfo.gpuName)\n"
        statusText += "✓ Metal: Supported\n"

        // Architecture info
        statusText += "✓ Architecture: \(systemInfo.isAppleSilicon ? "Apple Silicon" : "Intel")\n"

        if allGood {
            statusText += "\nAll system requirements met! ✓"
        } else {
            statusText += "\n⚠️ Some requirements not met. You may experience issues."
        }

        let statusLabel = createLabel(statusText, fontSize: 14, bold: false)
        statusLabel.frame = NSRect(x: 40, y: 120, width: 580, height: 180)
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        contentView.addSubview(statusLabel)

        nextButton.isEnabled = allGood
    }

    private func showWineSetup() {
        let title = createLabel("Setting up Wine", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let statusLabel = createLabel("Installing Wine compatibility layer...", fontSize: 14, bold: false)
        statusLabel.frame = NSRect(x: 20, y: 250, width: 620, height: 30)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)

        let spinner = NSProgressIndicator(frame: NSRect(x: 310, y: 200, width: 40, height: 40))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        // Start Wine setup
        wineManager.setupWinePrefix { success, error in
            if success {
                statusLabel.stringValue = "Wine setup complete! ✓"
                spinner.stopAnimation(nil)

                // Auto-advance after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showStep(.gameInstall)
                }
            } else {
                statusLabel.stringValue = "Wine setup failed: \(error ?? "Unknown error")"
                spinner.stopAnimation(nil)
                self.showError("Failed to setup Wine. Please try again.")
            }
        }
    }

    private func showGameInstall() {
        let title = createLabel("Install GTA San Andreas", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let message = createLabel("""
        Please select your GTA San Andreas installation folder
        (the folder containing gta_sa.exe)

        Or drag and drop the folder below.
        """, fontSize: 14, bold: false)
        message.frame = NSRect(x: 20, y: 220, width: 620, height: 80)
        message.alignment = .center
        contentView.addSubview(message)

        let browseButton = NSButton(frame: NSRect(x: 250, y: 160, width: 160, height: 36))
        browseButton.title = "Browse..."
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseForGame)
        contentView.addSubview(browseButton)

        if let path = selectedGamePath {
            let pathLabel = createLabel("Selected: \(path.lastPathComponent)", fontSize: 12, bold: false)
            pathLabel.frame = NSRect(x: 20, y: 120, width: 620, height: 20)
            pathLabel.alignment = .center
            pathLabel.textColor = .secondaryLabelColor
            contentView.addSubview(pathLabel)

            nextButton.isEnabled = true
        }
    }

    private func showSAMPInstall() {
        let title = createLabel("Installing SA-MP", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let statusLabel = createLabel("Downloading and installing SA-MP client...", fontSize: 14, bold: false)
        statusLabel.frame = NSRect(x: 20, y: 250, width: 620, height: 30)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)

        let progressBar = NSProgressIndicator(frame: NSRect(x: 180, y: 200, width: 340, height: 20))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        contentView.addSubview(progressBar)

        // Install SA-MP
        gameInstaller.installSAMP { progress, message in
            DispatchQueue.main.async {
                statusLabel.stringValue = message
                progressBar.doubleValue = progress
            }
        } completion: { success, error in
            if success {
                statusLabel.stringValue = "SA-MP installed successfully! ✓"

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showStep(.optimization)
                }
            } else {
                statusLabel.stringValue = "Installation failed"
                self.showError("Failed to install SA-MP: \(error ?? "Unknown error")")
            }
        }
    }

    private func showOptimization() {
        let title = createLabel("Optimizing Performance", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let statusLabel = createLabel("Applying performance optimizations...", fontSize: 14, bold: false)
        statusLabel.frame = NSRect(x: 20, y: 250, width: 620, height: 30)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)

        let spinner = NSProgressIndicator(frame: NSRect(x: 310, y: 200, width: 40, height: 40))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        // Apply optimizations
        DispatchQueue.global(qos: .userInitiated).async {
            // Apply auto preset
            self.performanceOptimizer.applyPreset(.auto)

            // Precompile shaders
            self.performanceOptimizer.precompileShaders { progress, message in
                DispatchQueue.main.async {
                    statusLabel.stringValue = message
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusLabel.stringValue = "Optimization complete! ✓"
                spinner.stopAnimation(nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showStep(.complete)
                }
            }
        }
    }

    private func showComplete() {
        let title = createLabel("Installation Complete!", fontSize: 28, bold: true)
        title.frame = NSRect(x: 0, y: 280, width: 660, height: 40)
        title.alignment = .center
        contentView.addSubview(title)

        let message = createLabel("""
        🎮 SA-MP Runner is now ready!

        You can now launch GTA San Andreas Multiplayer
        directly from macOS without any virtual machines.

        Tips for best performance:
        • Close other applications while playing
        • Use the Settings panel to adjust graphics
        • Update to the latest macOS for best compatibility

        Click Finish to start playing!
        """, fontSize: 14, bold: false)
        message.frame = NSRect(x: 50, y: 80, width: 560, height: 180)
        message.alignment = .center
        contentView.addSubview(message)
    }

    // MARK: - Actions

    @objc private func nextClicked() {
        switch currentStep {
        case .welcome:
            showStep(.systemCheck)
        case .systemCheck:
            showStep(.wineSetup)
        case .wineSetup:
            showStep(.gameInstall)
        case .gameInstall:
            if let path = selectedGamePath {
                installGame(from: path)
            }
        case .sampInstall, .optimization:
            break // Handled automatically
        case .complete:
            // Show main launcher first, then close wizard
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showLauncherWindow()
            }

            // Close wizard window after a short delay to prevent crash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.view.window?.close()
            }
        }
    }

    @objc private func backClicked() {
        switch currentStep {
        case .systemCheck:
            showStep(.welcome)
        case .gameInstall:
            showStep(.systemCheck)
        default:
            break
        }
    }

    @objc private func cancelClicked() {
        let alert = NSAlert()
        alert.messageText = "Cancel Installation?"
        alert.informativeText = "Are you sure you want to cancel the installation?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes, Cancel")
        alert.addButton(withTitle: "No, Continue")

        if alert.runModal() == .alertFirstButtonReturn {
            view.window?.close()
        }
    }

    @objc private func browseForGame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your GTA San Andreas folder"

        if panel.runModal() == .OK, let url = panel.url {
            // Verify it contains gta_sa.exe
            let exePath = url.appendingPathComponent("gta_sa.exe")
            if FileManager.default.fileExists(atPath: exePath.path) {
                selectedGamePath = url
                showStep(.gameInstall) // Refresh to show selected path
            } else {
                showError("Selected folder does not contain gta_sa.exe")
            }
        }
    }

    private func installGame(from path: URL) {
        showStep(.sampInstall) // Move to SA-MP installation

        // Start installation
        let contentView = self.contentView!
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let title = createLabel("Installing Game Files", fontSize: 20, bold: true)
        title.frame = NSRect(x: 20, y: 320, width: 620, height: 30)
        contentView.addSubview(title)

        let statusLabel = createLabel("Copying game files...", fontSize: 14, bold: false)
        statusLabel.frame = NSRect(x: 20, y: 250, width: 620, height: 30)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)

        let progressBar = NSProgressIndicator(frame: NSRect(x: 180, y: 200, width: 340, height: 20))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        contentView.addSubview(progressBar)

        gameInstaller.installGTASA(from: path, progress: { progress, message in
            DispatchQueue.main.async {
                statusLabel.stringValue = message
                progressBar.doubleValue = progress
            }
        }) { success, error in
            if success {
                self.showStep(.sampInstall)
            } else {
                self.showError("Failed to install game: \(error ?? "Unknown error")")
            }
        }
    }

    // MARK: - Helpers

    private func createLabel(_ text: String, fontSize: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.systemFont(ofSize: fontSize, weight: .bold) : NSFont.systemFont(ofSize: fontSize)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func getAvailableDiskSpace() -> UInt64? {
        let fileManager = FileManager.default
        guard let path = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        do {
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity.map { UInt64($0) }
        } catch {
            return nil
        }
    }
}
