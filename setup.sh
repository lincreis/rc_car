#!/bin/bash

# setup_rc_car.sh
# Automates installation for RC car project on Raspberry Pi OS Bookworm with Python 3.11.2

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
    build-essential pkg-config libcap-dev \
    python3-rpi.gpio python3-spidev \
    ffmpeg libavformat-dev libavcodec-dev libavdevice-dev \
    libavutil-dev libavfilter-dev libswscale-dev libswresample-dev \
    cmake git

# Enable SPI and Camera
echo "Enabling SPI and Camera..."
raspi-config nonint do_spi 0  # Enable SPI
raspi-config nonint do_camera 0  # Enable Camera

# Set up project directory
echo "Setting up project directory..."
cd /home/pi
git clone git@github.com:lincreis/rc_car.git
cd rc_car

# Build RF24 library from source since libnrf24-dev is unavailable
echo "Building RF24 C++ library from source..."
git clone https://github.com/nRF24/RF24.git
cd RF24
mkdir -p build
cd build
cmake ..
make -j1  # Single-threaded due to Pi Zero's limited resources
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

# Install Python packages
echo "Installing Python packages..."
pip install RF24 flask av==10.0.0 picamera2  # av 10.0.0 works with FFmpeg 6

# Set permissions on scripts
cd /home/pi/rc_car
chmod +x joystick_pi.py robot_pi.py web_server.py

# Deactivate virtual environment
deactivate

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