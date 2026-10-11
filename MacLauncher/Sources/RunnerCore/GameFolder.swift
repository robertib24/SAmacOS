import Foundation

/// A GTA San Andreas folder and what's in it.
public struct GameFolder {
    public let url: URL
    let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public var gtaExecutable: URL { url.appendingPathComponent("gta_sa.exe") }
    public var sampExecutable: URL { url.appendingPathComponent("samp.exe") }
    public var sampLibrary: URL { url.appendingPathComponent("samp.dll") }

    public var hasGame: Bool { exists(gtaExecutable) }
    public var hasSAMP: Bool { exists(sampExecutable) && exists(sampLibrary) }

    /// SA-MP 0.3.7 only works with the 1.0 US executable.
    public enum ExecutableKind: Equatable, Sendable {
        case v1_0_US
        case unknown(bytes: Int64)
        case missing

        public var description: String {
            switch self {
            case .v1_0_US: return "GTA SA 1.0 US (SA-MP compatible)"
            case .unknown(let bytes): return "unrecognised gta_sa.exe (\(bytes) bytes) — SA-MP needs the 1.0 US executable"
            case .missing: return "gta_sa.exe not found"
            }
        }
    }

    public var executableKind: ExecutableKind {
        guard let size = fileSize(gtaExecutable) else { return .missing }
        return size == 14_383_616 ? .v1_0_US : .unknown(bytes: size)
    }

    /// Direct3D/DXGI DLLs next to gta_sa.exe that came from DXVK (the old
    /// launcher copied them there). DXVK's D3D9 doesn't work on MoltenVK.
    public var dxvkLeftovers: [URL] {
        ["d3d9.dll", "dxgi.dll", "d3d10core.dll", "d3d11.dll", "d3d8.dll"]
            .map { url.appendingPathComponent($0) }
            // Every DXVK DLL reads DXVK_LOG_LEVEL; mod proxies like ReShade don't.
            .filter { exists($0) && Self.fileContains($0, marker: "DXVK_LOG_LEVEL") }
    }

    /// Any other d3d9.dll in the folder: usually a mod proxy (ReShade, ENB, SAMP Addon).
    public var hasD3D9Proxy: Bool {
        let d3d9 = url.appendingPathComponent("d3d9.dll")
        return exists(d3d9) && !dxvkLeftovers.contains(d3d9)
    }

    /// Renames DXVK leftovers to `*.dxvk-disabled` (kept, in case you want them back).
    @discardableResult
    public func disableDXVKLeftovers() throws -> [URL] {
        var moved: [URL] = []
        for dll in dxvkLeftovers {
            let target = dll.appendingPathExtension("dxvk-disabled")
            try? fileManager.removeItem(at: target)
            try fileManager.moveItem(at: dll, to: target)
            moved.append(target)
        }
        let conf = url.appendingPathComponent("dxvk.conf")
        if exists(conf) { try? fileManager.removeItem(at: conf) }
        return moved
    }

    private func exists(_ file: URL) -> Bool {
        fileManager.fileExists(atPath: file.path)
    }

    private func fileSize(_ file: URL) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
              let size = attributes[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    /// Scans the start of a file for an ASCII marker (case-insensitive).
    static func fileContains(_ file: URL, marker: String, limit: Int = 8 * 1024 * 1024) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: limit)
        let needle = Array(marker.lowercased().utf8)
        guard !needle.isEmpty, data.count >= needle.count else { return false }
        let first = needle[0]
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            let bytes = raw.bindMemory(to: UInt8.self)
            var i = 0
            while i <= bytes.count - needle.count {
                if lower(bytes[i]) == first {
                    var j = 1
                    while j < needle.count && lower(bytes[i + j]) == needle[j] { j += 1 }
                    if j == needle.count { return true }
                }
                i += 1
            }
            return false
        }
    }

    private static func lower(_ byte: UInt8) -> UInt8 {
        (byte >= 65 && byte <= 90) ? byte + 32 : byte
    }
}

public enum GameImportError: LocalizedError {
    case notAGameFolder(URL)
    case destinationExists(URL)

    public var errorDescription: String? {
        switch self {
        case .notAGameFolder(let url):
            return "\(url.path) doesn't contain gta_sa.exe. Pick the folder that has gta_sa.exe in it."
        case .destinationExists(let url):
            return "A game is already installed at \(url.path). Remove it first or import with replace."
        }
    }
}

public enum GameImporter {
    /// Copies a GTA SA folder into the prefix. On APFS `copyItem` clones files, so
    /// this is near-instant and takes no extra disk space until files change.
    public static func importGame(from source: URL, paths: AppPaths, replace: Bool = false,
                                  move: Bool = false, fileManager: FileManager = .default) throws {
        let source = source.standardizedFileURL
        guard GameFolder(url: source, fileManager: fileManager).hasGame else {
            throw GameImportError.notAGameFolder(source)
        }
        let destination = paths.gameDirectory
        if source.path == destination.standardizedFileURL.path { return }
        if fileManager.fileExists(atPath: destination.path) {
            guard replace else { throw GameImportError.destinationExists(destination) }
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if move {
            try fileManager.moveItem(at: source, to: destination)
        } else {
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    /// The old launcher installed into `wine/drive_c/Program Files/...` and let
    /// Wine store user files in ~/Documents. Bring both into the new prefix.
    public static func importLegacyInstall(paths: AppPaths, fileManager: FileManager = .default) throws -> Bool {
        let legacy = paths.legacyGameDirectory
        guard GameFolder(url: legacy, fileManager: fileManager).hasGame else { return false }
        try importGame(from: legacy, paths: paths, replace: false, move: true, fileManager: fileManager)
        importMacDocumentsUserFiles(paths: paths, fileManager: fileManager)
        return true
    }

    /// Copies ~/Documents/GTA San Andreas User Files (settings, SA-MP favorites,
    /// screenshots) into the prefix if the prefix doesn't have its own yet.
    @discardableResult
    public static func importMacDocumentsUserFiles(paths: AppPaths, fileManager: FileManager = .default) -> Bool {
        let source = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/GTA San Andreas User Files", isDirectory: true)
        guard fileManager.fileExists(atPath: source.path),
              let destination = paths.userFilesDirectory(fileManager: fileManager),
              !fileManager.fileExists(atPath: destination.path) else { return false }
        try? fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? fileManager.copyItem(at: source, to: destination)) != nil
    }
}
