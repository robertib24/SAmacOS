import Foundation

/// Frame pacing summary from a benchmark session.
public struct BenchmarkResult: Codable, Equatable {
    public let frames: Int
    public let seconds: Double
    public let averageFPS: Double
    /// Average FPS of the slowest 1% of frames: what stutter feels like.
    public let onePercentLowFPS: Double
    public let worstFrameMS: Double
    public let renderer: String?

    public var summary: String {
        String(format: "%.0f FPS average, %.0f FPS 1%% low, worst frame %.0f ms (%d frames over %.0f s)",
               averageFPS, onePercentLowFPS, worstFrameMS, frames, seconds)
    }
}

/// Parses wined3d's `+frametime` trace: one `Frame duration <N> μs.` line per
/// presented frame.
public enum Benchmark {
    static let marker = "Frame duration "

    public static func frameTimes(in log: String) -> [Double] {
        var result: [Double] = []
        log.enumerateLines { line, _ in
            guard let range = line.range(of: marker) else { return }
            let digits = line[range.upperBound...].prefix { $0.isNumber }
            if let micro = Double(digits), micro > 0 { result.append(micro / 1000.0) }
        }
        return result
    }

    /// - Parameters:
    ///   - warmupSeconds: ignored at the start (menus, loading, shader compilation).
    ///   - maxFrameMS: frames longer than this are loading screens, not gameplay.
    public static func summarize(frameTimesMS: [Double], warmupSeconds: Double = 10,
                                 maxFrameMS: Double = 1000, renderer: String? = nil) -> BenchmarkResult? {
        var elapsed = 0.0
        var samples: [Double] = []
        samples.reserveCapacity(frameTimesMS.count)
        for ms in frameTimesMS {
            elapsed += ms / 1000
            if elapsed > warmupSeconds && ms <= maxFrameMS { samples.append(ms) }
        }
        guard samples.count >= 30 else { return nil }

        let total = samples.reduce(0, +)
        let sorted = samples.sorted()
        let slowest = sorted.suffix(max(1, sorted.count / 100))
        let slowestAverage = slowest.reduce(0, +) / Double(slowest.count)
        return BenchmarkResult(frames: samples.count,
                               seconds: total / 1000,
                               averageFPS: Double(samples.count) / (total / 1000),
                               onePercentLowFPS: 1000 / slowestAverage,
                               worstFrameMS: sorted.last ?? 0,
                               renderer: renderer)
    }

    public static func summarize(logFile: URL, renderer: String? = nil) -> BenchmarkResult? {
        guard let data = try? Data(contentsOf: logFile) else { return nil }
        return summarize(frameTimesMS: frameTimes(in: String(decoding: data, as: UTF8.self)), renderer: renderer)
    }
}
