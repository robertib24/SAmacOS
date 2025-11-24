#!/bin/bash

# DXVK + MoltenVK Setup Script
# Installs and configures DXVK for DirectX to Metal translation
# Optimized for M2 8GB RAM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DXVK_DIR="$PROJECT_ROOT/GameOptimizations/dxvk"
WINE_ENGINE_DIR="$PROJECT_ROOT/WineEngine"

echo "🎮 Setting up DXVK for SA-MP Runner (M2 8GB optimized)..."

# DXVK version - 2.3 is more stable on macOS
DXVK_VERSION="2.3"

# Create directories
mkdir -p "$DXVK_DIR"
mkdir -p "$WINE_ENGINE_DIR/dlls/x32"
mkdir -p "$WINE_ENGINE_DIR/dlls/x64"

# Download DXVK 2.3
echo "📥 Downloading DXVK v$DXVK_VERSION..."

DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VERSION/dxvk-$DXVK_VERSION.tar.gz"
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

DXVK_EXTRACTED=$(find . -type d -name "dxvk-*" | head -n 1)

if [ -d "$DXVK_EXTRACTED/x32" ]; then
    cp "$DXVK_EXTRACTED/x32"/*.dll "$WINE_ENGINE_DIR/dlls/x32/"
    echo "  ✓ x32 DLLs copied"
fi

if [ -d "$DXVK_EXTRACTED/x64" ]; then
    cp "$DXVK_EXTRACTED/x64"/*.dll "$WINE_ENGINE_DIR/dlls/x64/"
    echo "  ✓ x64 DLLs copied"
fi

# Create DXVK config optimized for M2 8GB
echo "⚙️  Creating DXVK configuration (M2 8GB optimized)..."

cat > "$DXVK_DIR/dxvk.conf" << 'EOF'
# DXVK Configuration for GTA San Andreas
# Optimized for MacBook Pro M2 8GB RAM

# Async shader compilation (reduces stuttering)
dxvk.enableAsync = True

# Compiler threads - 4 for M2 (4 P-cores)
dxvk.numCompilerThreads = 4

# Frame latency - low for less input lag
dxvk.maxFrameLatency = 1

# Device memory - 2GB for M2 8GB (conservative)
# M2 8GB: Don't allocate too much or system will swap
dxvk.maxDeviceMemory = 2048

# Graphics pipeline library
dxvk.enableGraphicsPipelineLibrary = Auto

# Use raw SSBO for better performance
dxvk.useRawSsbo = True

# Enable state cache (saves compiled shaders)
dxvk.enableStateCache = True

# HUD - disable for performance
dxvk.hud = 0

# Graphics optimizations
dxvk.maxChunkSize = 64

# macOS specific: reduce overhead
dxvk.enableOpenVR = False
dxvk.enableNvapiHack = False

# M2 8GB: Conservative memory management
d3d9.maxFrameLatency = 1
d3d9.numBackBuffers = 2
d3d9.presentInterval = 0
EOF

echo "  ✓ dxvk.conf created (M2 optimized)"

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
echo "  - $DXVK_DIR/dxvk.conf (M2 8GB optimized)"
echo "  - $WINE_ENGINE_DIR/install-dxvk-to-prefix.sh"
echo ""
echo "M2 8GB Optimizations applied:"
echo "  ✓ VRAM limit: 2GB (prevents swapping)"
echo "  ✓ Compiler threads: 4 (matches P-cores)"
echo "  ✓ Frame latency: 1 (low input lag)"
echo "  ✓ Async shaders: Enabled"
echo ""
echo "Next: Launcher will try DXVK first, fallback to WineD3D if fails"
