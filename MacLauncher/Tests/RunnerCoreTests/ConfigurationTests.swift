import XCTest
@testable import RunnerCore

final class LaunchEnvironmentTests: XCTestCase {
    let prefix = URL(fileURLWithPath: "/tmp/prefix")

    func testDefaultsUseVulkanRendererAndQuietLogging() {
        let env = LaunchEnvironment.game(settings: Settings(), prefix: prefix, benchmark: false)
        XCTAssertEqual(env["WINEPREFIX"], "/tmp/prefix")
        XCTAssertEqual(env["WINE_D3D_CONFIG"], "renderer=vulkan;csmt=0x1;VideoMemorySize=2048")
        XCTAssertEqual(env["WINEDEBUG"], "-all")
        XCTAssertEqual(env["WINEDLLOVERRIDES"], "mscoree,mshtml=;winemenubuilder.exe=d;d3d9=b")
        XCTAssertEqual(env["MVK_CONFIG_RESUME_LOST_DEVICE"], "1")
        XCTAssertNil(env["MTL_HUD_ENABLED"])
    }

    func testOpenGLRendererAndOptions() {
        var settings = Settings()
        settings.renderer = .opengl
        settings.showMetalHUD = true
        settings.allowGameFolderD3D9 = true
        settings.videoMemoryMB = 1024
        let env = LaunchEnvironment.game(settings: settings, prefix: prefix, benchmark: true)
        XCTAssertEqual(env["WINE_D3D_CONFIG"], "renderer=gl;csmt=0x1;VideoMemorySize=1024")
        XCTAssertEqual(env["WINEDEBUG"], "-all,+frametime")
        XCTAssertEqual(env["WINEDLLOVERRIDES"], "mscoree,mshtml=;winemenubuilder.exe=d")
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
        XCTAssertNil(env["MVK_CONFIG_RESUME_LOST_DEVICE"])
    }

    func testVerboseKeepsErrors() {
        let env = LaunchEnvironment.game(settings: Settings(), prefix: prefix, benchmark: true, verbose: true)
        XCTAssertEqual(env["WINEDEBUG"], "fixme-all,+frametime")
    }

    func testShellEnvironmentScrubsUserWineVariables() {
        let env = Shell.environment(merging: ["WINEPREFIX": "/new"],
                                    base: ["WINEPREFIX": "/old", "WINEARCH": "win32", "DXVK_HUD": "fps", "PATH": "/bin"])
        XCTAssertEqual(env["WINEPREFIX"], "/new")
        XCTAssertNil(env["WINEARCH"])
        XCTAssertNil(env["DXVK_HUD"])
        XCTAssertEqual(env["PATH"], "/bin")
    }
}

final class RegistryFileTests: XCTestCase {
    func testRenderingAndEscaping() {
        var reg = RegistryFile()
        reg.set(#"HKEY_CURRENT_USER\Software\SAMP"#, "gta_sa_exe", .string(#"C:\Games\GTA San Andreas\gta_sa.exe"#))
        reg.set(#"HKEY_CURRENT_USER\Software\SAMP"#, "PlayerName", .string(#"Bad"Name"#))
        reg.set(#"HKEY_CURRENT_USER\Software\Wine\WineDbg"#, "ShowCrashDialog", .dword(0))
        reg.set(#"HKEY_CURRENT_USER\Software\SAMP"#, "PlayerName", .string("Carl_Johnson"))

        let expected = [
            "Windows Registry Editor Version 5.00",
            "",
            #"[HKEY_CURRENT_USER\Software\SAMP]"#,
            #""gta_sa_exe"="C:\\Games\\GTA San Andreas\\gta_sa.exe""#,
            #""PlayerName"="Carl_Johnson""#,
            "",
            #"[HKEY_CURRENT_USER\Software\Wine\WineDbg]"#,
            #""ShowCrashDialog"=dword:00000000"#,
            ""
        ].joined(separator: "\r\n")
        XCTAssertEqual(reg.render(), expected)
        XCTAssertEqual(RegistryFile.quote(#"a"b\c"#), #""a\"b\\c""#)
    }

    func testEncodedAsUTF16LittleEndianWithBOM() {
        var reg = RegistryFile()
        reg.set("HKEY_CURRENT_USER\\X", "v", .string("é"))
        let data = reg.encoded()
        XCTAssertEqual(Array(data.prefix(4)), [0xFF, 0xFE, 0x57, 0x00])  // BOM, "W"
        XCTAssertEqual(String(data: data.dropFirst(2), encoding: .utf16LittleEndian), reg.render())
    }

    func testLauncherSettings() {
        var settings = Settings()
        settings.nickname = "Big_Smoke"
        settings.retinaMode = true
        settings.optionKeyAsAlt = false
        let text = RegistryFile.launcherSettings(settings, gameExeWindowsPath: #"C:\Games\GTA San Andreas\gta_sa.exe"#).render()
        XCTAssertTrue(text.contains(#""RetinaMode"="y""#))
        XCTAssertTrue(text.contains(#""LeftOptionIsAlt"="n""#))
        XCTAssertTrue(text.contains(#""PlayerName"="Big_Smoke""#))
        XCTAssertTrue(text.contains(#""gta_sa_exe"="C:\\Games\\GTA San Andreas\\gta_sa.exe""#))
        XCTAssertTrue(text.contains(#"[HKEY_CURRENT_USER\Software\Wine\Mac Driver]"#))
    }
}

final class SettingsTests: XCTestCase {
    func testPartialAndUnknownValuesFallBackToDefaults() throws {
        let json = #"{"nickname":"Ryder","renderer":"directx12","fpsLimit":500,"futureOption":true}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8)).normalized()
        XCTAssertEqual(settings.nickname, "Ryder")
        XCTAssertEqual(settings.renderer, .vulkan)
        XCTAssertEqual(settings.fpsLimit, 90)
        XCTAssertEqual(settings.runtimeID, WineRuntime.recommended.id)
    }

    func testStoreRoundTrip() throws {
        let dir = try temporaryDirectory()
        let store = SettingsStore(url: dir.appendingPathComponent("settings.json"))
        XCTAssertEqual(store.load(), Settings())
        var settings = Settings()
        settings.renderer = .opengl
        settings.fpsLimit = 5
        settings.customWinePath = "  "
        try store.save(settings)
        let loaded = store.load()
        XCTAssertEqual(loaded.renderer, .opengl)
        XCTAssertEqual(loaded.fpsLimit, 20)
        XCTAssertNil(loaded.customWinePath)
    }

    func testNicknameRules() {
        XCTAssertNil(Nickname.validationError("Carl_Johnson"))
        XCTAssertNil(Nickname.validationError("[GSF]Sweet"))
        XCTAssertNotNil(Nickname.validationError("CJ"))
        XCTAssertNotNil(Nickname.validationError("Carl Johnson"))
        XCTAssertNotNil(Nickname.validationError(String(repeating: "a", count: 21)))
    }
}

final class SAMPConfigFileTests: XCTestCase {
    func testKeepsPlayerKeysAndUpdatesManagedOnes() {
        var config = SAMPConfigFile(text: "pagesize=20\r\nFPSLIMIT=40\nfontface=Arial\n\ngarbage line\n")
        var settings = Settings()
        settings.fpsLimit = 75
        config.applyLauncherSettings(settings)
        XCTAssertEqual(config.render(), "pagesize=20\r\nFPSLIMIT=75\r\nfontface=Arial\r\nmulticore=1\r\n")
        XCTAssertEqual(config["fpslimit"], "75")
    }

    func testUpdateWritesIntoUserFilesInsidePrefix() throws {
        let paths = AppPaths(root: try temporaryDirectory())
        try FileManager.default.createDirectory(at: paths.driveC.appendingPathComponent("users/tester"),
                                                withIntermediateDirectories: true)
        let file = try XCTUnwrap(try SAMPConfigFile.update(paths: paths, settings: Settings()))
        XCTAssertTrue(file.path.hasSuffix("drive_c/users/tester/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg"))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "fpslimit=60\r\nmulticore=1\r\n")
    }
}

final class ServerAddressTests: XCTestCase {
    func testParsing() {
        XCTAssertEqual(ServerAddress("1.2.3.4"), ServerAddress(host: "1.2.3.4", port: 7777))
        XCTAssertEqual(ServerAddress(" play.example.com:7778 "), ServerAddress(host: "play.example.com", port: 7778))
        XCTAssertEqual(ServerAddress("samp://1.2.3.4:7780/"), ServerAddress(host: "1.2.3.4", port: 7780))
        XCTAssertEqual(ServerAddress("[::1]:7777"), ServerAddress(host: "::1", port: 7777))
        XCTAssertNil(ServerAddress(""))
        XCTAssertNil(ServerAddress("1.2.3.4:0"))
        XCTAssertNil(ServerAddress("1.2.3.4:99999"))
        XCTAssertNil(ServerAddress("bad host"))
        XCTAssertEqual(ServerAddress(host: "1.2.3.4", port: 7777).description, "1.2.3.4:7777")
    }
}

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("samp-runner-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
