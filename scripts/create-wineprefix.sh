#!/bin/bash

# Wine Prefix Creation Script
# Creates an optimized Wine prefix for GTA San Andreas

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WINE_ENGINE_DIR="$PROJECT_ROOT/WineEngine"

# Default Wine prefix location
WINEPREFIX="${WINEPREFIX:-$HOME/Library/Application Support/SA-MP Runner/wine}"

echo "🍷 Creating Wine prefix for SA-MP Runner..."
echo "Prefix location: $WINEPREFIX"

# Check if Wine is installed
if ! command -v wine &> /dev/null; then
    echo "❌ Wine not found. Please run ./scripts/install-wine.sh first"
    exit 1
fi

# Export Wine environment
export WINEPREFIX
export WINEARCH=win32  # 32-bit for GTA SA
export WINEDEBUG=-all  # Suppress debug output

# Remove existing prefix if requested
if [ -d "$WINEPREFIX" ]; then
    echo "⚠️  Wine prefix already exists"
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing prefix..."
        rm -rf "$WINEPREFIX"
    else
        echo "Keeping existing prefix"
        exit 0
    fi
fi

# Create Wine prefix
echo "📦 Creating Wine prefix (32-bit)..."
wineboot --init

# Wait for Wine to finish initialization
sleep 3

# Kill any remaining Wine processes
wineserver --wait

echo "✓ Wine prefix created"

# Install DXVK
if [ -x "$WINE_ENGINE_DIR/install-dxvk-to-prefix.sh" ]; then
    echo "🎮 Installing DXVK..."
    "$WINE_ENGINE_DIR/install-dxvk-to-prefix.sh" "$WINEPREFIX"
else
    echo "⚠️  DXVK installer not found. Run ./scripts/setup-dxvk.sh first"
fi

# Configure Wine registry
echo "⚙️  Configuring Wine registry..."

# Set Windows version to Windows 10
wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f

# DLL overrides for DXVK
wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v d3d9 /t REG_SZ /d native /f
wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v dxgi /t REG_SZ /d native /f
wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v d3d11 /t REG_SZ /d native /f

# DirectSound settings (audio optimization)
wine reg add "HKCU\\Software\\Wine\\DirectSound" /v HelBuflen /t REG_SZ /d "512" /f
wine reg add "HKCU\\Software\\Wine\\DirectSound" /v SndQueueMax /t REG_SZ /d "3" /f

# Disable Wine crash dialog
wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f

# Enable large address aware (allows 32-bit apps to use more RAM)
wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Windows" /v LargeAddressAware /t REG_DWORD /d 1 /f

echo "✓ Registry configured"

# Create GTA SA directory structure
echo "📁 Creating game directory structure..."
mkdir -p "$WINEPREFIX/drive_c/Program Files/Rockstar Games/GTA San Andreas"
echo "✓ Directory structure created"

# Copy DXVK config
if [ -f "$PROJECT_ROOT/GameOptimizations/dxvk/dxvk.conf" ]; then
    cp "$PROJECT_ROOT/GameOptimizations/dxvk/dxvk.conf" "$WINEPREFIX/dxvk.conf"
    echo "✓ DXVK config installed"
fi

# Kill Wine processes
wineserver --wait
wineserver --kill

echo ""
echo "✅ Wine prefix creation complete!"
echo ""
echo "Prefix details:"
echo "  Location: $WINEPREFIX"
echo "  Architecture: 32-bit (win32)"
echo "  Windows version: Windows 10"
echo "  DXVK: Installed"
echo ""
echo "Environment variables to use:"
echo "  export WINEPREFIX=\"$WINEPREFIX\""
echo "  export WINEARCH=win32"
echo "  export DXVK_HUD=fps"
echo "  export DXVK_ASYNC=1"
