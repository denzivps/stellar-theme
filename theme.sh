#!/bin/bash

set -e

# Spinner functie (ASCII, werkt altijd)
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

# Functie om spinner te combineren met commando
run_step() {
    SPINNER_TEXT="$1"
    shift
    "$@" > /dev/null 2>&1 &
    show_spinner $!
}

# Theme URL + tijdelijke map
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/heads/main.tar.gz"
TEMP_DIR=$(mktemp -d)

# Duidelijke echo's met iconen
echo "⏬ Theme downloaden..."
run_step "Theme downloaden..." curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz"

echo "📦 Uitpakken..."
run_step "Theme uitpakken..." tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR"

THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")
if [ ! -d "$THEME_DIR" ]; then
    echo "❌ Theme-map niet gevonden."
    exit 1
fi

echo "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
run_step "Bestanden kopiëren..." cp -r "$THEME_DIR/"* /var/www/pterodactyl/

echo "🔑 Machtigingen instellen..."
run_step "Rechten instellen..." bash -c "chown -R www-data:www-data /var/www/pterodactyl && chmod -R 755 /var/www/pterodactyl"

# Zorg dat 'read' input pakt van de echte terminal
read_from_terminal() {
    local dummy
    read -r -p "$1" dummy < /dev/tty
}

# 💖 Stap 1: Bedankt-bericht
echo -e "\e[95m"
echo "✅ Bedankt voor het gebruiken van deze installer!"
echo
read_from_terminal "Druk op Enter om het hart te tonen..."

# 💖 Stap 2: Hart tonen
echo -e "\e[95m"
echo "        ******       ******"
echo "      **********   **********"
echo "    ************* *************"
echo "   *****************************"
echo "   *****************************"
echo "    ***************************"
echo "      ***********************"
echo "        *******************"
echo "          ***************"
echo "            ***********"
echo "              *******"
echo "                ***"
echo "                 *"
echo
read_from_terminal "Druk op Enter om verder te gaan..."
echo -e "\e[0m"

cd /var/www/pterodactyl

if command -v node > /dev/null 2>&1 && command -v yarn > /dev/null 2>&1; then
    echo "✅ Node.js en Yarn zijn al geïnstalleerd."
else
    echo "🔧 Node.js en Yarn installeren..."
    run_step "Node.js + Yarn installeren..." bash -c '
        sudo apt-get install -y ca-certificates curl gnupg
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt-get update
        sudo apt-get install -y nodejs
        sudo npm install -g yarn
    '
fi

echo "📦 react-feather installeren..."
run_step "react-feather installeren..." yarn add react-feather

echo "🛠️ Database migreren..."
run_step "Database migreren..." php artisan migrate --force

echo "⚙️ Node legacy provider instellen..."
export NODE_OPTIONS=--openssl-legacy-provider
sleep 1  # kleine wacht nodig om spinner te triggeren
run_step "Node legacy provider instellen..." sleep 1

echo "🏗️ Productie build maken..."
run_step "Build maken..." yarn build:production

echo "🧹 Laravel views cache legen..."
run_step "Cache legen..." php artisan view:clear

echo "🔄 Webserver herstarten..."
run_step "Webserver herstarten..." sudo systemctl restart nginx || true

echo "✅ Theme succesvol geïnstalleerd!"
