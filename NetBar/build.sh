#!/bin/bash
set -e

# Build script for NetBar

echo "Building NetBar..."

# Output directory structure
APP_DIR="NetBar.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Info.plist
cp NetBar/Info.plist "$CONTENTS_DIR/Info.plist"

# Copy App Icon (must have transparent background — see scripts/generate-icon.sh)
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "../AppIcon.icns" ]; then
    cp "../AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "NetBar.app/Contents/Resources/AppIcon.icns" ]; then
    cp "NetBar.app/Contents/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "⚠️  AppIcon.icns not found, skipping"
fi

# Optional: Set the bundle structure (PkgInfo is recommended for App bundles)
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Compile Swift files
ARCH=$(uname -m)
swiftc -o "$MACOS_DIR/NetBar" \
    NetBar/main.swift \
    NetBar/AppDelegate.swift \
    NetBar/Preferences.swift \
    NetBar/SettingsWindowController.swift \
    NetBar/NetworkMonitor.swift \
    NetBar/NetworkChangeDetector.swift \
    NetBar/IPFlagFetcher.swift \
    NetBar/MenuBarView.swift \
    -framework Cocoa \
    -framework Foundation \
    -framework SystemConfiguration \
    -framework Network \
    -target ${ARCH}-apple-macos13.0

echo "Build complete! App bundle created at ${PWD}/${APP_DIR}"
echo "You can run it with: open ${APP_DIR}"
