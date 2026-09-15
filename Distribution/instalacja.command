#!/bin/bash
# Instaluje DownieClip z tego folderu do /Applications (bez hasła administratora —
# /Applications jest zapisywalne dla administrujących użytkowników).
set -euo pipefail

cd "$(dirname "$0")"

APP="/Applications/DownieClip.app"
SRC="DownieClip.app"

if [ ! -d "$SRC" ]; then
    echo "Nie widzę DownieClip.app obok tego skryptu. Rozpakuj całe archiwum ZIP i spróbuj ponownie."
    read -n 1 -s -r -p "Naciśnij dowolny klawisz, aby zamknąć…"
    exit 1
fi

echo "Zamykam starą wersję (jeśli działa)…"
pkill -x DownieClip 2>/dev/null || true
sleep 1

echo "Kopiuję do /Applications…"
if [ -d "$APP" ]; then
    # zamiast kasować — odsuń starą wersję na bok (można ją potem wyrzucić ręcznie)
    mv "$APP" "${TMPDIR:-/tmp}/DownieClip-poprzednia-wersja.app" 2>/dev/null || true
fi
ditto "$SRC" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Uruchamiam…"
open -a "$APP"

echo
echo "Gotowe. Skopiuj link i naciśnij ⌥⌘V."
echo "Ustawienia (zmiana skrótu, autostart, metoda wysyłki): ikona w pasku menu → Ustawienia…"
echo
read -n 1 -s -r -p "Naciśnij dowolny klawisz, aby zamknąć…"
