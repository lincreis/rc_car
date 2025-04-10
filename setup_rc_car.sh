#!/bin/bash

# Exit on any error
set -e

# Update system
echo "******************************************************"
echo "******************************************************"
echo "Update system..."
echo "******************************************************"
echo "******************************************************"
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "******************************************************"
echo "******************************************************"
echo "Install required packages..."
echo "******************************************************"
echo "******************************************************"
sudo apt install -y python3-pip python3-venv python3-dev libboost-python-dev python3-git libatlas-base-dev pigpio python3-picamera2

# Start pigpio daemon
echo "******************************************************"
echo "******************************************************"
echo "Start pigpio daemon..."
echo "******************************************************"
echo "******************************************************"
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

# Enable camera and SPI
echo "******************************************************"
echo "******************************************************"
echo "Enable camera and SPI..."
echo "******************************************************"
echo "******************************************************"
sudo raspi-config nonint do_camera 0
sudo raspi-config nonint do_spi 0

# Clone repository
echo "******************************************************"
echo "******************************************************"
echo "Clone repository..."
echo "******************************************************"
echo "******************************************************"
git clone https://github.com/lincreis/rc_car.git
cd rc_car

# Create virtual environments
echo "******************************************************"
echo "******************************************************"
echo "Create virtual environments..."
echo "******************************************************"
echo "******************************************************"
mkdir env
cd ~/rc_car
python3 -m venv venv

# Activate and install dependencies for the Rc Car
echo "******************************************************"
echo "******************************************************"
echo "Activate and install dependencies for the Rc Car..."
echo "******************************************************"
echo "******************************************************"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# Make scripts executable
echo "******************************************************"
echo "******************************************************"
echo "Make scripts executable..."
echo "******************************************************"
echo "******************************************************"
chmod +x car_control.py joystick.py

echo "Setup complete! Access the web interface at http://<raspberry_pi_ip>:8000"
echo "Rebooting in 5 seconds..."
sleep 5
sudo reboot