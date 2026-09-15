#!/bin/bash
# Dostęp do repo sansavi/downieclip na TYM Macu.
#
# Repo jest publiczne: klon i pull działają bez tokenu. Ten skrypt przydaje się, gdy chcesz
# z tego Maca PUSHOWAĆ, a logujesz się tu innym kontem GitHub (np. firmowym/enterprise) —
# wtedy autoryzacja idzie tokenem z konta sansavi.
#
# Uwaga (sprawdzone na macOS 27): `git credential-osxkeychain store` NIE działa
# ("failed to store: -1"), dlatego zamiast klasycznego wpisu w Keychainie używamy
# albo gh (przechowuje token sam), albo Keychaina przez `security add-generic-password`.
# Dzięki repo-lokalnemu helperowi nie ruszamy globalnego konta gh ani globalnego gita.
set -euo pipefail

OWNER="sansavi"
REPO="downieclip"
TARGET="${TARGET:-$HOME/GIT/$REPO}"
KEYCHAIN_ITEM="downieclip-pat"

echo "== Dostęp do $OWNER/$REPO (klon jest publiczny; token tylko do push) =="
echo

have_gh=0
command -v gh >/dev/null 2>&1 && have_gh=1

token_available=0
if [ "$have_gh" = "1" ] && gh auth token --user "$OWNER" >/dev/null 2>&1; then
    token_available=1
    echo "gh już ma token dla konta $OWNER — nie pytam o nic."
fi

if [ "$token_available" = "0" ]; then
    echo "Potrzebny token (fine-grained PAT) z konta $OWNER:"
    echo "  1. https://github.com/settings/personal-access-tokens/new"
    echo "  2. Repository access → Only select repositories → $REPO"
    echo "  3. Permissions → Repository permissions → Contents: Read and write"
    echo "     (Metadata: Read jest domyślnie; nic więcej nie trzeba)"
    echo "  4. Expiration wg uznania — po wygaśnięciu powtórz ten skrypt"
    echo
    read -rs -p "Token (wpisywane znaki nie będą widoczne): " TOKEN
    echo
    if [ -z "$TOKEN" ]; then
        echo "Nie podano tokenu — przerywam."
        exit 1
    fi

    if [ "$have_gh" = "1" ]; then
        printf '%s' "$TOKEN" | gh auth login --with-token
        unset TOKEN
        token_available=1
        echo "Token zapisany przez gh jako konto $OWNER."
        echo "UWAGA: gh mógł przełączyć aktywne konto — jeśli używasz tu też konta firmowego,"
        echo "wróć do niego przez: gh auth switch --user <twoje-firmowe-konto>"
    else
        # brak gh: token w Keychainie jako hasło generyczne (nie plaintext w pliku)
        security add-generic-password -a "$OWNER" -s "$KEYCHAIN_ITEM" -w "$TOKEN" -U
        unset TOKEN
        token_available=2
        echo "Token zapisany w Keychainie (item: $KEYCHAIN_ITEM)."
    fi
fi

# Repo-lokalny helper: git dostaje poświadczenia z gh albo z Keychaina,
# bez zmiany globalnej konfiguracji i bez zmiany aktywnego konta gh.
if [ "$have_gh" = "1" ]; then
    HELPER='!f() { echo username=sansavi; echo password=$(gh auth token --user sansavi); }; f'
else
    HELPER='!f() { echo username=sansavi; echo password=$(security find-generic-password -a sansavi -s downieclip-pat -w); }; f'
fi

url="https://github.com/$OWNER/$REPO.git"

if [ -d "$TARGET/.git" ]; then
    echo "Repo już jest w $TARGET — ustawiam helper i robię fetch"
    git -C "$TARGET" config --local credential.helper "$HELPER"
    git -C "$TARGET" remote set-url origin "$url"
    git -C "$TARGET" fetch origin
else
    mkdir -p "$(dirname "$TARGET")"
    echo "Klonuję do $TARGET"
    git -c credential.helper="$HELPER" clone "$url" "$TARGET"
    git -C "$TARGET" config --local credential.helper "$HELPER"
fi

# Tożsamość commitów tylko lokalnie — na służbowym Macu globalna bywa ustawiona na konto firmowe.
if [ -z "$(git -C "$TARGET" config user.email || true)" ]; then
    default_mail="9073796+$OWNER@users.noreply.github.com"
    read -r -p "E-mail do commitów w tym repo [$default_mail]: " MAIL
    MAIL="${MAIL:-$default_mail}"
    git -C "$TARGET" config user.name "$OWNER"
    git -C "$TARGET" config user.email "$MAIL"
fi

echo
echo "== Test dostępu =="
if git ls-remote "$url" HEAD >/dev/null 2>&1; then
    echo "OK: $OWNER/$REPO dostępne, repo w $TARGET"
else
    echo "BŁĄD: brak dostępu. Sprawdź, czy token ma Contents: Read and write i wskazuje $OWNER/$REPO."
    exit 1
fi

echo
echo "Dalej:"
echo "  cd $TARGET && bash make-package.sh     # zbuduj apkę i paczki (wymaga Xcode)"
echo "  albo pobierz gotową paczkę: gh release download v1.0 --repo $OWNER/$REPO --pattern '*.pkg'"
