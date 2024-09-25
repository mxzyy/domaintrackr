#!/bin/bash

# Nama program
PROGRAM_NAME="alert.sh"
JSON_FILE="result.json"
TELEGRAM_BOT_TOKEN=""
CHAT_ID=""        

send_new_domain() {
    local domain=$1
    local is_new=$2
    local message="Domain $domain telah ditambahkan!\n"
    if [ $is_new == "yes" ]; then
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d "chat_id=$CHAT_ID" -d "text=$(echo -e "$message")" -d "parse_mode=markdown" > /dev/null
    fi
}

# Fungsi untuk mengirimkan pesan ke Telegram
send_telegram_alert() {
    local domain=$1
    local registrar=$2
    local created=$3
    local expires=$4
    local days_remaining=$5
    local status=$6
    local is_new=$7

    # Pesan yang akan dikirim ke Telegram
    local message="⚠️ *Peringatan Domain Expired* ⚠️\n\n"
    message+="*Domain*: $domain\n"
    message+="*Registrar*: $registrar\n"
    message+="*Tanggal Dibuat*: $created\n"
    message+="*Tanggal Expired*: $expires\n"
    message+="*Sisa Hari*: $days_remaining hari\n"
    message+="*Status*: $status\n\n"
    message+="Segera perbarui domain ini sebelum kadaluarsa! 🔄"

    local expired_message="⚠️ *Peringatan Domain Expired* ⚠️\n\n"
    expired_message+="$domain akan expired dalam $days_remaining kedepan"

    local today_message="⚠️ *PERINGATAN DOMAIN EXPIRED TODAY!* ⚠️\n\n"
    today_message+="$domain akan expired HARI INI!!!!!"

    # Mengirim pesan ke Telegram menggunakan API
    if [ "$days_remaining" -ge 2 ]; then
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d "chat_id=$CHAT_ID" -d "text=$(echo -e "$expired_message")" -d "parse_mode=markdown" > /dev/null
    elif [ $days_remaining = 0 ]; then
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d "chat_id=$CHAT_ID" -d "text=$(echo -e "$today_message")" -d "parse_mode=markdown" > /dev/null
    else
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d "chat_id=$CHAT_ID" -d "text=$(echo -e "$message")" -d "parse_mode=markdown" > /dev/null
    fi
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
    is_new=$(echo "$entry" | jq -r '.is_new')

    send_new_domain $domain $is_new

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
