#!/bin/zsh
# Builds Nook (Release) and packages it into a styled DMG:
# white background, Nook.app on the left, Applications on the right.
#
# Usage: scripts/make-dmg.sh
# Output: Nook.dmg in the repository root. All intermediate build products
# stay in dist/, which is disposable and git-ignored.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VOLNAME="Nook"
BACKGROUND="$ROOT/assets/dmg-background.png"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-stage"
RW_DMG="$DIST/Nook-rw.dmg"
OUT_DMG="$ROOT/Nook.dmg"

echo "▸ Building Release…"
xcodebuild -scheme Nook -configuration Release \
  -derivedDataPath "$DIST/DerivedData" \
  -destination 'platform=macOS' build -quiet
APP="$DIST/DerivedData/Build/Products/Release/Nook.app"
[[ -d "$APP" ]] || { echo "Release build not found at $APP" >&2; exit 1; }

echo "▸ Staging…"
rm -rf "$STAGE" "$RW_DMG" "$OUT_DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/Nook.app"
ln -s /Applications "$STAGE/Applications"
cp "$BACKGROUND" "$STAGE/.background/background.png"

echo "▸ Creating writable DMG…"
hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" -quiet

echo "▸ Styling the DMG window…"
MOUNT_DIR="/Volumes/$VOLNAME"
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -quiet
# Give Finder a moment to notice the volume.
sleep 1

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 800, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set background picture of viewOptions to file ".background:background.png"
    set position of item "Nook.app" of container window to {150, 195}
    set position of item "Applications" of container window to {450, 195}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
# Finder can briefly hold the volume after scripting it; retry the detach.
for attempt in 1 2 3 4 5; do
  if hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null; then
    break
  fi
  if [[ $attempt -eq 5 ]]; then
    hdiutil detach "$MOUNT_DIR" -force -quiet
  else
    sleep 2
  fi
done

echo "▸ Compressing to final DMG…"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG" -quiet
rm -f "$RW_DMG"
rm -rf "$STAGE"

echo "✓ Created $OUT_DMG"
