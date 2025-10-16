#!/usr/bin/env bash
set -euo pipefail

# --- Konfiguracja ---
SRC_DIR="/home/maciek/TEST/zrodlo"   # katalog, w którym szukamy
DST_DIR="/home/maciek/TEST/cel"   # katalog, do którego kopiujemy
PATTERN="alamakota"                     # fraza do wyszukania (może zawierać spacje)

# Opcjonalnie: wykluczenia (pattern dla --exclude-dir grep), rozdzielone spacją
EXCLUDE_DIRS="node_modules .git"

# --- Konwersja i walidacja ---
# upewnij się że katalog źródłowy istnieje
if [ ! -d "$SRC_DIR" ]; then
  echo "Katalog źródłowy nie istnieje: $SRC_DIR" >&2
  exit 2
fi
mkdir -p "$DST_DIR"

# przygotuj opcję --exclude-dir dla grep, jeśli podano wykluczenia
GREP_EXCLUDE_OPTS=()
if [ -n "$EXCLUDE_DIRS" ]; then
  for d in $EXCLUDE_DIRS; do
    GREP_EXCLUDE_OPTS+=(--exclude-dir="$d")
  done
fi

# --- Wyszukiwanie i kopiowanie ---
# grep -RIl : R - rekursywnie, I - ignoruj pliki binarne, l - wypisz nazwę pliku
# używamy printf0 + xargs -0 albo while read -r -d '' dla bezpieczeństwa z nazwami plików zawierającymi spacje/nowe linie
grep -RIl "${GREP_EXCLUDE_OPTS[@]:-}" -- "$PATTERN" "$SRC_DIR" \
  | tr '\n' '\0' \
  | while IFS= read -r -d '' file; do
    # oblicz ścieżkę względną i przygotuj miejsce docelowe
    rel="${file#$SRC_DIR/}"
    target="$DST_DIR/$rel"
    mkdir -p "$(dirname "$target")"
    cp -a -- "$file" "$target"
    echo "Skopiowano: $rel"
done
