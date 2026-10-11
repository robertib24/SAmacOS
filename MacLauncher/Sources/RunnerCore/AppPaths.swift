import Foundation

/// Every on-disk location the launcher uses, derived from a single root.
///
/// Layout (default root is `~/Library/Application Support/SA-MP Runner`):
///
///     runtimes/<runtime-id>/Wine Devel.app   pinned Wine builds
///     prefix/                                Wine prefix (WoW64, win10)
///     prefix/drive_c/Games/GTA San Andreas   the game
///     logs/                                  launcher + game logs
///     downloads/                             partial downloads
///     settings.json, favorites.json
///     wine/                                  prefix from the old launcher (legacy, import only)
public struct AppPaths: Equatable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// `SAMP_RUNNER_HOME` overrides the root (used by tests and handy for keeping
    /// several independent installs side by side).
    public static func `default`(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppPaths {
        if let override = environment["SAMP_RUNNER_HOME"], !override.isEmpty {
            return AppPaths(root: URL(fileURLWithPath: override, isDirectory: true))
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return AppPaths(root: base.appendingPathComponent("SA-MP Runner", isDirectory: true))
    }

    public var runtimes: URL { root.appendingPathComponent("runtimes", isDirectory: true) }
    public var prefix: URL { root.appendingPathComponent("prefix", isDirectory: true) }
    public var logs: URL { root.appendingPathComponent("logs", isDirectory: true) }
    public var downloads: URL { root.appendingPathComponent("downloads", isDirectory: true) }
    public var settingsFile: URL { root.appendingPathComponent("settings.json") }
    public var favoritesFile: URL { root.appendingPathComponent("favorites.json") }

    public var driveC: URL { prefix.appendingPathComponent("drive_c", isDirectory: true) }

    /// The game lives at a short, space-free path inside the prefix.
    public var gameDirectory: URL { driveC.appendingPathComponent("Games/GTA San Andreas", isDirectory: true) }
    public static let gameDirectoryWindows = #"C:\Games\GTA San Andreas"#

    /// Prefix created by the previous (Homebrew-Wine based) launcher.
    public var legacyPrefix: URL { root.appendingPathComponent("wine", isDirectory: true) }
    public var legacyGameDirectory: URL {
        legacyPrefix.appendingPathComponent("drive_c/Program Files/Rockstar Games/GTA San Andreas", isDirectory: true)
    }

    /// `drive_c/users/<name>` for the user that owns the prefix. Wine names it
    /// after the Unix user, so look at what is actually there rather than guessing.
    public func prefixUserDirectory(fileManager: FileManager = .default) -> URL? {
        let users = driveC.appendingPathComponent("users", isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(atPath: users.path) else { return nil }
        let ignored: Set<String> = ["Public", "crossover", "Default"]
        let candidates = entries.filter { !ignored.contains($0) && !$0.hasPrefix(".") }.sorted()
        if let current = ProcessInfo.processInfo.environment["USER"], candidates.contains(current) {
            return users.appendingPathComponent(current, isDirectory: true)
        }
        return candidates.first.map { users.appendingPathComponent($0, isDirectory: true) }
    }

    /// `Documents/GTA San Andreas User Files` inside the prefix: where the game keeps
    /// gta_sa.set and SA-MP keeps sa-mp.cfg, USERDATA.DAT (favorites) and chat logs.
    public func userFilesDirectory(fileManager: FileManager = .default) -> URL? {
        prefixUserDirectory(fileManager: fileManager)?
            .appendingPathComponent("Documents/GTA San Andreas User Files", isDirectory: true)
    }

    public func createBaseDirectories(fileManager: FileManager = .default) throws {
        for dir in [root, runtimes, logs, downloads] {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
