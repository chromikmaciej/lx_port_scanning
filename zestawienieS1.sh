#!/bin/bash

# Pliki wejściowe i wyjściowe
zestawienie="zestawienie.csv"
export="export.csv"
wyniki="wyniki.csv"

# Sprawdzenie, czy plik wynikowy istnieje i usunięcie go, jeśli tak
if [ -f "$wyniki" ]; then
  rm "$wyniki"
fi

# Pętla po każdym hoście w pliku zestawienie1.csv
while IFS= read -r host; do
  # Usunięcie białych znaków z początku i końca nazwy hosta
  host=$(echo "$host" | tr -d '[:space:]')

  # Wyszukiwanie linii w pliku export1.csv zawierającej dany host
  linia=$(grep -w -F "$host" "$export")

  # Jeśli linia została znaleziona
  if [ -n "$linia" ]; then
    # Zapisanie do pliku wyniki.csv
    echo "$host;$linia" >> "$wyniki"
  else
    # Jeśli host nie został znaleziony, zapisujemy tylko nazwę hosta z informacją
    echo "$host;Nie znaleziono w pliku export1.csv" >> "$wyniki"
  fi
done < "$zestawienie"

echo "Zakończono. Wyniki zapisano w pliku: $wyniki"

