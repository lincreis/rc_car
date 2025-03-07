#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3-pip python3-venv python3-dev libboost-python-dev python3-git libatlas-base-dev pigpio python3-picamera2

# Start pigpio daemon
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

# Enable camera and SPI
sudo raspi-config nonint do_camera 0
sudo raspi-config nonint do_spi 0

# Clone repository
git clone https://github.com/lincreis/rc_car.git
cd rc_car

# Create virtual environments
mkdir env
cd ~/rc_car/env
python3 -m venv car_venv
python3 -m venv web_venv
python3 -m venv nrf24_env

# Activate and install dependencies for car control
source car_venv/bin/activate
pip install --upgrade pip
pip install RPi.GPIO pigpio
deactivate

# Activate and install dependencies for web server
source web_venv/bin/activate
pip install --upgrade pip
pip install picamera2
deactivate

# Activate and install dependencies for radio
source nrf24_venv/bin/activate
pip install --upgrade pip
pip install pyrf24 spidev
deactivate

# Make scripts executable
chmod +x car_control.py web_server.py joystick.py

echo "Setup complete! Access the web interface at http://<raspberry_pi_ip>:8000"
echo "Rebooting in 5 seconds..."
sleep 5
sudo reboot