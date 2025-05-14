#!/bin/bash

# Stop if anything fails
set -e

# Spinner function
run_with_spinner() {
    local cmd="$1"
    local message="$2"
    local pid

    echo -n "$message"
    bash -c "$cmd" > /dev/null 2>&1 &
    pid=$!

    local spin='|/-\'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r$message ${spin:$i:1}"
        sleep 0.2
    done
    wait $pid
    printf "\r$message ✅\n"
}

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/tags/theme.tar.gz"

# Temporary directory
TEMP_DIR=$(mktemp -d)

echo "⏬ Theme downloaden..."
curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz" > /dev/null 2>&1

echo "📦 Uitpakken..."
tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR" > /dev/null 2>&1

# Zoek uitgepakte map
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")

if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

echo "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
cp -r "$THEME_DIR/"* /var/www/pterodactyl/ > /dev/null 2>&1

# Ga naar Pterodactyl map
cd /var/www/pterodactyl

# ✅ Install Node.js 20 and Yarn if not present
if ! command -v node > /dev/null 2>&1 || ! command -v yarn > /dev/null 2>&1; then
  run_with_spinner "sudo apt-get install -y ca-certificates curl gnupg" "📦 Benodigdheden installeren..."
  run_with_spinner "sudo mkdir -p /etc/apt/keyrings" "📁 Keyring-map maken..."
  run_with_spinner "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg" "🔑 Node.js sleutel toevoegen..."
  run_with_spinner "echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main' | sudo tee /etc/apt/sources.list.d/nodesource.list" "➕ Node.js repo toevoegen..."
  run_with_spinner "sudo apt-get update" "🔄 Apt updaten..."
  run_with_spinner "sudo apt-get install -y nodejs" "📦 Node.js installeren..."
  run_with_spinner "sudo npm install -g yarn" "📦 Yarn installeren..."
else
  echo "✅ Node.js en Yarn zijn al geïnstalleerd."
fi

run_with_spinner "yarn add react-feather" "📦 react-feather installeren..."
run_with_spinner "php artisan migrate --force" "🛠️ Database migreren..."
run_with_spinner "export NODE_OPTIONS=--openssl-legacy-provider" "⚙️ Node legacy provider instellen..."
run_with_spinner "yarn build:production" "🏗️ Productie build maken..."
run_with_spinner "php artisan view:clear" "🧹 Laravel views cache legen..."

echo "✅ Theme succesvol geïnstalleerd!"
