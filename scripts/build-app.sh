#!/bin/bash
# Builds dist/Vigil.app (release, ad-hoc signed). Usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Vigil"

APP="dist/Vigil.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Vigil"

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/render-icon.swift Resources/logo.svg "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.juansuarezdev.vigil</string>
  <key>CFBundleName</key><string>Vigil</string>
  <key>CFBundleExecutable</key><string>Vigil</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
