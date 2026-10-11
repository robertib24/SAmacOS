import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum RuntimeInstallError: LocalizedError {
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case missingBinary(URL)

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case let .checksumMismatch(expected, actual):
            return "The download is corrupted or was changed upstream (SHA-256 \(actual), expected \(expected))."
        case .extractionFailed(let message):
            return "Couldn't unpack Wine: \(message)"
        case .missingBinary(let url):
            return "Unpacked Wine is missing \(url.lastPathComponent)."
        }
    }
}

/// Downloads a pinned Wine build, verifies its SHA-256 and unpacks it into
/// `runtimes/<id>`. Nothing is installed system-wide and no Homebrew is needed.
// Mutable state is only touched before the download starts and then from the
// session's serial delegate queue.
public final class RuntimeInstaller: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    public typealias Progress = (_ fraction: Double, _ message: String) -> Void

    let paths: AppPaths
    let fileManager: FileManager
    private var progress: Progress?
    private var continuation: CheckedContinuation<URL, Error>?
    private var expectedBytes: Int64 = 0

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func install(_ runtime: WineRuntime, progress: Progress? = nil) async throws {
        if runtime.isInstalled(in: paths, fileManager: fileManager) {
            progress?(1, "\(runtime.displayName) is already installed")
            return
        }
        try paths.createBaseDirectories(fileManager: fileManager)
        self.progress = progress
        expectedBytes = runtime.sizeBytes

        let archive = paths.downloads.appendingPathComponent(runtime.downloadURL.lastPathComponent)
        if !(fileManager.fileExists(atPath: archive.path)
             && (try? Self.sha256(of: archive)) == runtime.sha256) {
            progress?(0, "Downloading \(runtime.displayName)…")
            let temp = try await download(runtime.downloadURL)
            try? fileManager.removeItem(at: archive)
            try fileManager.moveItem(at: temp, to: archive)
        }

        progress?(0.9, "Verifying download…")
        let digest = try Self.sha256(of: archive)
        guard digest == runtime.sha256 else {
            try? fileManager.removeItem(at: archive)
            throw RuntimeInstallError.checksumMismatch(expected: runtime.sha256, actual: digest)
        }

        progress?(0.93, "Unpacking…")
        let staging = paths.runtimes.appendingPathComponent(".staging-\(runtime.id)", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        let tar = try Shell.run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xJf", archive.path, "-C", staging.path])
        guard tar.succeeded else {
            try? fileManager.removeItem(at: staging)
            throw RuntimeInstallError.extractionFailed(tar.output)
        }
        // Not downloaded through a browser so it shouldn't be quarantined, but make
        // sure Gatekeeper never blocks the unsigned Wine binaries.
        _ = try? Shell.run(URL(fileURLWithPath: "/usr/bin/xattr"), ["-dr", "com.apple.quarantine", staging.path])

        let binary = staging.appendingPathComponent(runtime.bundleName)
            .appendingPathComponent("Contents/Resources/wine/bin/wine")
        guard fileManager.isExecutableFile(atPath: binary.path) else {
            try? fileManager.removeItem(at: staging)
            throw RuntimeInstallError.missingBinary(binary)
        }

        let destination = runtime.installDirectory(in: paths)
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: staging, to: destination)
        try? fileManager.removeItem(at: archive)
        progress?(1, "\(runtime.displayName) installed")
    }

    /// Removes installed runtimes that aren't `keep`.
    public func removeRuntimes(except keep: WineRuntime.ID) {
        for runtime in WineRuntime.catalog where runtime.id != keep {
            try? fileManager.removeItem(at: runtime.installDirectory(in: paths))
        }
    }

    // MARK: - Download

    private func download(_ url: URL) async throws -> URL {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedBytes
        guard total > 0 else { return }
        let fraction = min(1, Double(totalBytesWritten) / Double(total))
        let mb = { (b: Int64) in String(format: "%.0f", Double(b) / 1_048_576) }
        progress?(fraction * 0.9, "Downloading Wine… \(mb(totalBytesWritten)) / \(mb(total)) MB")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        // `location` is deleted when this method returns, so move it right away.
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(RuntimeInstallError.downloadFailed("HTTP \(http.statusCode)")))
            return
        }
        let kept = paths.downloads.appendingPathComponent(UUID().uuidString + ".part")
        do {
            try fileManager.moveItem(at: location, to: kept)
            finish(.success(kept))
        } catch {
            finish(.failure(error))
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(RuntimeInstallError.downloadFailed(error.localizedDescription)))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: - Checksum

    public static func sha256(of file: URL) throws -> String {
        #if canImport(CryptoKit)
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 4 * 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        #else
        let result = try Shell.runChecked(URL(fileURLWithPath: "/usr/bin/sha256sum"), [file.path])
        return String(result.output.prefix(64))
        #endif
    }
}
