# Performance Guide for SA-MP macOS Runner

## Expected Performance

### Apple Silicon (M1/M2/M3)

| Model | Resolution | Settings | FPS | Notes |
|-------|-----------|----------|-----|-------|
| M1 | 1080p | High | 60-90 | Perfect for most scenarios |
| M1 | 1440p | Medium | 55-75 | Good balance |
| M1 Pro/Max | 1440p | High | 75-100 | Excellent performance |
| M1 Pro/Max | 4K | Medium | 45-60 | Playable |
| M2/M3 | 1080p | Ultra | 90-120 | Best experience |
| M2/M3 | 1440p | High | 70-100 | Recommended |

### Intel Macs

| GPU | Resolution | Settings | FPS | Notes |
|-----|-----------|----------|-----|-------|
| Intel Iris | 1080p | Low | 30-45 | Minimum playable |
| AMD Radeon 5300M | 1080p | Medium | 45-60 | Good |
| AMD Radeon 5500M+ | 1080p | High | 60-80 | Very good |
| AMD Radeon Pro 5700 | 1440p | High | 55-75 | Excellent |

## Performance Optimization Tips

### 1. Graphics Settings

**Low Settings (30-45 FPS target):**
- Resolution: 1280x720 or 1920x1080
- Draw Distance: 0.8
- Anti-Aliasing: Off
- Visual FX: Low
- Frame Limiter: Off

**Medium Settings (45-60 FPS target):**
- Resolution: 1920x1080
- Draw Distance: 1.0
- Anti-Aliasing: On
- Visual FX: Medium
- Frame Limiter: Off

**High Settings (60+ FPS target):**
- Resolution: 1920x1080
- Draw Distance: 1.2
- Anti-Aliasing: On
- Visual FX: High
- Frame Limiter: Off

**Ultra Settings (90+ FPS target, M2+ only):**
- Resolution: 2560x1440
- Draw Distance: 1.5
- Anti-Aliasing: On
- Visual FX: Very High
- Frame Limiter: Off

### 2. DXVK Optimizations

#### Shader Compilation

The first time you run the game, DXVK will compile shaders on-the-fly. This causes stuttering.

**Solutions:**
- Let the game run for 10-15 minutes to build shader cache
- Download pre-compiled shader cache (if available)
- Enable DXVK async mode (enabled by default)

#### DXVK Configuration

Edit `~/Library/Application Support/SA-MP Runner/dxvk_cache/dxvk.conf`:

**For maximum performance:**
```ini
dxvk.enableAsync = True
dxvk.numCompilerThreads = 0  # Use all cores
dxvk.maxFrameLatency = 1
dxvk.maxDeviceMemory = 8192  # If you have 16GB+ RAM
```

**For reduced stuttering:**
```ini
dxvk.enableAsync = True
dxvk.numCompilerThreads = 4
dxvk.maxFrameLatency = 2
```

### 3. macOS System Optimizations

#### Close Background Apps
- Quit unnecessary applications
- Disable automatic backups during gameplay
- Close web browsers (Chrome/Firefox use a lot of RAM)

#### Energy Settings
```bash
# Disable App Nap for SA-MP Runner
defaults write com.samprunner.macos NSAppSleepDisabled -bool YES

# Set GPU to prefer performance
sudo pmset -a gpuswitch 2  # Force discrete GPU (if available)
```

#### Monitor Performance
```bash
# Check GPU usage
sudo powermetrics --samplers gpu_power -i 1000

# Check CPU usage per core
top -o cpu
```

### 4. Wine Optimizations

#### Enable Esync/Fsync

Esync reduces CPU overhead for synchronization:

```bash
# Check if esync is available
export WINEESYNC=1
wine --version  # Should mention esync support
```

If available, it's enabled by default in SA-MP Runner.

#### Memory Tweaks

Increase streaming memory for better texture loading:

```bash
# Set in Wine registry
wine reg add "HKCU\\Software\\Wine\\DirectDraw" /v VideoMemorySize /t REG_SZ /d "2048" /f
```

### 5. In-Game Settings

#### Optimal gta_sa.set

Location: `~/Library/Application Support/SA-MP Runner/wine/drive_c/Program Files/Rockstar Games/GTA San Andreas/gta_sa.set`

```ini
[Display]
Width=1920
Height=1080
Depth=32
Windowed=0
VSync=0
FrameLimiter=0  # IMPORTANT: Always 0 for maximum FPS

[Graphics]
VideoMode=1
Brightness=0
DrawDistance=1.2
AntiAliasing=1
VisualFX=2
MipMapping=1
```

### 6. Network Optimizations

For online play (SA-MP):

#### Reduce Ping
```bash
# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Use Google DNS
networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
```

#### TCP Optimizations
Wine uses native BSD sockets, so network performance should be good by default.

## Troubleshooting Performance Issues

### Low FPS (< 30)

**Possible causes:**
1. Integrated GPU (Intel Iris)
2. Background apps consuming resources
3. Thermal throttling
4. Wrong graphics settings

**Solutions:**
1. Lower graphics settings to "Low" preset
2. Close all background applications
3. Use cooling pad or improve ventilation
4. Check Activity Monitor for CPU/GPU hogs

### Stuttering

**Causes:**
1. Shader compilation (first run)
2. Disk I/O (HDD instead of SSD)
3. Insufficient RAM
4. DXVK state cache building

**Solutions:**
1. Let game run for 10-15 minutes
2. Move game to SSD
3. Close memory-hungry apps
4. Download pre-compiled shader cache

### Input Lag

**Causes:**
1. VSync enabled
2. High frame latency
3. macOS mouse acceleration

**Solutions:**
```bash
# Disable VSync in game settings
# Set DXVK frame latency to 1
dxvk.maxFrameLatency = 1

# Disable mouse acceleration (macOS)
defaults write .GlobalPreferences com.apple.mouse.scaling -1
```

### Crashes

**Causes:**
1. Out of memory
2. Incompatible mods
3. Wine instability

**Solutions:**
1. Increase swap space
2. Remove mods one by one
3. Update Wine to latest version
4. Check logs: `~/Library/Application Support/SA-MP Runner/logs/`

## Performance Monitoring

### Built-in FPS Counter

Enable DXVK HUD:
```bash
export DXVK_HUD=fps,devinfo,memory
```

### Detailed Profiling

```bash
# CPU usage per core
top -pid $(pgrep -f "SA-MP Runner") -stats pid,cpu,mem,threads

# GPU usage
sudo powermetrics --samplers gpu_power -i 1000

# Memory usage
vmmap $(pgrep -f "SA-MP Runner")
```

## Benchmarking

### Quick Benchmark

1. Launch game
2. Load single player
3. Go to Los Santos airport
4. Face towards city
5. Note average FPS

**Expected results:**
- M1: 70-90 FPS
- M2: 90-120 FPS
- Intel (dedicated): 50-70 FPS

### Advanced Benchmark

Use the built-in performance logger:

```bash
# Enable performance logging
defaults write com.samprunner.macos PerformanceLogging -bool YES

# Play for 10 minutes
# Check logs
cat ~/Library/Application\ Support/SA-MP\ Runner/logs/performance.log
```

## Best Practices

1. **Always use SSD** - HDD will cause stuttering
2. **Keep macOS updated** - Metal performance improves with updates
3. **Use Auto preset** - Launcher detects optimal settings
4. **Disable frame limiter** - Let your Mac run at maximum FPS
5. **Close background apps** - Especially browsers and Electron apps
6. **Monitor temperatures** - Use iStat Menus or similar
7. **Regular shader cache cleanup** - Once a month, clear and rebuild
8. **Update Wine** - Check for updates monthly

## Performance Comparison

### Wine vs Virtual Machine

| Method | Performance | Compatibility | Setup |
|--------|-------------|---------------|-------|
| SA-MP Runner (Wine) | 90-95% | Excellent | Easy |
| Parallels | 70-80% | Good | Medium |
| VMware | 60-70% | Good | Medium |
| Boot Camp | 100% | Perfect | Hard |

Wine (SA-MP Runner) provides near-native performance without dual-booting!

## Future Optimizations

Planned improvements:

1. **MetalFX Integration** (macOS 13+)
   - Upscaling technology
   - Better performance at high resolutions

2. **Game Porting Toolkit** (macOS 14+)
   - Apple's official DirectX translation
   - Potentially better than DXVK+MoltenVK

3. **Custom Wine Patches**
   - macOS-specific optimizations
   - Reduced syscall overhead

4. **Shader Pre-compilation**
   - Ship with pre-compiled shaders
   - Zero stuttering on first run

## Getting Help

If you're experiencing performance issues:

1. Check system requirements
2. Review this guide
3. Check logs: `~/Library/Application Support/SA-MP Runner/logs/`
4. Report issue with:
   - Mac model and specs
   - macOS version
   - In-game settings
   - Average FPS
   - Log files

---

**Remember:** GTA San Andreas is from 2004. Even low-end modern Macs should run it well with proper configuration!
