#!/bin/bash

BOT_TOKEN=""
CHAT_ID=""
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"
DATA_FILE="result.json"
HOUR=

if [[ ! -f $DATA_FILE ]]; then
    echo "[]" > $DATA_FILE
fi


send_message() {
    local CHAT_ID=$1
    local MESSAGE=$2

  curl -s -X POST "${API_URL}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d "parse_mode=markdown" \
    -d text="$(echo -e $MESSAGE)" > /dev/null
}

format_date() {
    local raw_date=$1
    formatted_date=$(date -d "$raw_date" +"%d/%m/%Y")
    echo $formatted_date
}

calculate_days_remaining() {
    local expiry_date=$1
    expiry_seconds=$(date -d "$expiry_date" +%s)
    current_seconds=$(date +%s)
    days_remaining=$(( (expiry_seconds - current_seconds) / 86400 ))
    echo $days_remaining
}

check_domain() {
    local CHAT_ID=$1
    local DOMAIN=$2
    echo "checkdomain: $DOMAIN, chatid: $CHAT_ID"
    if ping -c 1 $DOMAIN &> /dev/null; then
        STATUS="Active"
        local IP_ADDR=$(ping -c 1 $DOMAIN | grep -oP '(?<=\().*?(?=\))')
        send_message "$CHAT_ID" "checking, $DOMAIN"
        sleep 0.6
        send_message "$CHAT_ID" "got Ip, $IP_ADDR"
    else
        STATUS="Inactive"
    fi

    local whois=$(whois $DOMAIN)
    REGISTRAR=$(echo "$whois" | grep -i "Registrar:" | head -n 1 | cut -d ":" -f 2 | xargs | tr -d ',')
    CREATED=$(echo "$whois" | grep -i "Creation Date" | head -n 1 | cut -d ":" -f 2- | xargs)
    EXPIRED=$(echo "$whois" | grep -i "Registry Expiry Date" | head -n 1 | cut -d ":" -f 2- | xargs)
    CREATED_DATE=$(format_date "$CREATED")
    EXPIRED_DATE=$(format_date "$EXPIRED")
    DAYS_REMAINING=$(calculate_days_remaining "$EXPIRED")
    NOW=$(date "+%d/%m/%y %H:%M")

    local message="🌐 *INFO DOMAIN* 🌐\n\n"
    message+="*Waktu*: [$NOW]\n"
    message+="*Domain*: $DOMAIN\n"
    message+="*Registrar*: $REGISTRAR\n"
    message+="*Tanggal Dibuat*: $CREATED_DATE\n"
    message+="*Tanggal Expired*: $EXPIRED_DATE\n"
    message+="*Sisa Hari*: $DAYS_REMAINING hari\n"
    message+="*Status*: $STATUS\n\n"

    local live_message+="Umur domain masih panjang, sans! 😄"

    local expired_message="⚠️ *Peringatan Domain Expired* ⚠️\n\n"
    expired_message+="$DOMAIN akan expired dalam $DAYS_REMAINING. segera lakukan Update!"

    local today_message="😨 *PERINGATAN BERAT BANGET* 😧\n\n"
    today_message+="$DOMAIN akan expired HARI INI!!!!! 💀💀💀💀💀💀💀💀"

    # Mengirim pesan ke Telegram menggunakan API
    if [ $DAYS_REMAINING = 0 ]; then
        send_message "$CHAT_ID" "$message"
        send_message "$CHAT_ID" "$today_message"
    elif  [ "$DAYS_REMAINING" -le 30 ]; then
        send_message "$CHAT_ID" "$message"
        send_message "$CHAT_ID" "$expired_message" 
    else
        send_message "$CHAT_ID" "$message"
        send_message "$CHAT_ID" "$live_message"
    fi

    echo "sebelum jq"
    save_to_json "$DOMAIN" "$REGISTRAR" "$CREATED_DATE" "$EXPIRED_DATE" "$DAYS_REMAINING" "$STATUS"
}   

save_to_json() {
    local domain=$1
    local registrar=$2
    local created=$3
    local expires=$4
    local days_remaining=$5
    local status=$6

    if [[ ! -f $DATA_FILE ]]; then
        echo "[]" > $DATA_FILE
    fi

    if jq -e --arg domain "$domain" '.[] | select(.domain == $domain)' $DATA_FILE > /dev/null; then
        jq --arg domain "$domain" \
            --arg registrar "$registrar" \
            --arg created "$created" \
            --arg expires "$expires" \
            --argjson days_remaining "$days_remaining" \
            --arg status "$status" \
            --arg is_new "no" \
            'map(if .domain == $domain then
                .registrar = $registrar |
                .created = $created |
                .expires = $expires |
                .days_remaining = $days_remaining |
                .status = $status |
                .is_new = $is_new
            else
                .
            end)' "$DATA_FILE" > temp.json && mv temp.json "$DATA_FILE"
    else
        jq --arg domain "$domain" \
           --arg registrar "$registrar" \
           --arg created "$created" \
           --arg expires "$expires" \
           --argjson days_remaining "$days_remaining" \
           --arg status "$status" \
           --arg is_new "yes" \
           '. += [{"domain": $domain, "registrar": $registrar, "created": $created, "expires": $expires, "days_remaining": $days_remaining, "status": $status, "is_new": $is_new}]' $DATA_FILE > temp.json && mv temp.json $DATA_FILE
    fi
}

show_list() {
    CHAT_ID=$1
    if [ ! -f "$DATA_FILE" ]; then
        echo "File $DATA_FILE tidak ditemukan."
    fi

    if [ ! -s "$DATA_FILE" ] || ! jq -e . >/dev/null 2>&1 <"$DATA_FILE"; then
        echo "File $DATA_FILE kosong atau bukan format JSON yang valid."
    fi

    DOMAINS=$(jq -r '.[] | "\(.domain)"' $DATA_FILE)

    if [ -z "$DATA_FILE" ]; then
        echo "Tidak ada data domain yang ditemukan."
    fi

    i=1
    MESSAGE="Daftar Nama Domain:\n"

    while IFS= read -r DOMAIN; do
        MESSAGE+="$i. $DOMAIN\n"
        ((i++))
    done <<< "$DOMAINS"
    
    send_message "$CHAT_ID" "$MESSAGE"
}

IS_FIRST="true"
daily_check() {
    echo "daily check"
    local first=$1
    echo $first
    local CHAT_ID="1514282558"
    if [[ "$first" == "true" ]]; then 
        cat "$DATA_FILE" | jq -r '.[].domain' | while read -r domain; do
            cleaned_text=$(echo -n "$domain" | tr -d '\n' | sed ':a;N;$!ba;s/\n//g')
            check_domain "$CHAT_ID" "$cleaned_text"
        done
    fi
    IS_FIRST="false"
}

LAST_UPDATE_ID=0
HOUR=00
while true; do
    RESPONSE=$(curl -s "${API_URL}/getUpdates?offset=$((LAST_UPDATE_ID + 1))")
    UPDATE_ID=$(echo "$RESPONSE" | jq -r '.result[-1].update_id')
    CHAT_ID=$(echo "$RESPONSE" | jq -r '.result[-1].message.chat.id')
    USERNAME=$(echo "$RESPONSE" | jq -r '.result[-1].message.from.username')
    MESSAGE_TEXT=$(echo "$RESPONSE" | jq -r '.result[-1].message.text')

    if [[ "$MESSAGE_TEXT" == "/hello" && "$UPDATE_ID" != "null" ]]; then
        send_message "$CHAT_ID" "Hello, $USERNAME"
        LAST_UPDATE_ID=$UPDATE_ID
    fi

    if [[ "$MESSAGE_TEXT" == "/help" && "$UPDATE_ID" != "null" ]]; then
        help="DOMAINTRACKER HELP FUNCTION 💠\n"
        help+="/hello  untuk menyapa bot.\n"
        help+="/list   untuk cek list domain yang dipantau.\n"
        help+="/time   untuk cek waktu daily check.\n"
        help+="/check  untuk menambahkan domain ke list.\n"
        help+="/delete untuk hapus domain dari list\n"
        send_message "$CHAT_ID" "$help"
        LAST_UPDATE_ID=$UPDATE_ID
    fi

    if [[ "$MESSAGE_TEXT" == "/list" && "$UPDATE_ID" != "null" ]]; then
        show_list "$CHAT_ID"
        LAST_UPDATE_ID=$UPDATE_ID
    fi

    
    if [[ "$MESSAGE_TEXT" == /time* && "$UPDATE_ID" != "null" ]]; then        
        PARAM=$(echo "$MESSAGE_TEXT" | cut -d' ' -f2-)
        #echo "$PARAM"
        if [ "$PARAM" == "/time" ]; then
            send_message "$CHAT_ID" "🔴 Waktu daily check setiap Jam $HOUR\nUntuk ganti gunakan /time ( int )"
        else
            HOUR=$PARAM
            send_message "$CHAT_ID" "⏲ Waktu telah diset setiap Jam $HOUR"
        fi
        LAST_UPDATE_ID=$UPDATE_ID
    fi

    if [[ "$MESSAGE_TEXT" == /check* && "$UPDATE_ID" != "null" ]]; then
        PARAM=$(echo "$MESSAGE_TEXT" | cut -d' ' -f2-)
        DOMAIN_REGEX="^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$"
        if  [[ $PARAM =~ $DOMAIN_REGEX ]]; then
            DOMAIN="$PARAM"
            send_message "$CHAT_ID" "🌐 Mengecek Domain $DOMAIN dalam DB! "
            if jq -r --arg domain "$DOMAIN" '.[] | select(.domain == $domain) | .domain' "$DATA_FILE"; then
                send_message "$CHAT_ID" "❗ Domain Sudah pernah ditambahkan, melakukan Update!"
                check_domain "$CHAT_ID" "$DOMAIN"
            else
                send_message "$CHAT_ID" "📌 Menambahkan Domain: $DOMAIN"
                check_domain "$CHAT_ID" "$DOMAIN"
            fi
        else
            send_message "$CHAT_ID" "🔴 [ERROR:134] : Regex check Failed!\nUsage: /check ( DOMAIN )"
        fi  
        
        LAST_UPDATE_ID=$UPDATE_ID
    fi

    if [[ "$MESSAGE_TEXT" == /delete* && "$UPDATE_ID" != "null" ]]; then
        PARAM=$(echo "$MESSAGE_TEXT" | cut -d' ' -f2-)
        DOMAIN_REGEX="^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$"
        if  [[ $PARAM =~ $DOMAIN_REGEX ]]; then
            DOMAIN="$PARAM"
            jq --arg domain "$DOMAIN" 'map(select(.domain != $domain))' "$DATA_FILE" > updated_res.json
            mv updated_res.json "$DATA_FILE"
        else
            send_message "$CHAT_ID" "🔴 [ERROR:134] : Regex check Failed!\nUsage: /delete ( DOMAIN )"
        fi
        LAST_UPDATE_ID=$UPDATE_ID
    fi
    
    if [[ $(date +%H) == "$HOUR" ]]; then
        daily_check "$IS_FIRST"
    else
        IS_FIRST="true"
    fi

    sleep 2
done
