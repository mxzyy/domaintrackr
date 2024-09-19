#!/bin/bash

# Nama program
PROGRAM_NAME="domtrackr"
OUTPUT_FILE="result.json"

# Fungsi untuk menampilkan bantuan
show_help() {
    cat << "EOF"
______                      _     _____              _         
|  _  \                    (_)   |_   _|            | |        
| | | |___  _ __ ___   __ _ _ _ __ | |_ __ __ _  ___| | ___ __ 
| | | / _ \| '_ ` _ \ / _` | | '_ \| | '__/ _` |/ __| |/ / '__|
| |/ / (_) | | | | | | (_| | | | | | | | | (_| | (__|   <| |   
|___/ \___/|_| |_| |_|\__,_|_|_| |_\_/_|  \__,_|\___|_|\_\_|    
EOF
    printf "%-30s\n" "-------------------------------------------------------------"
    echo "$PROGRAM_NAME - Cek status domain dan ekspor hasil ke JSON"
    echo "Usage:"
    echo "  -u <url>     Cek status satu domain"
    echo "  -l <file>    Baca beberapa domain dari file"
    echo "  -h           Tampilkan bantuan ini"
    exit 1
}

# Fungsi untuk menghitung sisa hari
calculate_days_remaining() {
    local expiry_date=$1
    expiry_seconds=$(date -d "$expiry_date" +%s)
    current_seconds=$(date +%s)
    days_remaining=$(( (expiry_seconds - current_seconds) / 86400 ))
    echo $days_remaining
}

# Fungsi untuk mengubah format tanggal
format_date() {
    local raw_date=$1
    formatted_date=$(date -d "$raw_date" +"%d/%m/%Y")
    echo $formatted_date
}

# Fungsi untuk mencetak header tabel
print_table_header() {
    printf "%-25s %-20s %-20s %-20s %-10s\n" "Domain" "Dibuat Oleh" "Tanggal Dibuat" "Tanggal Expired" "Sisa Hari"
    printf "%-25s %-20s %-20s %-20s %-10s\n" "-------------------------" "-------------------" "-------------------" "-------------------" "---------"
}

# Fungsi untuk menampilkan hasil dalam format tabel
print_table_row() {
    printf "%-25s %-20s %-20s %-20s %-10s\n" "$1" "$2" "$3" "$4" "$5"
}

# Fungsi Init Memeriksa
init_check_domain() {
    if [[ $2 == "u" ]]; then
        local domain=$1
        echo "Memeriksa domain: $domain"
    elif [[ $2 == "l" ]]; then
        local file=$1
        local list=($(cat $1))
        IFS=',  '; echo "Memeriksa domain: ${list[*]}"
    else
        echo "err"
    fi
}

# Fungsi untuk cek domain
check_domain() {
    local domain=$1
    # Ping domain untuk cek apakah masih hidup
    if ping -c 1 $domain &> /dev/null; then
        status="Domain masih hidup"
    else
        status="Domain tidak dapat diakses"
    fi

    # Gunakan whois untuk mendapatkan detail domain
    whois_output=$(whois $domain)
    
    # Ambil informasi tentang pendaftar dan tanggal pembuatan/expirasi
    registrar=$(echo "$whois_output" | grep -i "Registrar:" | head -n 1 | cut -d ":" -f 2 | xargs | tr -d ',')
    created=$(echo "$whois_output" | grep -i "Creation Date" | head -n 1 | cut -d ":" -f 2- | xargs)
    expires=$(echo "$whois_output" | grep -i "Registry Expiry Date" | head -n 1 | cut -d ":" -f 2- | xargs)

    # Format tanggal
    formatted_created=$(format_date "$created")
    formatted_expires=$(format_date "$expires")

    # Hitung berapa hari lagi domain akan expired
    days_remaining=$(calculate_days_remaining "$expires")

    # Tampilkan hasil ke tabel
    print_table_row "$domain" "${registrar:-Tidak ditemukan}" "${formatted_created:-Tidak ditemukan}" "${formatted_expires:-Tidak ditemukan}" "${days_remaining:-Tidak diketahui}"

    # Simpan atau perbarui hasil ke file JSON
    save_to_json "$domain" "$registrar" "$formatted_created" "$formatted_expires" "$days_remaining" "$status"
}

# Fungsi untuk menyimpan atau memperbarui data ke JSON
save_to_json() {
    local domain=$1
    local registrar=$2
    local created=$3
    local expires=$4
    local days_remaining=$5
    local status=$6

    # Jika file JSON belum ada, buat file JSON kosong
    if [[ ! -f $OUTPUT_FILE ]]; then
        echo "[]" > $OUTPUT_FILE
    fi

    # Periksa apakah domain sudah ada di file JSON
    if jq -e --arg domain "$domain" '.[] | select(.domain == $domain)' $OUTPUT_FILE > /dev/null; then
        # Jika domain sudah ada, perbarui data
        jq --arg domain "$domain" \
           --arg registrar "$registrar" \
           --arg created "$created" \
           --arg expires "$expires" \
           --argjson days_remaining "$days_remaining" \
           --arg status "$status" \
           '(.[] | select(.domain == $domain) |
           .registrar = $registrar |
           .created = $created |
           .expires = $expires |
           .days_remaining = $days_remaining |
           .status = $status)' $OUTPUT_FILE > temp.json && mv temp.json $OUTPUT_FILE
    else
        # Jika domain belum ada, tambahkan data baru
        jq --arg domain "$domain" \
           --arg registrar "$registrar" \
           --arg created "$created" \
           --arg expires "$expires" \
           --argjson days_remaining "$days_remaining" \
           --arg status "$status" \
           '. += [{"domain": $domain, "registrar": $registrar, "created": $created, "expires": $expires, "days_remaining": $days_remaining, "status": $status}]' $OUTPUT_FILE > temp.json && mv temp.json $OUTPUT_FILE
    fi
}

# Cek apakah argumen diberikan
if [[ $# -eq 0 ]]; then
    show_help
fi

# Parsing argumen
while getopts ":u:l:h" opt; do
    case ${opt} in
        u )
            # Cetak header tabel
            init_check_domain "$OPTARG" "u"
            print_table_header
            check_domain "$OPTARG"
            echo "Hasil disimpan ke $OUTPUT_FILE"
            ;;
        l )
            if [[ -f "$OPTARG" ]]; then
                # Cetak header tabel
                init_check_domain "$OPTARG" "l"
                print_table_header
                while IFS= read -r domain; do
                    check_domain "$domain"
                done < "$OPTARG"
                echo "Hasil disimpan ke $OUTPUT_FILE"
            else
                echo "File tidak ditemukan: $OPTARG"
                exit 1
            fi
            ;;
        h )
            show_help
            ;;
        \? )
            show_help
            ;;
    esac
done

# Jika tidak menggunakan -u atau -l, tampilkan bantuan
if [[ $OPTIND -eq 1 ]]; then
    show_help
fi
