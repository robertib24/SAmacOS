#!/bin/bash

# Wine Installation Script for SA-MP Runner
# Installs Wine Crossover or Wine Staging with optimizations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WINE_DIR="$PROJECT_ROOT/MacLauncher/Resources/wine"

echo "🍷 Installing Wine for SA-MP Runner..."

# Detect architecture
ARCH=$(uname -m)
echo "Architecture: $ARCH"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install Wine dependencies
echo "📦 Installing Wine dependencies..."
brew install --formula cmake ninja meson

# Install Wine
if [ "$ARCH" = "arm64" ]; then
    echo "🍎 Installing Wine for Apple Silicon..."

    # For Apple Silicon, use Wine Crossover or Game Porting Toolkit
    # For now, we'll use Wine Crossover from Homebrew

    # Add wine tap if not already added
    brew tap homebrew/cask-versions 2>/dev/null || true

    # Install Wine Staging (has better game support)
    if ! brew list wine-staging &> /dev/null; then
        echo "Installing Wine Staging..."
        brew install --cask wine-staging || brew install wine-stable
    fi

else
    echo "💻 Installing Wine for Intel..."

    # Intel: use regular Wine
    if ! brew list wine-stable &> /dev/null; then
        brew install --cask wine-stable
    fi
fi

# Get Wine installation path
WINE_PATH=$(which wine)
WINE_VERSION=$(wine --version)

echo "✓ Wine installed: $WINE_VERSION"
echo "✓ Wine path: $WINE_PATH"

# Create symlink in Resources
echo "Creating Wine symlink in app bundle..."
mkdir -p "$WINE_DIR"

# Get the Wine prefix from Homebrew
HOMEBREW_WINE="/usr/local/bin/wine"
if [ "$ARCH" = "arm64" ]; then
    HOMEBREW_WINE="/opt/homebrew/bin/wine"
fi

# Create bin directory and symlink
mkdir -p "$WINE_DIR/bin"
ln -sf "$HOMEBREW_WINE" "$WINE_DIR/bin/wine" 2>/dev/null || true
ln -sf "$(dirname $HOMEBREW_WINE)/wineserver" "$WINE_DIR/bin/wineserver" 2>/dev/null || true
ln -sf "$(dirname $HOMEBREW_WINE)/wine64" "$WINE_DIR/bin/wine64" 2>/dev/null || true

echo "✅ Wine installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run ./scripts/setup-dxvk.sh to install DXVK"
echo "  2. Run ./scripts/create-wineprefix.sh to create the Wine environment"
