#!/bin/zsh
# 일기장.app 빌드 스크립트
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Simple Diary"
APP="build/$APP_NAME.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 아이콘 (실패해도 빌드는 계속)
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
    echo "경고: 아이콘 생성 실패 — 아이콘 없이 계속합니다" >&2
  fi
fi
[ -f build/AppIcon.icns ] && cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cp .build/release/Ilgi "$APP/Contents/MacOS/Ilgi"
cp packaging/Info.plist "$APP/Contents/Info.plist"

codesign --force -s - "$APP"

echo "완료: $APP"
