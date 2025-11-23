# SA-MP macOS Runner

🎮 Run GTA San Andreas Multiplayer (modded Windows version) natively on macOS with optimal performance.

## Overview

SA-MP macOS Runner is a complete hybrid solution that allows you to play GTA San Andreas Multiplayer on macOS without using virtual machines. The application combines native macOS technologies with Wine compatibility layer for maximum performance.

## Architecture

### Core Components

```
┌─────────────────────────────────────────┐
│   Native macOS Launcher (Swift/AppKit)  │
│   - UI/UX                                │
│   - Installation Manager                 │
│   - Settings & Configuration             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   Wine Engine (Optimized)                │
│   - Crossover/Wine Staging               │
│   - DXVK (DirectX → Vulkan)              │
│   - MoltenVK (Vulkan → Metal)            │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   GTA SA + SA-MP (Windows)               │
│   - Modded game files                    │
│   - SA-MP client                         │
│   - Custom patches                       │
└─────────────────────────────────────────┘
```

### Performance Pipeline

```
GTA SA (DirectX 9)
    → DXVK (DX9 → Vulkan)
    → MoltenVK (Vulkan → Metal)
    → macOS GPU (Native performance)
```

## Features

### ✅ Current Features
- 🚀 Native macOS application (no VM needed)
- 📦 Complete installer for GTA SA + SA-MP
- ⚡ Optimized Wine configuration for gaming
- 🎯 DXVK + MoltenVK for GPU acceleration
- 🔧 Automatic performance tuning
- 🎮 Server browser integration
- 💾 Mod management system
- 🔄 Auto-update for SA-MP client

### 🔮 Planned Features
- 📊 Performance monitoring overlay
- 🎨 Graphics presets (Low/Medium/High/Ultra)
- 🌐 Integrated server list
- 🎭 Skin preview and management
- 🔊 Audio optimization for macOS
- ☁️ Cloud save synchronization

## System Requirements

### Minimum
- macOS 11.0 Big Sur or later
- Apple Silicon (M1/M2/M3) or Intel with Metal support
- 8 GB RAM
- 5 GB free disk space
- GTA San Andreas (Windows version)

### Recommended
- macOS 13.0 Ventura or later
- Apple Silicon M2 or later
- 16 GB RAM
- 10 GB free disk space
- SSD storage

## Installation

### Quick Start

1. Download SA-MP macOS Runner from releases
2. Install the application to /Applications
3. Launch and follow the setup wizard
4. Point to your GTA SA installation or let the installer download it
5. Play!

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/SAmacOS.git
cd SAmacOS

# Build the native launcher
cd MacLauncher
xcodebuild -scheme "SA-MP Runner" -configuration Release

# Install Wine dependencies
./scripts/install-wine.sh

# Setup DXVK
./scripts/setup-dxvk.sh

# Configure Wine prefix
./scripts/create-wineprefix.sh
```

## Performance Optimization

### For Apple Silicon (M1/M2/M3)

The application uses:
- **Rosetta 2** for Wine x86 translation
- **Metal API** for direct GPU access
- **DXVK** async shader compilation
- **esync/fsync** for reduced overhead
- **PBA (Performance Boost Audio)** for audio subsystem

Expected performance: **60+ FPS** at 1080p on M1 or later.

### For Intel Macs

- Uses native x86 Wine builds
- DXVK with Metal backend
- Optimized memory allocation

Expected performance: **45+ FPS** at 1080p on recent Intel chips.

## Project Structure

```
SAmacOS/
├── MacLauncher/              # Native macOS application (Swift)
│   ├── Sources/
│   │   ├── App/              # Main app entry point
│   │   ├── UI/               # User interface components
│   │   ├── Installer/        # Game installation logic
│   │   ├── WineManager/      # Wine process management
│   │   └── Performance/      # Optimization utilities
│   ├── Resources/            # Assets, icons, configs
│   └── SA-MP Runner.xcodeproj
│
├── WineEngine/               # Wine configuration and patches
│   ├── configs/              # Optimized Wine configs
│   ├── patches/              # Custom Wine patches
│   └── dlls/                 # Required DLLs
│
├── GameOptimizations/        # Performance tweaks
│   ├── dxvk/                 # DXVK configuration
│   ├── shaders/              # Shader cache
│   └── patches/              # Game patches for macOS
│
├── Installer/                # Installation scripts
│   ├── game-installer.sh
│   ├── samp-installer.sh
│   └── dependencies.sh
│
├── scripts/                  # Build and setup scripts
│   ├── build.sh
│   ├── install-wine.sh
│   ├── setup-dxvk.sh
│   └── create-wineprefix.sh
│
└── docs/                     # Documentation
    ├── ARCHITECTURE.md
    ├── PERFORMANCE.md
    └── TROUBLESHOOTING.md
```

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Launcher UI | Swift + AppKit | Native macOS interface |
| Wine Layer | Wine Crossover 23+ | Windows compatibility |
| Graphics | DXVK + MoltenVK | DirectX → Metal translation |
| Audio | PulseAudio + CoreAudio | Audio routing |
| Networking | Native BSD sockets | Network optimization |
| Packaging | DMG + Installer pkg | Distribution |

## Development

### Building from Source

```bash
# Prerequisites
xcode-select --install
brew install wine-crossover cmake ninja

# Clone and build
git clone https://github.com/yourusername/SAmacOS.git
cd SAmacOS

# Build native launcher
./scripts/build.sh

# Run in development mode
./scripts/run-dev.sh
```

### Testing

```bash
# Run unit tests
./scripts/test.sh

# Performance benchmark
./scripts/benchmark.sh
```

## Configuration

### Wine Configuration

Located in: `~/Library/Application Support/SA-MP Runner/wine/`

Key settings:
- `WINEPREFIX`: Isolated Wine environment
- `DXVK_HUD`: Performance overlay
- `DXVK_ASYNC`: Async shader compilation

### Game Settings

Located in: `~/Library/Application Support/SA-MP Runner/gta-sa/`

Automatic optimizations:
- Frame limiter disabled for maximum FPS
- Draw distance optimized for macOS
- Memory pool sizes adjusted
- Audio buffer tuning

## Troubleshooting

### Common Issues

**Game won't launch:**
- Check Wine installation: `./scripts/check-wine.sh`
- Verify GTA SA files are intact
- Check logs: `~/Library/Logs/SA-MP Runner/`

**Low FPS:**
- Enable DXVK async: `DXVK_ASYNC=1`
- Lower graphics settings in-game
- Check Activity Monitor for background processes

**Crashes:**
- Update to latest macOS
- Reinstall Wine engine
- Check crash logs in Console.app

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas needing help:
- Performance optimization
- macOS-specific bug fixes
- UI/UX improvements
- Documentation
- Testing on different Mac models

## Legal

This project does NOT include:
- GTA San Andreas game files
- SA-MP client files
- Any copyrighted materials

Users must own a legitimate copy of GTA San Andreas.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- Rockstar Games - GTA San Andreas
- SA-MP Team - San Andreas Multiplayer
- Wine Project - Compatibility layer
- DXVK Project - DirectX to Vulkan
- MoltenVK - Vulkan to Metal

## Support

- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/SAmacOS/issues)
- 💬 Discord: [SA-MP macOS Community](https://discord.gg/example)
- 📖 Wiki: [Documentation](https://github.com/yourusername/SAmacOS/wiki)

---

Made with ❤️ for the GTA SA macOS community
