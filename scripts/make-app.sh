#!/bin/bash
# Builds Launager.app into dist/ from the SPM executable.
#   ./scripts/make-app.sh            release build, current architecture
#   ./scripts/make-app.sh universal  release build, arm64 + x86_64
#   ARCH=arm64 ./scripts/make-app.sh build an explicit architecture (CI)
#   ./scripts/make-app.sh x86_64     equivalent explicit-architecture form
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.2}"
APP=dist/Launager.app
BUILD_ARGS=(-c release)
TARGET_ARCH="${1:-${ARCH:-}}"
case "$TARGET_ARCH" in
    "")
        ;;
    universal)
        BUILD_ARGS+=(--arch arm64 --arch x86_64)
        ;;
    arm64|x86_64)
        BUILD_ARGS+=(--arch "$TARGET_ARCH")
        ;;
    *)
        echo "Unsupported architecture: $TARGET_ARCH (expected arm64, x86_64, or universal)" >&2
        exit 64
        ;;
esac

echo "==> swift build ${BUILD_ARGS[*]}"
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/Launager"

echo "==> assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Launager"

# SwiftPM keeps library resources in target-specific bundles next to the
# executable. Copy both bundles into the app so the packaged build resolves
# the same localized strings as `swift run` and `swift test`.
BIN_DIR="$(dirname "$BIN_PATH")"
for bundle in \
    "$BIN_DIR/Launager_BirthCore.bundle" \
    "$BIN_DIR/Launager_BirthUI.bundle"; do
    if [ ! -d "$bundle" ]; then
        echo "ERROR: missing SwiftPM resource bundle: $bundle" >&2
        exit 1
    fi
    cp -R "$bundle" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>Launager</string>
    <key>CFBundleIdentifier</key>
    <string>ai.tiy.launager</string>
    <key>CFBundleName</key>
    <string>Launager</string>
    <key>CFBundleDisplayName</key>
    <string>Launager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Launager 需要通过“系统事件”来添加和移除登录时打开的 App。</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
</dict>
</plist>
PLIST

# Declare both localizations so framework-provided strings (menu bar,
# standard dialog buttons) follow the app's language.
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj" "$APP/Contents/Resources/en.lproj"

# TCC usage strings follow the app language too; the Chinese original lives
# in Info.plist itself as the development-region fallback.
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'STRINGS'
"NSAppleEventsUsageDescription" = "Launager needs to control System Events to add and remove apps that open at login.";
STRINGS

echo "==> rendering icon"
ICONSET=dist/AppIcon.iconset
rm -rf "$ICONSET"
swift scripts/generate-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "==> done: $APP"
