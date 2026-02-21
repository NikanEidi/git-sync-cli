#!/bin/bash

# Git-Sync Global Installer
# Fetches the latest version from GitHub and installs it globally

echo -e "\033[1;34mℹ\033[0m Downloading Git-Sync from GitHub..."

sudo curl -sSL https://raw.githubusercontent.com/NikanEidi/git-sync-cli/main/git-sync.sh -o /usr/local/bin/git-sync

echo -e "\033[1;34mℹ\033[0m Setting executable permissions..."
sudo chmod +x /usr/local/bin/git-sync

echo ""
echo -e "\033[1;32m✔\033[0m Git-Sync installed successfully!"
echo -e "\033[2mType 'git-sync' anywhere in your terminal to launch the dashboard.\033[0m"
echo ""
