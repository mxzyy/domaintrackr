#!/bin/bash

REPO_URL="https://github.com/mxzyy/domaintrackr.git"
INSTALL_DIR="$HOME/domaintrackr"

if ! command -v git &> /dev/null; then
    echo "git tidak ditemukan. Menginstal git..."
    sudo apt-get update
    sudo apt-get install -y git whois iputils-ping
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Mengkloning repositori..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Repositori sudah ada di $INSTALL_DIR. Melakukan update..."
    cd "$INSTALL_DIR" || exit
    git pull origin main  
fi

chmod +x "$INSTALL_DIR"/*.sh

echo "Menjalankan program..."
cd "$INSTALL_DIR" || exit
./app.sh -u codingcollective.com -l lists.txt
./alert.sh
./export.sh

CRON_JOB="@daily cd $INSTALL_DIR && ./app.sh
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./export.sh
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./alert.sh"

(crontab -l; echo -e "$CRON_JOB") | crontab -

echo "Instalasi selesai"
