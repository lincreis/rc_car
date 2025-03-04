#!/bin/bash

# Pull latest changes from GitHub
cd rc_car
git pull origin main
git stash         # Stash (hide) your local changes
git pull origin main  # Pull latest changes from remote
git stash pop     # Reapply your local changes

# Reboot
echo "************************"
echo "************************"
echo "Update Complete"
echo "************************"
echo "************************"
sleep 5