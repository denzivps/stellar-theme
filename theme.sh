#!/bin/bash

# Stop if anything fails
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

# Theme URL
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/heads/main.tar.gz"

# Temporary directory
TEMP_DIR=$(mktemp -d)

# Download theme
echo "⏬ Theme downloaden..."
curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz" > /dev/null 2>&1 &
show_spinner $!

# Extract theme
echo "📦 Uitpakken..."
tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR" > /dev/null 2>&1
show_spinner $!

# Find extracted theme directory
THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")

if [ ! -d "$THEME_DIR" ]; then
  echo "❌ Theme-map niet gevonden."
  exit 1
fi

# Copy theme files
echo "🔁 Bestanden kopiëren naar /var/www/pterodactyl..."
cp -r "$THEME_DIR/"* /var/www/pterodactyl/ > /dev/null 2>&1
show_spinner $!

# Change ownership and permissions
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl

# Go to Pterodactyl directory
cd /var/www/pterodactyl

# Check if Node.js is installed
if command -v node > /dev/null 2>&1 && command -v yarn > /dev/null 2>&1; then
    echo "✅ Node.js en Yarn zijn al geïnstalleerd."
else
    echo "🔧 Node.js en Yarn installeren..."
    sudo apt-get install -y ca-certificates curl gnupg > /dev/null 2>&1
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null 2>&1
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y nodejs > /dev/null 2>&1
    sudo npm install -g yarn > /dev/null 2>&1
fi
show_spinner $!

# Install react-feather
echo "📦 react-feather installeren..."
yarn add react-feather > /dev/null 2>&1
show_spinner $!

# Migrate database
echo "🛠️ Database migreren..."
php artisan migrate --force > /dev/null 2>&1
show_spinner $!

# Set Node.js legacy provider
echo "⚙️ Node legacy provider instellen..."
export NODE_OPTIONS=--openssl-legacy-provider
show_spinner $!

# Build production
echo "🏗️ Productie build maken..."
yarn build:production > /dev/null 2>&1
show_spinner $!

# Clear Laravel view cache
echo "🧹 Laravel views cache legen..."
php artisan view:clear > /dev/null 2>&1
show_spinner $!

# Restart webserver
echo "🔄 Webserver herstarten..."
sudo systemctl restart nginx > /dev/null 2>&1 || true
show_spinner $!

# Done
echo "✅ Theme succesvol geïnstalleerd!"
