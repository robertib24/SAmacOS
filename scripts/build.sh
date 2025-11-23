#!/bin/bash

# Build Script for SA-MP Runner
# Builds the macOS application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAC_LAUNCHER_DIR="$PROJECT_ROOT/MacLauncher"
BUILD_DIR="$PROJECT_ROOT/build"

echo "🔨 Building SA-MP Runner..."

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not found. Please install Xcode Command Line Tools."
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n 1)
echo "Swift version: $SWIFT_VERSION"

# Create build directory
mkdir -p "$BUILD_DIR"

# Build using Swift Package Manager
echo "📦 Building with Swift Package Manager..."
cd "$MAC_LAUNCHER_DIR"

# Clean previous build
swift package clean

# Detect platform architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo "Building for Apple Silicon (arm64)..."
    BUILD_ARCH="arm64"
else
    echo "Building for Intel (x86_64)..."
    BUILD_ARCH="x86_64"
fi

# Build in release mode with proper architecture
swift build -c release --arch "$BUILD_ARCH"

# Get build output location
BUILD_OUTPUT=$(swift build -c release --arch "$BUILD_ARCH" --show-bin-path)

echo "✓ Build complete"
echo "Binary location: $BUILD_OUTPUT/SAMPRunner"

# Create application bundle
echo "📱 Creating application bundle..."

APP_NAME="SA-MP Runner.app"
APP_PATH="$BUILD_DIR/$APP_NAME"

# Remove existing bundle
rm -rf "$APP_PATH"

# Create bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
mkdir -p "$APP_PATH/Contents/Frameworks"

# Copy binary
cp "$BUILD_OUTPUT/SAMPRunner" "$APP_PATH/Contents/MacOS/SA-MP Runner"
chmod +x "$APP_PATH/Contents/MacOS/SA-MP Runner"

# Copy Wine binaries (if bundled)
if [ -d "$MAC_LAUNCHER_DIR/Resources/wine" ]; then
    echo "  Copying Wine..."
    cp -R "$MAC_LAUNCHER_DIR/Resources/wine" "$APP_PATH/Contents/Resources/"
fi

# Copy DXVK files
if [ -d "$PROJECT_ROOT/WineEngine/dlls" ]; then
    echo "  Copying DXVK..."
    mkdir -p "$APP_PATH/Contents/Resources/dxvk"
    cp -R "$PROJECT_ROOT/WineEngine/dlls" "$APP_PATH/Contents/Resources/dxvk/"
fi

# Copy DXVK config
if [ -f "$PROJECT_ROOT/GameOptimizations/dxvk/dxvk.conf" ]; then
    cp "$PROJECT_ROOT/GameOptimizations/dxvk/dxvk.conf" "$APP_PATH/Contents/Resources/"
fi

# Create Info.plist
echo "  Creating Info.plist..."
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SA-MP Runner</string>
    <key>CFBundleIdentifier</key>
    <string>com.samprunner.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SA-MP Runner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
</dict>
</plist>
EOF

# Create app icon (placeholder)
# TODO: Create actual icon
echo "  Creating icon placeholder..."
mkdir -p "$APP_PATH/Contents/Resources/AppIcon.iconset"

# Set icon (if available)
if [ -f "$MAC_LAUNCHER_DIR/Resources/AppIcon.icns" ]; then
    cp "$MAC_LAUNCHER_DIR/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/"
fi

echo "✓ Application bundle created"

# Code signing (for development)
echo "🔏 Code signing..."
codesign --force --deep --sign - "$APP_PATH" || echo "⚠️  Code signing failed (this is OK for development)"

echo ""
echo "✅ Build complete!"
echo ""
echo "Application: $APP_PATH"
echo ""
echo "To run:"
echo "  open \"$APP_PATH\""
echo ""
echo "To install:"
echo "  cp -R \"$APP_PATH\" /Applications/"
