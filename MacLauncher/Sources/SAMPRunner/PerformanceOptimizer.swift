import Foundation
import Metal

/// Handles performance optimization for GTA SA on macOS
class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()

    private let appSupportURL: URL
    private let dxvkCachePath: URL
    private var isAppleSilicon: Bool
    private var metalDevice: MTLDevice?

    private init() {
        let fileManager = FileManager.default
        appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SA-MP Runner")
        dxvkCachePath = appSupportURL.appendingPathComponent("dxvk_cache")

        // Detect Apple Silicon
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        isAppleSilicon = machine?.contains("arm64") ?? false

        // Get Metal device
        metalDevice = MTLCreateSystemDefaultDevice()

        Logger.shared.info("System: \(isAppleSilicon ? "Apple Silicon" : "Intel")")
        if let device = metalDevice {
            Logger.shared.info("GPU: \(device.name)")
        }
    }

    // MARK: - System Information

    func getSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo

        return SystemInfo(
            isAppleSilicon: isAppleSilicon,
            gpuName: metalDevice?.name ?? "Unknown",
            totalRAM: processInfo.physicalMemory,
            cpuCoreCount: processInfo.processorCount,
            osVersion: processInfo.operatingSystemVersionString,
            supportsMetalFX: supportsMetalFX()
        )
    }

    private func supportsMetalFX() -> Bool {
        // MetalFX available on macOS 13+ with Apple Silicon
        if #available(macOS 13.0, *) {
            return isAppleSilicon
        }
        return false
    }

    // MARK: - Performance Presets

    enum PerformancePreset {
        case low
        case medium
        case high
        case ultra
        case auto
    }

    func applyPreset(_ preset: PerformancePreset) {
        let actualPreset = preset == .auto ? getRecommendedPreset() : preset

        Logger.shared.info("Applying performance preset: \(actualPreset)")

        switch actualPreset {
        case .low:
            applyLowSettings()
        case .medium:
            applyMediumSettings()
        case .high:
            applyHighSettings()
        case .ultra:
            applyUltraSettings()
        case .auto:
            break // Already handled
        }

        configureDXVK(for: actualPreset)
    }

    private func getRecommendedPreset() -> PerformancePreset {
        let info = getSystemInfo()

        // Cu WineD3D (fara DXVK), performance-ul e mai slab
        // Folosim setari mai conservative pentru playability

        // Apple Silicon M2+ with 16GB+ RAM: High
        if isAppleSilicon && info.totalRAM >= 16 * 1024 * 1024 * 1024 {
            return .high
        }

        // Apple Silicon M2/M1 with 8GB RAM: LOW pentru FPS maxim
        // WineD3D consumption + 8GB limita = trebuie low settings
        if isAppleSilicon && info.totalRAM < 16 * 1024 * 1024 * 1024 {
            return .low  // FORCED LOW pentru M2 8GB
        }

        // Intel with dedicated GPU: Medium
        if info.gpuName.contains("Radeon") || info.gpuName.contains("AMD") {
            return .medium
        }

        // Intel with integrated GPU: Low
        if info.gpuName.contains("Intel") {
            return .low
        }

        // Fallback: Low pentru garantat playable
        return .low
    }

    // MARK: - Settings Application

    private func applyLowSettings() {
        let settings = GameSettings(
            resolution: (640, 480),  // M2 8GB: minim pentru FPS playable
            drawDistance: 0.4,  // Foarte mica pentru performance maxim
            antiAliasing: false,
            visualFX: 0,  // Minim pentru maxim FPS
            frameLimiter: false,
            vsync: false
        )
        applyGameSettings(settings)
    }

    private func applyMediumSettings() {
        let settings = GameSettings(
            resolution: (1024, 768),  // Reduced pentru mai mult FPS
            drawDistance: 0.7,  // Reduced pentru performance
            antiAliasing: false,  // Disabled pentru FPS
            visualFX: 0,  // Minim pentru FPS
            frameLimiter: false,
            vsync: false
        )
        applyGameSettings(settings)
    }

    private func applyHighSettings() {
        let settings = GameSettings(
            resolution: (1920, 1080),
            drawDistance: 1.0,  // Reduced pentru performance
            antiAliasing: false,  // Disabled pentru FPS
            visualFX: 2,  // Reduced
            frameLimiter: false,
            vsync: false
        )
        applyGameSettings(settings)
    }

    private func applyUltraSettings() {
        let settings = GameSettings(
            resolution: (2560, 1440),
            drawDistance: 1.5,
            antiAliasing: true,
            visualFX: 3,
            frameLimiter: false,
            vsync: false
        )
        applyGameSettings(settings)
    }

    private func applyGameSettings(_ settings: GameSettings) {
        // Write settings to gta_sa.set file
        // Aici era eroarea: getGamePath() trebuie sa existe in GameInstaller
        let gtaSAPath = GameInstaller.shared.getGamePath()
        let settingsPath = gtaSAPath.appendingPathComponent("gta_sa.set")

        let config = """
        [Display]
        Width=\(settings.resolution.0)
        Height=\(settings.resolution.1)
        Depth=32
        Windowed=0
        VSync=\(settings.vsync ? 1 : 0)
        FrameLimiter=\(settings.frameLimiter ? 1 : 0)

        [Graphics]
        VideoMode=1
        Brightness=0
        DrawDistance=\(settings.drawDistance)
        AntiAliasing=\(settings.antiAliasing ? 1 : 0)
        VisualFX=\(settings.visualFX)
        MipMapping=1

        [Audio]
        SfxVolume=100
        MusicVolume=80
        RadioVolume=80
        RadioEQ=0
        """

        try? config.write(to: settingsPath, atomically: true, encoding: .utf8)
    }

    // MARK: - DXVK Configuration

    private func configureDXVK(for preset: PerformancePreset) {
        let dxvkConfig = generateDXVKConfig(for: preset)
        let configPath = appSupportURL.appendingPathComponent("dxvk.conf")

        try? dxvkConfig.write(to: configPath, atomically: true, encoding: .utf8)

        Logger.shared.info("DXVK configuration updated")
    }

    private func generateDXVKConfig(for preset: PerformancePreset) -> String {
        let numThreads = ProcessInfo.processInfo.processorCount

        switch preset {
        case .low, .medium:
            return """
            # DXVK Configuration - Low/Medium Preset

            dxvk.enableAsync = True
            dxvk.numCompilerThreads = \(max(2, numThreads / 2))
            dxvk.maxFrameLatency = 2
            dxvk.maxDeviceMemory = 2048
            dxvk.enableGraphicsPipelineLibrary = False
            dxvk.useRawSsbo = True
            dxvk.enableStateCache = True
            """

        case .high:
            return """
            # DXVK Configuration - High Preset

            dxvk.enableAsync = True
            dxvk.numCompilerThreads = \(numThreads)
            dxvk.maxFrameLatency = 1
            dxvk.maxDeviceMemory = 4096
            dxvk.enableGraphicsPipelineLibrary = True
            dxvk.useRawSsbo = True
            dxvk.enableStateCache = True
            dxvk.hud = fps
            """

        case .ultra:
            return """
            # DXVK Configuration - Ultra Preset

            dxvk.enableAsync = True
            dxvk.numCompilerThreads = \(numThreads)
            dxvk.maxFrameLatency = 1
            dxvk.maxDeviceMemory = 8192
            dxvk.enableGraphicsPipelineLibrary = True
            dxvk.useRawSsbo = True
            dxvk.enableStateCache = True
            dxvk.hud = fps,devinfo,memory

            # Ultra-specific optimizations
            dxvk.maxChunkSize = 128
            """

        case .auto:
            return generateDXVKConfig(for: getRecommendedPreset())
        }
    }

    // MARK: - Shader Cache Management

    func precompileShaders(progress: @escaping (Double, String) -> Void) {
        Logger.shared.info("Precompiling shader cache...")

        DispatchQueue.global(qos: .userInitiated).async {
            // Check if shader cache exists
            let cacheFile = self.dxvkCachePath.appendingPathComponent("GTA_SA.dxvk-cache")

            if FileManager.default.fileExists(atPath: cacheFile.path) {
                Logger.shared.info("Shader cache already exists")
                progress(1.0, "Shader cache ready")
                return
            }

            // Download pre-compiled shader cache if available
            progress(0.5, "Downloading shader cache...")

            // In production, this would download from a CDN
            // For now, we'll let DXVK build it on first run

            progress(1.0, "Shader cache will be built on first launch")
        }
    }

    func clearShaderCache() {
        Logger.shared.info("Clearing shader cache...")

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: dxvkCachePath, includingPropertiesForKeys: nil)
            for file in contents {
                try FileManager.default.removeItem(at: file)
            }
            Logger.shared.info("Shader cache cleared")
        } catch {
            Logger.shared.error("Failed to clear shader cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Performance Monitoring

    func getPerformanceStats() -> PerformanceStats {
        let task = mach_task_self_
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(task, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        let memoryUsage = result == KERN_SUCCESS ? info.phys_footprint : 0

        return PerformanceStats(
            memoryUsage: UInt64(memoryUsage),
            cpuUsage: getCPUUsage(),
            gpuUsage: getGPUUsage()
        )
    }

    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                if infoResult == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo as thread_basic_info
                    if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                        totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                    }
                }
            }

            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        return totalUsageOfCPU
    }

    private func getGPUUsage() -> Double {
        // macOS doesn't provide easy GPU usage API
        // This would require IOKit or Metal performance counters
        // Returning 0 for now
        return 0.0
    }
}

// MARK: - Data Structures

struct SystemInfo {
    let isAppleSilicon: Bool
    let gpuName: String
    let totalRAM: UInt64
    let cpuCoreCount: Int
    let osVersion: String
    let supportsMetalFX: Bool
}

struct GameSettings {
    let resolution: (Int, Int)
    let drawDistance: Double
    let antiAliasing: Bool
    let visualFX: Int
    let frameLimiter: Bool
    let vsync: Bool
}

struct PerformanceStats {
    let memoryUsage: UInt64
    let cpuUsage: Double
    let gpuUsage: Double
}
