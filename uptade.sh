#!/bin/bash

# Pull latest changes from GitHub
cd ~
git pull origin main

# Check if package-lock.json changed
if git diff-tree --name-only HEAD^ HEAD | grep -q "package-lock.json"; then
  echo "package-lock.json changed, updating dependencies..."
  npm ci
fi

# Reboot
echo "Reboot in 5 seconds"
sleep 5
sudo reboot