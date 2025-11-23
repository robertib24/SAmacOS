# Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### "Wine not found"

**Problem:** Launcher cannot find Wine installation

**Solution:**
```bash
# Install Wine via Homebrew
brew install --cask wine-stable

# Or run the installer script
./scripts/install-wine.sh
```

#### "Failed to create Wine prefix"

**Problem:** Wine prefix creation fails

**Solutions:**
1. Check disk space (need 2GB+)
2. Remove existing prefix:
   ```bash
   rm -rf ~/Library/Application\ Support/SA-MP\ Runner/wine
   ```
3. Run creation script manually:
   ```bash
   ./scripts/create-wineprefix.sh
   ```

#### "DXVK installation failed"

**Problem:** DXVK DLLs not installing

**Solution:**
```bash
# Re-run DXVK setup
./scripts/setup-dxvk.sh

# Manual installation
./WineEngine/install-dxvk-to-prefix.sh
```

### Launch Issues

#### "Game won't start"

**Checklist:**
1. Is GTA SA installed?
2. Is Wine prefix created?
3. Are all required files present?

**Debug:**
```bash
# Check Wine status
export WINEPREFIX=~/Library/Application\ Support/SA-MP\ Runner/wine
wine --version

# Test Wine
wine notepad

# Check logs
tail -f ~/Library/Application\ Support/SA-MP\ Runner/logs/wine_game.log
```

#### "Black screen on launch"

**Causes:**
- Graphics driver issue
- DXVK not loading
- Wrong DLL overrides

**Solutions:**
```bash
# Disable DXVK temporarily
wine reg delete "HKCU\\Software\\Wine\\DllOverrides" /v d3d9 /f

# Use WineD3D instead
# (Will be slower but more compatible)

# Or reinstall DXVK
./scripts/setup-dxvk.sh
./WineEngine/install-dxvk-to-prefix.sh
```

#### "Crash on startup"

**Check logs:**
```bash
cat ~/Library/Application\ Support/SA-MP\ Runner/logs/launcher.log
cat ~/Library/Application\ Support/SA-MP\ Runner/logs/wine_game.log
```

**Common fixes:**
1. Update macOS
2. Update Wine
3. Reinstall game
4. Remove mods

### Performance Issues

#### "Low FPS (< 30)"

**Solutions:**
1. Lower graphics settings (Settings panel → Low preset)
2. Close background applications
3. Disable VSync and frame limiter
4. Check if discrete GPU is being used (if available)

**Check GPU usage:**
```bash
sudo powermetrics --samplers gpu_power -i 1000
```

#### "Stuttering / Lag spikes"

**Causes:**
- Shader compilation (normal on first run)
- Disk I/O (HDD)
- Insufficient RAM
- Background processes

**Solutions:**
1. Wait 10-15 minutes for shader cache to build
2. Close Chrome/Firefox/Electron apps
3. Move game to SSD
4. Enable DXVK async:
   ```bash
   export DXVK_ASYNC=1
   ```

#### "Mouse lag / Input delay"

**Solutions:**
```bash
# Disable macOS mouse acceleration
defaults write .GlobalPreferences com.apple.mouse.scaling -1

# Reduce frame latency in DXVK config
# Edit: ~/Library/Application Support/SA-MP Runner/dxvk_cache/dxvk.conf
# Set: dxvk.maxFrameLatency = 1
```

### Graphics Issues

#### "Graphics glitches / Artifacts"

**Causes:**
- DXVK shader cache corruption
- GPU driver issue
- Mod conflicts

**Solutions:**
```bash
# Clear shader cache
rm -rf ~/Library/Application\ Support/SA-MP\ Runner/dxvk_cache/*

# Restart game (shaders will rebuild)

# Or use Settings → Clear Shader Cache
```

#### "Wrong resolution / Stretched screen"

**Fix:**
```bash
# Edit game settings
# File: ~/Library/Application Support/SA-MP Runner/wine/drive_c/Program Files/Rockstar Games/GTA San Andreas/gta_sa.set

[Display]
Width=1920   # Your screen width
Height=1080  # Your screen height
Windowed=0
```

#### "No fullscreen"

**Solution:**
- Game runs in borderless window by default on macOS
- This is normal and provides best alt-tab experience
- True fullscreen not recommended with Wine

### Audio Issues

#### "No sound"

**Checks:**
1. macOS volume not muted
2. Wine audio configured correctly

**Solutions:**
```bash
# Test Wine audio
wine winecfg
# Go to Audio tab → Test Sound

# Check audio devices
wine reg query "HKCU\\Software\\Wine\\Drivers"

# Reset audio driver
wine reg add "HKCU\\Software\\Wine\\Drivers" /v Audio /t REG_SZ /d "coreaudio" /f
```

#### "Audio crackling / Distortion"

**Solution:**
```bash
# Increase audio buffer
wine reg add "HKCU\\Software\\Wine\\DirectSound" /v HelBuflen /t REG_SZ /d "1024" /f
wine reg add "HKCU\\Software\\Wine\\DirectSound" /v SndQueueMax /t REG_SZ /d "5" /f
```

### Network Issues (SA-MP)

#### "Can't connect to servers"

**Checks:**
1. Internet connection working
2. Firewall not blocking Wine
3. SA-MP version matches server

**Solutions:**
```bash
# Allow Wine through firewall
# System Preferences → Security & Privacy → Firewall → Firewall Options
# Add "wine" and "wineserver"

# Test connection
ping server-ip

# Check SA-MP version
cat ~/Library/Application\ Support/SA-MP\ Runner/wine/drive_c/Program\ Files/Rockstar\ Games/GTA\ San\ Andreas/samp/VERSION
```

#### "High ping / Lag"

**Optimizations:**
```bash
# Flush DNS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Use better DNS servers
networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1  # Cloudflare
# or
networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4  # Google

# Check ping
ping -c 10 server-ip
```

### Mod Issues

#### "Mods not loading"

**Checklist:**
1. Mods in correct directory?
2. CLEO installed (for CLEO mods)?
3. Mod compatible with Wine?

**Directories:**
```
CLEO mods: ~/Library/Application Support/SA-MP Runner/wine/drive_c/Program Files/Rockstar Games/GTA San Andreas/CLEO/
Textures: ~/Library/Application Support/SA-MP Runner/wine/drive_c/Program Files/Rockstar Games/GTA San Andreas/modloader/
```

#### "Game crashes with mods"

**Debug:**
1. Remove all mods
2. Add mods one by one
3. Identify problematic mod
4. Check mod compatibility with Wine

**Some mods may not work with Wine!**

### macOS-Specific Issues

#### "Rosetta 2 not installed" (Apple Silicon)

**Solution:**
```bash
# Install Rosetta 2
softwareupdate --install-rosetta
```

#### "App won't open - Security warning"

**Solution:**
```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine /Applications/SA-MP\ Runner.app

# Or: System Preferences → Security & Privacy → Open Anyway
```

#### "Gatekeeper blocking"

**Solution:**
```bash
# Disable Gatekeeper for this app
sudo spctl --add /Applications/SA-MP\ Runner.app
sudo xattr -rd com.apple.quarantine /Applications/SA-MP\ Runner.app
```

### Wine Issues

#### "wineserver using 100% CPU"

**Solution:**
```bash
# Kill all Wine processes
wineserver --kill

# Restart launcher
```

#### "Wine prefix corrupted"

**Nuclear option - Recreate prefix:**
```bash
# Backup saves first!
cp -R ~/Library/Application\ Support/SA-MP\ Runner/wine/drive_c/Users/*/Documents/GTA\ San\ Andreas\ User\ Files ~/Desktop/gta_saves

# Remove prefix
rm -rf ~/Library/Application\ Support/SA-MP\ Runner/wine

# Recreate
./scripts/create-wineprefix.sh

# Reinstall game through launcher
```

## Advanced Debugging

### Enable Debug Logging

```bash
# Wine debug output
export WINEDEBUG=+all

# DXVK debug
export DXVK_LOG_LEVEL=debug

# MoltenVK debug
export MVK_DEBUG=1

# Run game
# Logs will be very verbose!
```

### Collect System Information

```bash
# Create debug report
echo "=== System Info ===" > ~/Desktop/samp_debug.txt
system_profiler SPHardwareDataType >> ~/Desktop/samp_debug.txt
echo "\n=== macOS Version ===" >> ~/Desktop/samp_debug.txt
sw_vers >> ~/Desktop/samp_debug.txt
echo "\n=== Wine Version ===" >> ~/Desktop/samp_debug.txt
wine --version >> ~/Desktop/samp_debug.txt
echo "\n=== DXVK Files ===" >> ~/Desktop/samp_debug.txt
ls -la ~/Library/Application\ Support/SA-MP\ Runner/wine/drive_c/windows/system32/d3d9.dll >> ~/Desktop/samp_debug.txt
echo "\n=== Recent Logs ===" >> ~/Desktop/samp_debug.txt
tail -100 ~/Library/Application\ Support/SA-MP\ Runner/logs/launcher.log >> ~/Desktop/samp_debug.txt
```

### Check File Integrity

```bash
# Verify GTA SA files
cd ~/Library/Application\ Support/SA-MP\ Runner/wine/drive_c/Program\ Files/Rockstar\ Games/GTA\ San\ Andreas

# Required files:
ls -lh gta_sa.exe
ls -lh data/gta3.img
ls -lh models/gta3.img

# SA-MP files:
ls -lh samp.exe
ls -lh samp.dll
```

## Getting More Help

If issues persist:

1. **Check logs:**
   ```bash
   ~/Library/Application Support/SA-MP Runner/logs/
   ```

2. **Create issue on GitHub with:**
   - Mac model and specs
   - macOS version (`sw_vers`)
   - Wine version (`wine --version`)
   - Exact error message
   - Steps to reproduce
   - Log files

3. **Community forums:**
   - SA-MP forums
   - Wine macOS community
   - Reddit: r/wine_gaming

## Known Limitations

### What Works:
✅ Single player
✅ Multiplayer (SA-MP)
✅ Most mods (CLEO, texture, car mods)
✅ Controllers (partial support)
✅ Saves/load

### What Doesn't Work Well:
❌ Some CLEO mods requiring Windows APIs
❌ Mods using .NET or C# scripts
❌ DirectInput controllers (use remapping tools)
❌ Some advanced shaders (ENB)

### Workarounds:
- **ENB**: Use ReShade instead (better Wine compatibility)
- **Controllers**: Use Controllermate or enjoyable.app for mapping
- **.NET mods**: Not supported - choose Lua/CLEO alternatives

---

## Quick Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| Won't launch | `./scripts/create-wineprefix.sh` |
| Low FPS | Lower settings to "Low" preset |
| No sound | Check macOS volume, test in `wine winecfg` |
| Stuttering | Wait for shader cache, enable DXVK async |
| Graphics glitches | Clear shader cache |
| High CPU | `wineserver --kill` |
| Can't connect | Check firewall, allow Wine |
| Crashes | Remove mods, reinstall |

---

**Still stuck? Open an issue with logs and system info!**
