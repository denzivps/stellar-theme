#!/bin/bash

# Stop als er iets fout gaat
set -e

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/tags/pterodactyl.tar.gz"

# Tijdelijke map
TEMP_DIR=$(mktemp -d)

echo "⏬ Theme downloaden..."
curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz"

echo "📦 Uitpakken..."
tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR"

# Zoek uitgepakte map
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")

if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

echo "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
cp -r "$THEME_DIR/"* /var/www/pterodactyl/

# Ga naar Pterodactyl map
cd /var/www/pterodactyl

echo "📦 react-feather installeren..."
yarn add react-feather

echo "🛠️ Database migreren..."
yes | php artisan migrate

echo "⚙️ Node legacy provider instellen..."
export NODE_OPTIONS=--openssl-legacy-provider

echo "🏗️ Productie build maken..."
yarn build:production

echo "🧹 Laravel views cache legen..."
php artisan view:clear

echo "✅ Theme succesvol geïnstalleerd!"
