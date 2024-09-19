#!/bin/bash

# Mengatur variabel
REPO_URL="https://github.com/username/repo.git"  # Ganti dengan URL repositori GitHub Anda
INSTALL_DIR="$HOME/my_program"                     # Direktori tempat menginstal program

# Menginstal git jika belum ada
if ! command -v git &> /dev/null; then
    echo "git tidak ditemukan. Menginstal git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

# Mengkloning repositori
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Mengkloning repositori..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Repositori sudah ada di $INSTALL_DIR. Melakukan update..."
    cd "$INSTALL_DIR" || exit
    git pull origin main  # Ganti 'main' dengan branch yang sesuai
fi

# Menjalankan program untuk pertama kali (sesuaikan dengan perintah yang diperlukan)
echo "Menjalankan program..."
cd "$INSTALL_DIR" || exit

# Misalnya jika ada perintah untuk menjalankan program
# ./app.sh &
# ./export.sh &
# ./alert.sh &

# Menambahkan cron job untuk menjalankan ketiga program setiap hari
CRON_JOB="@daily cd $INSTALL_DIR && ./app.sh >> $INSTALL_DIR/app.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./export.sh >> $INSTALL_DIR/export.log 2>&1"
CRON_JOB+="\n@daily cd $INSTALL_DIR && ./alert.sh >> $INSTALL_DIR/alert.log 2>&1"

# Memperbarui crontab
(crontab -l; echo -e "$CRON_JOB") | crontab -

echo "Instalasi selesai. Ketiga program akan dijalankan setiap hari."
