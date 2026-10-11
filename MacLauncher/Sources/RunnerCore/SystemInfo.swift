import Foundation

public struct SystemInfo {
    public let machine: String
    public let osVersion: String
    public let physicalMemoryGB: Double
    public let cpuCount: Int
    public let lowPowerMode: Bool
    /// "nominal", "fair", "serious (throttling)", ...
    public let thermalState: String

    public static func current() -> SystemInfo {
        let info = ProcessInfo.processInfo
        #if os(macOS)
        let lowPower = info.isLowPowerModeEnabled
        let thermal: String
        switch info.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious (throttling)"
        case .critical: thermal = "critical (heavy throttling)"
        @unknown default: thermal = "unknown"
        }
        #else
        let lowPower = false
        let thermal = "unknown"
        #endif
        return SystemInfo(machine: hardwareMachine(),
                          osVersion: info.operatingSystemVersionString,
                          physicalMemoryGB: Double(info.physicalMemory) / 1_073_741_824,
                          cpuCount: info.activeProcessorCount,
                          lowPowerMode: lowPower,
                          thermalState: thermal)
    }

    public var isAppleSilicon: Bool {
        #if os(macOS)
        return machine.hasPrefix("arm64") || Self.translatedProcess
        #else
        return false
        #endif
    }

    /// x86_64 Wine runs through Rosetta 2 on Apple Silicon.
    public var rosettaInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
    }

    static func hardwareMachine() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// True when this launcher itself was started under Rosetta.
    static var translatedProcess: Bool {
        #if os(macOS)
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("sysctl.proc_translated", &value, &size, nil, 0) == 0 && value == 1
        #else
        return false
        #endif
    }
}
