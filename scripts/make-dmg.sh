#!/bin/bash
# Packages dist/Launager.app into a drag-to-Applications DMG. The release
# workflow re-signs and notarizes this artifact before publishing it.
#   ./scripts/make-app.sh universal && ./scripts/make-dmg.sh
#   ./scripts/make-dmg.sh release-artifacts/Launager_0.0.2_universal.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.2}"
APP=dist/Launager.app
if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [output-dmg]" >&2
    exit 64
fi
DMG="${1:-dist/Launager-${VERSION}.dmg}"

[ -d "$APP" ] || { echo "缺少 $APP —— 先运行 ./scripts/make-app.sh"; exit 1; }

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil create -volname "Launager" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "==> done: $DMG"
