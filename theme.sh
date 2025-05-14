#!/bin/bash

# Stop if anything fails
set -e

# Spinner function for loading effect
run_with_spinner() {
    local message="$1"
    shift
    echo -n "$message..."

    "$@" > /dev/null 2>&1 &
    local pid=$!

    local spin='-\|/'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r$message... ${spin:$i:1}"
        sleep 0.1
    done

    wait $pid
    local status=$?

    if [ $status -ne 0 ]; then
        echo -e "\r$message... ❌"
        exit 1
    else
        echo -e "\r$message... ✅"
    fi
}

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/tags/theme.tar.gz"

# Temporary directory
TEMP_DIR=$(mktemp -d)

run_with_spinner "⏬ Theme downloaden" curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz"
run_with_spinner "📦 Theme uitpakken" tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR"

# Zoek uitgepakte map
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")

if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

run_with_spinner "🔁 Bestanden kopiëren naar /var/www/pterodactyl" cp -r "$THEME_DIR/"* /var/www/pterodactyl/

cd /var/www/pterodactyl

# Check Node.js
if command -v node > /dev/null 2>&1; then
    echo "🔎 Node.js is al geïnstalleerd."
else
    run_with_spinner "🔧 Node.js installeren" bash -c '
        sudo apt-get install -y ca-certificates curl gnupg > /dev/null
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
        sudo apt-get update > /dev/null
        sudo apt-get install -y nodejs > /dev/null'
fi

# Check Yarn
if command -v yarn > /dev/null 2>&1; then
    echo "🔎 Yarn is al geïnstalleerd."
else
    run_with_spinner "🧵 Yarn installeren" sudo npm install -g yarn
fi

run_with_spinner "📦 react-feather installeren" yarn add react-feather
run_with_spinner "🛠️ Database migreren" php artisan migrate --force

export NODE_OPTIONS=--openssl-legacy-provider

run_with_spinner "🏗️ Productie build maken" yarn build:production
run_with_spinner "🧹 Laravel views cache legen" php artisan view:clear

echo "✅ Theme succesvol geïnstalleerd!"
