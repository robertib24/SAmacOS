#!/bin/bash

# DXVK + MoltenVK Setup Script
# Installs and configures DXVK for DirectX to Metal translation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DXVK_DIR="$PROJECT_ROOT/GameOptimizations/dxvk"
WINE_ENGINE_DIR="$PROJECT_ROOT/WineEngine"

echo "🎮 Setting up DXVK for SA-MP Runner..."

# DXVK version
DXVK_VERSION="2.3.1"
DXVK_ASYNC_VERSION="2.3.1"

# Create directories
mkdir -p "$DXVK_DIR"
mkdir -p "$WINE_ENGINE_DIR/dlls/x32"
mkdir -p "$WINE_ENGINE_DIR/dlls/x64"

# Download DXVK async
echo "📥 Downloading DXVK async v$DXVK_ASYNC_VERSION..."

DXVK_URL="https://github.com/Sporif/dxvk-async/releases/download/$DXVK_ASYNC_VERSION/dxvk-async-$DXVK_ASYNC_VERSION.tar.gz"
TEMP_DIR=$(mktemp -d)

cd "$TEMP_DIR"

# Download
if command -v curl &> /dev/null; then
    curl -L -o dxvk.tar.gz "$DXVK_URL"
elif command -v wget &> /dev/null; then
    wget -O dxvk.tar.gz "$DXVK_URL"
else
    echo "❌ Neither curl nor wget found. Please install one."
    exit 1
fi

# Extract
echo "📦 Extracting DXVK..."
tar -xzf dxvk.tar.gz

# Copy DLLs
echo "📋 Copying DXVK DLLs..."

DXVK_EXTRACTED=$(find . -type d -name "dxvk-async-*" | head -n 1)

if [ -d "$DXVK_EXTRACTED/x32" ]; then
    cp "$DXVK_EXTRACTED/x32"/*.dll "$WINE_ENGINE_DIR/dlls/x32/"
    echo "  ✓ x32 DLLs copied"
fi

if [ -d "$DXVK_EXTRACTED/x64" ]; then
    cp "$DXVK_EXTRACTED/x64"/*.dll "$WINE_ENGINE_DIR/dlls/x64/"
    echo "  ✓ x64 DLLs copied"
fi

# Create DXVK config
echo "⚙️  Creating DXVK configuration..."

cat > "$DXVK_DIR/dxvk.conf" << 'EOF'
# DXVK Configuration for GTA San Andreas
# Optimized for macOS + Wine + Metal

# Enable async shader compilation (reduces stuttering)
dxvk.enableAsync = True

# Use all available CPU cores for shader compilation
dxvk.numCompilerThreads = 0

# Frame latency (lower = less input lag, but may reduce performance)
dxvk.maxFrameLatency = 1

# Device memory limit (MB) - adjust based on your GPU
# 4096 MB = 4 GB (good for most Macs)
# 8192 MB = 8 GB (for high-end Macs)
dxvk.maxDeviceMemory = 4096

# Enable graphics pipeline library (faster pipeline creation)
dxvk.enableGraphicsPipelineLibrary = Auto

# Use raw SSBO for better performance
dxvk.useRawSsbo = True

# Enable state cache (saves compiled shaders)
dxvk.enableStateCache = True

# State cache path will be set by launcher
# dxvk.enableStateCache = True

# HUD (fps counter, etc.)
# Set to "fps" for FPS only, "full" for all info, or "0" to disable
# Launcher will override this based on user preference
dxvk.hud = fps

# Graphics optimizations
dxvk.maxChunkSize = 128

# macOS specific: reduce overhead
dxvk.enableOpenVR = False
dxvk.enableNvapiHack = False
EOF

echo "  ✓ dxvk.conf created"

# Create MoltenVK config
echo "⚙️  Creating MoltenVK configuration..."

cat > "$DXVK_DIR/MoltenVK_icd.json" << 'EOF'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "./libMoltenVK.dylib",
        "api_version": "1.2.0"
    }
}
EOF

echo "  ✓ MoltenVK config created"

# Create installer script for Wine prefix
echo "📝 Creating DXVK installer script..."

cat > "$WINE_ENGINE_DIR/install-dxvk-to-prefix.sh" << 'EOF'
#!/bin/bash

# Install DXVK DLLs to a Wine prefix
# Usage: ./install-dxvk-to-prefix.sh [WINEPREFIX]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINEPREFIX="${1:-$HOME/Library/Application Support/SA-MP Runner/wine}"

echo "Installing DXVK to Wine prefix: $WINEPREFIX"

# Detect architecture of Wine prefix
if [ -f "$WINEPREFIX/system.reg" ]; then
    if grep -q "win64" "$WINEPREFIX/system.reg"; then
        ARCH="x64"
    else
        ARCH="x32"
    fi
else
    # Default to 32-bit for GTA SA
    ARCH="x32"
fi

echo "Prefix architecture: $ARCH"

# Copy DLLs
SYSTEM32="$WINEPREFIX/drive_c/windows/system32"
mkdir -p "$SYSTEM32"

if [ "$ARCH" = "x32" ]; then
    echo "Copying 32-bit DXVK DLLs..."
    cp "$SCRIPT_DIR/dlls/x32"/*.dll "$SYSTEM32/"
else
    echo "Copying 64-bit DXVK DLLs..."
    cp "$SCRIPT_DIR/dlls/x64"/*.dll "$SYSTEM32/"
fi

echo "✓ DXVK installed to Wine prefix"
echo ""
echo "Note: DLL overrides will be set by the launcher"
EOF

chmod +x "$WINE_ENGINE_DIR/install-dxvk-to-prefix.sh"

# Cleanup
cd "$PROJECT_ROOT"
rm -rf "$TEMP_DIR"

echo "✅ DXVK setup complete!"
echo ""
echo "Files created:"
echo "  - $WINE_ENGINE_DIR/dlls/x32/*.dll"
echo "  - $WINE_ENGINE_DIR/dlls/x64/*.dll"
echo "  - $DXVK_DIR/dxvk.conf"
echo "  - $WINE_ENGINE_DIR/install-dxvk-to-prefix.sh"
echo ""
echo "Next steps:"
echo "  Run ./scripts/create-wineprefix.sh to create a Wine prefix with DXVK"
