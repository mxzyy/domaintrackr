#!/bin/bash

REPO_URL="https://github.com/mxzyy/domaintrackr.git"
INSTALL_DIR="$HOME/domaintrackr"

if ! command -v git &> /dev/null; then
    echo "git tidak ditemukan. Menginstal git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Mengkloning repositori..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Repositori sudah ada di $INSTALL_DIR. Melakukan update..."
    cd "$INSTALL_DIR" || exit
    git pull origin main  
fi


echo "Menjalankan program..."
cd "$INSTALL_DIR" || exit


CRON_JOB="@daily cd $INSTALL_DIR && ./app.sh >> $INSTALL_DIR/app.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./export.sh >> $INSTALL_DIR/export.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./alert.sh >> $INSTALL_DIR/alert.log 2>&1"

(crontab -l; echo -e "$CRON_JOB") | crontab -

echo "Instalasi selesai."
