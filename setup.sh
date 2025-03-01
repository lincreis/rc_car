#!/bin/bash

# Exit on any error
set -e

# Step 1: Update and install dependencies
echo "***********************************************"
echo "Updating dapendencies..."
echo "***********************************************"
sudo apt update && sudo apt upgrade -y
sudo apt install python3-pip python3-spidev python3-libgpiod python3-rpi.gpio python3-pil -y
sudo pip3 install nrf24 spidev flask picamera2

# Step 2: Activating SPI and Camera
echo "***********************************************"
echo "Activating SPI and Camera..."
echo "***********************************************"

# Navigate to Interface Options > SPI > Enable
sudo raspi-config nonint do_spi 0  # Enable SPI
# Navigate to Interface Options > Camera > Enable
sudo raspi-config nonint do_camera 0  # Enable Camera

# Step 4: Clone your GitHub fork
echo "***********************************************"
echo "Cloning Rc Car repository..."
echo "***********************************************"
cd ~
git clone https://github.com/lincreis/ZeroBot.git
cd rc_car
sudo chmod +x robot_pi.py web_server.py

# Step 5: Reboot to apply changes
echo "***********************************************"
echo "Setup complete! Rebooting in 5 seconds..."
echo "***********************************************"
sleep 5
sudo reboot