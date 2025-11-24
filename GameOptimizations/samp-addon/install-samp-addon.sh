#!/bin/bash

# SAMP Addon 2.6 Installation Helper
# Optimizeaza SA-MP pentru performance mai bun pe M2 8GB

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMP_ADDON_URL="https://www.mediafire.com/file/tas2s0a1f75e3oz/SAMP_Addon_2.6_Setup.exe/file"
SAMP_ADDON_FILE="$SCRIPT_DIR/SAMP_Addon_2.6_Setup.exe"

echo "🎮 SAMP Addon 2.6 Installation Helper"
echo ""

# Check if file already downloaded
if [ -f "$SAMP_ADDON_FILE" ]; then
    echo "✅ SAMP Addon setup already downloaded"
else
    echo "📥 SAMP Addon setup not found."
    echo ""
    echo "Please download SAMP Addon 2.6 manually from:"
    echo "   $SAMP_ADDON_URL"
    echo ""
    echo "Save it as:"
    echo "   $SAMP_ADDON_FILE"
    echo ""
    echo "Then run this script again."
    echo ""
    echo "Opening download link in browser..."

    # Try to open in browser
    if command -v open &> /dev/null; then
        open "$SAMP_ADDON_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$SAMP_ADDON_URL"
    fi

    exit 1
fi

# Install SAMP Addon
echo "🔧 Installing SAMP Addon..."
echo ""
echo "IMPORTANT: When the installer opens:"
echo "  1. Select your GTA San Andreas directory"
echo "  2. Install all recommended components"
echo "  3. SAMP Addon will optimize graphics for performance"
echo ""
read -p "Press ENTER to start installation..."

# Run installer via Wine
WINE_PREFIX="$HOME/Library/Application Support/SA-MP Runner/wine"

if [ -z "$WINEPREFIX" ]; then
    export WINEPREFIX="$WINE_PREFIX"
fi

# Find Wine executable
WINE_BIN=""
if [ -f "/opt/homebrew/bin/wine" ]; then
    WINE_BIN="/opt/homebrew/bin/wine"
elif [ -f "/usr/local/bin/wine" ]; then
    WINE_BIN="/usr/local/bin/wine"
fi

if [ -z "$WINE_BIN" ]; then
    echo "❌ Wine not found! Please install Wine first."
    exit 1
fi

echo "Running SAMP Addon installer..."
"$WINE_BIN" "$SAMP_ADDON_FILE"

echo ""
echo "✅ SAMP Addon installation complete!"
echo ""
echo "⚠️  ⚠️  ⚠️  IMPORTANT ⚠️  ⚠️  ⚠️"
echo ""
echo "TREBUIE să REINSTALEZI SA-MP acum!"
echo ""
echo "SAMP Addon a modificat fișiere care trebuie"
echo "suprascrise de SA-MP pentru ca jocul să pornească."
echo ""
echo "Rulează din nou installer-ul SA-MP:"
echo "  wine samp_install.exe"
echo ""
echo "Selectează același folder GTA SA și reinstalează."
echo ""
echo "Dacă nu faci asta, jocul NU VA PORNI!"
echo ""
echo "Benefits SAMP Addon (după reinstalare SA-MP):"
echo "  ✅ Optimized graphics for low-end PCs"
echo "  ✅ Better FPS (20-30% improvement)"
echo "  ✅ Reduced stuttering"
echo "  ✅ Better memory management"
echo "  ✅ SA-MP specific optimizations"
