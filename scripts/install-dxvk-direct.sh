#!/bin/bash

# Direct DXVK Installer - Downloads and installs DXVK to game folder
# Bypass GitHub API issues by using direct download links

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🎮 DXVK Direct Installer for SA-MP (M2 8GB optimized)"
echo ""

# DXVK version
DXVK_VERSION="2.4.1"
echo "📥 Downloading DXVK v$DXVK_VERSION..."
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Direct download link (no GitHub API redirect issues)
# Using archive.org mirror for reliability
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"

echo "Downloading from: $DXVK_URL"
echo ""

# Download with retry
MAX_RETRIES=3
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -L --fail --max-time 60 -o dxvk.tar.gz "$DXVK_URL" 2>/dev/null; then
        echo "✓ Download successful"
        break
    else
        RETRY=$((RETRY + 1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo "⚠️  Download failed, retrying ($RETRY/$MAX_RETRIES)..."
            sleep 2
        else
            echo "❌ Download failed after $MAX_RETRIES attempts"
            echo ""
            echo "Alternative: Download manually from:"
            echo "https://github.com/doitsujin/dxvk/releases"
            echo ""
            echo "Then extract d3d9.dll and dxgi.dll from x32 folder to:"
            echo "\$GAME_DIR/"
            exit 1
        fi
    fi
done

# Extract
echo "📦 Extracting DXVK..."
tar -xzf dxvk.tar.gz

# Find extracted folder
DXVK_EXTRACTED=$(find . -type d -name "dxvk-*" -maxdepth 1 | head -n 1)

if [ -z "$DXVK_EXTRACTED" ]; then
    echo "❌ Failed to find extracted DXVK folder"
    exit 1
fi

echo "✓ Extracted to: $DXVK_EXTRACTED"
echo ""

# Copy to WineEngine (for future automatic installs)
echo "📋 Installing DXVK to WineEngine..."
WINE_ENGINE_DIR="$PROJECT_ROOT/WineEngine/dlls"
mkdir -p "$WINE_ENGINE_DIR/x32"
mkdir -p "$WINE_ENGINE_DIR/x64"

if [ -d "$DXVK_EXTRACTED/x32" ]; then
    cp "$DXVK_EXTRACTED/x32"/*.dll "$WINE_ENGINE_DIR/x32/" 2>/dev/null || true
    DLL_COUNT=$(ls "$WINE_ENGINE_DIR/x32"/*.dll 2>/dev/null | wc -l)
    echo "  ✓ Installed $DLL_COUNT x32 DLLs to WineEngine"
fi

if [ -d "$DXVK_EXTRACTED/x64" ]; then
    cp "$DXVK_EXTRACTED/x64"/*.dll "$WINE_ENGINE_DIR/x64/" 2>/dev/null || true
    DLL_COUNT=$(ls "$WINE_ENGINE_DIR/x64"/*.dll 2>/dev/null | wc -l)
    echo "  ✓ Installed $DLL_COUNT x64 DLLs to WineEngine"
fi

# Create DXVK config for M2 8GB
echo ""
echo "⚙️  Creating DXVK configuration..."

DXVK_DIR="$PROJECT_ROOT/GameOptimizations/dxvk"
mkdir -p "$DXVK_DIR"

cat > "$DXVK_DIR/dxvk.conf" << 'EOF'
# DXVK Configuration - GTA San Andreas on M2 8GB
dxvk.enableAsync = True
dxvk.numCompilerThreads = 4
dxvk.maxFrameLatency = 1
dxvk.maxDeviceMemory = 2048
dxvk.enableStateCache = True
dxvk.hud = 0
d3d9.maxFrameLatency = 1
d3d9.numBackBuffers = 2
d3d9.presentInterval = 0
EOF

echo "  ✓ dxvk.conf created (M2 optimized)"

# Cleanup
cd "$PROJECT_ROOT"
rm -rf "$TEMP_DIR"

echo ""
echo "✅ DXVK Installation Complete!"
echo ""
echo "Files installed:"
echo "  - WineEngine/dlls/x32/*.dll (for automatic Wine prefix install)"
echo "  - GameOptimizations/dxvk/dxvk.conf (M2 8GB config)"
echo ""
echo "M2 8GB Optimizations:"
echo "  ✓ VRAM: 2GB (prevents system swapping)"
echo "  ✓ Compiler threads: 4 (P-cores)"
echo "  ✓ Frame latency: 1 (low input lag)"
echo "  ✓ Async shaders: Enabled"
echo ""
echo "Next steps:"
echo "  1. Rebuild launcher: cd MacLauncher && xcodebuild"
echo "  2. Launch game - DXVK will install automatically!"
echo ""
