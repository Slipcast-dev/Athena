#!/usr/bin/env bash
# Единая точка запуска SwiftUI-приложения из Swift Package. Скрипт собирает
# воспроизводимый локальный .app-пакет, поэтому macOS запускает приложение как GUI.
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MacAssistant"
BUNDLE_ID="com.macassistant.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/MacAssistant/Resources/AgentAthena.png"
ICON_FILE="$APP_CONTENTS/Resources/$APP_NAME.icns"

BUILD_CONFIGURATION="debug"
if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  # Релизный бинарник нужен для передачи на ручную подпись; запускать его
  # автоматически не следует, поскольку это операция подготовки артефакта.
  BUILD_CONFIGURATION="release"
fi

if [[ "$MODE" != "--package" && "$MODE" != "package" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Не найден исходный файл иконки: $ICON_SOURCE" >&2
  exit 1
fi

# macOS использует .icns для иконки приложения. Набор размеров создаётся из
# одного квадратного исходника, чтобы Finder и Dock не масштабировали его
# некачественно на Retina-экранах.
ICONSET_PARENT="$(mktemp -d)"
ICONSET_DIR="$ICONSET_PARENT/$APP_NAME.iconset"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$ICONSET_PARENT"' EXIT
for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  /usr/bin/sips -z "$retina_size" "$retina_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc подпись проверяет целостность локального артефакта, но не заменяет
# Developer ID Application и не делает приложение пригодным для распространения.
/usr/bin/codesign --force --sign - "$APP_BUNDLE"

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }

case "$MODE" in
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --package|package) /usr/bin/plutil -lint "$INFO_PLIST"; /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"; echo "Локальный релизный пакет: $APP_BUNDLE" ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2; exit 2 ;;
esac
