#!/bin/bash

# Stop als er iets fout gaat
set -e

# Functie voor laad-animatie
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/tags/theme.tar.gz"

# Tijdelijke map
TEMP_DIR=$(mktemp -d)

echo "⏬ Theme downloaden..."
(curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz" > /dev/null 2>&1) & spinner

echo "📦 Uitpakken..."
(tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR" > /dev/null 2>&1) & spinner

# Zoek uitgepakte map
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")

if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

echo "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
(cp -r "$THEME_DIR/"* /var/www/pterodactyl/ > /dev/null 2>&1) & spinner

cd /var/www/pterodactyl

# ✅ Node.js en Yarn alleen installeren als ze ontbreken
if ! command -v node > /dev/null 2>&1 || ! command -v yarn > /dev/null 2>&1; then
    echo "🔧 Node.js en Yarn installeren..."
    (
        sudo apt-get install -y ca-certificates curl gnupg > /dev/null 2>&1
        sudo mkdir -p /etc/apt/keyrings > /dev/null 2>&1
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg > /dev/null 2>&1
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null 2>&1
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y nodejs > /dev/null 2>&1
        sudo npm install -g yarn > /dev/null 2>&1
    ) & spinner
else
    echo "✅ Node.js en Yarn zijn al geïnstalleerd."
fi

echo "📦 react-feather installeren..."
(yarn add react-feather > /dev/null 2>&1) & spinner

echo "🛠️ Database migreren..."
(php artisan migrate --force > /dev/null 2>&1) & spinner

echo "⚙️ Node legacy provider instellen..."
(export NODE_OPTIONS=--openssl-legacy-provider) & spinner

echo "🏗️ Productie build maken..."
(yarn build:production > /dev/null 2>&1) & spinner

echo "🧹 Laravel views cache legen..."
(php artisan view:clear > /dev/null 2>&1) & spinner

echo "✅ Theme succesvol geïnstalleerd!"
