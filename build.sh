#!/bin/bash
set -e

APP_NAME="MenubarBalance"
ICON_NAME="MenubarBalance"
APP_DIR="$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Building $APP_NAME..."

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile the .icon asset (Icon Composer) into Assets.car + .icns
xcrun actool "$ICON_NAME.icon" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 26.0 \
    --app-icon "$ICON_NAME" \
    --output-partial-info-plist "$RESOURCES_DIR/.icon-partial.plist" \
    --output-format human-readable-text \
    --errors --warnings

# Write Info.plist
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_NAME</string>
    <key>CFBundleIconName</key>
    <string>$ICON_NAME</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

rm -f "$RESOURCES_DIR/.icon-partial.plist"

# Compile Swift code
swiftc Sources/main.swift Sources/AppDelegate.swift Sources/Providers.swift Sources/ProvidersWindowController.swift -o "$MACOS_DIR/$APP_NAME"

echo "Build complete: $APP_DIR"
echo "You can launch it by running: open $APP_DIR"
