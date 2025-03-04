#!/bin/bash

# Script to set up and test NRF24L01+PA+LNA on Raspberry Pi Zero
# Custom pinout: CE on GPIO 8, CSN on GPIO 7
# Using nrf24 library with pigpio
# Date: March 03, 2025

echo "Starting NRF24L01+PA+LNA setup and test on Raspberry Pi Zero..."

# Update the system
echo "Updating package lists..."
sudo apt update -y
sudo apt upgrade -y

# Enable SPI interface
echo "Enabling SPI interface..."
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI enabled in /boot/config.txt. Reboot may be required after script."
else
    echo "SPI is already enabled."
fi

# Install required packages
echo "Installing necessary dependencies..."
sudo apt install -y python3-pip python3-dev python3-spidev python3-venv git pigpio python3-pigpio

# Create a directory for the test files
echo "Creating test directory..."
mkdir -p ~/nrf24_test
cd ~/nrf24_test

# Create and activate a Python virtual environment
echo "Creating and activating Python virtual environment..."
python3 -m venv nrf24_venv
source nrf24_venv/bin/activate

# Install nrf24 library in the virtual environment
echo "Installing nrf24 Python library in virtual environment..."
pip3 install nrf24

# Start pigpiod daemon if not already running
echo "Checking and starting pigpiod daemon..."
if ! pgrep -f pigpiod > /dev/null; then
    sudo pigpiod
    sleep 2  # Give the daemon a moment to start
    echo "pigpiod daemon started."
else
    echo "pigpiod daemon is already running."
fi

# Create a Python transmitter script with custom CE and CSN pins
echo "Creating transmitter test script..."
cat << EOF > nrf24_transmitter.py
import time
import pigpio
from nrf24 import NRF24

# Connect to pigpio daemon
pi = pigpio.pi()
if not pi.connected:
    print("Failed to connect to pigpiod daemon!")
    exit(1)

# Initialize NRF24L01 with pigpio and CE pin
radio = NRF24(pi, ce=8)  # CE on GPIO 8
radio.set_spi(1, 0)  # SPI bus 1, CSN on GPIO 7 (SPI0 CE1)
radio.setRetries(15, 15)  # Max retries and delay
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(NRF24.BR_1MBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.setAutoAck(True)
radio.openWritingPipe([0xe7, 0xe7, 0xe7, 0xe7, 0xe7])
radio.openReadingPipe(1, [0xc2, 0xc2, 0xc2, 0xc2, 0xc2])
radio.printDetails()

print("Starting transmission test...")
while True:
    message = "Hello NRF24L01"
    radio.write(message.encode('utf-8'))
    print(f"Sent: {message}")
    time.sleep(1)
EOF

# Create a Python receiver script with custom CE and CSN pins (optional)
echo "Creating receiver test script (optional)..."
cat << EOF > nrf24_receiver.py
import time
import pigpio
from nrf24 import NRF24

# Connect to pigpio daemon
pi = pigpio.pi()
if not pi.connected:
    print("Failed to connect to pigpiod daemon!")
    exit(1)

# Initialize NRF24L01 with pigpio and CE pin
radio = NRF24(pi, ce=8)  # CE on GPIO 8
radio.set_spi(1, 0)  # SPI bus 1, CSN on GPIO 7 (SPI0 CE1)
radio.setRetries(15, 15)  # Max retries and delay
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(NRF24.BR_1MBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.setAutoAck(True)
radio.openWritingPipe([0xc2, 0xc2, 0xc2, 0xc2, 0xc2])
radio.openReadingPipe(1, [0xe7, 0xe7, 0xe7, 0xe7, 0xe7])
radio.printDetails()

print("Starting receiver test...")
radio.startListening()

while True:
    if radio.available():
        received = radio.read()
        try:
            print(f"Received: {received.decode('utf-8')}")
        except UnicodeDecodeError:
            print(f"Received (raw): {received}")
    time.sleep(0.1)
EOF

# Set permissions
chmod +x nrf24_transmitter.py nrf24_receiver.py

# Check if SPI is loaded
echo "Checking SPI module..."
if lsmod | grep -q spi; then
    echo "SPI module is loaded."
else
    echo "Loading SPI module..."
    sudo modprobe spi-bcm2835
fi

# Test the transmitter using the virtual environment
echo "Running transmitter test (Ctrl+C to stop)..."
echo "If you have a second NRF24L01 device, run nrf24_receiver.py on it to see the messages."
~/nrf24_test/nrf24_venv/bin/python3 nrf24_transmitter.py &

# Keep the script running to allow observation
echo "Transmitter is running in the background. Check output above."
echo "To stop, use 'pkill -f nrf24_transmitter.py' or reboot."
echo "If SPI was just enabled, please reboot and rerun this script with './nrf24_test.sh'."
wait

# Deactivate the virtual environment
deactivate