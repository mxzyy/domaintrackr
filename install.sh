#!/bin/bash

REPO_URL="https://github.com/mxzyy/domaintrackr.git"
INSTALL_DIR="$HOME/domaintrackr"

if ! command -v git &> /dev/null; then
    echo "git tidak ditemukan. Menginstal git..."
    sudo apt-get update
    sudo apt-get install -y git whois iputils-ping jq
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Mengkloning repositori..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Repositori sudah ada di $INSTALL_DIR. Melakukan update..."
    cd "$INSTALL_DIR" || exit
    git pull origin main  
fi

read -p "Masukkan token_id: " NEW_TOKEN
read -p "Masukkan chat_id: " CHAT_ID

sed -i "s/TELEGRAM_BOT_TOKEN=\"[^\"]*\"/TELEGRAM_BOT_TOKEN=\"$NEW_TOKEN\"/" $INSTALL_DIR/export.sh
sed -i "s/TELEGRAM_BOT_TOKEN=\"[^\"]*\"/TELEGRAM_BOT_TOKEN=\"$NEW_TOKEN\"/" $INSTALL_DIR/alert.sh
sed -i "s/CHAT_ID=\"[^\"]*\"/CHAT_ID=\"$CHAT_ID\"/" $INSTALL_DIR/export.sh
sed -i "s/CHAT_ID=\"[^\"]*\"/CHAT_ID=\"$CHAT_ID\"/" $INSTALL_DIR/alert.sh

echo "Menjalankan program..."
cd "$INSTALL_DIR" || exit
./app.sh -u codingcollective.com -l lists.txt
./alert.sh
./export.sh

CRON_JOB="@daily cd $INSTALL_DIR && ./app.sh >> $INSTALL_DIR/app.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./export.sh >> $INSTALL_DIR/export.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./alert.sh >> $INSTALL_DIR/alert.log 2>&1"

(crontab -l; echo -e "$CRON_JOB") | crontab -

echo "Instalasi selesai"
