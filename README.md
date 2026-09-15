# DownieClip

Agent w pasku menu dla macOS: skopiowany link wysyłasz skrótem (**domyślnie ⌥⌘V**),
a Downie 4 dostaje go do kolejki i od razu zaczyna pobieranie. Bez klikania w Downie,
bez wklejania w okienku.

```
skopiuj link  →  ⌥⌘V  →  Downie pobiera
```

## Funkcje

- globalny skrót (Carbon `RegisterEventHotKey` — bez uprawnień Accessibility)
- Skrót globalny, zmienialny w ustawieniach (pole do nagrania własnej kombinacji)
- Wysyłka przez oficjalne API Downie (`open all URLs in text` + `start queue`),
  z automatycznym fallbackiem na LaunchServices, gdy macOS odmówi zgody na Automation
- Uruchamia Downie, jeśli nie działa; pokazuje ✓/✗ w pasku menu + dźwięk
- Autostart przy logowaniu (LaunchAgent), tryb CLI do testów, log w `~/Library/Logs/DownieClip.log`

## Struktura

```
Sources/                 kod (AppKit, bez zależności zewnętrznych)
Resources/Info.plist     LSUIElement, LSMinimumSystemVersion 12.0
project.yml              konfiguracja xcodegen (universal: arm64 + x86_64)
DownieClip.xcodeproj     wygenerowany projekt (w repo, żeby wystarczył sam Xcode)
build-app.sh             awaryjny build bez Xcode (tylko arm64)
make-package.sh          buduje apkę i składa dist/*.pkg + dist/*.zip
Distribution/            README dla użytkownika, instalacja.command, odinstaluj.command, postinstall
```

## Budowanie

```bash
bash make-package.sh          # apka + dist/DownieClip-1.0.pkg + dist/DownieClip-1.0.zip
```

Wymagania: Xcode (z zaakceptowaną licencją) i opcjonalnie `brew install xcodegen`.
Bez Xcode zadziała `bash build-app.sh`, ale zbuduje tylko architekturę tego Maca.

Podczas developmentu wygodniej budować wprost:

```bash
xcodebuild -project DownieClip.xcodeproj -scheme DownieClip -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
open build/Build/Products/Release/DownieClip.app
```

## Instalacja na Macu

Z paczki `.pkg` (prawy przycisk → Otwórz za pierwszym razem — podpis ad-hoc, brak Developer ID)
albo z `.zip` przez `instalacja.command`. Szczegóły: `Distribution/README.txt`.

## Tryb CLI

```bash
APP=/Applications/DownieClip.app/Contents/MacOS/DownieClip
$APP --status                     # skrót, metoda wysyłki, autostart, ścieżki
$APP --send                       # wyślij URL ze schowka (ta sama ścieżka co skrót)
$APP --send-url URL --method launchServices
$APP --login-item on|off
```

## Praca na kilku Macach

Kod i skrypty jadą przez git; **stan lokalny każdego Maca nie jedzie** i tak ma być:

| Co | Gdzie żyje | Przenoszone gitem? |
|---|---|---|
| źródła, skrypty, README | repo | tak |
| ustawienia apki (skrót, metoda, dźwięk) | `UserDefaults com.github.sansavi.downieclip` | nie — każdy Mac ma swoje |
| autostart | `~/Library/LaunchAgents/com.github.sansavi.downieclip.plist` | nie — tworzy się przy pierwszym uruchomieniu z /Applications |
| zgoda na sterowanie Downie (TCC) | system, per Mac i per podpis binarki | nie — po każdej przebudowie może zapytać ponownie |
| `build/`, `dist/` | lokalne artefakty | nie (`.gitignore`) |

Typowy obieg:

```bash
git pull --rebase          # przed pracą
# ... zmiany ...
git add -A && git commit -m "co i po co"
git push
```

Gotowe paczki nie muszą być budowane na obu Macach — wystarczy wystawić release
z załączonym `.pkg`, a drugi Mac pobiera z niego plik:

```bash
gh release create v1.0 --title "v1.0" dist/DownieClip-1.0.pkg dist/DownieClip-1.0.zip
gh release download v1.0 --pattern '*.pkg' --dir ~/Downloads
```

### Gdy drugi Mac używa innego konta GitHub

Repo jest prywatne i należy do konta `sansavi`. Jeśli na drugim Macu logujesz się innym
kontem (np. firmowym/enterprise, `login_firma`), to konto **nie dostanie dostępu** —
konta enterprise mogą współpracować tylko w obrębie swojego enterprise. Rozwiązanie:
autoryzacja tokenem z konta `sansavi`, zapisanym w Keychainie tego Maca.

```bash
# 1. Utwórz fine-grained token na koncie sansavi (przeglądarka):
#    https://github.com/settings/personal-access-tokens/new
#    Repository access: Only select repositories → downieclip
#    Permissions → Contents: Read and write
# 2. Na drugim Macu:
git clone https://github.com/sansavi/downieclip.git ~/GIT/downieclip
cd ~/GIT/downieclip && bash scripts/setup-drugi-mac.sh   # pyta o token, zapisuje w Keychainie, testuje dostęp
```

Token jest wpisywany tylko w oknie promptu skryptu (`read -s`) i ląduje wyłącznie
w Keychainie — nigdy w pliku repo, w historii shella ani w argumentach polecenia.
Po wygaśnięciu tokenu wystarczy powtórzyć skrypt.
