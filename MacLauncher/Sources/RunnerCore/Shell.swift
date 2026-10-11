import Foundation

public struct CommandResult {
    public let status: Int32
    public let output: String

    public var succeeded: Bool { status == 0 }
}

public enum ShellError: LocalizedError {
    case failed(command: String, status: Int32, output: String)
    case timedOut(command: String)

    public var errorDescription: String? {
        switch self {
        case let .failed(command, status, output):
            let tail = output.split(separator: "\n").suffix(15).joined(separator: "\n")
            return "\(command) exited with status \(status).\n\(tail)"
        case let .timedOut(command):
            return "\(command) did not finish in time."
        }
    }
}

public enum Shell {
    /// Variables from the user's shell that would silently change which Wine or
    /// prefix gets used.
    static let scrubbedVariables: Set<String> = [
        "WINEPREFIX", "WINEARCH", "WINELOADER", "WINESERVER", "WINEDLLPATH",
        "WINEDLLOVERRIDES", "WINEDEBUG", "WINE_D3D_CONFIG", "DXVK_HUD", "DXVK_ASYNC"
    ]

    public static func environment(merging overrides: [String: String],
                                   base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var env = base.filter { !scrubbedVariables.contains($0.key) }
        for (key, value) in overrides { env[key] = value }
        return env
    }

    /// Runs a command to completion and returns its combined stdout/stderr.
    @discardableResult
    public static func run(_ executable: URL,
                           _ arguments: [String] = [],
                           environment: [String: String]? = nil,
                           currentDirectory: URL? = nil,
                           timeout: TimeInterval? = nil) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        // Drain the pipe on another thread so a chatty child can't fill the pipe
        // buffer and deadlock against waitUntilExit().
        let collected = OutputBuffer()
        let reader = DispatchGroup()
        reader.enter()
        DispatchQueue.global(qos: .utility).async {
            collected.set(pipe.fileHandleForReading.readDataToEndOfFile())
            reader.leave()
        }

        try process.run()

        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                reader.wait()
                throw ShellError.timedOut(command: describe(executable, arguments))
            }
        }
        process.waitUntilExit()
        reader.wait()

        return CommandResult(status: process.terminationStatus,
                             output: String(decoding: collected.get(), as: UTF8.self))
    }

    /// Like `run`, but throws when the command fails.
    @discardableResult
    public static func runChecked(_ executable: URL,
                                  _ arguments: [String] = [],
                                  environment: [String: String]? = nil,
                                  currentDirectory: URL? = nil,
                                  timeout: TimeInterval? = nil) throws -> CommandResult {
        let result = try run(executable, arguments, environment: environment,
                             currentDirectory: currentDirectory, timeout: timeout)
        guard result.succeeded else {
            throw ShellError.failed(command: describe(executable, arguments),
                                    status: result.status, output: result.output)
        }
        return result
    }

    /// Starts a long-running process (the game) with output going to `logFile`.
    public static func spawn(_ executable: URL,
                             _ arguments: [String],
                             environment: [String: String],
                             currentDirectory: URL?,
                             logFile: URL?,
                             onExit: ((Int32) -> Void)? = nil) throws -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }
        // Keep the game (and the wineserver it starts) on the performance cores.
        process.qualityOfService = .userInteractive
        process.standardInput = FileHandle.nullDevice

        if let logFile {
            _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
            let handle = try FileHandle(forWritingTo: logFile)
            process.standardOutput = handle
            process.standardError = handle
        } else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        if let onExit {
            process.terminationHandler = { onExit($0.terminationStatus) }
        }
        try process.run()
        return process
    }

    static func describe(_ executable: URL, _ arguments: [String]) -> String {
        ([executable.lastPathComponent] + arguments).joined(separator: " ")
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ value: Data) { lock.lock(); data = value; lock.unlock() }
    func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}
