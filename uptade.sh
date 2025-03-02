#!/bin/bash

# Pull latest changes from GitHub
cd rc_car
git pull origin main
git stash         # Stash (hide) your local changes
git pull origin main  # Pull latest changes from remote
git stash pop     # Reapply your local changes


# Check if package-lock.json changed
if git diff-tree --name-only HEAD^ HEAD | grep -q "package-lock.json"; then
  echo "package-lock.json changed, updating dependencies..."
  npm ci
fi

sudo chmod +x robot_pi.py web_server.py

# Reboot
echo "************************"
echo "************************"
echo "Update Complete"
echo "************************"
echo "************************"
sleep 5