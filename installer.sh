#!/bin/bash

REPO_URL="https://github.com/mxzyy/domaintrackr.git"
INSTALL_DIR="$HOME/domaintrackr"
PACKAGES=("iputils-ping" "git" "jq" "whois")

# Memeriksa setiap paket
for PACKAGE in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $PACKAGE"; then
        echo "$PACKAGE sudah terinstal."
    else
        echo "$PACKAGE belum terinstal. Installing sekarang"
        # Menambahkan perintah untuk menginstal paket jika belum terinstal
        sudo apt-get install -y "$PACKAGE"
    fi
done


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
chmod +x $INSTALL_DIR/*.sh
cd "$INSTALL_DIR" || exit
./app.sh -u codingcollective.com -l lists.txt
./alert.sh
./export.sh

CRON_JOB="@daily cd $INSTALL_DIR && ./app.sh"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./export.sh"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./alert.sh "

(crontab -l; echo -e "$CRON_JOB") | crontab -

echo "Instalasi selesai"
