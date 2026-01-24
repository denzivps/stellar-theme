#!/bin/bash

# Zorg dat het script stopt bij fouten
set -e

# --- FUNCTIES ---
show_spinner() {
    local pid=$1
    local delay=0.1
    local spin='|/-\\'
    local i=0
    tput civis
    while kill -0 $pid 2>/dev/null; do
        printf "\r[%c] %s" "${spin:i++%${#spin}:1}" "$SPINNER_TEXT"
        sleep $delay
    done
    printf "\r[✔] %s\n" "$SPINNER_TEXT"
    tput cnorm
}

run_step() {
    SPINNER_TEXT="$1"
    shift
    "$@" > /dev/null 2>&1 &
    show_spinner $!
}

# --- CONFIGURATIE ---
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/heads/main.tar.gz"
TEMP_DIR=$(mktemp -d)
PTERO_DIR="/var/www/pterodactyl"

echo -e "\e[36m🚀 Start Stellar Theme Installatie met Webpack-Fix...\e[0m"

# 1. Node.js 22 & Yarn Installeren/Upgraden
echo "🔧 Node.js 22 en Yarn voorbereiden..."
run_step "Node.js 22 installeren..." bash -c '
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt-get update
    apt-get install -y nodejs
    npm install -g yarn
'

# 2. Theme downloaden en uitpakken
echo "⏬ Theme ophalen..."
run_step "Downloaden..." curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz"
run_step "Uitpakken..." tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR"

THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")
echo "🔁 Bestanden overzetten..."
cp -r "$THEME_DIR/"* "$PTERO_DIR/"

# 3. Naar de Pterodactyl map
cd "$PTERO_DIR"

# 4. Vereiste extra pakketten installeren
echo "📦 Node modules installeren..."
run_step "Pakketten toevoegen (react-feather & path-browserify)..." yarn add react-feather path-browserify

# 5. DE WEBPACK FIX (Automatische bewerking van webpack.config.js)
echo "🛠️ Webpack config patchen..."
run_step "Patch toepassen..." bash -c '
    if ! grep -q "path-browserify" webpack.config.js; then
        # Zoek naar symlinks: false, en voeg de fallback daaronder toe
        sed -i "/symlinks: false,/a \        fallback: { \"path\": require.resolve(\"path-browserify\") }," webpack.config.js
    fi
'

# 6. Build proces
echo "🏗️ Productie build maken (dit duurt enkele minuten)..."
export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=4096"
# We draaien deze zonder run_step om eventuele fouten live te zien
yarn build:production

# 7. Afronden (Database, Cache, Rechten)
echo "🧹 Systeem optimaliseren..."
run_step "Database migreren..." php artisan migrate --force
run_step "Cache legen..." php artisan view:clear
run_step "Rechten herstellen..." chown -R www-data:www-data "$PTERO_DIR"/*

# 8. Webserver herstarten
echo "🔄 Webserver herstarten..."
systemctl restart nginx || true

echo -e "\n\e[92m✅ INSTALLATIE VOLTOOID!\e[0m"
echo -e "\e[33mJe Stellar Theme is nu geïnstalleerd met de juiste Node 22 instellingen.\e[0m"

# Schoonmaak
rm -rf "$TEMP_DIR"
