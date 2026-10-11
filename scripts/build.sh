#!/bin/bash
# Builds "SA-MP Runner.app" and the samp-runner command-line tool into ./build.
#
#   ./scripts/build.sh              native architecture (arm64 on Apple Silicon)
#   ./scripts/build.sh --universal  arm64 + x86_64
#
# Needs Xcode or the Command Line Tools (xcode-select --install). Wine itself is
# downloaded by the app/CLI on first setup, not bundled here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/MacLauncher"
OUT="$ROOT/build"
APP="$OUT/SA-MP Runner.app"
VERSION="2.0.0"

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift not found. Install Xcode or run: xcode-select --install" >&2
    exit 1
fi

ARCH_FLAGS=(--arch "$(uname -m)")
if [[ "${1:-}" == "--universal" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> Building (${ARCH_FLAGS[*]})"
swift build -c release --package-path "$PACKAGE" "${ARCH_FLAGS[@]}" --product SAMPRunner
swift build -c release --package-path "$PACKAGE" "${ARCH_FLAGS[@]}" --product samp-runner
BIN="$(swift build -c release --package-path "$PACKAGE" "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SAMPRunner" "$APP/Contents/MacOS/SA-MP Runner"
cp "$BIN/samp-runner" "$APP/Contents/MacOS/samp-runner"
cp "$BIN/samp-runner" "$OUT/samp-runner"

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -f "$PACKAGE/Resources/AppIcon.icns" ]]; then
    cp "$PACKAGE/Resources/AppIcon.icns" "$APP/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP/Contents/MacOS/samp-runner"
codesign --force --sign - "$APP"
codesign --force --sign - "$OUT/samp-runner"

echo
echo "Built:"
echo "  $APP"
echo "  $OUT/samp-runner   (command-line tool; also inside the app bundle)"
echo
echo "Run:      open \"$APP\""
echo "Install:  cp -R \"$APP\" /Applications/"
