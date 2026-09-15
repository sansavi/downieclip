#!/bin/bash
# Buduje apkę i składa paczki instalacyjne w dist/:
#   dist/DownieClip-1.0.pkg   — instalator (Installer.app, wymaga hasła admina na docelowym Macu)
#   dist/DownieClip-1.0.zip   — apka + instalacja.command + README + odinstaluj.command
#
# Budowanie: xcodebuild (universal arm64+x86_64). Jeśli Xcode jest niedostępny
# (np. niezaakceptowana licencja), spada na build-app.sh, który zrobi wersję arm64-only.
set -euo pipefail

cd "$(dirname "$0")"

VERSION="1.0"
STAGE="dist/stage"
ZIPDIR="dist/DownieClip-$VERSION"

if xcodebuild -version >/dev/null 2>&1; then
  echo "== buduję przez xcodebuild (universal) =="
  # .xcodeproj jest w repo, więc xcodegen nie jest wymagany; jeśli jest — odśwież projekt
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
  else
    echo "   (brak xcodegen — używam projektu z repo)"
  fi
  # -destination generic/platform=macOS + jawne ARCHS: bez tego xcodebuild zwęża
  # architektury do architektury tego Maca (wychodzi arm64-only).
  xcodebuild -project DownieClip.xcodeproj -scheme DownieClip -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | grep -E "error:|BUILD" || true
  APP="build/Build/Products/Release/DownieClip.app"
  [ -d "$APP" ] || { echo "BŁĄD: brak $APP"; exit 1; }
else
  echo "== Xcode niedostępny — fallback build-app.sh =="
  ./build-app.sh
  APP="build/fallback/DownieClip.app"
fi

echo "== architektury =="
lipo -archs "$APP/Contents/MacOS/DownieClip"

mkdir -p "$STAGE/Applications" "$ZIPDIR" "dist/scripts"
ditto "$APP" "$STAGE/Applications/DownieClip.app"
ditto "$APP" "$ZIPDIR/DownieClip.app"
cp Distribution/README.txt Distribution/instalacja.command Distribution/odinstaluj.command "$ZIPDIR/"
cp Distribution/scripts/postinstall dist/scripts/postinstall

chmod +x make-package.sh \
  Distribution/instalacja.command Distribution/odinstaluj.command Distribution/scripts/postinstall \
  dist/scripts/postinstall "$ZIPDIR/instalacja.command" "$ZIPDIR/odinstaluj.command"

echo "== pkg =="
pkgbuild --root "$STAGE" \
  --identifier com.github.sansavi.downieclip \
  --version "$VERSION" \
  --install-location / \
  --scripts dist/scripts \
  "dist/DownieClip-$VERSION.pkg"

echo "== zip =="
ditto -c -k --sequesterRsrc --keepParent "$ZIPDIR" "dist/DownieClip-$VERSION.zip"

echo "== podsumowanie =="
shasum -a 256 "dist/DownieClip-$VERSION.pkg" "dist/DownieClip-$VERSION.zip"
du -h "dist/DownieClip-$VERSION.pkg" "dist/DownieClip-$VERSION.zip"
