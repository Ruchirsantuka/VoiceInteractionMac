#!/bin/bash
set -euo pipefail

APP_NAME="Voice Interaction"
EXECUTABLE_NAME="VoiceInteractionMac"
BUILD_CONFIGURATION="release"
VERSION="0.1.0"
BUILD_NUMBER="1"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_NAME="AppIcon"
ICONSET_DIR="$DIST_DIR/$ICON_NAME.iconset"
ICNS_PATH="$RESOURCES_DIR/$ICON_NAME.icns"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$BUILD_CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
  point_file="$ICONSET_DIR/icon_${size}x${size}.png"
  retina_file="$ICONSET_DIR/icon_${size}x${size}@2x.png"

  cat > "$DIST_DIR/icon.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$((size * 2))" height="$((size * 2))" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="220" fill="#1e1e2e"/>
  <circle cx="512" cy="512" r="320" fill="#a6e3a1"/>
  <rect x="430" y="230" width="164" height="360" rx="82" fill="#1e1e2e"/>
  <path d="M330 500c0 100 82 182 182 182s182-82 182-182" fill="none" stroke="#1e1e2e" stroke-width="72" stroke-linecap="round"/>
  <path d="M512 682v132M400 814h224" fill="none" stroke="#1e1e2e" stroke-width="72" stroke-linecap="round"/>
</svg>
SVG

  qlmanage -t -s "$size" -o "$ICONSET_DIR" "$DIST_DIR/icon.svg" >/dev/null 2>&1
  mv "$ICONSET_DIR/icon.svg.png" "$point_file"

  qlmanage -t -s "$((size * 2))" -o "$ICONSET_DIR" "$DIST_DIR/icon.svg" >/dev/null 2>&1
  mv "$ICONSET_DIR/icon.svg.png" "$retina_file"
done

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$ICONSET_DIR" "$DIST_DIR/icon.svg"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>VoiceInteractionMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.voice-interaction.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Voice Interaction</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__BUILD_NUMBER__</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Voice Interaction needs microphone access to transcribe your speech locally.</string>
</dict>
</plist>
PLIST

sed -i '' "s/__VERSION__/$VERSION/g" "$CONTENTS_DIR/Info.plist"
sed -i '' "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" "$CONTENTS_DIR/Info.plist"

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
