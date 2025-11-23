# SA-MP macOS Runner - Technical Architecture

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface Layer                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   Native macOS Application (Swift + AppKit)      │  │
│  │   - Main Window & Launcher UI                    │  │
│  │   - Settings Panel                               │  │
│  │   - Installation Wizard                          │  │
│  │   - Server Browser                               │  │
│  │   - Mod Manager                                  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 Application Logic Layer                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   WineManager (Process Management)               │  │
│  │   - Wine process lifecycle                       │  │
│  │   - Environment configuration                    │  │
│  │   - WINEPREFIX management                        │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   GameManager (Game Operations)                  │  │
│  │   - Installation & updates                       │  │
│  │   - File integrity checks                        │  │
│  │   - Mod installation                             │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   PerformanceOptimizer                           │  │
│  │   - DXVK configuration                           │  │
│  │   - Graphics presets                             │  │
│  │   - System monitoring                            │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Compatibility Layer (Wine)                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   Wine Crossover Engine                          │  │
│  │   - Windows API implementation                   │  │
│  │   - Process management                           │  │
│  │   - File system mapping                          │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   DXVK (DirectX 9 → Vulkan)                      │  │
│  │   - D3D9 translation                             │  │
│  │   - Shader compilation & caching                 │  │
│  │   - Async pipeline compilation                   │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   MoltenVK (Vulkan → Metal)                      │  │
│  │   - Vulkan API implementation                    │  │
│  │   - Metal backend                                │  │
│  │   - GPU memory management                        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                  macOS System Layer                      │
│  ┌──────────────────────────────────────────────────┐  │
│  │   Metal (GPU)                                    │  │
│  │   CoreAudio (Audio)                              │  │
│  │   IOKit (Input devices)                          │  │
│  │   BSD Sockets (Networking)                       │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Native macOS Application (Swift)

**Purpose:** Provide seamless macOS user experience

**Key Classes:**
```swift
// Main application controller
class AppDelegate: NSObject, NSApplicationDelegate

// Launcher window
class LauncherWindowController: NSWindowController
    - serverBrowser: ServerBrowserViewController
    - settingsPanel: SettingsViewController
    - modManager: ModManagerViewController

// Wine process manager
class WineManager {
    func createPrefix()
    func launchGame(withArgs: [String])
    func killWine()
    func getStatus() -> WineStatus
}

// Game installation
class GameInstaller {
    func installGTASA(fromPath: URL)
    func installSAMP(version: String)
    func verifyInstallation() -> Bool
}

// Performance monitoring
class PerformanceMonitor {
    func getCurrentFPS() -> Int
    func getGPUUsage() -> Float
    func getMemoryUsage() -> MemoryStats
}
```

**Features:**
- Native macOS UI with dark mode support
- Drag & drop game installation
- Real-time FPS overlay
- One-click server join
- Mod management with conflict detection

### 2. Wine Engine

**Wine Version:** Crossover 23+ (based on Wine 8.0+)

**Why Crossover over vanilla Wine:**
- Better macOS integration
- Apple Silicon optimizations
- Superior graphics performance
- Commercial support

**Wine Configuration:**

```bash
# Environment variables
export WINEPREFIX="$HOME/Library/Application Support/SA-MP Runner/wine"
export WINEARCH=win32
export WINE=/Applications/SA-MP\ Runner.app/Contents/Resources/wine/bin/wine

# Performance settings
export STAGING_SHARED_MEMORY=1
export WINE_LARGE_ADDRESS_AWARE=1
export DXVK_HUD=fps
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH="$WINEPREFIX/dxvk_cache"

# macOS specific
export MTL_HUD_ENABLED=0
export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1
```

**DLL Overrides:**
```ini
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"d3d9"="native"
"dxgi"="native"
"d3d11"="native"
```

### 3. DXVK (DirectX → Vulkan Translation)

**Version:** DXVK 2.3+ with async patch

**Purpose:** Translate DirectX 9 calls to Vulkan for better performance

**Configuration (`dxvk.conf`):**

```ini
# Performance
dxvk.enableAsync = True
dxvk.numCompilerThreads = 0  # Use all available threads

# Memory
dxvk.maxFrameLatency = 1
dxvk.maxDeviceMemory = 4096

# Graphics
dxvk.enableGraphicsPipelineLibrary = True
dxvk.useRawSsbo = True

# Shader cache
dxvk.enableStateCache = True
```

**How it works:**
1. GTA SA makes D3D9 API calls
2. DXVK intercepts and translates to Vulkan
3. Commands sent to MoltenVK
4. MoltenVK translates to Metal
5. macOS GPU executes

**Performance benefits:**
- ~30-40% FPS improvement over WineD3D
- Async shader compilation (no stuttering)
- Better memory management
- Modern GPU features

### 4. MoltenVK (Vulkan → Metal)

**Purpose:** Translate Vulkan API to Apple's Metal

**Configuration:**

```bash
# MoltenVK settings
export MVK_CONFIG_LOG_LEVEL=1  # Errors only
export MVK_CONFIG_TRACE_VULKAN_CALLS=0  # Disable tracing
export MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0  # Async submissions
export MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=1  # Optimization
export MVK_ALLOW_METAL_FENCES=1
export MVK_ALLOW_METAL_EVENTS=1
```

**Optimizations:**
- Direct Metal shader compilation
- Zero-copy texture transfers where possible
- Unified memory on Apple Silicon
- Async compute queues

### 5. Performance Pipeline

```
GTA SA Draw Call
    ↓
Direct3D 9 API
    ↓
DXVK (D3D9 → Vulkan)
    ├─ Shader Translation
    ├─ State Management
    └─ Command Buffering
    ↓
Vulkan API
    ↓
MoltenVK (Vulkan → Metal)
    ├─ Metal Shader Compilation
    ├─ Descriptor Management
    └─ Resource Tracking
    ↓
Metal API
    ↓
macOS GPU Driver
    ↓
GPU Hardware (Apple Silicon / AMD / Intel)
```

## Installation Flow

```
User launches SA-MP Runner
    ↓
First-time setup detected
    ↓
Installation Wizard starts
    ↓
[Step 1] Check system requirements
    ├─ macOS version
    ├─ Available disk space
    ├─ GPU capabilities
    └─ RAM
    ↓
[Step 2] Install Wine engine
    ├─ Extract Wine binaries
    ├─ Install dependencies
    └─ Create WINEPREFIX
    ↓
[Step 3] Install DXVK + MoltenVK
    ├─ Download DXVK DLLs
    ├─ Install to Wine prefix
    └─ Configure settings
    ↓
[Step 4] GTA SA installation
    ├─ Option A: Use existing installation
    ├─ Option B: Install from disc/ISO
    └─ Option C: Download (if legal)
    ↓
[Step 5] Install SA-MP client
    ├─ Download latest version
    ├─ Extract to GTA SA folder
    └─ Apply compatibility patches
    ↓
[Step 6] Apply optimizations
    ├─ Create optimized gta_sa.set
    ├─ Shader cache setup
    ├─ Memory allocation tweaks
    └─ Audio configuration
    ↓
[Step 7] First launch test
    ├─ Launch game
    ├─ Verify functionality
    └─ Benchmark performance
    ↓
Setup complete!
```

## Data Storage

### Application Data Structure

```
~/Library/Application Support/SA-MP Runner/
├── wine/                          # Wine prefix
│   ├── drive_c/
│   │   ├── Program Files/
│   │   │   └── Rockstar Games/
│   │   │       └── GTA San Andreas/
│   │   └── windows/
│   ├── dosdevices/
│   └── system.reg
│
├── dxvk_cache/                    # Shader cache
│   └── GTA_SA.cache
│
├── mods/                          # Installed mods
│   ├── CLEO/
│   ├── modloader/
│   └── skins/
│
├── config/                        # App configuration
│   ├── launcher.json
│   ├── graphics.json
│   └── servers.json
│
└── logs/                          # Application logs
    ├── launcher.log
    ├── wine.log
    └── game.log
```

## Performance Optimizations

### 1. CPU Optimizations

**For Apple Silicon:**
- Wine runs through Rosetta 2 (x86 → ARM translation)
- Use all P-cores for game thread
- E-cores for background tasks
- Minimal translation overhead (~5%)

**For Intel:**
- Native x86 execution
- Hyper-threading enabled
- CPU affinity for game process

### 2. GPU Optimizations

**Metal Configuration:**
```swift
// Optimal Metal settings
let device = MTLCreateSystemDefaultDevice()
let commandQueue = device.makeCommandQueue()
commandQueue.maxCommandBufferCount = 3  // Triple buffering
```

**DXVK Settings:**
- Async shader compilation (DXVK_ASYNC=1)
- Pre-compiled shader cache
- Aggressive pipeline caching

### 3. Memory Optimizations

**Wine Memory Settings:**
```
[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Memory Management]
"LargePageMinimum"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Wine]
"AllocExecutableMemory"="1"
```

**Game Memory Tweaks:**
- Increased streaming memory
- Larger texture cache
- Optimized heap sizes

### 4. Audio Optimizations

**CoreAudio Bridge:**
- Low-latency audio pipeline
- 256 sample buffer
- 48kHz sample rate
- Stereo output

### 5. Network Optimizations

**SA-MP Networking:**
- Native BSD sockets (no Wine translation)
- TCP_NODELAY enabled
- Optimal buffer sizes
- IPv4/IPv6 support

## Apple Silicon Specific

### Unified Memory Architecture (UMA)

**Benefits:**
- Zero-copy GPU uploads
- Faster texture streaming
- Reduced memory overhead

**Implementation:**
```swift
// Use shared memory mode
let options = MTLResourceOptions.storageModeShared
let buffer = device.makeBuffer(length: size, options: options)
```

### Rosetta 2 Translation

**Wine through Rosetta:**
```
x86 Wine → Rosetta 2 → ARM64 Native
         ↓
    ~5% overhead
```

**Optimization:**
- AOT compilation on first run
- Translation cache persistent
- Minimal runtime overhead

## Monitoring & Debugging

### Performance Monitoring

**Built-in overlay:**
- FPS counter
- Frame time graph
- GPU usage
- CPU usage per core
- Memory usage
- Network latency

**Logging:**
```swift
// Performance logger
class PerformanceLogger {
    func logFrame(fps: Int, frameTime: Double, gpuUsage: Float)
    func generateReport() -> PerformanceReport
}
```

### Debug Mode

```bash
# Enable debug output
export WINEDEBUG=+all
export DXVK_LOG_LEVEL=debug
export MVK_DEBUG=1

# Launch with debugging
./SA-MP\ Runner --debug
```

## Security Considerations

1. **Sandboxing:** App runs in macOS sandbox
2. **Code Signing:** All binaries signed
3. **Gatekeeper:** Notarized for macOS
4. **Network:** Firewall rules for SA-MP
5. **File Access:** Limited to app container

## Future Optimizations

### Planned Improvements

1. **Metal 3 Features (macOS 13+)**
   - MetalFX upscaling
   - Fast resource loading
   - Mesh shaders

2. **Game Porting Toolkit Integration**
   - Apple's official D3D → Metal translator
   - Better performance than DXVK+MoltenVK
   - Native feeling

3. **Shader Pre-compilation**
   - Ship with pre-compiled shaders
   - Eliminate first-run stuttering
   - Faster load times

4. **Custom Wine Patches**
   - macOS-specific optimizations
   - Better memory management
   - Reduced syscall overhead

## Performance Targets

| Hardware | Resolution | Settings | Target FPS |
|----------|-----------|----------|------------|
| M1 | 1080p | High | 60+ |
| M1 | 1440p | Medium | 60+ |
| M1 Pro/Max | 1440p | High | 90+ |
| M2/M3 | 1080p | Ultra | 90+ |
| Intel (dedicated GPU) | 1080p | High | 50+ |
| Intel (integrated) | 1080p | Low | 30+ |

## Conclusion

This hybrid architecture provides:
- ✅ Native macOS experience
- ✅ Near-native gaming performance
- ✅ Full mod compatibility
- ✅ No VM overhead
- ✅ Future-proof design
