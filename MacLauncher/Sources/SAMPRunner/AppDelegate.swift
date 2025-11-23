import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindow: NSWindow?
    var launcherController: LauncherViewController?
    let wineManager = WineManager.shared
    let gameInstaller = GameInstaller.shared
    let performanceOptimizer = PerformanceOptimizer.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        setupApplication()
        checkFirstLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean shutdown
        wineManager.shutdown()
        saveApplicationState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Setup

    private func setupApplication() {
        // Create application support directory
        createApplicationDirectories()

        // Initialize logging
        Logger.shared.initialize()
        Logger.shared.info("SA-MP Runner starting...")

        // Show main launcher window
        showLauncherWindow()
    }

    private func createApplicationDirectories() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SA-MP Runner")

        let directories = [
            "wine",
            "dxvk_cache",
            "mods",
            "config",
            "logs",
            "screenshots"
        ]

        for dir in directories {
            let path = appDir.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: path.path) {
                try? fileManager.createDirectory(at: path, withIntermediateDirectories: true)
            }
        }
    }

    private func checkFirstLaunch() {
        let userDefaults = UserDefaults.standard
        let hasLaunchedBefore = userDefaults.bool(forKey: "HasLaunchedBefore")

        if !hasLaunchedBefore {
            // First launch - show installation wizard
            showInstallationWizard()
            userDefaults.set(true, forKey: "HasLaunchedBefore")
        } else {
            // Check if installation is complete
            if !gameInstaller.isGameInstalled() {
                showInstallationWizard()
            }
        }
    }

    private func showLauncherWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SA-MP Runner"
        window.center()
        window.isReleasedWhenClosed = false

        let controller = LauncherViewController()
        window.contentViewController = controller

        self.mainWindow = window
        self.launcherController = controller

        window.makeKeyAndOrderFront(nil)
    }

    private func showInstallationWizard() {
        let wizardWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        wizardWindow.title = "SA-MP Runner Setup"
        wizardWindow.center()

        let wizardController = InstallationWizardViewController()
        wizardWindow.contentViewController = wizardController

        wizardWindow.makeKeyAndOrderFront(nil)
    }

    private func saveApplicationState() {
        Logger.shared.info("Saving application state...")
        // Save any necessary state
    }
}

// MARK: - Logger

class Logger {
    static let shared = Logger()
    private var logFileHandle: FileHandle?

    func initialize() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("SA-MP Runner/logs")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let logFile = logDir.appendingPathComponent("launcher_\(timestamp).log")

        fileManager.createFile(atPath: logFile.path, contents: nil)
        logFileHandle = try? FileHandle(forWritingTo: logFile)
    }

    func log(_ level: String, _ message: String) {
        let timestamp = Date()
        let logMessage = "[\(timestamp)] [\(level)] \(message)\n"

        print(logMessage, terminator: "")

        if let data = logMessage.data(using: .utf8) {
            logFileHandle?.write(data)
        }
    }

    func info(_ message: String) { log("INFO", message) }
    func warning(_ message: String) { log("WARN", message) }
    func error(_ message: String) { log("ERROR", message) }
    func debug(_ message: String) { log("DEBUG", message) }

    deinit {
        try? logFileHandle?.close()
    }
}
