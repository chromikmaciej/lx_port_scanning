#!/bin/bash

# Ścieżki do plików
zestawienie_file="zestawienie.csv"
export_file="export.csv"
output_file="wynik.csv"

# Nagłówki pliku wynikowego
echo "Hostname;SOSGodzina;SOSData;Krytyczność;Computer" > $output_file

# Przetwarzaj każdy element w zestawieniu
while IFS= read -r item; do
    # Znajdź odpowiednie wiersze w pliku export.csv
    grep -F "$item" "$export_file" | while IFS=';' read -r line; do
        # Przenieś kolumnę 'Computer' na początek i dodaj 'SOSGodzina' (pustą)
        #echo "$item;${line#*;}" >> $output_file
        echo "$item;$line" >> $output_file
    done
done < "$zestawienie_file"

echo "Wynik zapisano do pliku $output_file"
