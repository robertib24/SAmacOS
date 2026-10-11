import XCTest
@testable import RunnerCore

/// Drives the Runner end to end against a fake `wine`/`wineserver` pair that
/// records how it was called, so the real orchestration (prefix creation,
/// registry import, sa-mp.cfg, launch arguments and environment, session end,
/// benchmark parsing) runs without Wine.
final class RunnerIntegrationTests: XCTestCase {
    var paths: AppPaths!
    var calls: URL { paths.root.appendingPathComponent("wine-calls.txt") }

    override func setUpWithError() throws {
        paths = AppPaths(root: try temporaryDirectory())
        let bin = WineRuntime.recommended.wineBinary(in: paths).deletingLastPathComponent()
        let record = paths.root.path
        try makeExecutable(bin.appendingPathComponent("wine"), script: """
        #!/bin/sh
        echo "$*" >> "\(record)/wine-calls.txt"
        case "$1" in
          wineboot)
            mkdir -p "$WINEPREFIX/drive_c/users/tester"
            ln -s /tmp "$WINEPREFIX/drive_c/users/tester/Documents"
            ln -s /tmp "$WINEPREFIX/drive_c/users/tester/Desktop"
            touch "$WINEPREFIX/system.reg" ;;
          reg)
            cp "$WINEPREFIX/drive_c/windows/temp/samp-runner.reg" "\(record)/imported.reg" ;;
          --version)
            echo "wine-11.18" ;;
          *)
            env | grep -E '^(WINE|MVK_|MTL_)' | sort > "\(record)/game-env.txt"
            pwd > "\(record)/game-cwd.txt"
            awk 'BEGIN { for (i = 0; i < 1200; i++) printf "0124:trace:frametime:wined3d_cs_exec_present Frame duration 16667 \\316\\274s.\\n" }' >&2 ;;
        esac
        """)
        try makeExecutable(bin.appendingPathComponent("wineserver"), script: "#!/bin/sh\nexit 0\n")
    }

    func testSetupImportAndConnect() throws {
        let runner = Runner(paths: paths)
        try runner.updateSettings {
            $0.nickname = "Carl_Johnson"
            $0.fpsLimit = 75
            $0.benchmarkMode = true
        }

        // Prefix creation keeps Documents/Desktop inside the prefix.
        try runner.preparePrefix()
        let user = paths.driveC.appendingPathComponent("users/tester")
        for folder in ["Documents", "Desktop"] {
            let attributes = try FileManager.default.attributesOfItem(atPath: user.appendingPathComponent(folder).path)
            XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeDirectory, folder)
        }

        // Registry imported once; unchanged settings don't trigger another import.
        let imported = try Data(contentsOf: paths.root.appendingPathComponent("imported.reg"))
        let text = try XCTUnwrap(String(data: imported.dropFirst(2), encoding: .utf16LittleEndian))
        XCTAssertTrue(text.contains(#""PlayerName"="Carl_Johnson""#))
        try runner.preparePrefix()
        XCTAssertEqual(try callLines().filter { $0.hasPrefix("reg import") }.count, 1)

        // Launching before the game is imported fails clearly.
        XCTAssertThrowsError(try runner.launch(.sampBrowser)) { error in
            guard case RunnerError.gameNotInstalled = error else { return XCTFail("\(error)") }
        }

        let source = try temporaryDirectory()
        for file in ["gta_sa.exe", "samp.exe", "samp.dll"] {
            try Data("x".utf8).write(to: source.appendingPathComponent(file))
        }
        try runner.importGame(from: source)

        let finished = expectation(description: "session ended")
        var result: SessionResult?
        try runner.launch(.connect(ServerAddress(host: "51.10.20.30", port: 7777))) {
            result = $0
            finished.fulfill()
        }
        XCTAssertThrowsError(try runner.launch(.sampBrowser))  // already running
        wait(for: [finished], timeout: 20)
        XCTAssertNil(runner.currentSession)

        XCTAssertTrue(try callLines().contains(#"C:\Games\GTA San Andreas\samp.exe 51.10.20.30:7777"#))
        let cwd = try String(contentsOf: paths.root.appendingPathComponent("game-cwd.txt"), encoding: .utf8)
        XCTAssertTrue(cwd.hasSuffix("drive_c/Games/GTA San Andreas\n"))
        let env = try String(contentsOf: paths.root.appendingPathComponent("game-env.txt"), encoding: .utf8)
        XCTAssertTrue(env.contains("WINE_D3D_CONFIG=renderer=vulkan;csmt=0x1;VideoMemorySize=2048"))
        XCTAssertTrue(env.contains("WINEDEBUG=-all,+frametime"))
        XCTAssertTrue(env.contains("WINEPREFIX=\(paths.prefix.path)"))

        let cfg = try String(contentsOf: user.appendingPathComponent("Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg"),
                             encoding: .utf8)
        XCTAssertTrue(cfg.contains("fpslimit=75"))

        let benchmark = try XCTUnwrap(result?.benchmark)
        XCTAssertEqual(benchmark.averageFPS, 60, accuracy: 0.1)
        XCTAssertEqual(runner.settings.lastServer, "51.10.20.30:7777")

        // Doctor runs against the same state without crashing and sees the game.
        let report = Doctor.render(Doctor.run(runner))
        XCTAssertTrue(report.contains("SA-MP client installed"))
        XCTAssertTrue(report.contains("wine-11.18"))
    }

    func testNicknameIsValidatedBeforeLaunch() throws {
        let runner = Runner(paths: paths)
        try runner.updateSettings { $0.nickname = "No Spaces Allowed" }
        XCTAssertThrowsError(try runner.launch(.sampBrowser)) { error in
            guard case RunnerError.invalidNickname = error else { return XCTFail("\(error)") }
        }
    }

    private func callLines() throws -> [String] {
        try String(contentsOf: calls, encoding: .utf8).split(separator: "\n").map(String.init)
    }
}
