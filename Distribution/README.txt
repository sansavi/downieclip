DownieClip 1.1 — paczka instalacyjna
====================================

Co to jest
    Mały agent w pasku menu: naciskasz skrót (domyślnie ⌥⌘V), a link ze schowka
    ląduje w kolejce Downie 4 i pobieranie startuje od razu. Bez klikania w Downie,
    bez wklejania w okienku.

Wymagania na tym drugim Macu
    - macOS 12 (Monterey) lub nowszy — apka jest universal (Apple Silicon + Intel)
    - Downie 4 zainstalowany w /Applications (bundle id com.charliemonroe.Downie-4).
      Downie 3 nie zadziała — apka szuka konkretnie „Downie 4”.
    - Bez Downie 4 apka uruchomi się, ale przy próbie wysłania pokaże ✗ i napisze o tym w logu.

Instalacja — wariant A: plik .pkg (zalecany)
    1. Skopiuj DownieClip-1.1.pkg na drugi Mac (AirDrop / USB / iCloud).
    2. Kliknij dwukrotnie.
       - Jeśli macOS napisze „nie można otworzyć, bo pochodzi od niezidentyfikowanego
         dewelopera”: kliknij plik prawym przyciskiem → Otwórz → Otwórz.
         Albo: Ustawienia systemowe → Prywatność i bezpieczeństwo → „Otwórz mimo to”.
       - Pakiet nie jest podpisany certyfikatem Apple Developer ID (apka jest darmowa,
         podpisana ad-hoc), stąd ten jednorazowy komunikat.
    3. Podaj hasło administratora. Apka trafi do /Applications, kwarantanna zostanie
       zdjęta, a agent wystartuje od razu.
    Z terminala (bez okienek): sudo installer -pkg DownieClip-1.1.pkg -target /

Instalacja — wariant B: ZIP
    1. Rozpakuj DownieClip-1.1.zip.
    2. Kliknij dwukrotnie instalacja.command (jeśli macOS zablokuje: prawy → Otwórz).
       Skopiuje apkę do /Applications, zdejmie kwarantannę i uruchomi ją.
    Alternatywnie ręcznie: przeciągnij DownieClip.app do /Applications, a potem w Terminalu:
       xattr -dr com.apple.quarantine /Applications/DownieClip.app && open -a /Applications/DownieClip.app

Po instalacji
    - Skopiuj dowolny link i naciśnij ⌥⌘V → Downie dostaje go do kolejki.
    - Ikona w pasku menu pokazuje ✓ / ✗ i ma menu: Ustawienia…, Otwórz Downie 4, Otwórz log.
    - Autostart przy logowaniu włącza się sam przy pierwszym uruchomieniu; wyłączysz go
      w Ustawieniach (checkbox) albo: /Applications/DownieClip.app/Contents/MacOS/DownieClip --login-item off
    - Zmiana skrótu: ikona w pasku menu → Ustawienia… → kliknij pole i naciśnij kombinację.
    - Pierwsze wysłanie może wywołać systemowe pytanie „DownieClip chce sterować Downie 4” —
      kliknij OK (to oficjalne API Downie). Jeśli odmówisz, apka automatycznie przejdzie
      na drugą metodę (LaunchServices) i dalej będzie działać.

Log
    ~/Library/Logs/DownieClip.log  (menu → „Otwórz log”)

Odinstalowanie
    Uruchom odinstaluj.command (z ZIP-a) albo ręcznie:
       pkill -x DownieClip
       /Applications/DownieClip.app/Contents/MacOS/DownieClip --login-item off
       rm -f ~/Library/LaunchAgents/com.github.sansavi.downieclip.plist
       rm -rf /Applications/DownieClip.app
       defaults delete com.github.sansavi.downieclip

Materiały źródłowe / przebudowa
    ~/GIT/DownieClip — ./build-app.sh (kompilacja universal), ./make-package.sh (paczki w dist/)
