#!/bin/bash

# Exit on any error
set -e

echo "Starting rc_car setup..."

# Step 1: Update and install dependencies
echo "***********************************************"
echo "[0%] Updating and installing dependencies..."
echo "***********************************************"
sudo apt update && sudo apt upgrade -y
sudo apt install python3-pip python3-spidev python3-libgpiod python3-rpi.gpio python3-pil git npm -y
sudo pip3 install nrf24 spidev flask picamera2

# Step 2: Making files executable
echo "***********************************************"
echo "[20%] Making files executable..."
echo "***********************************************"
cd rc_car
sudo chmod +x robot_pi.py web_server.py
cd ~

# Step 3: Activating SPI and Camera
echo "***********************************************"
echo "[40%] Activating SPI and Camera..."
echo "***********************************************"
sudo raspi-config nonint do_spi 0  # Enable SPI
sudo raspi-config nonint do_camera 0  # Enable Camera

# Step 4: Checking Rc Car repository updates
echo "***********************************************"
echo "[60%] Checking rc_car repository updates..."
echo "***********************************************"
cd ~
git pull origin main
cd rc_car

# Step 5: Creating new Package.json
echo "***********************************************"
echo "[80%] Creating new Package.json..."
echo "***********************************************"
npm init

# Step 6: Reboot to apply changes
echo "***********************************************"
echo "[100%] Setup complete! Rebooting in 5 seconds..."
echo "***********************************************"
sleep 5
sudo reboot