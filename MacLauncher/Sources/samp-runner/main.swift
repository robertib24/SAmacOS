import Foundation
import RunnerCore

let usage = """
samp-runner — GTA San Andreas Multiplayer on macOS

Usage: samp-runner <command> [arguments]

Setup
  setup                          Download Wine (pinned + checksum-verified) and create the prefix
  import-game <folder> [--replace]
                                 Copy your GTA San Andreas folder into the prefix
  import-legacy [--delete-old]   Move the game out of the old launcher's prefix
  install-samp <installer.exe>   Run an SA-MP client installer inside the prefix
  fix-dxvk                       Disable leftover DXVK DLLs in the game folder

Play
  play                           Open SA-MP's server browser
  connect <host[:port]>          Join a server directly
  singleplayer                   Start GTA SA without SA-MP
  stop                           Close the game and everything in the prefix
    --detach                     (play/connect/singleplayer) return immediately
    --verbose                    keep Wine's error messages in the log

Servers
  servers [search] [--limit N]   Search the open.mp server list
  query <host[:port]>            Ping a server and show players
  favorites [add|remove <host[:port]>]

Tuning & diagnostics
  config [key [value]]           Show or change settings (run `config` to list keys)
  bench [logfile]                Summarise a benchmark log (default: the latest)
  doctor                         Check for common problems
  winecfg | regedit | taskmgr    Open a Wine tool in the prefix
  paths                          Show where everything is stored
"""

struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

var arguments = Array(CommandLine.arguments.dropFirst())

func takeFlag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: name) else { return false }
    arguments.remove(at: index)
    return true
}

func takeOption(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...index + 1)
    return value
}

func printErr(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

func parseBool(_ value: String) throws -> Bool {
    switch value.lowercased() {
    case "1", "on", "yes", "true", "y": return true
    case "0", "off", "no", "false", "n": return false
    default: throw CLIError("Expected on/off, got \"\(value)\"")
    }
}

/// Runs async work from this synchronous CLI.
func blocking<T>(_ body: @escaping () async throws -> T) throws -> T {
    let done = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    Task.detached {
        do { result = .success(try await body()) } catch { result = .failure(error) }
        done.signal()
    }
    done.wait()
    return try result.get()
}

func address(_ text: String?) throws -> ServerAddress {
    guard let text, let address = ServerAddress(text) else { throw CLIError("Expected a server address like 1.2.3.4:7777") }
    return address
}

let runner = Runner()

// MARK: - Settings

let configKeys: [(key: String, help: String, get: (Settings) -> String, set: (inout Settings, String) throws -> Void)] = [
    ("renderer", "vulkan | opengl", { $0.renderer.rawValue }, { s, v in
        guard let r = Renderer(rawValue: v.lowercased()) else { throw CLIError("renderer must be vulkan or opengl") }
        s.renderer = r }),
    ("nickname", "SA-MP nickname", { $0.nickname }, { s, v in
        if let reason = Nickname.validationError(v) { throw CLIError(reason) }
        s.nickname = v }),
    ("fps", "SA-MP frame cap, 20-90 (in-game Frame Limiter must be OFF)", { String($0.fpsLimit) }, { s, v in
        guard let n = Int(v) else { throw CLIError("fps must be a number") }
        s.fpsLimit = n }),
    ("hud", "Metal performance HUD (on/off)", { $0.showMetalHUD ? "on" : "off" }, { s, v in s.showMetalHUD = try parseBool(v) }),
    ("retina", "render at full Retina resolution (on/off, off is faster)", { $0.retinaMode ? "on" : "off" }, { s, v in s.retinaMode = try parseBool(v) }),
    ("option-alt", "Option key acts as Alt (on/off)", { $0.optionKeyAsAlt ? "on" : "off" }, { s, v in s.optionKeyAsAlt = try parseBool(v) }),
    ("vram", "video memory reported to the game, MB", { String($0.videoMemoryMB) }, { s, v in
        guard let n = Int(v) else { throw CLIError("vram must be a number") }
        s.videoMemoryMB = n }),
    ("d3d9-mods", "load a d3d9.dll from the game folder (ReShade/ENB) (on/off)", { $0.allowGameFolderD3D9 ? "on" : "off" }, { s, v in s.allowGameFolderD3D9 = try parseBool(v) }),
    ("benchmark", "record frame times for the next sessions (on/off)", { $0.benchmarkMode ? "on" : "off" }, { s, v in s.benchmarkMode = try parseBool(v) }),
    ("runtime", WineRuntime.catalog.map(\.id).joined(separator: " | "), { $0.runtimeID }, { s, v in
        guard WineRuntime.find(id: v) != nil else { throw CLIError("Unknown runtime. Choices: " + WineRuntime.catalog.map(\.id).joined(separator: ", ")) }
        s.runtimeID = v }),
    ("wine", "path to a custom wine binary, or \"none\"", { $0.customWinePath ?? "none" }, { s, v in
        s.customWinePath = (v == "none" || v.isEmpty) ? nil : v })
]

func printConfig() {
    for entry in configKeys {
        let value = entry.get(runner.settings)
        print("\(entry.key.padding(toLength: 11, withPad: " ", startingAt: 0)) \(value.padding(toLength: 18, withPad: " ", startingAt: 0)) \(entry.help)")
    }
}

// MARK: - Commands

func setup() throws {
    if let wine = takeOption("--wine") {
        try runner.updateSettings { $0.customWinePath = wine }
    }
    if let id = takeOption("--runtime") {
        guard WineRuntime.find(id: id) != nil else { throw CLIError("Unknown runtime \(id)") }
        try runner.updateSettings { $0.runtimeID = id; $0.customWinePath = nil }
    }
    #if os(macOS)
    let system = SystemInfo.current()
    if system.isAppleSilicon && !system.rosettaInstalled {
        throw CLIError("Rosetta 2 is required (Wine is an Intel app). Install it with:\n  softwareupdate --install-rosetta --agree-to-license")
    }
    #endif
    if let runtime = runner.selectedRuntime {
        print("Wine runtime: \(runtime.displayName)")
        var lastPrinted = -1
        try blocking {
            try await runner.installRuntime { fraction, message in
                let percent = Int(fraction * 100)
                if percent / 5 != lastPrinted / 5 || fraction >= 1 {
                    lastPrinted = percent
                    print("  [\(String(format: "%3d", percent))%] \(message)")
                }
            }
        }
    }
    try runner.preparePrefix { print("  \($0)") }
    print("Prefix ready: \(runner.paths.prefix.path)")
    if runner.legacyInstallAvailable {
        print("\nFound GTA SA from the previous launcher. Move it over with:  samp-runner import-legacy")
    } else if !runner.game.hasGame {
        print("\nNext: samp-runner import-game \"/path/to/GTA San Andreas\"")
    }
}

func waitForSession(_ start: (@escaping (SessionResult) -> Void) throws -> GameSession) throws {
    let detach = takeFlag("--detach")
    let done = DispatchSemaphore(value: 0)
    var result: SessionResult?
    let session = try start { result = $0; done.signal() }
    print("Started (log: \(session.logFile.path))")
    if session.benchmark { print("Benchmark mode is on: frame times are being recorded.") }
    if detach { return }
    print("Waiting for the game to exit… (Ctrl-C leaves it running)")
    done.wait()
    guard let result else { return }
    print(String(format: "Game closed after %.0f min.", result.duration / 60))
    if let bench = result.benchmark {
        print("Benchmark (\(bench.renderer ?? "?")): \(bench.summary)")
    } else if session.benchmark {
        print("Benchmark: not enough gameplay frames recorded (play for at least ~30 s past the loading screen).")
    }
}

func run() throws {
    guard let command = arguments.first else {
        print(usage)
        return
    }
    arguments.removeFirst()
    let verbose = takeFlag("--verbose")

    switch command {
    case "help", "-h", "--help":
        print(usage)

    case "setup":
        try setup()

    case "import-game":
        let replace = takeFlag("--replace")
        guard let folder = arguments.first else { throw CLIError("Usage: samp-runner import-game <folder> [--replace]") }
        try runner.importGame(from: URL(fileURLWithPath: (folder as NSString).expandingTildeInPath), replace: replace)
        if let prefix = try? runner.prefix(), prefix.isInitialized { try runner.preparePrefix() }
        let game = runner.game
        print("Imported to \(game.url.path)\n  \(game.executableKind.description)\n  SA-MP: \(game.hasSAMP ? "installed" : "not installed — run install-samp")")
        if !game.dxvkLeftovers.isEmpty { print("  Leftover DXVK DLLs found — run: samp-runner fix-dxvk") }

    case "import-legacy":
        let deleteOld = takeFlag("--delete-old")
        guard try runner.importLegacyInstall() else { throw CLIError("No game found in \(runner.paths.legacyGameDirectory.path)") }
        print("Moved the game to \(runner.game.url.path)")
        if deleteOld {
            try runner.removeLegacyPrefix()
            print("Deleted the old prefix.")
        } else {
            print("The old prefix is still at \(runner.paths.legacyPrefix.path) (remove it with --delete-old to free space).")
        }
        if !runner.game.dxvkLeftovers.isEmpty { print("Leftover DXVK DLLs found — run: samp-runner fix-dxvk") }

    case "install-samp":
        guard let path = arguments.first else { throw CLIError("Usage: samp-runner install-samp <installer.exe>") }
        print("Starting the installer. When it asks for the GTA folder, choose \(AppPaths.gameDirectoryWindows)")
        try runner.runInstaller(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
        print(runner.game.hasSAMP ? "SA-MP installed." : "Installer finished, but samp.exe/samp.dll weren't found in the game folder.")

    case "fix-dxvk":
        let moved = try runner.game.disableDXVKLeftovers()
        print(moved.isEmpty ? "No DXVK DLLs in the game folder." : "Disabled: " + moved.map(\.lastPathComponent).joined(separator: ", "))

    case "play":
        try waitForSession { try runner.launch(.sampBrowser, verbose: verbose, onExit: $0) }

    case "connect":
        let target = try address(arguments.first)
        try waitForSession { try runner.launch(.connect(target), verbose: verbose, onExit: $0) }

    case "singleplayer", "sp":
        try waitForSession { try runner.launch(.singlePlayer, verbose: verbose, onExit: $0) }

    case "stop":
        runner.stopGame()
        print("Stopped.")

    case "servers":
        let limit = Int(takeOption("--limit") ?? "") ?? 25
        let search = arguments.joined(separator: " ").lowercased()
        var servers = try blocking { try await OpenMPServerList.fetch() }
        if !search.isEmpty {
            servers = servers.filter {
                $0.name.lowercased().contains(search) || ($0.gamemode ?? "").lowercased().contains(search)
                    || ($0.language ?? "").lowercased().contains(search) || $0.id.contains(search)
            }
        }
        servers.sort { ($0.players ?? 0) > ($1.players ?? 0) }
        for server in servers.prefix(limit) {
            let players = "\(server.players ?? 0)/\(server.maxPlayers ?? 0)"
            let lock = server.passworded == true ? "🔒 " : ""
            print("\(players.padding(toLength: 10, withPad: " ", startingAt: 0)) \(server.id.padding(toLength: 22, withPad: " ", startingAt: 0)) \(lock)\(server.name)")
        }
        print("\(servers.count) servers. Join one with: samp-runner connect <address>")

    case "query":
        let target = try address(arguments.first)
        let (info, ping) = try SAMPQuery.query(target)
        print("\(info.hostname)\n  \(info.players)/\(info.maxPlayers) players, \(ping) ms, \(info.gamemode), \(info.language)\(info.passworded ? ", password protected" : "")")

    case "favorites":
        switch arguments.first {
        case "add":
            let target = try address(arguments.dropFirst().first)
            var entry = ServerEntry(address: target)
            if let (info, ping) = try? SAMPQuery.query(target) { entry.apply(info, pingMS: ping) }
            try runner.favorites.add(entry)
            print("Added \(entry.name)")
        case "remove":
            try runner.favorites.remove(try address(arguments.dropFirst().first))
            print("Removed.")
        default:
            let favorites = runner.favorites.load()
            if favorites.isEmpty { print("No favorites yet. Add one with: samp-runner favorites add <host:port>") }
            for entry in favorites { print("\(entry.id.padding(toLength: 22, withPad: " ", startingAt: 0)) \(entry.name)") }
        }

    case "config":
        if arguments.isEmpty {
            printConfig()
            return
        }
        let key = arguments[0]
        guard let entry = configKeys.first(where: { $0.key == key }) else {
            throw CLIError("Unknown key \"\(key)\". Keys: " + configKeys.map(\.key).joined(separator: ", "))
        }
        if arguments.count == 1 {
            print(entry.get(runner.settings))
        } else {
            var updated = runner.settings
            try entry.set(&updated, arguments.dropFirst().joined(separator: " "))
            try runner.updateSettings { $0 = updated }
            print("\(key) = \(entry.get(runner.settings))")
        }

    case "bench":
        let file = arguments.first.map { URL(fileURLWithPath: $0) } ?? runner.latestLog(prefix: "benchmark")
        guard let file else { throw CLIError("No benchmark logs yet. Turn it on with `samp-runner config benchmark on`, then play.") }
        guard let result = Benchmark.summarize(logFile: file) else {
            throw CLIError("Not enough frames in \(file.lastPathComponent).")
        }
        print("\(file.lastPathComponent): \(result.summary)")

    case "doctor":
        print(Doctor.render(Doctor.run(runner)))

    case "winecfg", "regedit", "taskmgr", "explorer":
        try runner.openWineTool(command)

    case "paths":
        let paths = runner.paths
        print("""
        root      \(paths.root.path)
        runtimes  \(paths.runtimes.path)
        prefix    \(paths.prefix.path)
        game      \(paths.gameDirectory.path)
        user files \(paths.userFilesDirectory()?.path ?? "(prefix not created)")
        logs      \(paths.logs.path)
        """)

    default:
        throw CLIError("Unknown command \"\(command)\".\n\n\(usage)")
    }
}

do {
    try run()
} catch {
    printErr("error: \(error.localizedDescription)")
    exit(1)
}
