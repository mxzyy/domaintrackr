#!/bin/bash

# Nama program
PROGRAM_NAME="alert.sh"
JSON_FILE="result.json"
TELEGRAM_BOT_TOKEN="" 
CHAT_ID=""              

# Fungsi untuk mengirimkan pesan ke Telegram
send_telegram_alert() {
    local domain=$1
    local registrar=$2
    local created=$3
    local expires=$4
    local days_remaining=$5
    local status=$6

    # Pesan yang akan dikirim ke Telegram
    local message="⚠️ *Peringatan Domain Expired* ⚠️\n\n"
    message+="*Domain*: $domain\n"
    message+="*Registrar*: $registrar\n"
    message+="*Tanggal Dibuat*: $created\n"
    message+="*Tanggal Expired*: $expires\n"
    message+="*Sisa Hari*: $days_remaining hari\n"
    message+="*Status*: $status\n\n"
    message+="Segera perbarui domain ini sebelum kadaluarsa! 🔄"

    # Mengirim pesan ke Telegram menggunakan API
    curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d "chat_id=$CHAT_ID" -d "text=$(echo -e "$message")" -d "parse_mode=markdown" 
}

# Fungsi untuk memeriksa sisa hari di result.json
check_domain_expiry() {
    # Membaca setiap domain dari file JSON
    domains=$(jq -c '.[]' $JSON_FILE)
    if [[ $? -ne 0 ]]; then
        echo "Error membaca file JSON!"
        exit 1
    fi

    while IFS= read -r entry; do
    # Mengambil nilai dari setiap kunci
    domain=$(echo "$entry" | jq -r '.domain')
    registrar=$(echo "$entry" | jq -r '.registrar')
    created=$(echo "$entry" | jq -r '.created')
    expires=$(echo "$entry" | jq -r '.expires')
    days_remaining=$(echo "$entry" | jq -r '.days_remaining')
    status=$(echo "$entry" | jq -r '.status')

        if [[ $days_remaining -le 7 && $days_remaining -ge 0 ]]; then
            echo "Mengirimkan alert untuk domain: $domain (Sisa hari: $days_remaining)"
            send_telegram_alert "$domain" "$registrar" "$created" "$expires" "$days_remaining" "$status"
        fi

    done <<< "$domains"
}

# Memulai program
echo "$PROGRAM_NAME - Memeriksa domain yang akan expired dalam waktu dekat"

# Cek apakah file JSON ada
if [[ ! -f $JSON_FILE ]]; then
    echo "File $JSON_FILE tidak ditemukan!"
    exit 1
fi

# Jalankan pengecekan
check_domain_expiry
