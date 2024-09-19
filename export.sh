#!/bin/bash

# Nama file JSON dan CSV
JSON_FILE="result.json"
CSV_FILE="result.csv"
TELEGRAM_BOT_TOKEN="6269039385:AAFG8_BkyqVHKTIsq6qLgY1WeBMF_96z8xo" 
CHAT_ID="-1002184336839"

# Fungsi untuk mengubah JSON ke CSV
json_to_csv() {
    if [[ ! -f $JSON_FILE ]]; then
        echo "File $JSON_FILE tidak ditemukan!"
        exit 1
    fi

    # Buat header untuk CSV
    echo "Domain,Registrar,Tanggal Dibuat,Tanggal Expired,Sisa Hari,Status" > $CSV_FILE

    # Ekspor data dari JSON ke CSV menggunakan jq
    jq -r '.[] | [.domain, .registrar, .created, .expires, .days_remaining, .status] | @csv' $JSON_FILE >> $CSV_FILE

    if [[ $? -eq 0 ]]; then
        echo "Berhasil mengekspor $JSON_FILE ke $CSV_FILE"
    else
        echo "Gagal mengekspor file!"
        exit 1
    fi
}

# Fungsi untuk mengirimkan file CSV ke Telegram
send_csv_to_telegram() {
    curl -F "chat_id=$CHAT_ID" \
         -F "document=@$CSV_FILE" \
         "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" > /dev/null

    if [[ $? -eq 0 ]]; then
        echo "Berhasil mengirim file $CSV_FILE ke Telegram"
    else
        echo "Gagal mengirim file ke Telegram!"
    fi
}

# Jalankan konversi JSON ke CSV
json_to_csv

# Kirimkan file CSV ke Telegram
send_csv_to_telegram
