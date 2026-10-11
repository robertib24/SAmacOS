import Foundation

/// Builds the environment variables Wine is started with. Pure functions, so the
/// exact performance-relevant configuration is unit-tested.
///
/// Every variable here is one Wine/MoltenVK/Metal actually reads (checked against
/// the Wine 11 sources). The previous launcher set many that did nothing on macOS
/// (esync/fsync, __GL_* NVIDIA variables, a malformed WINE_CPU_TOPOLOGY, removed
/// wined3d registry keys).
public enum LaunchEnvironment {
    /// Never wanted in this prefix: Mono/Gecko installers (SA-MP needs neither) and
    /// winemenubuilder, which creates Launchpad entries and file associations.
    static let baseOverrides = ["mscoree,mshtml=", "winemenubuilder.exe=d"]

    /// Environment for prefix maintenance (wineboot, reg import, winecfg).
    public static func maintenance(prefix: URL) -> [String: String] {
        [
            "WINEPREFIX": prefix.path,
            "WINEDEBUG": "-all",
            "WINEDLLOVERRIDES": baseOverrides.joined(separator: ";")
        ]
    }

    /// Environment for running the game.
    public static func game(settings: Settings, prefix: URL, benchmark: Bool, verbose: Bool = false) -> [String: String] {
        let settings = settings.normalized()
        var env = maintenance(prefix: prefix)

        // wined3d reads WINE_D3D_CONFIG before the registry, so the renderer switch
        // needs no prefix changes. csmt (rendering on its own thread) is Wine's
        // default; set explicitly so a stale registry value can't disable it.
        env["WINE_D3D_CONFIG"] = [
            "renderer=\(settings.renderer.wined3dName)",
            "csmt=0x1",
            "VideoMemorySize=\(settings.videoMemoryMB)"
        ].joined(separator: ";")

        var overrides = baseOverrides
        if !settings.allowGameFolderD3D9 {
            // Force Wine's d3d9 even if a stray d3d9.dll (old DXVK copy, mod proxy)
            // sits next to gta_sa.exe.
            overrides.append("d3d9=b")
        }
        env["WINEDLLOVERRIDES"] = overrides.joined(separator: ";")

        // Logging costs CPU time, so it's off unless asked for. Benchmark mode logs
        // one line per presented frame ("Frame duration N μs"); verbose keeps Wine's
        // error messages for troubleshooting.
        var debug = [verbose ? "fixme-all" : "-all"]
        if benchmark { debug.append("+frametime") }
        env["WINEDEBUG"] = debug.joined(separator: ",")

        if settings.renderer == .vulkan {
            // Recover instead of crashing if Metal reports a lost device (e.g. after sleep).
            env["MVK_CONFIG_RESUME_LOST_DEVICE"] = "1"
        }
        if settings.showMetalHUD {
            env["MTL_HUD_ENABLED"] = "1"
        }
        return env
    }
}
