#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[31m[-] Please run this script as root (sudo).\e[0m"
    exit 1
fi

# --- CONFIGURATION ---
PTERO_DIR="/var/www/pterodactyl"
THEME_URL="https://github.com/denzivps/stellar-theme/archive/refs/heads/main.tar.gz"

# --- HELPER FUNCTIONS ---
show_spinner() {
    local pid=$1
    local delay=0.1
    local spin='|/-\\'
    local i=0
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
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

# --- INSTALLATION FUNCTION ---
install_theme() {
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)

    echo -e "\n\e[36m🚀 Starting Stellar Theme Installation with Webpack-Fix...\e[0m"

    # 1. Node.js 22 & Yarn Setup
    echo "🔧 Setting up Node.js 22 and Yarn..."
    run_step "Installing Node.js 22 & Yarn..." bash -c '
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
        apt-get update
        apt-get install -y nodejs
        npm install -g yarn
    '

    # 2. Download and Extract Theme
    echo "⏬ Fetching theme files..."
    run_step "Downloading theme archive..." curl -L "$THEME_URL" -o "$TEMP_DIR/theme.tar.gz"
    run_step "Extracting theme files..." tar -xzf "$TEMP_DIR/theme.tar.gz" -C "$TEMP_DIR"

    local THEME_DIR
    THEME_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "stellar-theme-*")
    echo "🔁 Applying theme files to Pterodactyl..."
    cp -r "$THEME_DIR/"* "$PTERO_DIR/"

    # 3. Enter Pterodactyl Directory
    cd "$PTERO_DIR" || exit 1

    # 4. Install Dependencies
    echo "📦 Installing required npm packages..."
    run_step "Adding react-feather and path-browserify..." yarn add react-feather path-browserify

    # 5. Apply Webpack Patch
    echo "🛠️ Patching webpack configuration..."
    run_step "Applying patch to webpack.config.js..." bash -c '
        if ! grep -q "path-browserify" webpack.config.js; then
            sed -i "/symlinks: false,/a \        fallback: { \"path\": require.resolve(\"path-browserify\") }," webpack.config.js
        fi
    '

    # 6. Build Assets
    echo "🏗️ Building production assets (this may take a few minutes)..."
    export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=4096"
    yarn build:production

    # 7. Finalizing
    echo "🧹 Optimizing panel & cleaning cache..."
    run_step "Migrating database..." php artisan migrate --force
    run_step "Clearing view cache..." php artisan view:clear
    run_step "Clearing config cache..." php artisan config:clear
    run_step "Setting file permissions..." chown -R www-data:www-data "$PTERO_DIR"/*

    # 8. Restart Web Server & Queue
    echo "🔄 Restarting web server and queue..."
    php artisan queue:restart > /dev/null 2>&1 || true
    systemctl restart nginx || true

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo -e "\n\e[92m✅ INSTALLATION COMPLETED SUCCESSFULLY!\e[0m"
    echo -e "\e[33mStellar Theme has been applied with Node 22 build settings.\e[0m\n"
}

# --- UNINSTALL / RESTORE FUNCTION ---
uninstall_theme() {
    echo -e "\n\e[33m⚠️  Warning: This will restore default Pterodactyl panel files and remove custom theme modifications.\e[0m"
    read -rp "Are you sure you want to proceed? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "\e[31mOperation cancelled.\e[0m\n"
        return
    fi

    echo -e "\n\e[36m🔄 Restoring Default Pterodactyl Panel Theme...\e[0m"
    cd "$PTERO_DIR" || exit 1

    # 1. Download official panel release
    echo "⏬ Fetching latest official Pterodactyl release..."
    run_step "Downloading official panel archive..." curl -Lo /tmp/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz

    # 2. Extract and restore default files
    echo "🔁 Restoring original panel files..."
    run_step "Extracting default files..." tar -xzvf /tmp/panel.tar.gz -C "$PTERO_DIR"
    run_step "Setting folder permissions..." chmod -R 755 storage/* bootstrap/cache/

    # 3. Update dependencies & clear cache
    echo "🧹 Rebuilding dependencies and clearing cache..."
    run_step "Updating Composer dependencies..." composer install --no-dev --optimize-autoloader
    run_step "Clearing view cache..." php artisan view:clear
    run_step "Clearing config cache..." php artisan config:clear
    run_step "Running migrations..." php artisan migrate --force
    run_step "Fixing file permissions..." chown -R www-data:www-data "$PTERO_DIR"/*

    # 4. Restart services
    echo "🔄 Restarting web server and background workers..."
    php artisan queue:restart > /dev/null 2>&1 || true
    systemctl restart nginx || true

    # Cleanup
    rm -f /tmp/panel.tar.gz

    echo -e "\n\e[92m✅ UNINSTALLATION COMPLETED!\e[0m"
    echo -e "\e[33mYour Pterodactyl panel has been restored to its default state.\e[0m\n"
}

# --- MAIN MENU ---
clear
echo "=================================================="
echo "          Pterodactyl Theme Manager               "
echo "=================================================="
echo " 1) Install Stellar Theme"
echo " 2) Uninstall Theme (Restore Default Pterodactyl)"
echo " 3) Exit"
echo "=================================================="
read -rp "Please select an option [1-3]: " CHOICE

case "$CHOICE" in
    1)
        install_theme
        ;;
    2)
        uninstall_theme
        ;;
    3)
        echo "Exiting. Goodbye!"
        exit 0
        ;;
    *)
        echo -e "\e[31mInvalid option selected. Exiting.\e[0m"
        exit 1
        ;;
esac
