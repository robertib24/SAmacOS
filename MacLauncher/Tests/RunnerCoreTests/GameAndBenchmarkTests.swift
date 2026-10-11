import XCTest
@testable import RunnerCore

final class BenchmarkTests: XCTestCase {
    func testParsesWined3dFrametimeTrace() {
        let log = """
        0124:trace:frametime:wined3d_cs_exec_present Frame duration 16667 μs.
        some other output
        0124:trace:frametime:wined3d_cs_exec_present Frame duration 33333 μs.
        0124:trace:frametime:wined3d_cs_exec_present Frame duration 0 μs.
        """
        XCTAssertEqual(Benchmark.frameTimes(in: log), [16.667, 33.333])
    }

    func testSummary() throws {
        // ~10 s warm-up at 30 FPS (ignored), then 990 frames at 60 FPS and 10 at 20 FPS.
        var frames = Array(repeating: 33.333, count: 300)
        frames += Array(repeating: 16.667, count: 990)
        frames += Array(repeating: 50.0, count: 10)
        frames.append(5000)  // a loading screen, excluded
        let result = try XCTUnwrap(Benchmark.summarize(frameTimesMS: frames, renderer: "vulkan"))
        XCTAssertEqual(result.frames, 1000)
        XCTAssertEqual(result.onePercentLowFPS, 20, accuracy: 0.01)
        XCTAssertEqual(result.averageFPS, 58.82, accuracy: 0.05)
        XCTAssertEqual(result.worstFrameMS, 50)
        XCTAssertEqual(result.renderer, "vulkan")
    }

    func testTooFewFramesGivesNoResult() {
        XCTAssertNil(Benchmark.summarize(frameTimesMS: Array(repeating: 16.7, count: 100)))
    }
}

final class GameFolderTests: XCTestCase {
    func testRecognisesExecutablesAndSAMP() throws {
        let dir = try temporaryDirectory()
        let game = GameFolder(url: dir)
        XCTAssertEqual(game.executableKind, .missing)
        try sparseFile(dir.appendingPathComponent("gta_sa.exe"), size: 14_383_616)
        XCTAssertEqual(game.executableKind, .v1_0_US)
        XCTAssertFalse(game.hasSAMP)
        try Data().write(to: dir.appendingPathComponent("samp.exe"))
        try Data().write(to: dir.appendingPathComponent("samp.dll"))
        XCTAssertTrue(game.hasSAMP)
        try sparseFile(dir.appendingPathComponent("gta_sa.exe"), size: 5_189_632)
        XCTAssertEqual(game.executableKind, .unknown(bytes: 5_189_632))
    }

    func testFindsAndDisablesDXVKLeftoversButNotModProxies() throws {
        let dir = try temporaryDirectory()
        let game = GameFolder(url: dir)
        try Data(repeating: 0, count: 100_000).write(to: dir.appendingPathComponent("d3d9.dll"))
        XCTAssertTrue(game.dxvkLeftovers.isEmpty)
        XCTAssertTrue(game.hasD3D9Proxy)

        var dxvk = Data(repeating: 0x41, count: 50_000)
        dxvk.append(Data("...dxvk_log_level...".utf8))
        try dxvk.write(to: dir.appendingPathComponent("d3d9.dll"))
        try dxvk.write(to: dir.appendingPathComponent("dxgi.dll"))
        try Data("dxvk.enableAsync = True".utf8).write(to: dir.appendingPathComponent("dxvk.conf"))
        XCTAssertEqual(Set(game.dxvkLeftovers.map(\.lastPathComponent)), ["d3d9.dll", "dxgi.dll"])
        XCTAssertFalse(game.hasD3D9Proxy)

        let moved = try game.disableDXVKLeftovers()
        XCTAssertEqual(moved.count, 2)
        XCTAssertTrue(game.dxvkLeftovers.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("d3d9.dll.dxvk-disabled").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("dxvk.conf").path))
    }

    func testImportCopiesIntoPrefixAndRefusesToOverwrite() throws {
        let paths = AppPaths(root: try temporaryDirectory())
        let source = try temporaryDirectory()
        XCTAssertThrowsError(try GameImporter.importGame(from: source, paths: paths))
        try Data("exe".utf8).write(to: source.appendingPathComponent("gta_sa.exe"))
        try FileManager.default.createDirectory(at: source.appendingPathComponent("models"), withIntermediateDirectories: true)
        try Data("img".utf8).write(to: source.appendingPathComponent("models/gta3.img"))

        try GameImporter.importGame(from: source, paths: paths)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.gameDirectory.appendingPathComponent("models/gta3.img").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("gta_sa.exe").path))
        XCTAssertThrowsError(try GameImporter.importGame(from: source, paths: paths))
        XCTAssertNoThrow(try GameImporter.importGame(from: source, paths: paths, replace: true))
    }

    func testLegacyImportMovesGameOutOfOldPrefix() throws {
        let paths = AppPaths(root: try temporaryDirectory())
        try FileManager.default.createDirectory(at: paths.legacyGameDirectory, withIntermediateDirectories: true)
        try Data("exe".utf8).write(to: paths.legacyGameDirectory.appendingPathComponent("gta_sa.exe"))
        let runner = Runner(paths: paths)
        XCTAssertTrue(runner.legacyInstallAvailable)
        XCTAssertTrue(try runner.importLegacyInstall())
        XCTAssertTrue(runner.game.hasGame)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.legacyGameDirectory.path))
        XCTAssertFalse(runner.legacyInstallAvailable)
    }

    private func sparseFile(_ url: URL, size: UInt64) throws {
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }
}

final class RuntimeTests: XCTestCase {
    func testCatalogPinsChecksumsAndHTTPS() {
        for runtime in WineRuntime.catalog {
            XCTAssertEqual(runtime.sha256.count, 64, runtime.id)
            XCTAssertEqual(runtime.downloadURL.scheme, "https", runtime.id)
            XCTAssertTrue(runtime.downloadURL.lastPathComponent.hasPrefix(runtime.id), runtime.id)
        }
        XCTAssertEqual(WineRuntime.find(id: WineRuntime.recommended.id), WineRuntime.recommended)
    }

    func testResolution() throws {
        let paths = AppPaths(root: try temporaryDirectory())
        var settings = Settings()
        XCTAssertThrowsError(try RuntimeResolver.resolve(settings: settings, paths: paths)) { error in
            XCTAssertEqual(error as? RuntimeResolutionError, .notInstalled(WineRuntime.recommended.id))
        }
        let wine = WineRuntime.recommended.wineBinary(in: paths)
        try makeExecutable(wine, script: "#!/bin/sh\n")
        let resolved = try RuntimeResolver.resolve(settings: settings, paths: paths)
        XCTAssertEqual(resolved.wine, wine)
        XCTAssertEqual(resolved.wineserver.lastPathComponent, "wineserver")

        settings.customWinePath = "/nonexistent/wine"
        XCTAssertThrowsError(try RuntimeResolver.resolve(settings: settings, paths: paths))
        settings.runtimeID = "nope"
        settings.customWinePath = nil
        XCTAssertThrowsError(try RuntimeResolver.resolve(settings: settings, paths: paths)) { error in
            XCTAssertEqual(error as? RuntimeResolutionError, .unknownRuntime("nope"))
        }
    }

    func testSHA256() throws {
        let file = try temporaryDirectory().appendingPathComponent("data")
        try Data("abc".utf8).write(to: file)
        XCTAssertEqual(try RuntimeInstaller.sha256(of: file),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

func makeExecutable(_ url: URL, script: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(script.utf8).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
