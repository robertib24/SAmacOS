import Foundation

/// How Direct3D 9 (what GTA SA uses) gets turned into something the Mac GPU runs.
public enum Renderer: String, Codable, CaseIterable, Identifiable, Sendable {
    /// wined3d -> Vulkan -> MoltenVK -> Metal. With WoW64 Wine, Vulkan memory maps
    /// straight into the 32-bit game, avoiding the buffer copies the OpenGL path makes.
    case vulkan
    /// wined3d -> OpenGL -> Apple's GL-on-Metal. The long-standing default; use it if
    /// the Vulkan path shows rendering glitches.
    case opengl

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vulkan: return "Vulkan (MoltenVK) — faster"
        case .opengl: return "OpenGL — most compatible"
        }
    }

    /// Value for wined3d's `renderer` option.
    var wined3dName: String {
        switch self {
        case .vulkan: return "vulkan"
        case .opengl: return "gl"
        }
    }
}

public struct Settings: Codable, Equatable, Sendable {
    /// Pinned runtime id from `WineRuntime.catalog`, ignored when `customWinePath` is set.
    public var runtimeID: String = WineRuntime.recommended.id
    /// Path to any `wine` binary (e.g. a CrossOver or Sikarugir engine) to use instead.
    public var customWinePath: String?

    public var renderer: Renderer = .vulkan
    public var nickname: String = "Player"
    /// SA-MP frame cap (sa-mp.cfg `fpslimit`). Only applies while the in-game
    /// "Frame Limiter" option is OFF. SA-MP accepts 20...90.
    public var fpsLimit: Int = 60
    /// Apple's Metal Performance HUD (FPS, frame time, GPU time, memory).
    public var showMetalHUD: Bool = false
    /// Render at full Retina resolution. Sharper, but 4x the pixels; off is faster.
    public var retinaMode: Bool = false
    /// Map Option to Alt (GTA SA walks with Left Alt).
    public var optionKeyAsAlt: Bool = true
    /// Video memory reported to the game, in MB.
    public var videoMemoryMB: Int = 2048
    /// Let a d3d9.dll in the game folder (ReShade/ENB/mod proxies) load. Off forces
    /// Wine's own d3d9 so stale DXVK leftovers can't break rendering.
    public var allowGameFolderD3D9: Bool = false
    /// Record per-frame timings for the next session and summarise them afterwards.
    public var benchmarkMode: Bool = false
    /// Last server joined, "host:port".
    public var lastServer: String?

    public init() {}

    public static let fpsLimitRange = 20...90

    /// Clamp values into ranges the game and Wine accept.
    public func normalized() -> Settings {
        var copy = self
        copy.fpsLimit = min(max(fpsLimit, Settings.fpsLimitRange.lowerBound), Settings.fpsLimitRange.upperBound)
        copy.videoMemoryMB = min(max(videoMemoryMB, 256), 4096)
        if let path = customWinePath, path.trimmingCharacters(in: .whitespaces).isEmpty {
            copy.customWinePath = nil
        }
        return copy
    }

    // Decode field by field so settings files written by older versions (or with
    // unknown values) still load, falling back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        runtimeID = (try? c.decodeIfPresent(String.self, forKey: .runtimeID)) ?? d.runtimeID
        customWinePath = try? c.decodeIfPresent(String.self, forKey: .customWinePath)
        renderer = (try? c.decodeIfPresent(Renderer.self, forKey: .renderer)) ?? d.renderer
        nickname = (try? c.decodeIfPresent(String.self, forKey: .nickname)) ?? d.nickname
        fpsLimit = (try? c.decodeIfPresent(Int.self, forKey: .fpsLimit)) ?? d.fpsLimit
        showMetalHUD = (try? c.decodeIfPresent(Bool.self, forKey: .showMetalHUD)) ?? d.showMetalHUD
        retinaMode = (try? c.decodeIfPresent(Bool.self, forKey: .retinaMode)) ?? d.retinaMode
        optionKeyAsAlt = (try? c.decodeIfPresent(Bool.self, forKey: .optionKeyAsAlt)) ?? d.optionKeyAsAlt
        videoMemoryMB = (try? c.decodeIfPresent(Int.self, forKey: .videoMemoryMB)) ?? d.videoMemoryMB
        allowGameFolderD3D9 = (try? c.decodeIfPresent(Bool.self, forKey: .allowGameFolderD3D9)) ?? d.allowGameFolderD3D9
        benchmarkMode = (try? c.decodeIfPresent(Bool.self, forKey: .benchmarkMode)) ?? d.benchmarkMode
        lastServer = try? c.decodeIfPresent(String.self, forKey: .lastServer)
    }
}

/// Validates SA-MP nicknames the same way the client does: 3-20 characters from
/// `A-Z a-z 0-9 [ ] ( ) $ @ . _ =`.
public enum Nickname {
    public static let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[]()$@._=")

    public static func validationError(_ name: String) -> String? {
        if name.count < 3 || name.count > 20 { return "Nickname must be 3–20 characters." }
        if let bad = name.first(where: { !allowed.contains($0) }) {
            return "Nickname can't contain “\(bad)”. Use letters, digits and [ ] ( ) $ @ . _ ="
        }
        return nil
    }
}

public final class SettingsStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public convenience init(paths: AppPaths) {
        self.init(url: paths.settingsFile)
    }

    public func load() -> Settings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings()
        }
        return settings.normalized()
    }

    public func save(_ settings: Settings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings.normalized())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
