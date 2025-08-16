#!/bin/bash

# Sprawdź, czy podano argument z katalogiem
if [ $# -ne 1 ]; then
    echo "Użycie: $0 <katalog_z_plikami_wynikowymi>"
    exit 1
fi

# Katalog z plikami wynikowymi
RESULT_DIR="$1"

# Przetwarzanie każdego pliku w katalogu
for FILE in "$RESULT_DIR"/*; do
    # Wyciąganie nazwy hosta z nazwy pliku
    HOST=$(basename "$FILE" | cut -d'@' -f1)
    OUTPUT_FILE="${HOST}.nft"

    # Rozpoczęcie pisania do pliku wynikowego
    {
        echo "table inet filter {"
        echo "  chain output {"
        echo "    type filter hook output priority 0; policy accept;"
        echo "  }"

        echo "  chain input {"
        echo "    type filter hook input priority 0; policy drop;"

        # Dodawanie reguł dla otwartych portów
        echo "    # Zezwolenie na ruch przychodzący na otwartych portach"
        PORTS_FOUND=false

        # Tablica do przechowywania dodanych portów
        declare -A ADDED_PORTS

        # Przetwarzanie sekcji otwartych portów
        while read -r line; do
            if [[ "$line" =~ ^(TCP|UDP) ]]; then
                # Rozdzielanie na protokół i adres
                PROTOCOL=$(echo "$line" | awk -F', ' '{print $1}')
                ADDR_PORT=$(echo "$line" | awk -F', ' '{print $2}')
                MPORT=$(echo "$ADDR_PORT" | cut -d':' -f2)
                MADDR=$(echo "$ADDR_PORT" | cut -d':' -f1)
                
		        if [[ $MADDR != "127.0.0.1" ]]; then
           	        if [[ $MPORT =~ ^[0-9]+$ ]] && [ "$MPORT" -gt 0 ]; then
           	            # Sprawdzanie, czy adres zawiera port
               	        if [[ "$ADDR_PORT" =~ : ]]; then
                	        PORT=$(echo "$ADDR_PORT" | cut -d':' -f2)
                        
               		        # Dodawanie reguły tylko, jeśli port nie został wcześniej dodany
               		        if [[ -z "${ADDED_PORTS[$PORT]}" ]]; then
                		        if [[ "$PROTOCOL" == "TCP" ]]; then
                       		        echo "    tcp dport $PORT accept;"
                   		        elif [[ "$PROTOCOL" == "UDP" ]]; then
                       		        echo "    udp dport $PORT accept;"
                   		        fi
                   	            ADDED_PORTS[$PORT]=1  # Oznacz port jako dodany
                                PORTS_FOUND=true
                            fi
                        fi
                    fi
	            fi
	        fi
        done < <(awk '/^Sekcja 1: Otwarte porty:/,/^Sekcja 2: Połączenia TCP:/' "$FILE")

        if [ "$PORTS_FOUND" = false ]; then
            echo "    # Brak otwartych portów do zezwolenia."
        fi

        echo "  }"
        echo "}"

    } > "$OUTPUT_FILE"

    echo "Utworzono plik z regułami dla hosta: $HOST"
done	
