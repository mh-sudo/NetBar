#!/bin/bash
set -e

APP_NAME="NetBar"
VERSION=${1:-"1.0.2"}
BUILD_DIR="build"
EXPORT_PATH="$BUILD_DIR/export"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo "🔨 Building $APP_NAME v$VERSION..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_PATH"

# Build (Adapted from build.sh using swiftc)
echo "📦 Compiling..."
APP_BUNDLE="$EXPORT_PATH/$APP_NAME.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Info.plist
cp NetBar/NetBar/Info.plist "$CONTENTS_DIR/Info.plist"

# Copy App Icon (must have transparent background — see scripts/generate-icon.sh)
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "NetBar/NetBar.app/Contents/Resources/AppIcon.icns" ]; then
    cp "NetBar/NetBar.app/Contents/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "⚠️  AppIcon.icns not found, skipping"
fi

# PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Compile Swift files
# Note: Using absolute paths or relative to repository root as needed. 
# The script is expected to be run from the repository root.
echo "Compiling arm64 slice..."
swiftc -o "$MACOS_DIR/NetBar_arm64" \
    NetBar/NetBar/main.swift \
    NetBar/NetBar/AppDelegate.swift \
    NetBar/NetBar/Preferences.swift \
    NetBar/NetBar/SettingsWindowController.swift \
    NetBar/NetBar/NetworkMonitor.swift \
    NetBar/NetBar/IPFlagFetcher.swift \
    NetBar/NetBar/MenuBarView.swift \
    NetBar/NetBar/NetworkChangeDetector.swift \
    -framework Cocoa \
    -framework Foundation \
    -framework SystemConfiguration \
    -target arm64-apple-macos13.0

echo "Compiling x86_64 slice..."
swiftc -o "$MACOS_DIR/NetBar_x86_64" \
    NetBar/NetBar/main.swift \
    NetBar/NetBar/AppDelegate.swift \
    NetBar/NetBar/Preferences.swift \
    NetBar/NetBar/SettingsWindowController.swift \
    NetBar/NetBar/NetworkMonitor.swift \
    NetBar/NetBar/IPFlagFetcher.swift \
    NetBar/NetBar/MenuBarView.swift \
    NetBar/NetBar/NetworkChangeDetector.swift \
    -framework Cocoa \
    -framework Foundation \
    -framework SystemConfiguration \
    -target x86_64-apple-macos13.0

echo "Creating Universal Binary..."
lipo -create -output "$MACOS_DIR/NetBar" "$MACOS_DIR/NetBar_arm64" "$MACOS_DIR/NetBar_x86_64"
rm "$MACOS_DIR/NetBar_arm64" "$MACOS_DIR/NetBar_x86_64"

# Ad-hoc sign
echo "🔏 Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Remove quarantine-triggering metadata
echo "🧹 Removing quarantine metadata..."
xattr -cr "$APP_BUNDLE"

# Zip
echo "🤐 Zipping..."
cd "$EXPORT_PATH"
ditto -c -k --keepParent "$APP_NAME.app" "../../$ZIP_NAME"
cd ../../

# Print SHA256 (needed for Homebrew cask)
echo ""
echo "✅ Build complete: $ZIP_NAME"
echo ""
echo "📋 SHA256 (update Casks/netbar.rb sha256 with this value before tagging the release):"
shasum -a 256 "$ZIP_NAME"
