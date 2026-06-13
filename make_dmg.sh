#!/bin/zsh
# Simple Diary.app → 배포용 .dmg 생성 (드래그-투-Applications, 커스텀 배경)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Simple Diary.app"
DMG="site/SimpleDiary.dmg"
VOL="Simple Diary"

[ -d "$APP" ] || { echo "먼저 ./build.sh 로 앱을 빌드하세요" >&2; exit 1; }

# 설치 창 배경 (1x + 2x 레티나를 tiff 한 장으로)
swift scripts/make_dmg_bg.swift build/dmg-bg.png 640 400
swift scripts/make_dmg_bg.swift build/dmg-bg@2x.png 1280 800
tiffutil -cathidpicheck build/dmg-bg.png build/dmg-bg@2x.png -out build/dmg-bg.tiff >/dev/null

DMGBUILD="$(python3 -c 'import sysconfig,os;print(os.path.join(sysconfig.get_path("scripts","posix_user"),"dmgbuild"))' 2>/dev/null || true)"

rm -f "$DMG"
if [ -n "$DMGBUILD" ] && [ -x "$DMGBUILD" ]; then
  "$DMGBUILD" -s scripts/dmg_settings.py "$VOL" "$DMG" >/dev/null
else
  echo "경고: dmgbuild 없음 — 단순 DMG로 대체 (pip3 install --user dmgbuild 권장)" >&2
  STAGING="$(mktemp -d)"
  cp -R "$APP" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGING"
fi

echo "완료: $DMG ($(du -h "$DMG" | cut -f1))"
