#!/bin/bash

set -e

# Spinner functie
spinner() {
    local pid=$1
    local spin='|/-\\'
    local i=0

    tput civis  # Verberg cursor
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r[%c] " "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r[✓] "
    tput cnorm  # Herstel cursor
    echo
}

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/heads/main.tar.gz"
TEMP_DIR=$(mktemp -d)

# Download theme
echo -n "⏬ Theme downloaden..."
curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz" > /dev/null 2>&1 &
spinner $!

# Uitpakken
echo -n "📦 Uitpakken..."
tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR" > /dev/null 2>&1 &
spinner $!

# Theme folder zoeken
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")
if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

# Bestanden kopiëren
echo -n "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
cp -r "$THEME_DIR/"* /var/www/pterodactyl/ > /dev/null 2>&1 &
spinner $!

# Machtigingen
echo -n "🔑 Machtigingen instellen..."
(chown -R www-data:www-data /var/www/pterodactyl && chmod -R 755 /var/www/pterodactyl) > /dev/null 2>&1 &
spinner $!

cd /var/www/pterodactyl

# Node.js en Yarn
if command -v node > /dev/null 2>&1 && command -v yarn > /dev/null 2>&1; then
    echo "✅ Node.js en Yarn zijn al geïnstalleerd."
else
    echo -n "🔧 Node.js en Yarn installeren..."
    (
        sudo apt-get install -y ca-certificates curl gnupg
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt-get update
        sudo apt-get install -y nodejs
        sudo npm install -g yarn
    ) > /dev/null 2>&1 &
    spinner $!
fi

# React-feather installeren
echo -n "📦 react-feather installeren..."
yarn add react-feather > /dev/null 2>&1 &
spinner $!

# Database migreren
echo -n "🛠️ Database migreren..."
php artisan migrate --force > /dev/null 2>&1 &
spinner $!

# Legacy provider
echo -n "⚙️ Node legacy provider instellen..."
export NODE_OPTIONS=--openssl-legacy-provider
sleep 1 &
spinner $!

# Build maken
echo -n "🏗️ Productie build maken..."
yarn build:production > /dev/null 2>&1 &
spinner $!

# Laravel cache legen
echo -n "🧹 Laravel views cache legen..."
php artisan view:clear > /dev/null 2>&1 &
spinner $!

# Webserver herstarten
echo -n "🔄 Webserver herstarten..."
sudo systemctl restart nginx > /dev/null 2>&1 || true &
spinner $!

# Klaar
echo "✅ Theme succesvol geïnstalleerd!"
