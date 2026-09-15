#!/bin/bash
# Awaryjny build bez Xcode (gdy licencja Xcode nie jest zaakceptowana / brak Xcode).
# Buduje TYLKO architekturę tego Maca — kompilator z CommandLineTools nie potrafi
# zlinkować x86_64 (biblioteki libswiftCompatibility* mają wyłącznie slice arm64).
# Preferowane: xcodebuild (patrz make-package.sh), daje pełne universal.
set -euo pipefail

cd "$(dirname "$0")"

CLT=/Library/Developer/CommandLineTools
SWIFTC="$CLT/usr/bin/swiftc"
LIPO="$CLT/usr/bin/lipo"
SDK="$CLT/SDKs/MacOSX.sdk"
TARGET_MACOS="12.0"
ARCH="$(uname -m)"
OUT="build/fallback"
APP="$OUT/DownieClip.app"

mkdir -p "$OUT/$ARCH" "$APP/Contents/MacOS"

echo "== kompiluję $ARCH (fallback, bez Xcode) =="
"$SWIFTC" -O -sdk "$SDK" -target "${ARCH}-apple-macos${TARGET_MACOS}" \
  -framework AppKit -framework Carbon \
  Sources/*.swift -o "$OUT/$ARCH/DownieClip"

cp "$OUT/$ARCH/DownieClip" "$APP/Contents/MacOS/DownieClip"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --identifier com.github.sansavi.downieclip "$APP"

echo "== gotowe: $APP =="
"$LIPO" -archs "$APP/Contents/MacOS/DownieClip"
