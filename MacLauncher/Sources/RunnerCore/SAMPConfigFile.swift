import Foundation

/// `sa-mp.cfg`: SA-MP's client settings, `key=value` per line. Lives in
/// `Documents/GTA San Andreas User Files/SAMP/` (the old launcher wrote it into the
/// game folder, where SA-MP never reads it).
public struct SAMPConfigFile: Equatable {
    public private(set) var entries: [(key: String, value: String)]

    public init(text: String = "") {
        entries = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            set(key, value)
        }
    }

    public subscript(key: String) -> String? {
        entries.first { $0.key.lowercased() == key.lowercased() }?.value
    }

    /// Updates a key in place (keeping its position) or appends it.
    public mutating func set(_ key: String, _ value: String) {
        if let index = entries.firstIndex(where: { $0.key.lowercased() == key.lowercased() }) {
            entries[index].value = value
        } else {
            entries.append((key, value))
        }
    }

    public func render() -> String {
        entries.map { "\($0.key)=\($0.value)" }.joined(separator: "\r\n") + "\r\n"
    }

    /// Applies the launcher-managed keys, leaving everything else the player set alone.
    public mutating func applyLauncherSettings(_ settings: Settings) {
        let settings = settings.normalized()
        set("fpslimit", String(settings.fpsLimit))
        // Lets SA-MP use a second core; on by default in SA-MP, pinned here in case
        // an old config turned it off.
        set("multicore", "1")
    }

    public static func == (lhs: SAMPConfigFile, rhs: SAMPConfigFile) -> Bool {
        lhs.render() == rhs.render()
    }

    /// Reads, updates and writes the config inside the prefix. Returns the file URL.
    @discardableResult
    public static func update(paths: AppPaths, settings: Settings, fileManager: FileManager = .default) throws -> URL? {
        guard let userFiles = paths.userFilesDirectory(fileManager: fileManager) else { return nil }
        let dir = userFiles.appendingPathComponent("SAMP", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("sa-mp.cfg")
        let existing = (try? Data(contentsOf: file)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        var config = SAMPConfigFile(text: existing)
        config.applyLauncherSettings(settings)
        try config.render().data(using: .utf8)!.write(to: file, options: .atomic)
        return file
    }
}
