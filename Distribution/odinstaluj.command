#!/bin/bash
# Usuwa DownieClip: proces, autostart, apkę i ustawienia. Log zostaje.
set -uo pipefail

APP="/Applications/DownieClip.app"
DOMAIN="com.github.sansavi.downieclip"
PLIST="$HOME/Library/LaunchAgents/com.github.sansavi.downieclip.plist"

echo "Zamykam DownieClip…"
pkill -x DownieClip 2>/dev/null || true
sleep 1

echo "Wyłączam autostart…"
launchctl bootout "gui/$(id -u)/$DOMAIN" 2>/dev/null || true
rm -f "$PLIST"

echo "Usuwam aplikację…"
rm -rf "$APP"

echo "Usuwam ustawienia…"
defaults delete "$DOMAIN" 2>/dev/null || true

echo
echo "DownieClip usunięty. Log (możesz skasować ręcznie): ~/Library/Logs/DownieClip.log"
echo
read -n 1 -s -r -p "Naciśnij dowolny klawisz, aby zamknąć…"
