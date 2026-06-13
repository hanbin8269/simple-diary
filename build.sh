#!/bin/zsh
# Build script for Simple Diary.app
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Simple Diary"
APP="build/$APP_NAME.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Icon (build continues even if this fails)
if [ ! -f build/AppIcon.icns ]; then
  if swift scripts/make_icon.swift build/icon_1024.png; then
    rm -rf build/AppIcon.iconset
    mkdir -p build/AppIcon.iconset
    for s in 16 32 128 256 512; do
      sips -z $s $s build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
      d=$((s * 2))
      sips -z $d $d build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
  else
    echo "Warning: icon generation failed — continuing without an icon" >&2
  fi
fi
[ -f build/AppIcon.icns ] && cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cp .build/release/Ilgi "$APP/Contents/MacOS/Ilgi"
cp packaging/Info.plist "$APP/Contents/Info.plist"

codesign --force -s - "$APP"

echo "Done: $APP"
