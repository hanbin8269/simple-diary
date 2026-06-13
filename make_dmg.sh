#!/bin/zsh
# Build the distributable Simple Diary.app .dmg (drag-to-Applications, custom background)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Simple Diary.app"
DMG="site/SimpleDiary.dmg"
VOL="Simple Diary"

[ -d "$APP" ] || { echo "Build the app first with ./build.sh" >&2; exit 1; }

# Install-window background (1x + 2x retina combined into one tiff)
swift scripts/make_dmg_bg.swift build/dmg-bg.png 640 400
swift scripts/make_dmg_bg.swift build/dmg-bg@2x.png 1280 800
tiffutil -cathidpicheck build/dmg-bg.png build/dmg-bg@2x.png -out build/dmg-bg.tiff >/dev/null

DMGBUILD="$(python3 -c 'import sysconfig,os;print(os.path.join(sysconfig.get_path("scripts","posix_user"),"dmgbuild"))' 2>/dev/null || true)"

rm -f "$DMG"
if [ -n "$DMGBUILD" ] && [ -x "$DMGBUILD" ]; then
  "$DMGBUILD" -s scripts/dmg_settings.py "$VOL" "$DMG" >/dev/null
else
  echo "Warning: dmgbuild not found — falling back to a plain DMG (pip3 install --user dmgbuild recommended)" >&2
  STAGING="$(mktemp -d)"
  cp -R "$APP" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGING"
fi

echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"
