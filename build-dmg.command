#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
BUILD="$PWD/build"
DIST="$PWD/dist"
APP="$BUILD/GlobeToggle.app"
STAGING="$BUILD/dmg"
DMG="$DIST/GlobeToggle-$VERSION-universal.dmg"
mkdir -p "$BUILD" "$DIST"
# Remove all previous products so stale resources cannot leak into this release.
rm -rf "$BUILD/GlobeToggle.app" "$BUILD/dmg" "$BUILD/icons" "$BUILD/AppIcon.iconset"
export CLANG_MODULE_CACHE_PATH="$BUILD/ModuleCache"
export SWIFT_MODULECACHE_PATH="$BUILD/ModuleCache"

echo 'Building for Apple Silicon and Intel (macOS 14 or later)…'
for ARCH in arm64 x86_64; do
    xcrun swiftc -O -target "$ARCH-apple-macos14.0" \
        -module-cache-path "$BUILD/ModuleCache" \
        -framework AppKit -framework Carbon -framework IOKit \
        -framework ApplicationServices GlobeToggle.swift TapGesture.swift -o "$BUILD/GlobeToggle-$ARCH"
done
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
bash build-icon.command
cp "$BUILD/icons/"* "$APP/Contents/Resources/"
xcrun lipo -create "$BUILD/GlobeToggle-arm64" "$BUILD/GlobeToggle-x86_64" \
    -output "$APP/Contents/MacOS/GlobeToggle"
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 14.0' "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"

mkdir -p "$STAGING"
ditto "$APP" "$STAGING/GlobeToggle.app"
if [ ! -e "$STAGING/Applications" ]; then
    ln -s /Applications "$STAGING/Applications"
fi
cp README.md "$STAGING/Read Me.txt"
echo 'Creating disk image…'
hdiutil makehybrid -hfs -hfs-volume-name "GlobeToggle $VERSION" \
    -ov -o "$BUILD/GlobeToggle-hfs.dmg" "$STAGING"
hdiutil convert "$BUILD/GlobeToggle-hfs.dmg" -ov -format UDZO -o "$DMG"
hdiutil verify "$DMG"
echo "Built: $DMG"
# Keep a ready-to-use app beside the disk image, without an extra ZIP.
rm -rf "$DIST/GlobeToggle.app"
ditto "$APP" "$DIST/GlobeToggle.app"
codesign --verify --strict --verbose=2 "$DIST/GlobeToggle.app"
