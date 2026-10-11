import Foundation

/// A Wine build the launcher can download and verify.
///
/// These are the WineHQ macOS builds by Gcenx (the same packages Homebrew's
/// `wine-stable`/`wine@devel` casks used to install; Homebrew disabled those casks
/// on 2026-09-01 because they aren't notarized). They are WoW64 builds: one
/// 64-bit `wine` that runs 32-bit games like GTA SA without the old 32-on-64 hacks,
/// and they bundle MoltenVK + the Vulkan loader.
public struct WineRuntime: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let version: String
    public let downloadURL: URL
    public let sha256: String
    public let sizeBytes: Int64
    /// Name of the `.app` bundle inside the tarball.
    public let bundleName: String
    public let notes: String

    public static let devel_11_18 = WineRuntime(
        id: "wine-devel-11.18",
        displayName: "Wine 11.18 (development)",
        version: "11.18",
        downloadURL: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.18/wine-devel-11.18-osx64.tar.xz")!,
        sha256: "aa0ea4c82e636ae7bca2076387cb0a5affa26509ad13f119ecd0d62bd7ba6f82",
        sizeBytes: 190_974_384,
        bundleName: "Wine Devel.app",
        notes: "Recommended. Includes the Vulkan portability fix (Wine 11.15+) that MoltenVK needs."
    )

    public static let stable_11_0_1 = WineRuntime(
        id: "wine-stable-11.0_1",
        displayName: "Wine 11.0 (stable)",
        version: "11.0",
        downloadURL: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz")!,
        sha256: "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388",
        sizeBytes: 185_303_032,
        bundleName: "Wine Stable.app",
        notes: "Fallback. Pair with the OpenGL renderer if Vulkan doesn't start on this build."
    )

    public static let catalog: [WineRuntime] = [devel_11_18, stable_11_0_1]
    public static let recommended = devel_11_18

    public static func find(id: String) -> WineRuntime? {
        catalog.first { $0.id == id }
    }

    public func installDirectory(in paths: AppPaths) -> URL {
        paths.runtimes.appendingPathComponent(id, isDirectory: true)
    }

    public func wineBinary(in paths: AppPaths) -> URL {
        installDirectory(in: paths)
            .appendingPathComponent(bundleName, isDirectory: true)
            .appendingPathComponent("Contents/Resources/wine/bin/wine")
    }

    public func isInstalled(in paths: AppPaths, fileManager: FileManager = .default) -> Bool {
        fileManager.isExecutableFile(atPath: wineBinary(in: paths).path)
    }
}

/// The concrete Wine binaries a launch will use.
public struct ResolvedRuntime: Equatable {
    public let wine: URL
    public let wineserver: URL
    public let label: String

    public init(wine: URL, label: String) {
        self.wine = wine
        self.wineserver = wine.deletingLastPathComponent().appendingPathComponent("wineserver")
        self.label = label
    }
}

public enum RuntimeResolutionError: LocalizedError, Equatable {
    case notInstalled(WineRuntime.ID)
    case unknownRuntime(String)
    case customWineMissing(String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled(let id):
            return "Wine runtime \(id) isn't installed yet. Run setup first."
        case .unknownRuntime(let id):
            return "Unknown Wine runtime \"\(id)\"."
        case .customWineMissing(let path):
            return "Custom Wine binary not found or not executable: \(path)"
        }
    }
}

public enum RuntimeResolver {
    public static func resolve(settings: Settings, paths: AppPaths, fileManager: FileManager = .default) throws -> ResolvedRuntime {
        if let custom = settings.customWinePath {
            let expanded = (custom as NSString).expandingTildeInPath
            guard fileManager.isExecutableFile(atPath: expanded) else {
                throw RuntimeResolutionError.customWineMissing(expanded)
            }
            return ResolvedRuntime(wine: URL(fileURLWithPath: expanded), label: "Custom Wine (\(expanded))")
        }
        guard let runtime = WineRuntime.find(id: settings.runtimeID) else {
            throw RuntimeResolutionError.unknownRuntime(settings.runtimeID)
        }
        guard runtime.isInstalled(in: paths, fileManager: fileManager) else {
            throw RuntimeResolutionError.notInstalled(runtime.id)
        }
        return ResolvedRuntime(wine: runtime.wineBinary(in: paths), label: runtime.displayName)
    }

    /// Wine installs left over from Homebrew or manual installs, reported by `doctor`.
    public static func systemWineInstalls(fileManager: FileManager = .default) -> [String] {
        let candidates = [
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
            "/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
            "/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine",
            "/opt/homebrew/bin/wine",
            "/usr/local/bin/wine",
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
        ]
        return candidates.filter { fileManager.fileExists(atPath: $0) }
    }
}
