import Foundation

public struct DiagnosticCheck: Identifiable, Sendable {
    public enum Level: String, Sendable { case ok, info, warning, error }

    public let id = UUID()
    public let level: Level
    public let title: String
    public let detail: String?

    public init(_ level: Level, _ title: String, _ detail: String? = nil) {
        self.level = level
        self.title = title
        self.detail = detail
    }

    public var symbol: String {
        switch level {
        case .ok: return "✓"
        case .info: return "•"
        case .warning: return "!"
        case .error: return "✗"
        }
    }
}

/// Checks the things that most often make the game slow or fail to start.
public enum Doctor {
    public static func run(_ runner: Runner, system: SystemInfo = .current(), probeWine: Bool = true) -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []
        let fm = runner.fileManager

        // Machine
        checks.append(.init(.info, "Mac: \(system.machine), \(system.cpuCount) cores, \(String(format: "%.0f", system.physicalMemoryGB)) GB RAM",
                            system.osVersion))
        #if os(macOS)
        if system.isAppleSilicon {
            checks.append(system.rosettaInstalled
                ? .init(.ok, "Rosetta 2 installed")
                : .init(.error, "Rosetta 2 is not installed",
                        "Wine is an Intel program. Install Rosetta with: softwareupdate --install-rosetta --agree-to-license"))
        }
        if system.lowPowerMode {
            checks.append(.init(.warning, "Low Power Mode is on",
                                "It caps CPU and GPU clocks. Turn it off in System Settings › Battery while playing."))
        }
        if system.thermalState.hasPrefix("serious") || system.thermalState.hasPrefix("critical") {
            checks.append(.init(.warning, "The Mac is thermally throttling (\(system.thermalState))",
                                "Let it cool down, keep the vents clear, and avoid playing on soft surfaces."))
        }
        if system.physicalMemoryGB <= 8.5 {
            checks.append(.init(.info, "8 GB RAM: close browsers and Electron apps before playing",
                                "Wine + GTA SA + SA-MP use roughly 1–1.5 GB; swapping is what causes long stutters on 8 GB Macs."))
        }
        #endif

        // Wine runtime
        do {
            let runtime = try runner.resolvedRuntime()
            var detail = runtime.wine.path
            if probeWine, let version = WinePrefix(paths: runner.paths, runtime: runtime, fileManager: fm).wineVersion() {
                detail = "\(version) — \(detail)"
            }
            checks.append(.init(.ok, "Wine runtime: \(runtime.label)", detail))
        } catch {
            checks.append(.init(.error, "Wine runtime not ready", error.localizedDescription))
        }
        let leftovers = RuntimeResolver.systemWineInstalls(fileManager: fm)
        if !leftovers.isEmpty {
            checks.append(.init(.info, "Other Wine installs found (not used)", leftovers.joined(separator: "\n")))
        }

        // Prefix
        if fm.fileExists(atPath: runner.paths.prefix.appendingPathComponent("system.reg").path) {
            checks.append(.init(.ok, "Wine prefix ready", runner.paths.prefix.path))
        } else {
            checks.append(.init(.error, "Wine prefix not created", "Run setup."))
        }

        // Game
        let game = runner.game
        switch game.executableKind {
        case .v1_0_US:
            checks.append(.init(.ok, game.executableKind.description, game.url.path))
        case .unknown:
            checks.append(.init(.warning, game.executableKind.description, game.url.path))
        case .missing:
            if runner.legacyInstallAvailable {
                checks.append(.init(.warning, "Game found in the old launcher's prefix",
                                    "Import it in Setup (or `samp-runner import-legacy`)."))
            } else {
                checks.append(.init(.error, "GTA San Andreas not installed", "Import your game folder in Setup."))
            }
        }
        if game.hasGame {
            checks.append(game.hasSAMP
                ? .init(.ok, "SA-MP client installed")
                : .init(.error, "SA-MP not installed", "samp.exe / samp.dll missing from the game folder."))
            let dxvk = game.dxvkLeftovers
            if !dxvk.isEmpty {
                checks.append(.init(.warning, "Leftover DXVK DLLs in the game folder",
                                    dxvk.map(\.lastPathComponent).joined(separator: ", ")
                                    + " — DXVK's D3D9 doesn't work on MoltenVK. Disable them in Setup (`samp-runner fix-dxvk`)."))
            } else if game.hasD3D9Proxy {
                checks.append(.init(.info, "A d3d9.dll mod (ReShade/ENB/proxy) is in the game folder",
                                    runner.settings.allowGameFolderD3D9
                                        ? "Loaded, because \"Allow d3d9.dll mods\" is on."
                                        : "Ignored. Turn on \"Allow d3d9.dll mods\" to use it."))
            }
        }

        // Settings that matter for speed
        let s = runner.settings
        checks.append(.init(.info, "Renderer: \(s.renderer.displayName)",
                            "FPS limit \(s.fpsLimit) (needs the in-game Frame Limiter OFF), Retina \(s.retinaMode ? "on" : "off")."))
        if s.retinaMode {
            checks.append(.init(.warning, "Retina mode is on", "Renders up to 4× the pixels. Turn it off for more FPS."))
        }

        #if os(macOS)
        if let free = try? runner.paths.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage, free < 5_000_000_000 {
            checks.append(.init(.warning, "Low disk space (\(free / 1_000_000_000) GB free)",
                                "macOS needs free space for swap; with 8 GB RAM a full disk makes stutter much worse."))
        }
        #endif
        return checks
    }

    public static func render(_ checks: [DiagnosticCheck]) -> String {
        checks.map { check in
            var line = "[\(check.symbol)] \(check.title)"
            if let detail = check.detail {
                line += "\n" + detail.split(separator: "\n").map { "    " + $0 }.joined(separator: "\n")
            }
            return line
        }.joined(separator: "\n")
    }
}
