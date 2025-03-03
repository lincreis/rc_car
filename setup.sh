#!/bin/bash

# setup_rc_car.sh
# Installs RF24 and dependencies for RC car project on Raspberry Pi OS Bookworm with Python 3.11.2
# Clones project files from GitHub repository

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

echo "Starting setup for RC car project on Bookworm..."

# Update and upgrade system
echo "Updating system..."
apt update && apt upgrade -y

# Install essential tools and libraries
echo "Installing system dependencies..."
apt install -y python3 python3-pip python3-dev python3-venv \
    build-essential cmake git libboost-python-dev libboost-thread-dev \
    python3-rpi.gpio python3-spidev \
    ffmpeg libavformat-dev libavcodec-dev libavdevice-dev \
    libavutil-dev libavfilter-dev libswscale-dev libswresample-dev \
    pkg-config libcap-dev

# Enable SPI and Camera
echo "Enabling SPI and Camera..."
raspi-config nonint do_spi 0  # Enable SPI
raspi-config nonint do_camera 0  # Enable Camera

# Increase swap size to handle compilation (Pi Zero has 512MB RAM)
echo "Increasing swap size to 1GB for compilation..."
dphys-swapfile swapoff
sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon

# Set up project directory by cloning from GitHub
echo "Setting up project directory..."
cd /home/pi
git clone https://github.com/lincreis/rc_car.git
cd rc_car

# Verify required Python files are present in the cloned repository
echo "Checking for Python scripts in cloned repository..."
for file in joystick_pi.py robot_pi.py web_server.py; do
    if [ ! -f "$file" ]; then
        echo "Error: $file not found in ~/rc_car/. Ensure the repository contains all required scripts."
        exit 1
    fi
done

# Clone and build RF24 C++ library from source
echo "Building RF24 C++ library from source..."
git clone https://github.com/nRF24/RF24.git RF24-lib
cd RF24-lib
mkdir -p build
cd build
cmake -DRF24_SPIDEV=ON -DRF24_DRIVER=SPIDEV ..  # Use SPIDEV driver for Raspberry Pi
make -j1  # Single-threaded to avoid memory issues
make install
ldconfig  # Update library cache
cd ../..

# Create and activate virtual environment
echo "Creating Python 3.11 virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install Python RF24 package
echo "Installing Python RF24 package..."
pip install RF24  # Links to the built C++ library

# Install remaining Python packages
echo "Installing additional Python packages..."
pip install flask av==10.0.0 picamera2

# Set permissions on scripts
chmod +x joystick_pi.py robot_pi.py web_server.py

# Deactivate virtual environment
deactivate

# Revert swap size
echo "Reverting swap size to 100MB..."
dphys-swapfile swapoff
sed -i 's/CONF_SWAPSIZE=1024/CONF_SWAPSIZE=100/' /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon

# Set ownership to pi user
chown -R pi:pi /home/pi/rc_car

# Instructions for user
echo "Setup complete!"
echo "To run on Joystick Pi: cd ~/rc_car && sudo ./joystick_pi.py"
echo "To run on Robot Pi: cd ~/rc_car && sudo ./robot_pi.py & sudo ./web_server.py &"
echo "Access the web interface at http://<robot-pi-ip>:5000"

# Reboot to apply changes
echo "Rebooting in 5 seconds..."
sleep 5
reboot