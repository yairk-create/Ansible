#!/bin/bash
set -e
export LC_ALL=C.UTF-8

echo "Setting up Ansible Agent Environment..."

# 1. Install Dependencies
echo "Installing Python dependencies..."
# Ensure pip is installed (might require sudo apt install python3-pip manually if missing)
if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found. Attempting to install..."
    sudo apt update && sudo apt install -y python3-pip python3-venv unzip curl
fi

# Create a virtual environment for Ansible to keep it isolated
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo "Installing Ansible and libraries..."
pip install ansible requests

# 2. Install Ansible Collections
echo "Installing Ansible Collections..."
ansible-galaxy collection install community.general

# 3. Check for Bitwarden CLI, install if missing
if ! command -v bw &> /dev/null; then
    echo "Bitwarden CLI (bw) not found. Downloading..."
    curl -L "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw.zip
    unzip -o bw.zip
    chmod +x bw
    # Move to venv bin so it is in path when activated
    mv bw "$VIRTUAL_ENV/bin/"
    rm bw.zip
    echo "Bitwarden CLI installed to $VIRTUAL_ENV/bin/bw"
else
    echo "Bitwarden CLI found."
fi

# Configure Vaultwarden URL
echo "Configuring Vaultwarden URL..."
bw config server https://vaultwarden.nanunana.page/

echo "Setup complete! Activate the environment with based on where you are running this from."
echo "source venv/bin/activate"
