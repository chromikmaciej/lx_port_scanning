#!/bin/bash

# Ustawienia
OUTPUT_FILE=$(hostname)@$(date +%T_"%Y-%m-%d")

INTERVAL=10  # Czas między zbieraniem danych w sekundach
DURATION=5   # Czas trwania nasłuchiwania przez tcpdump w sekundach

# Sprawdzenie, czy skrypt jest uruchamiany z odpowiednimi uprawnieniami
if [[ $EUID -ne 0 ]]; then
    echo "Ten skrypt musi być uruchamiany jako użytkownik root." 
    exit 1
fi

# Funkcja kończąca działanie skryptu
cleanup() {
    echo "Zatrzymano skrypt. Zapisuję szczątkowe wyniki do pliku." >> $OUTPUT_FILE
    exit 0
}

# Przechwytywanie sygnałów
trap 'cleanup' SIGTERM SIGINT

# Inicjalizacja pliku wynikowego z nagłówkiem, jeśli plik nie istnieje
if [ ! -f $OUTPUT_FILE ]; then
    echo "PID: $$ - Monitoring portów" > $OUTPUT_FILE
    echo "Sekcja 1: Otwarte porty:" >> $OUTPUT_FILE
    echo "Protokół, Lokalny adres (IP:Port), Typ" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
    echo "Sekcja 2: Połączenia TCP:" >> $OUTPUT_FILE
    echo "Protokół, Lokalny adres (IP:Port), Zdalny adres IP, Zdalny port, Typ" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
    echo "Sekcja 3: Połączenia UDP:" >> $OUTPUT_FILE
    echo "Protokół, Lokalny adres (IP:Port), Zdalny adres IP, Zdalny port, Typ" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
fi

while true; do

    TEMP_FILE_PORTS=$(mktemp)
    TEMP_FILE_TCP_CONNECTIONS=$(mktemp)
    TEMP_FILE_UDP_CONNECTIONS=$(mktemp)

    # Zbieranie aktywnych połączeń TCP z wykorzystaniem ss (ignorowanie IPv6)
    ss -tunap | awk '
    /^tcp/ && !/::/ {  # Ignoruj wiersze z IPv6
        split($5, local_addr, ":");
        split($6, remote_addr, ":");
        if (remote_addr[1] != "" && remote_addr[1] != "*") {
            printf "TCP, %s:%s, %s, %s, Active\n", local_addr[1], local_addr[2], remote_addr[1], remote_addr[2]
        }
    }
    ' >> $TEMP_FILE_TCP_CONNECTIONS

    # Zbieranie aktywnych połączeń UDP za pomocą tcpdump
    tcpdump -nn -c 100 -i any udp 2>/dev/null | awk '
    /IP/ {
        split($3, local, ":");
        split($5, remote, ":");
        sub(/:/, "", remote[4]);  # Usuwamy ":" z zdalnego portu
        if (length(remote) > 4) {
            printf "UDP, %s:%s, %s, %s, Active\n", local[1], local[2], remote[1], remote[4]
        } else {
            printf "UDP, %s:%s, %s, , Active\n", local[1], local[2], remote[1]
        }
    }
    ' >> $TEMP_FILE_UDP_CONNECTIONS

    # Zbieranie portów nasłuchujących (ignorowanie IPv6)
    ss -tunlp | awk '
    /^tcp/ && !/::/ {
        split($5, local_addr, ":");
        printf "TCP, %s:%s, Listening\n", local_addr[1], local_addr[2]
    }
    /^udp/ && !/::/ {
        split($5, local_addr, ":");
        printf "UDP, %s:%s, Listening\n", local_addr[1], local_addr[2]
    }
    ' >> $TEMP_FILE_PORTS

    # Funkcja do aktualizacji sekcji w pliku wynikowym
    update_section() {
        local section_title="$1"
        local temp_file="$2"
        
        # Wczytaj istniejące dane sekcji
        local current_data=$(awk "/^${section_title}$/{flag=1;next}/^Sekcja/{flag=0}flag" $OUTPUT_FILE)

        # Dołącz nowe wpisy bez duplikatów
        local new_data=$(sort -u <(echo "$current_data") <(sort -u $temp_file))

        # Zastąp starą sekcję nowymi danymi
        awk -v new_data="$new_data" -v section_title="$section_title" '
        BEGIN{print_section=1}
        /^'"$section_title"'$/ {
            print $0; print new_data; print_section=0; next
        }
        /^Sekcja/ {print_section=1}
        print_section' $OUTPUT_FILE > ${OUTPUT_FILE}.tmp && mv ${OUTPUT_FILE}.tmp $OUTPUT_FILE
    }

    # Aktualizuj sekcje w pliku wynikowym
    update_section "Sekcja 1: Otwarte porty:" $TEMP_FILE_PORTS
    update_section "Sekcja 2: Połączenia TCP:" $TEMP_FILE_TCP_CONNECTIONS
    update_section "Sekcja 3: Połączenia UDP:" $TEMP_FILE_UDP_CONNECTIONS

    rm $TEMP_FILE_PORTS
    rm $TEMP_FILE_TCP_CONNECTIONS
    rm $TEMP_FILE_UDP_CONNECTIONS

    # Czekaj na kolejne zbieranie danych
    sleep $INTERVAL

done
